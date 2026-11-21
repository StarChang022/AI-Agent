# OCR 辨識規格

> 範圍：新增支出、代墊款、收入三個表單共用的憑證 OCR 辨識。批次匯入憑證（一次多張不同憑證）另有端點，見 §9。
> Vendor：Google Vertex AI Gemini 3.1 Flash-Lite（模型直接回欄位 JSON，後端做格式檢查）；見技術選型 §6 與本文件 §3。
> 存檔策略：圖檔先上傳成暫存檔（`docs/資料模型.md` §2.4、`docs/dev/attachments-api.md`），辨識時帶暫存檔 id，OCR 本身不建立或刪除檔案。
> **策略**：多張憑證**每張獨立送 Gemini 辨識**，後端比對後回「可自動合併的欄位」+「衝突清單」給前端跳彈窗讓使用者挑。

## 1. 端點

```
POST /api/ocr/recognize
Content-Type: application/json
Authorization: Bearer <jwt>
```

### Request fields

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `attachment_ids[]` | string | ✓ | 1–5 個圖檔 id（2026-11-03 起取代 `files[]`）：自己剛上傳的暫存檔，或目前使用者讀得到的已存圖檔；圖檔限制同憑證附件（JPG／PNG／PDF，單檔 ≤ 5 MB）。找不到時回 400 `attachment_not_found` |
| `role` | string | ✓ | `expense` / `reimbursement` / `income`；決定「我方 vs 對方」欄位對應 |

多檔語意：「同一張憑證的多個鏡位 / 分段拍 / 多頁 PDF」。後端**對每個檔案獨立呼叫** Gemini，再把結果 normalize 後比對衝突，回單一 response。要辨識多張**不同**憑證請走批次匯入另案，不走這支 endpoint。

計費單位：**每張圖 / 每頁 PDF = 1 次配額**。多檔混 PDF 的場景會按實際頁數累計（PDF 頁數由後端用 `pdfinfo` 數）（例如 3 檔含一份 5 頁 PDF = 7 次）。扣次數**只在 Gemini 成功回傳時**發生；格式錯誤、檔案過大被擋下不扣次。送出前先算總頁數，剩餘次數不夠就整個請求不辨識、不扣次（見 §5 超額行為）。

## 2. Response

### Success (200)

```json
{
  "merged": {
    "documentType": "invoice",
    "incurredAt": "2026-10-15",
    "ourTaxId": null,
    "ourName": null,
    "counterpartyTaxId": "87654321",
    "counterpartyName": null,
    "invoicePrefix": "AB",
    "invoiceDigits": "98765432",
    "taxRate": "business_5",
    "preTaxAmt": 1200,
    "taxAmt": 60,
    "amount": 1260,
    "items": [
      { "name": "A4 影印紙", "quantity": 3, "unitPrice": 200, "subtotal": 600 }
    ]
  },
  "conflicts": {
    "fields": [
      {
        "field": "counterpartyName",
        "candidates": [
          { "value": "福華文具行", "sourceIndex": 0, "confidence": 0.91 },
          { "value": "福華文具", "sourceIndex": 1, "confidence": 0.74 }
        ]
      }
    ],
    "items": [
      {
        "candidates": [
          { "item": { "name": "鉛筆", "quantity": 3, "unitPrice": 20, "subtotal": 60 }, "sourceIndex": 0 },
          { "item": { "name": "鉛筆", "quantity": 5, "unitPrice": 20, "subtotal": 100 }, "sourceIndex": 1 }
        ]
      }
    ]
  },
  "confidence": {
    "overall": 0.87,
    "lowFields": ["counterpartyName"]
  },
  "warnings": ["counterpartyName 有多個候選值，請人工確認"],
  "quota": {
    "used": 1,
    "monthlyRemaining": 97,
    "purchasedRemaining": 50
  }
}
```

`merged` = 已能自動合併或只有單一來源的結果，可直接 bind 到表單。**列在 `conflicts.fields` 的欄位，`merged` 裡一律為 `null`**（等使用者在彈窗挑選；彈窗沒選就保持空白）。
`conflicts.fields` = 多張都辨識出但值不同的頂層欄位；每個 field 的 candidates 給前端跳彈窗讓使用者 radio 選。
`conflicts.items` = 被判定為「可能同一品項」但數量/小計有差的 line_item 群；使用者需挑一個保留。
`quota.used` = 本次扣除的次數（通常 = 傳入檔案的實際頁數）。

### Role → 欄位對應

| role | 「我方」= `ourXxx` | 「對方」= `counterpartyXxx` | 前端綁定 |
|---|---|---|---|
| `expense` | 本公司（買方） | 賣方 | `counterpartyName`→vendor、`counterpartyTaxId`→taxId |
| `reimbursement` | 本公司（買方） | 賣方 | 同上 |
| `income` | 本公司（賣方） | 買方（客戶） | `counterpartyName`→customer、`counterpartyTaxId`→買方統編 |

