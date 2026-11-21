# 圖檔（憑證附件）API

> 對應 `docs/資料模型.md` §2.4、§4.3「刪除圖檔」、PRD 規則 18「圖檔」、`docs/後續擴充規格.md` §9。
> 程式：`backend/app/controllers/api/attachments_controller.rb`、`files_controller.rb`、`app/services/attachment_files.rb`。

## 概念

- 圖檔存成實體檔案（Rails ActiveStorage，先存主機硬碟）。一張圖檔 = 一個「檔案」，有自己的 `id`。
- **暫存檔**：上傳後還沒掛到任何紀錄的檔案。只有上傳者本人能掛上、能刪除。建立超過 24 小時仍未掛上的，每天自動清除。
- 掛上紀錄後，同一個檔案可以被多筆紀錄共用（代墊款與它核准產生的支出、批次匯入同一頁拆出的多筆支出）。實體檔案在**沒有任何紀錄使用**時才刪除。
- 限制：每筆紀錄最多 5 張、單檔 5MB、JPG／PNG／PDF。格式看檔案內容判斷，不看副檔名。
- 可掛圖檔的紀錄：支出、收入、資金移轉、代墊款。手續費支出不掛圖檔（憑證在移轉上）。

## 圖檔格式（各 API 共用）

```json
{ "id": "uuid", "filename": "收據.jpg", "mime_type": "image/jpeg", "byte_size": 123456, "url": "/api/files/…" }
```

- 前端經 `service.ts` 轉成 `{ id, filename, mimeType, byteSize, url }`。
- 順序：依掛上的先後；編輯時新加的接在最後。不提供調整順序。
- 列表 API 不帶 `attachments`（員工「我的請款」列表例外，見下方代墊款）；單筆 API 帶。

## 讀取：`url`

- `url` 是**短效簽章網址**（網址本身帶 token），不需要 Authorization header，可直接放 `<img src>`、`<a href>`、`<iframe>`。
- 格式為以 `/` 開頭的相對路徑 `/api/files/<token>`，走跟其他 API 一樣的 `/api` 代理。若 `VITE_API_BASE_URL` 設成別的網域，前端自行接上網域。
- 有效期限 1～2 小時（到下一個整點再加一小時）。同一小時內重撈拿到的是同一個網址，瀏覽器可以快取。
- 加 `?download=1` 改為下載（Content-Disposition: attachment，檔名為原始檔名）；不加為直接顯示。
- 網址綁發出時的使用者；讀取時仍會再檢查：管理員可讀公司內所有圖檔；員工只能讀自己上傳的暫存檔與自己代墊款的圖檔。
- 過期、無效、沒有權限、檔案已刪除：一律 404。前端遇到圖片載入失敗時重打該紀錄的單筆 API 拿新網址（詳情抽屜本來就每次重撈）。

## 1. POST /api/attachments — 上傳（成為暫存檔）

管理員、員工都可用。multipart：`files[]`（一次 1～5 個）。全部通過才建立，任一個不符就整批不建立。

**201**

```json
{ "data": [ { "id": "…", "filename": "a.jpg", "mime_type": "image/jpeg", "byte_size": 12345, "url": "/api/files/…" } ] }
```

順序同送出的 `files[]`。

| 情況 | 回應 |
|---|---|
| 沒有檔案 | 422 `NO_FILE`「請選擇要上傳的圖檔」 |
| 一次超過 5 個 | 422 `TOO_MANY_FILES`「一次最多上傳 5 個檔案」 |
| 格式不是 JPG／PNG／PDF | 422 `INVALID_FILE_TYPE`「第 N 個檔案格式不支援，只接受 JPG、PNG、PDF」，附 `index`（從 0 起） |
| 單檔超過 5MB | 422 `FILE_TOO_LARGE`「第 N 個檔案超過 5MB」，附 `index` |

張數上限（每筆 5 張）在儲存紀錄時檢查；前端上傳前也請先擋。

