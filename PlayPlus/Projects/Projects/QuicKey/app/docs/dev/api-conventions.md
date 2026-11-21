# API 慣例（後端 Rails）

前端透過 `frontend/src/api/service.ts` 呼叫後端：request 由 camelCase 轉 snake_case，response 由 snake_case 轉 camelCase（FormData body 不轉，key 直接寫 snake_case）。

## 列表與單筆

- 列表 API 回精簡資料（不含附件、品項等大欄位）；單筆 API 回全欄位。詳情抽屜一律重打單筆 API。
- 單筆查詢（支出、收入、移轉的 `GET /:id`）也查得到垃圾桶內的紀錄（仍限本公司），給詳情抽屜唯讀顯示：
  - `deleted_at`：刪除時間，不在垃圾桶為 `null`。
  - `deleted_by`：`{ id, name }`，垃圾桶的操作人（最新一筆刪除稽核的操作者）；不在垃圾桶、或其他單筆 API（新增、編輯、狀態切換等）的回傳為 `null`。
  - `attachments[].url`：和一般紀錄一樣可預覽、下載。
  - 編輯、狀態切換、刪除只限垃圾桶外，垃圾桶內回 404；刪圖檔回 409 `IN_TRASH`（`attachments-api.md` 第 4 節）。還原後才能操作。
- 後台列表走伺服器端分頁：`{ data: [...], meta: { total, page, page_size } }`，預設每頁 10 筆、上限 100。
- 支出、收入垃圾桶的批次還原與永久刪除見 `trash-batch-api.md`：每筆各自處理，回 `{ succeeded, failed }`。

## 錯誤回應

格式：

```json
{ "error": "MISSING_COLUMN", "message": "找不到「發生日期」欄，請使用範本" }
```

- `error`：大寫代碼，給前端判斷分支用（例：`CATEGORY_CHANGED` 時停用按鈕）。
- `message`：**前端會直接顯示給使用者**，所以必須是使用者看得懂的白話句子：說明發生什麼事、下一步怎麼做。
  - 不放技術訊息：例外類別名、SQL、欄位 key、`errors.full_messages` 的英文欄位名、堆疊。
  - 技術細節寫進 `Rails.logger`。
  - ✗ `第 3 列無法寫入：Tax id 統編應為 8 碼數字`
  - ✓ `第 3 列無法建立，整批未匯入，請檢查這列的資料`
- 狀態碼：輸入或檔案內容有問題 422；資料已被別人改過、需重新整理 409；權限不足 403；找不到 404。
- 舊 API 只回 `{ error }` 的，前端以代碼對照文字；新 API 一律附 `message`。

## 稽核日誌

建立、編輯、刪除、狀態切換等寫 `AuditLog.record!`。建立用 model 的 `audit_snapshot`；非手動新增的來源在 `after` 加 `via`（例：Excel 匯入為 `via: "excel_import"`）。