無法辨識的欄位回 `null`。整張文件完全無法辨識則回 422（見下節），不會回 200 + 全 null。

### Error codes

| HTTP | 代碼 | 情境 |
|---|---|---|
| 400 | `invalid_role` | role 不在白名單 |
| 400 | `invalid_file_type` | 檔案類型不在支援清單（依檔案內容判斷，不採信副檔名）；或沒附任何檔案 |
| 400 | `too_many_files` | 超過 5 檔 |
| 413 | `file_too_large` | 單檔 > 5 MB |
| 422 | `ocr_no_result` | Gemini 全部檔案都回空；請改手動輸入（Google 已成功回傳，**照樣扣次**）。所有檔案都在送出前被擋下（轉檔失敗、PDF 超過 15 頁或讀不出頁數）時也回 422，此時沒有送 Google，`quota.used` 為 0 |
| 429 | `quota_exhausted` | 本月月費額度 + 加購次數皆用完（剩餘 0 次） |
| 429 | `quota_insufficient` | 剩餘次數大於 0，但不夠本次的總頁數（圖片每張 1 頁、PDF 照實際頁數）；**整個請求不辨識、不扣次**。附 `quota` 快照與 `required`（本次需要的次數） |
| 503 | `ocr_unavailable` | GCP 連線失敗 / credentials 缺 / 模型或區域不存在 / Vertex AI API 未啟用 / Google 回 400 但不是檔案本身的問題，或看不出是不是檔案問題（我們送的設定錯誤、帳單或區域前置條件未設好、訊息太籠統）/ 伺服器缺 `pdfinfo` |

「全部檔案都回空」＝每個檔案都沒抽出任何**表單上看得到的欄位**（日期、對方名稱、對方統編、發票號碼、未稅 / 稅額 / 含稅金額、品項；例如空白或看不清的照片）。只抽到推導欄位（`documentType`、`taxRate`）或表單沒有對應欄位的我方名稱 / 統編，也算回空（2026-10-28 決定：避免顯示「辨識完成」卻什麼都沒帶入，還依覆蓋規則清掉使用者手填的欄位）；抽欄位出錯或逾時的檔案也算回空（見 §3.1 效能與防呆）。

錯誤 payload：`{ "code": "...", "message": "...", "quota": { ... }, "required": 3 }`（`quota` 在 429 與 422 時附上；422 有扣次，前端用它更新剩餘次數；`required` 只在 `quota_insufficient` 附上）。

## 3. Gemini 設定

> **2026-10-29 決策**：由 Document AI Enterprise OCR + 後端規則改為 Vertex AI Gemini 3.1 Flash-Lite。模型直接讀圖片 / PDF，依 `responseSchema` 回欄位 JSON，手寫收據的賣方名稱、品項比規則準。比較與單價見 `docs/技術選型.md` §6。

| 項目 | 值 |
|---|---|
| 模型 | `gemini-3.1-flash-lite`（Vertex AI） |
| API | 同步 `generateContent`（一次送一份文件，圖片 / PDF 以 base64 放 `inline_data`） |
| Region | `global`（2026-10-29 實測可用）。`asia-east1`、`us-central1` 實測回 404（此模型不存在），所以不能選台灣區域。`global` 不指定資料處理地點。`us` / `eu` 多區域的主機名稱格式與 `{區域}-aiplatform` 不同，後端目前不支援 |
| 輸出 | `responseMimeType: application/json` + `responseSchema`；`temperature: 0`；思考量設最低（`thinkingLevel: minimal`，實測被接受，thinking token 為 0）；輸出上限 4096 token |

後端讀下列環境變數：

| ENV | 用途 |
|---|---|
| `GCP_PROJECT_ID` | GCP 專案 ID（專案要啟用 Vertex AI API，service account 要有 Vertex AI User 角色） |
| `GCP_LOCATION` | 填 `global` |
| `GOOGLE_APPLICATION_CREDENTIALS` | service account JSON 檔絕對路徑 |

原本的 `GCP_OCR_PROCESSOR_ID`（Document AI processor）已不使用，可從環境設定刪除。

**開發模式**：任一必填變數缺值時 `/api/ocr/recognize` 回 503 `ocr_unavailable`；不自動 fallback 到假資料（避免正式環境誤跑 stub）。

**PDF 頁數**：Gemini 不回頁數，後端用 poppler 的 `pdfinfo` 數頁（配額按頁計次用）；讀不出頁數（檔案壞掉）或超過 **15 頁**（2026-10-29 用戶確認），視為該檔無法辨識，不送 Google、不扣次。

