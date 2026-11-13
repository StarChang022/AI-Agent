# 批次匯入憑證 API（後端實作紀錄）

> 對應 `docs/資料模型.md` §5.5、`docs/批次匯入規格.md` 第二節、`docs/OCR辨識規格.md` §9。本文件記錄後端實際的 API 與規則。
> 程式：`backend/app/controllers/api/ocr_batches_controller.rb`、`backend/app/services/ocr/batch_recognizer.rb`。

## 共通

- 只有超級管理員可用（員工 → 403 `forbidden`）；開放 `role=expense`、`income`（代墊款不開放）；確認時沿用上傳時的 role 對應我方與對方。
- 錯誤格式同 `/api/ocr/recognize`：`{ code, message, quota?, required? }`。
- 單筆表單的 `/api/ocr/recognize` 不受影響（單檔仍是 5MB、每頁扣 1 次）。
- 流程分兩步：**上傳時只找每張憑證的位置**（不辨識內容、不扣次）；**確認後才把每張裁成單張逐張辨識**，扣辨識出內容的張數。整頁一次辨識多張時每張的解析度不夠，發票號碼、金額常讀不到，所以改成裁切後再辨識。
- 兩步各自最多 10 件同時處理、各最多 90 秒（正式環境前面的 Cloudflare 約 100 秒斷線）。
- **同一家公司同時只能有一個上傳或確認在進行**：用快取當鎖（key 綁公司），120 秒自動過期；請求結束一定釋放，出錯也一樣。第二個回 409 `batch_in_progress`「上一批憑證還在辨識中，請稍候再試」。取消不受影響。

## 1. POST /api/ocr/batch — 找位置（不扣次、不辨識內容）

multipart：`files[]`、`role=expense` 或 `income`

**檢查順序**（同 `/recognize`）：role → 檔案數 → 格式 → 單檔大小 → GCP 設定 → 剩餘次數（剩 0 就擋，不送 Google）→ 同公司是否有批次在進行 → 總頁數 → 找位置。

| 情況 | 回應 |
|---|---|
| role 不是 expense、income | 400 `invalid_role` |
| 沒有檔案 / 格式不是 JPG、PNG、WEBP、HEIC、PDF | 400 `invalid_file_type` |
| 超過 5 個檔案 | 400 `too_many_files` |
| 單檔超過 20MB | 413 `file_too_large` |
| 全部合計超過 5 頁 | 400 `too_many_pages`：「最多 5 頁（目前 N 頁）」 |
| 剩 0 次 | 429 `quota_exhausted` |
| 同一家公司已有上傳或確認在進行 | 409 `batch_in_progress` |
| Google / pdfinfo / pdfseparate 無法使用、暫存寫入失敗 | 503 `ocr_unavailable` |
| 一張憑證都沒找到 | 422 `ocr_no_result`（附 quota，不發 token、不扣次） |

**處理方式**

- PDF 用 poppler 的 `pdfseparate` 拆成單頁（不繼承環境變數、限制記憶體與時間，同 pdfinfo）；圖片整張是一頁。HEIC、WEBP 轉成 JPEG（WEBP 不是憑證附件接受的格式）。
- 每頁送 Gemini 一次（`GeminiClient#locate_receipts`，只找位置的 prompt），回每張憑證的框 `box_2d: [ymin, xmin, ymax, xmax]`，以整頁為範圍、0–1000 正規化。框夾在 0–1000 內、顛倒的對調；寬或高不到 1% 的不算。
- 照片有旋轉標記（EXIF orientation）時先轉正再送，確認時裁切用的圖也轉正，座標才對得上。
- 任一頁遇到 Google 無法使用 → 其他頁不再送出、進行中的頁中止，整批 503。
- 期限到了還沒找完的頁 `receipt_count` 為 0 並提醒；已完成的頁照常回傳。全部逾時或都沒找到 → 422 `ocr_no_result`。
- 每頁最多 10 張、整批最多 50 張（依檔案、頁碼順序），超過的捨棄並加提醒。5 頁 × 每頁 10 張剛好 50 張，整批上限目前不會觸發，留著當保險。
- 檔案轉檔失敗、讀不出頁數、某頁 Google 回 400 → 略過該檔案或該頁並加提醒，其他照常處理。
- 暫存在 `Rails.cache` 30 分鐘：每頁的原始檔案與找到的框。key 綁公司 + 使用者 + 隨機 token（32 字元）；別家公司或同公司別人的 token 查不到。