## 2. DELETE /api/attachments — 刪除暫存檔

- 單張：`DELETE /api/attachments/:id`
- 多張：`DELETE /api/attachments?ids[]=a&ids[]=b`（離開頁面時一次刪）
- 一律回 204。只刪「自己上傳、同公司、尚未掛上任何紀錄」的；其餘（別人的、已掛上的、找不到的）略過，不報錯。
- 取消新增、移除尚未儲存的圖檔時呼叫。**已儲存的圖檔不能用這支刪**，請用第 4 節。

## 3. 建立／編輯紀錄時掛上圖檔

body 帶 `attachment_ids`（前端寫 `attachmentIds`）：

### 支出、收入、資金移轉

- `attachment_ids` = **要新掛上的暫存檔 id**，依順序接在最後。
- 編輯時已存的圖檔不用帶，也不會因為沒帶而被拿掉；拿掉已存圖檔走第 4 節（立即刪除）。
- 不帶 `attachment_ids` 或空陣列 = 圖檔不變。
- 只能掛自己上傳、同公司的檔案。同一個 id 可以掛到多筆紀錄（批次匯入同一頁拆成多筆支出時，每筆都帶同一個 id，檔案共用、只算一次空間）。
- 舊欄位 `attachments`（data URL 陣列）不再接受，帶了會被忽略。

| 情況 | 回應 |
|---|---|
| id 找不到、不是自己上傳、已被清除 | 422 `ATTACHMENT_NOT_FOUND`「找不到上傳的圖檔，可能已逾時清除，請重新上傳」 |
| 加上去超過 5 張 | 422 `TOO_MANY_ATTACHMENTS`「每筆最多 5 張圖檔」 |

錯誤 body：`{ error, message }`。

### 代墊款

- `attachment_ids` = **完整的圖檔清單**：保留的已存圖檔 id + 新的暫存檔 id。沒列到的已存圖檔會被拿掉（代墊款只有草稿、駁回能編輯，此時還沒有對應支出，拿掉即刪除實體檔案）。
- 原本代墊款編輯就是整份覆寫，所以沿用這個方式。
- 已存的 id 可以照原順序帶；順序依掛上先後，不因 body 順序改變。
- 錯誤代碼同上。

## 4. 刪除已儲存的圖檔（編輯頁）

- `DELETE /api/expenses/:id/attachments/:attachment_id`
- `DELETE /api/incomes/:id/attachments/:attachment_id`
- `DELETE /api/transfers/:id/attachments/:attachment_id`

僅管理員。立即永久刪除，不必按儲存。`attachment_id` 是圖檔的 `id`。

**200**：回整筆紀錄（同單筆 API）。

| 情況 | 回應 |
|---|---|
| 紀錄找不到 | 404 `not_found` |
| 紀錄在垃圾桶 | 409 `IN_TRASH`「這筆紀錄在垃圾桶內，還原後才能刪除圖檔」 |
| 手續費支出 | 409 `TRANSFER_FEE_LOCKED`（同既有訊息） |
| 這筆紀錄沒有這張圖檔 | 404 `ATTACHMENT_NOT_FOUND`「找不到這張圖檔，請重新整理」 |

- 代墊款核准產生的支出：只從支出拿掉，代墊款保留原圖（同一個檔案，代墊款還在用就不刪實體檔案）。
- 稽核：寫該紀錄的 `update`，`before: { attachments: ["a.jpg", "b.pdf"] }`、`after: { attachments: ["b.pdf"] }`（檔名陣列）。

## 5. 跟著紀錄走

| 動作 | 圖檔 |
|---|---|
| 進垃圾桶 / 還原 | 不動 |
| 永久刪除（支出、收入、移轉，含移轉連帶的手續費支出） | 從紀錄拿掉；沒有其他紀錄使用的實體檔案刪除 |
| 刪除代墊款（草稿、駁回） | 同上 |
| 代墊款核准產生支出 | 支出掛同一批檔案（不複製），`id` 相同 |