**用量與費用**：App 不記錄 token 與費用，由開發者直接查 GCP Cloud Monitoring / 帳單。客戶端的配額仍以「次數」計算（見 §5）。

### 3.1 欄位抽取與格式檢查

模型依 `responseSchema` 回下列欄位（賣方 / 買方、金額、品項等）；後端只做**格式檢查**，不通過的欄位**不放**（回 `null`，不猜）。模型可能編造內容，所以電子發票 QR 優先（§3.2）、使用者核對仍是最後一道。

| 欄位 | 格式檢查（不通過就不採用） | 信心度 |
|---|---|---|
| `invoicePrefix` / `invoiceDigits` | 字軌 2 碼英文字母（轉大寫、去 `-`）+ 8 碼數字，兩個都通過才採用；模型判斷為收據時不帶發票號碼 | 依模型標記 |
| `documentType` | 有發票號碼 → `invoice`；沒有號碼且模型判斷為收據 → `receipt`；否則 `null`（**沒讀到號碼不等於收據**）。推導欄位，不計信心度 | — |
| `incurredAt` | 西元 `YYYY-MM-DD`，且年份在 **2000 年到今年 + 1 年**之間 | 依模型標記 |
| 賣方 / 買方統編 | 8 碼數字且**通過統編檢查碼**（各位數乘 1,2,1,2,1,2,4,1 後把乘積的十位與個位相加，總和能被 5 整除；第 7 碼為 7 時總和或總和 + 1 能被 5 整除即可），再依 role（§2 對應表）放進 `ourTaxId` / `counterpartyTaxId` | 依模型標記 |
| `preTaxAmt` / `amount` | 整數、1 到 99,999,999（字串、小數、負數、0 都不採用） | 依模型標記 |
| `taxAmt` | 整數、0 到 99,999,999（0 代表免稅） | 依模型標記 |
| 金額互相檢查 | 總計小於未稅 → 視為讀錯，`preTaxAmt` 與 `taxAmt` 都不採用（總計保留） | — |
| 賣方 / 買方名稱 | 去頭尾空白、全形轉半形、長度 ≤ 100 字 | **低** |
| `items` | 每筆要有品名，數量 ≥ 1、單價 ≥ 0、小計 ≥ 0 且都是整數，且**單價 × 數量 = 小計**，否則該筆略過；最多 50 筆。**不檢查**品項合計與總計是否相等（折扣、服務費、稅額都會造成差異），差異由使用者在表單核對 | **低** |

- **稅率（`taxRate`）**：不由模型回，照 §4 推導；只會是 `business_5`（稅額 / 未稅 ≈ 5%，±0.5%）、`exempt_0`（稅額為 0 或收據）或 `null`，沒有「超出範圍」的值。
- **信心度**：模型沒有逐欄分數，改讓它在 `uncertain_fields` 列出不確定的欄位（字跡模糊、手寫、被遮住、靠推測）。列入的欄位 **低 = 0.5**，其餘 **高 = 0.9**；名稱與品項是自由文字、最容易編造，一律低。前端本來就不依信心度提示（§6）。
- **抽欄位錯誤**：格式檢查過程出任何錯誤都當作「該檔沒有結果」，該檔頁數**照樣計入扣次**（Google 已計費），並記錄錯誤類別（不記內容與統編）。模型回應被截斷、被安全機制擋下或不是合法 JSON，也算該檔沒有結果。
- QR code：Gemini 不回條碼內容，由後端自己解碼，見 §3.2。

### 3.2 電子發票 QR Code（2026-10-28 決策）

電子發票證明聯上的 QR Code 存的是正確資料，解得出來就不用猜。但照片模糊或感熱紙彎曲時常解不出來（10/27 實測 4 張只有 1 張讀到），所以 **QR 是加分項，OCR 照跑**。

**在後端解碼**（不在前端）：
- 衝突比對、扣次數、角色對應都在後端，QR 結果直接併進同一份結果，三個表單的前端都不用改。
- 現有流程是先上傳照片、再按辨識，不是用相機即時掃描，所以前端解碼的優勢（即時對焦）用不到。

**流程**（每個檔案各自處理；PDF 每一頁都要解，使用者可能把多張電子發票掃成一份 PDF）：
1. 後端先解這張圖（或 PDF 每一頁）裡所有 QR Code，再照常呼叫 Gemini 抽欄位、套 §3.1 格式檢查。PDF 要先把每頁轉成圖片才能解碼，解析度要足夠讓 QR 解得出來。
2. 找到電子發票左邊的 QR（格式見下）且檢查通過 → 這張圖的下列欄位**以 QR 為準**，蓋掉 §3.1 抽出的值，信心度一律**高**。其他欄位（例如賣方名稱，QR 裡沒有）照 §3.1（模型回的值）。
3. 解不出來、不是電子發票格式（例如網址）、檢查沒通過 → 當作沒有 QR，結果完全照 §3.1。不另外提示使用者。
4. 解碼失敗或出錯不影響辨識，也不改變回 200 / 422 的判斷；解碼必須設逾時，逾時當作沒有 QR。