**200**

```json
{
  "token": "…32 字元…",
  "expires_at": "2026-10-29T15:30:00+08:00",
  "receipt_count": 3,
  "pages": [
    { "page_id": "0-1", "file_index": 0, "filename": "收據.pdf", "page_number": 1, "receipt_count": 2 },
    { "page_id": "0-2", "file_index": 0, "filename": "收據.pdf", "page_number": 2, "receipt_count": 0 },
    { "page_id": "1-1", "file_index": 1, "filename": "a.jpg",    "page_number": 1, "receipt_count": 1 }
  ],
  "warnings": [],
  "quota": { "monthly_remaining": 20, "purchased_remaining": 0 }
}
```

- `receipt_count` 是找到的框數，也是確認時最多扣的次數。
- `page_id` 為「檔案序（從 0）-頁碼（從 1）」；空白頁也列出，`receipt_count` 為 0。
- 讀不出頁數的檔案不列在 `pages`，只出現在 `warnings`。

## 2. POST /api/ocr/batch/:token/confirm — 逐張辨識、扣次並帶出內容

JSON：`{ "page_ids": ["0-1", "1-1"] }`

| 情況 | 回應 |
|---|---|
| token 不存在、過期、已確認過、不是本人本公司 | 404 `batch_expired` |
| `page_ids` 空白、有不存在的頁 | 400 `invalid_page_ids` |
| 所選頁都沒有憑證 | 400 `invalid_page_ids` |
| 同一家公司已有上傳或確認在進行（含同一批連按兩次） | 409 `batch_in_progress` |
| 剩 0 次 | 429 `quota_exhausted` |
| 剩餘次數不夠所選頁的框數 | 429 `quota_insufficient`（附 `required`），暫存保留，不送 Google |
| Google / pdftoppm 無法使用 | 503 `ocr_unavailable`，不扣次、暫存保留，可以再按確認 |

**處理方式**

1. 先檢查剩餘次數夠不夠所選頁的框數（確認前顯示的「最多扣 N 次」）。
2. 所選頁轉成圖：PDF 用 `pdftoppm` 轉成彩色 JPEG、長邊 3600px（印章多半是藍色，不轉灰階；同 pdfinfo 的安全做法：不經 shell、不繼承環境變數、Linux 限記憶體、逾時終止）；圖片用 libvips 讀，照旋轉標記轉正。
3. 每個框四周多留整頁 3% 的邊（夾在圖內），裁成單張 JPEG（長邊超過 3600px 先縮小）。
4. 每張用單張的 prompt（同 `/recognize`）辨識，並各自解 QR、照 `docs/OCR辨識規格.md` §3.2 套用（有電子發票 QR 時以 QR 為準）。
5. 辨識完在公司資料列鎖內刪暫存、扣次：**扣次 = 辨識出內容的張數**（ResultMerger 判斷有內容的才算）。極少數情況下同時有別的 OCR 用掉次數，扣到 0 為止，結果照常回傳。
6. 成功後暫存刪掉，同一 token 不能確認第二次。

- 辨識不出內容、Google 對那張回 400、期限到了還沒辨識完的憑證**不扣次**，不放進 `receipts`，改放 `warnings`。前端用「所選頁框數 − receipts 數」顯示沒扣次的張數。
- 所選的憑證**全部辨識不出內容**時回 200、`receipts` 為空、`quota.used` 為 0，暫存照常刪掉。
- 同一批同時確認兩次：後到的拿不到鎖回 409，或前一個已完成、暫存已刪回 404；只會扣一次。

**200**

```json
{
  "receipts": [
    {
      "page_id": "0-1", "page_number": 1, "filename": "收據.pdf",
      "result": { "merged": {}, "conflicts": {}, "confidence": {}, "warnings": [] }
    }
  ],
  "pages": [
    { "page_id": "0-1", "attachment": { "id": "uuid", "filename": "收據_p1.pdf", "mime_type": "application/pdf", "byte_size": 12345, "url": "/api/files/…" } }
  ],
  "warnings": ["第 1 個檔案第 1 頁第 2 張未辨識出內容，未扣次"],
  "quota": { "used": 1, "monthly_remaining": 19, "purchased_remaining": 0 }
}
```