## 6. 稽核日誌

- 編輯儲存時新掛上圖檔：併進該次 `update`，`attachments` 前後為檔名陣列。
- 刪除已存圖檔：見第 4 節。
- 建立（`create` 的 `after`）與永久刪除（`purge` 的 `before`）的快照加上 `attachments: [{ filename, mime_type, byte_size }]`，只記檔名、類型、大小。
- 代墊款原本的 `receipt_urls`／`receipt_names` 變更改記為 `attachments`（檔名陣列）。

## 7. 各 API 回應變更

| API | 變更 |
|---|---|
| 支出／收入／移轉 單筆 | `attachments` 改為上方格式。資金移轉原本的 `INVALID_ATTACHMENTS` 錯誤不再出現 |
| 代墊款 單筆、員工「我的請款」列表 | 移除 `receipt_urls`、`receipt_names`，改為 `attachments`（同上方格式）。員工列表帶 `url` 給卡片縮圖用（原圖，沒有另外縮小） |
| 代墊款 後台列表、my-summary 的 recent | 不帶圖檔（同原本） |
| `POST /api/ocr/batch/:token/confirm` | `pages[].attachment` 改為上方格式（是暫存檔，有 `id`），單頁超過 5MB 仍為 null。同一頁拆出的多張憑證共用同一個 id |
| `POST /api/ocr/recognize` | 見下 |
| Excel 匯入、固定收支產生 | 產生的紀錄 `attachments` 為空陣列（格式同上） |

### POST /api/ocr/recognize

- 改收 `attachment_ids[]`（1～5 個），不再收 `files[]`。可用 JSON：`{ "role": "expense", "attachment_ids": ["…"] }`。
- id 可以是自己剛上傳的暫存檔，或這筆紀錄已存的圖檔（必須是目前使用者讀得到的）。
- 回應不變。錯誤格式不變（`{ code, message }`），新增 400 `attachment_not_found`「找不到要辨識的圖檔，請重新上傳」。
- 因圖檔只接受 JPG／PNG／PDF，這條路徑不再出現 HEIC、WEBP。

## 8. 其他

- 公司儲存空間：`Company#storage_bytes`，所有紀錄（含垃圾桶與代墊款）使用的圖檔大小加總，共用檔只算一次，不含暫存檔。目前沒有 API 與畫面（後續擴充規格 §7）。
- 每日清除暫存檔：`PurgeStaleUploadsJob`，台北 03:00，刪建立超過 24 小時仍未掛上的檔案。
- 既有 base64 轉檔（`backend/lib/legacy_attachment_converter.rb`，migration `20261103000003`、`20261103000004`）：一次轉成實體檔案、掛回原紀錄、檔名不變；代墊款與它產生的支出若是同一張圖，轉成共用檔案。轉完並確認每張舊圖都找得到、實體檔案內容相同後，下一支 migration 才移除舊欄位；任何一筆不符就中止，舊欄位保留。

## 9. 部署注意

- **部署前同時備份資料庫與 `quickey_backend_storage` volume，兩者時間點要一致**（先停服務再備份）。圖檔的紀錄在資料庫、檔案本身在 volume，只還原其中一個會對不上。
- 兩支轉檔 migration（`20261103000003`、`20261103000004`）在同一次 `db:migrate` 執行，**全部完成前不開放服務**。`000004` 失敗時舊欄位保留，查明原因後可重跑。
- `000004` 移除舊欄位後不可逆。回滾 = 還原部署前的資料庫與 volume 備份，加上舊版映像。
- 轉檔每批只讀 10 筆紀錄，避免舊圖多時記憶體不夠。
- 圖檔存在 backend 容器的 `/rails/storage`（掛 `quickey_backend_storage`）。日後若把背景工作（solid_queue）拆成獨立容器，**必須掛同一個 volume**，否則永久刪除與每日清除會找不到檔案。