**扣次數不變**：每個檔案照樣呼叫 Google、照樣扣次數（QR 裡沒有賣方名稱，而且多數照片解不出 QR）。之後如果實測解碼率高，再評估「QR 解得出來就不呼叫 Google、不扣次數」。

**左邊 QR 的內容**（依財政部〈電子發票證明聯一維及二維條碼規格說明〉，實作以官方規格為準）：

| 位置 | 內容 | 對應欄位 |
|---|---|---|
| 第 1–10 碼 | 發票字軌 2 碼 + 號碼 8 碼 | `invoicePrefix` / `invoiceDigits` |
| 第 11–17 碼 | 民國年月日（7 碼） | `incurredAt`（民國年 + 1911） |
| 第 18–21 碼 | 隨機碼 | 不用 |
| 第 22–29 碼 | 銷售額（未稅，16 進位）；`00000000` = 店家沒把稅額分開 | `preTaxAmt`；`00000000` 時 `preTaxAmt` / `taxAmt` 都不填 |
| 第 30–37 碼 | 總計（含稅，16 進位） | `amount`；`taxAmt` = 總計 − 銷售額 |
| 第 38–45 碼 | 買方統編（`00000000` = 沒有買方） | 依 role 放進 `ourTaxId` / `counterpartyTaxId`；`00000000` 當作沒有 |
| 第 46–53 碼 | 賣方統編 | 依 role 放進 `counterpartyTaxId` / `ourTaxId` |
| 第 54–77 碼 | 加密驗證資訊 | 不用（要財政部金鑰才能驗） |
| 之後以 `:` 分隔 | 營業人自用區（10 碼）、左右兩個 QR 合計記載的品項筆數、發票總品項筆數、中文編碼（0 = Big5、1 = UTF-8、2 = Base64、3 = 境外電商 UTF-8）、接著每 3 段一筆「品名:數量:單價」，最後可能有補充說明 | `items` |

- **QR 裡沒有賣方名稱**：官方規格沒有這個欄位。有些店家會把店名寫進品名（例如「粥師傅 延吉店的訂購商品」），那是品項，不當賣方名稱。

- **右邊 QR** 以 `**` 開頭，接續左邊放不下的品項。
- **檢查**：發票號碼要符合 2 碼英文 + 8 碼數字；日期換算後要在 §3.1 的年份範圍內；賣方統編要通過檢查碼；總計 > 0 且 ≥ 銷售額。任一項不通過就整個 QR 不採用。
- **銷售額 = 總計**（算出來稅額是 0）：有些收銀機會把含稅總額填進銷售額，分不出是免稅還是填錯，所以跟 `00000000` 一樣，`preTaxAmt` / `taxAmt` 都不填，`taxRate` 也不推導（照 §4 第 2 條，「算出來的 0」不算免稅）。（2026-10-28 決定）前端照 §6 帶入規則：稅率預設 `business_5`，再用含稅總額自動算出未稅與稅額（例如總計 90 → 未稅 86、稅額 4），由使用者核對修改（2026-10-28 Peggy 確認維持）。
- **品項**：「左右 QR 合計記載的品項筆數」等於「發票總品項筆數」，而且實際解出的品項數也對得上時，才用 QR 的品項（小計 = 數量 × 單價，信心度高）取代 §3.1 的品項；筆數對不上（例如右邊 QR 沒解出來）就不用 QR 的品項，照 §3.1。
- `documentType` = `invoice`；`taxRate` 照 §4 稅率推導。
- **同一個檔案裡有多張不同號碼的電子發票**（2026-10-28 Peggy 決定）：
  - 新增單一支出 / 收入 / 代墊款（本 endpoint）：衝突彈窗**整張挑一張**，不逐欄挑，避免挑出第 1 張的金額配第 2 張的號碼。
    - 本次送的檔案中，只要有任一個檔案解出 2 張以上不同號碼的發票，回應就多一個 `conflicts.invoices`，列出本次**所有**解出的發票（跨檔案、號碼相同只列一次）：
      ```json
      "conflicts": {
        "fields": [ ... ],
        "items": [ ... ],
        "invoices": [
          { "sourceIndex": 0, "invoiceIndex": 1, "fields": { "invoicePrefix": "EU", "invoiceDigits": "04855261", "incurredAt": "2026-10-18", "preTaxAmt": 143, "taxAmt": 7, "amount": 150, "ourTaxId": null, "counterpartyTaxId": "70768666", "documentType": "invoice", "taxRate": "business_5" }, "items": [ { "name": "統一藥品", "quantity": 1, "unitPrice": 150, "subtotal": 150 } ] },
          { "sourceIndex": 0, "invoiceIndex": 2, "fields": { ... }, "items": [ ... ] }
        ]
      }
      ```
    - `invoiceIndex`：該發票在自己檔案裡的順序，從 1 開始；先看 PDF 頁序，同一頁由上到下、由左到右。`fields` 放 QR 有的欄位，加上名稱（見下）；品項不齊全時 `items` 為 `[]`。
    - 有 `conflicts.invoices` 時，QR 有的欄位（發票號碼、日期、金額、稅額、統編、`documentType`、`taxRate`）、名稱（`ourName`、`counterpartyName`）和品項**不進** `merged` / `conflicts.fields` / `conflicts.items`，`merged` 裡這些欄位為 `null`、`merged.items` 為 `[]`。
    - **名稱**（2026-10-29 改 Gemini 後調整，用戶已確認）：QR 裡沒有名稱。檔案只有 1 張發票時，用模型讀到的名稱放進該發票的 `fields`（信心度低）；檔案有 2 張以上發票時，Gemini 沒有每頁文字、分不出名稱屬於哪張，一律不填，讓使用者自己輸入（寧可空白，不帶錯的店名）。與 2026-10-28「按頁對應」相比，多頁 PDF 每頁一張發票的情況不再帶名稱。
    - 前端：衝突彈窗先問一題「要用哪一張發票？」，每個選項標「憑證 N 的第 K 張發票」並列出號碼、日期、金額。選一張就整組帶入它的 `fields` 和 `items`；沒選就關掉，這些欄位維持空白。
    - 沒有任何檔案出現多張發票時，不回 `conflicts.invoices`，一切照 §4，現有前端不受影響。
  - 同一張發票的左右 QR、或同一張發票在 PDF 裡重複出現（號碼相同）只算一張。
  - 批次匯入 PDF：要能一張發票新增一筆，見 §8（另案）。