- `result` 結構同 `/api/ocr/recognize` 成功回應（不含 quota）；每張憑證只有一個來源，`source_index` 一律 0。
- 附件放在 `pages`：只列所選、有辨識出內容的頁，每頁一份（同一頁多張憑證時不重複傳）。前端依 `page_id` 對應。附件是整頁，不是裁好的單張。
- `attachment` 是該頁檔案，已存成**暫存檔**（格式見 `attachments-api.md`）。同一頁拆出的多筆支出／收入儲存時都帶同一個 `id`，共用一個檔案；沒有掛上的由每日排程清除。
- 檔案內容：PDF 為單頁 PDF（檔名加 `_p頁碼`），圖片為原圖（HEIC、WEBP 轉 JPEG，副檔名改 `.jpg`）。
- 單頁檔案超過 5MB（憑證附件上限）時 `attachment` 為 null，`warnings` 加提醒。
- `warnings` 包含所選頁在上傳時的提醒（例如超過 10 張），以及確認時沒扣次的憑證。

## 3. DELETE /api/ocr/batch/:token — 取消

刪暫存、不扣次，回 204；找不到也回 204。

## 提醒文字

「第 K 張」照找到的順序（由上到下、由左到右）。圖片不寫頁碼；一頁只有一張、或整頁都是同一個原因時不寫第幾張。

| 時機 | 情況 | 文字 |
|---|---|---|
| 上傳 | 檔案轉檔失敗、讀不出頁數 | 第 N 個檔案無法辨識，已略過 |
| 上傳 | 某頁 Google 回 400 | 第 N 個檔案第 P 頁無法辨識，已略過 |
| 上傳 | 某頁超過 10 張 | 第 N 個檔案第 P 頁超過 10 張憑證，只取前 10 張 |
| 上傳 | 期限到了還沒找完 | 第 N 個檔案第 P 頁辨識逾時，未扣次，可重新上傳該頁 |
| 上傳 | 整批超過 50 張 | 憑證超過 50 張，只取前 50 張 |
| 確認 | 辨識不出內容 | 第 N 個檔案第 P 頁第 K 張未辨識出內容，未扣次 |
| 確認 | 那張 Google 回 400、這頁轉不成圖 | 第 N 個檔案第 P 頁第 K 張無法辨識，未扣次 |
| 確認 | 期限到了還沒辨識完 | 第 N 個檔案第 P 頁第 K 張辨識逾時，未扣次，可重新上傳該頁 |
| 確認 | 單頁超過 5MB | 第 N 個檔案第 P 頁的檔案超過 5MB，未附上憑證檔，請自行補上 |

## 部署與已知限制

- nginx 對 `POST /api/ocr/batch` 與確認 API 放寬上傳大小與等待時間（`frontend/nginx.conf`，前端負責）。
- 每次 Gemini 呼叫最長等 60 秒；兩步各最多 90 秒。上傳最多 5 頁、確認最多 50 張，10 件同時處理，正常一到五輪內做完，90 秒期限只在 Google 回應異常時用上。
- 確認時最多 5 頁同時轉圖，每頁彩色 3600px 約 30MB 記憶體；轉完、裁完就釋放。
- 同公司鎖用快取實作：solid_cache 對不存在的 key 寫入不是原子操作，所以寫入後再讀回確認是自己的值；兩個請求幾乎同時進來時，極少數情況兩個都會通過。確認時以「刪暫存成功」決定誰扣次，所以不會重複扣次，只會多送 Google。
- 正式環境快取是 solid_cache（總量 256MB，滿了會先清最舊的）；同時很多批次在暫存時，較早的批次可能被清掉，確認時回 404 `batch_expired`，使用者需重新上傳。
- 開發環境記憶體快取改為 256MB（預設 32MB 放不下多頁檔案）。
- 本機沒有 libzbar 時 QR 一律當作沒有，只能在正式環境驗證。