- **前端圖片壓縮**：前端上傳時會把圖片壓成長邊 1600px、約 1MB 的 JPG。QA 要確認壓縮後的電子發票照片還解得出 QR；解不出來的比例高的話，再調整壓縮設定。

## 4. 多檔辨識與衝突解析

### 流程

1. 使用者送 N 個檔案（1 ≤ N ≤ 5）
2. 後端對每個檔案獨立呼叫 Gemini；PDF 多頁一次 call
3. 把每份原始回應 normalize 成內部物件 `[{ sourceIndex, fields, items, confidence }]`
4. 逐欄位比對 → 分流到 `merged` 或 `conflicts`
5. 扣配額（實際頁數）
6. 回應前端

### 頂層欄位比對規則（完全比對；不做模糊）

對每個頂層欄位（`documentType`、`incurredAt`、`ourTaxId`、`ourName`、`counterpartyTaxId`、`counterpartyName`、`invoicePrefix`、`invoiceDigits`、`taxRate`、`preTaxAmt`、`taxAmt`、`amount`）：

| 情境 | 結果 |
|---|---|
| 只有 1 張辨識出來 | 進 `merged` |
| 多張都辨識出且值完全相同 | 進 `merged` |
| 多張都辨識出但值不同 | 進 `conflicts.fields`，列所有候選值 |
| 全部都 null | `merged` 該欄位為 null |

字串比較前先做正規化：去頭尾空白、全半形英數字統一；**不**做 Levenshtein 之類的相似度比對。這會多問使用者幾次（例如「福華文具行」vs「福華文具」會被當 conflict），寧可問、不要默默吃掉。

**發票號碼合成一題**（2026-10-27）：回應仍分成 `invoicePrefix` / `invoiceDigits` 兩個欄位，但前端衝突彈窗只要其中任一個有衝突，就合成一題「發票號碼」，每個候選顯示該張憑證的完整號碼（例如 `FV-63156693`；沒衝突的那半邊用 `merged` 的值補上）。選一張就同時帶入字軌和數字，避免挑出 `FV` + `04855261` 這種不存在的號碼。

### 品項（line_items）比對規則

Dedup key：`正規化後的 name + unitPrice`（quantity 不列入 key；因為同一品項分批買可能數量不同）。

分組規則：

1. 把所有張的 items 攤平、按 key 分組
2. 單一來源 group：直接進 `merged.items`
3. 多來源 group，且所有候選的 quantity + subtotal 都相同：進 `merged.items`（取第一個）
4. 多來源 group，但 quantity 或 subtotal 不同：進 `conflicts.items`，列所有候選 item 讓使用者挑一個保留

### 稅率推導

Gemini 不回傳 Quickey 的 `TaxRate` enum。對每張單獨推導後再比對：

1. 若發票有「稅額」欄且 `taxAmt / preTaxAmt ≈ 0.05`（允許 ±0.5% 誤差）→ `business_5`；沒有稅額但有 `preTaxAmt` 與 `amount`，且 `(amount − preTaxAmt) / preTaxAmt ≈ 0.05` → 也是 `business_5`
2. 若憑證上印的 `taxAmt === 0` 或 `documentType === 'receipt'` → `exempt_0`（`documentType` 為 `null` 時不適用，見 §3.1；用含稅 − 未稅推算出的 0 不算）
3. 其他 → `null`，前端預設帶 `business_5`

每張推導的結果再進 §4 頂層欄位比對。

## 5. OCR 配額

### 計次

- **1 張圖 = 1 次**；1 頁 PDF = 1 次；一份 N 頁 PDF = N 次
- 只在 Gemini 成功回傳的檔案才扣；格式錯 / 檔案過大 / PDF 頁數過多或讀不出 / 配額擋下 / Gemini 失敗（503）**不扣**
- 單次 `/recognize` 回應的 `quota.used` = 本次累計扣除
- 批次匯入憑證另計：扣次 = 使用者確認帶出的憑證張數，不是頁數，見 §9
- 剩 0 次時先回 `quota_exhausted`，不做轉檔和數頁；有剩才呼叫 Gemini 前先算**總頁數**（圖片每張 1 頁、PDF 用 `pdfinfo` 數；轉檔失敗、超過 15 頁、讀不出頁數的檔案不送 Google，不算進需要的次數），再檢查「剩餘次數 ≥ 總頁數」：剩 0 次回 `quota_exhausted`；有剩但不夠回 `quota_insufficient`（附 `required`）。兩者都**不辨識、不呼叫 Google、不扣次**（2026-10-29 用戶裁決；Gemini 之前頁數要辨識完才知道，才有「扣到 0 為止」的規則，現已不需要）。同一家公司同時送多個請求時，可能都通過檢查而超扣，此時扣到 0 為止，不扣成負數

### 月費額度 vs 加購

每公司兩池次數分開管：

| 池 | 行為 |
|---|---|
| 月費額度 | 月初依公司方案重置；當月用剩歸零。**依方案決定，團隊版每月 160 次**（2026-11-10；方案上限見 docs/資料模型.md §3.1。原基本方案 50 次，2026-10-28 由 20 次調為 50 次） |
| 加購包 | 單獨購買一次給一包；**不過期、永久累積** |

扣除順序：**先扣月費額度，用完才扣加購**。使用者永遠優先消耗當月免費額度，避免「加購沒用到就被月費蓋掉」。

### 超額行為

本月月費 + 加購皆為 0 時（剩餘次數大於 0 但不夠本次總頁數時，改回 `quota_insufficient`，其他同下）：
- `/api/ocr/recognize` 回 **429 `quota_exhausted`**，附上 `quota` 物件；剩餘次數不夠本次頁數時回 **429 `quota_insufficient`**，另附 `required`
- 前端 toast：「本月 OCR 辨識次數已用完」+ 行動按鈕「前往加購」→ 導到 `/admin/settings/ocr-quota`（頁面另案建；**加購頁上線前不顯示此按鈕**，只顯示文字，避免導到不存在的頁面）
- 不做即時彈窗加購（首版尚無金流）

### 誰可以加購

- 管理員：看得到剩餘次數、能進加購頁、能加購
- 員工（代墊款場景）：看得到剩餘次數（表單側邊顯示），**不能**加購；超額時 toast 改成「本月額度已用完，請聯絡管理員加購」

### 資料模型（Company 直接加欄位）

```ruby
# db/migrate/XXXX_add_ocr_quota_to_companies.rb
add_column :companies, :ocr_monthly_quota,       :integer, null: false, default: 20  # 基本方案每月次數
add_column :companies, :ocr_monthly_used,        :integer, null: false, default: 0
add_column :companies, :ocr_purchased_remaining, :integer, null: false, default: 0
add_column :companies, :ocr_quota_reset_at,      :datetime, null: false  # 下次 monthly_used 歸零時間（通常是每月 1 日 00:00 UTC+8）
```

扣次邏輯（簡化）：

```
if used + add > ocr_monthly_quota - ocr_monthly_used + ocr_purchased_remaining
  raise QuotaExhausted
end

from_monthly = min(add, ocr_monthly_quota - ocr_monthly_used)
from_purchased = add - from_monthly
ocr_monthly_used += from_monthly
ocr_purchased_remaining -= from_purchased
```

調整基本方案次數：新增一支 migration，改 `ocr_monthly_quota` 的 default，並把仍是舊基本值的公司一併更新成新值（已個別調整過次數的公司不動）。前端與 API 一律讀 `monthlyQuota`，不寫死次數。

重置：每次呼叫 `/recognize` 前檢查 `ocr_quota_reset_at`；若已過期 → `ocr_monthly_used = 0; ocr_quota_reset_at = next_month_start`。不開 cron job，lazy 重置省工。

缺點：沒有歷史用量紀錄；若未來要做「這家公司 9 月用了幾次」或對帳 → 加 `OcrUsageLog` table 時再補。首版不做。

### 查詢 endpoint

```
GET /api/ocr/quota
→ 200 {
  "monthlyQuota": 20,
  "monthlyUsed": 5,
  "monthlyRemaining": 15,
  "purchasedRemaining": 0,
  "resetAt": "2026-11-01T00:00:00+08:00"
}
```

前端在新增支出 / 代墊款 / 收入表單進入時 call 一次顯示剩餘次數；辨識後用 response 的 `quota` 更新。

## 6. 信心度與警示

- 欄位信心度依 §3.1 的固定值（高 0.9 / 低 0.5）
- `confidence.overall` = 每個辨識成功的檔案先算「直接辨識出的欄位」信心度平均，再對各檔取平均；推導欄位（`documentType`、`taxRate`）不計入；0–1 浮點數
- `confidence.lowFields` = `merged` 裡**有值**且由低信心度規則抓到的欄位 key（`items` 為 `[]` 時不列）；沒有就回 `[]`。可能出現：`counterpartyName`、`ourName`、`items`（一律低），以及 `amount`、`counterpartyTaxId`、`ourTaxId`（依 §3.1 抓法可能為低）。多張憑證抽到相同值時，任一張是低就列入
- **前端不依信心度提示**（2026-10-28 Peggy 決定）：辨識成功一律顯示固定提示「辨識完成｜欄位已自動帶入，請核對後儲存／送出」，不逐欄提示推測欄位，也不因 `overall` 偏低另外警告；有衝突時改顯示衝突提示並跳彈窗。`overall` 與 `lowFields` 後端照常回傳，僅供除錯與之後調整規則參考。憑證區在剩餘次數下方常駐核對提示（2026-10-29 用戶決定）
- 有欄位進 `conflicts` 時，前端一律跳 Modal 讓使用者挑；不自動選信心度最高的那個（寧可多問一次）
- 不自動丟棄低信心欄位；一律帶入 `merged`，由使用者決定是否改
- `warnings` 內含欄位 key，僅供除錯 / log，**前端不直接顯示給使用者**（衝突已由彈窗處理）

### 前端帶入規則

- **重新辨識＝整份取代**：使用者確認「覆蓋並辨識」後，OCR 會給的欄位一律以新結果取代，新結果為 `null` 的欄位清空，但憑證類型與稅率是必選欄位，不清空：`documentType` 為 `null` 時預設「發票」、`taxRate` 為 `null` 時預設 `business_5`（2026-10-27 決定；使用者手上是收據時，會因發票號碼必填而發現並改選）；OCR 不會給的欄位（類別、付款狀態、帳戶等）保持不動
- **已存檔的憑證可以辨識，預設不勾**：編輯既有紀錄（含員工草稿、駁回重送）時，新加入的憑證預設勾選辨識，已存檔的憑證可勾選但預設不勾，避免不小心重複扣次；每次辨識照常扣次（2026-11-03 改：移除已存檔的憑證會立即永久刪除，不再引導使用者移除後重傳）
- **日期帶到哪一欄**（2026-11-05，PRD 第 23 條）：後端只回一個 `incurredAt`（憑證上印的日期），單筆辨識與批次匯入憑證相同。支出、收入由前端依**帶入表單後的文件類型**決定：發票 → 填發票日期，再依 PRD 第 23 條「第一次填發票日期」的規則帶入發生日期；收據 → 直接填發生日期。`documentType` 為 `null` 時表單預設發票，所以也填發票日期。員工請款不變，填消費日。不拆成兩個欄位，是因為文件類型可能要在衝突彈窗選完才確定。
- **代墊款品項**（2026-11-11 改，PRD 第 23 條）：`role=reimbursement` 與支出相同，`merged.items`、`conflicts.items`、`conflicts.invoices[].items` 都照常回傳並帶入，品項衝突一樣跳彈窗挑選
- **不預填說明 / 備註欄**：辨識結果不寫入任何說明文字（避免隨請款送出），改以畫面提示「辨識完成，請核對後送出」

## 7. 稽核與 Rate limit

- 本 endpoint **不寫 AuditLog**（辨識結果最後是不是存成支出 / 收入，由該資源本身的建立事件記錄）
- 配額本身就是 rate limit；不另加「每分鐘 N 次」限制
- 例外：批次匯入憑證取消不扣次，但 Google 已計費，首版不限制，見 `docs/批次匯入規格.md`「已知風險」

## 8. 不做（out of scope）

- OCR 結果快取（相同檔案重跑結果可能不同；且使用者可能微調後再辨識）
- ~~批次辨識多筆**不同**憑證~~：2026-10-29 已實作，見 §9
- 字元層級座標回傳（前端 UI 不用）
- 電子發票 XML 直接匯入
- 用相機即時掃描 QR Code、一維條碼（2026-10-28 決定只解上傳的圖片與 PDF 裡的 QR，見 §3.2）
- QR 解得出來就不呼叫 Google、不扣次數（上線後依解碼率再評估）
- 用財政部電子發票 API 查明細、用統編查公司名稱
- Custom Extractor（每 1,000 頁 $30 另加部署時數費；已由 Gemini 取代，2026-10-29）
- OcrUsageLog 歷史用量明細（首版不做；超額對帳 / 客訴時再補）
- 加購包金流（本次只實作「加完次數進 Company 欄位」的 admin 工具；對外付款走獨立專案）

## 9. 批次匯入憑證（2026-10-29，支出、收入）

> 一次上傳多張**不同**憑證（一頁可以有多張），每張建立一筆支出或收入。產品規則見 `docs/批次匯入規格.md` 第二節，完整 API、錯誤碼與提醒文字見 `docs/dev/ocr-batch-api.md`。

### 端點

| 端點 | 做什麼 |
|---|---|
| `POST /api/ocr/batch` | multipart `files[]`、`role=expense` 或 `income`。每頁送 Gemini 一次，只找出每張憑證的位置，**不辨識內容、不扣次**；回 `token` 與每頁張數，位置暫存 30 分鐘 |
| `POST /api/ocr/batch/:token/confirm` | `{ page_ids }`。所選頁的每張憑證裁成單張，逐張辨識並解 QR，扣辨識出內容的張數，回傳每張憑證的辨識結果（結構同 `/recognize` 成功回應）；所選頁的檔案另列在 `pages[]`，每頁一次，憑證用 `page_id` 對應 |
| `DELETE /api/ocr/batch/:token` | 取消，不扣次；找不到也回 204 |

- 只有超級管理員可用；開放 `role=expense`、`income`（代墊款不開放）。確認時沿用上傳時的 role 對應我方與對方。
- 暫存綁公司 + 使用者，別家公司或別人的 token 一律 404 `batch_expired`。確認成功後刪除，不能確認第二次。

### 跟單筆 `/recognize` 的差異

| | 單筆 `/recognize` | 批次 `/batch` |
|---|---|---|
| 多個檔案的意思 | 同一張憑證的多張照片，合併成一筆 | 不同憑證，每張一筆 |
| 扣次 | 每頁 1 次，辨識完就扣 | 確認後逐張辨識，扣辨識出內容的張數；辨識不出內容的那張、空白頁、取消都不扣 |
| 上限 | 5 個檔案、單檔 5MB、PDF 15 頁 | 5 個檔案、單檔 20MB、合計 5 頁；每頁 10 張 |
| 送 Gemini | 每個檔案一次 | 上傳時每頁 1 次找位置（PDF 用 `pdfseparate` 拆成單頁）；確認時每張 1 次辨識。兩步各自同時處理、各最多 90 秒 |
| 電子發票 QR | 照 §3.2 | 每張裁好的圖各自照 §3.2 |
| 檔案 | 不回傳 | 每張附所在那一頁（PDF 單頁、圖片原圖；HEIC、WEBP 轉 JPEG）；單頁超過 5MB 不附，提醒使用者自己補 |

### 扣次流程

1. 剩 0 次 → 429 `quota_exhausted`，不送 Google。
2. 找完位置回每頁張數，畫面顯示「找到 N 張憑證，確認後最多扣 N 次（剩餘 M 次）」。
3. 確認時剩餘次數不夠所選張數 → 429 `quota_insufficient`，暫存保留，使用者改選頁再確認。
4. 確認後逐張辨識，辨識完只扣辨識出內容的張數；之後在新增頁刪掉某一筆或整批不建立，都不退次數。

### 已知限制

- 正式環境快取（solid_cache）總量 256MB，滿了先清最舊的；被清掉的批次確認時回 404，要重新上傳。
- 找位置、確認後的辨識各最多 90 秒（正式環境前面的 Cloudflare 100 秒就斷線）；到期沒做完的頁或憑證不扣次，提醒使用者重新上傳那幾頁。重新上傳時，同一頁已帶出的憑證會再算一次。
- 同一家公司同時只能有一批在辨識，第二批回 409 `batch_in_progress`。鎖放在快取、120 秒自動過期；兩個請求幾乎同時進來時極少數會都通過，只多占資源，不影響扣次。
