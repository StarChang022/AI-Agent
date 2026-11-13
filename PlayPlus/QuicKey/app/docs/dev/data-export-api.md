# 資料匯出 API（後端 Rails）

規格：PRD 第 24 條、資料模型 §3.7 DataExport、§2.7 AuditLog、§3.6 Notification。
全部限**管理員**；員工呼叫一律 `403 FORBIDDEN`。別家公司的匯出一律 `404 NOT_FOUND`。
錯誤格式同 `api-conventions.md`：`{ error: "大寫代碼", message: "給使用者看的句子" }`。

**欄位寫法**：後端只認 snake_case（例：`payout_status`），回應也是 snake_case。前端寫 camelCase，由 `frontend/src/api/service.ts` 自動轉換。本文件第 1 節的參數用後端實際接受的 snake_case；第 2、4、6 節的回應用前端拿到的 camelCase。直接呼叫 API（curl、測試）時請用 snake_case。

## 1. 發起匯出 `POST /api/data-exports`

一次只匯出一個列表（在哪個列表只匯出該列表）。

```jsonc
{
  "kind":  "expense" | "income" | "reimbursement",
  "scope": "single" | "selected" | "filtered",
  "ids":   ["uuid", ...],      // single 恰 1 筆；selected 1～100 筆
  "filters": { ... }            // filtered 用；可省略，省略就是該列表全部
}
```

| scope | 用途 | 支出 | 收入 | 代墊款 |
|---|---|---|---|---|
| `single` | 明細裡的「匯出」 | ✓ | ✓ | ✓ |
| `selected` | 選取列／頁首「已選項目」 | ✓ | ✓ | ✓ |
| `filtered` | 頁首「全部支出／全部收入／全部請款」 | ✓ | ✓ | ✓ |

`filters` 沿用列表查詢參數，全部選填（前端寫法為對應的 camelCase，例：`payoutStatus`）：

| 類型 | 參數 |
|---|---|
| 支出 | `date_from`、`date_to`、`source`、`category_ids`、`payout_status`、`q`（賣方／說明／發票號碼）、`missing_invoice_no` |
| 收入 | `date_from`、`date_to`、`recurring`、`category_ids`、`collection_status`、`q`（客戶／說明／發票號碼）、`missing_invoice_no` |
| 代墊款 | `date_from`、`date_to`、`status`（分頁標籤；「全部」不帶）、`category_ids`、`q`（賣方／說明／發票號碼）、`amount_min`、`amount_max` |

- 只接受上表該類型的參數。帶了其他參數（拼錯、camelCase、別的列表才有的、`page`）或型別不對（例如 `category_ids` 不是陣列），一律回 `422 INVALID_FILTER`，不會忽略後匯出全部。值為 `null` 視同沒選。

- 語意與列表相同（收入列表目前在前端篩選，後端照同樣規則做；支出、代墊款與列表 API 共用同一份篩選程式）。
- 發生日期區間選填，可只帶一端；都沒帶就是不限日期。
- 支出、收入不含垃圾桶內的紀錄；代墊款同「全部紀錄」列表，排除草稿（代墊款沒有垃圾桶）。

### 回應

- **這次匯出都沒有圖檔** → `200`，直接回 CSV（`text/csv; charset=utf-8`，UTF-8 BOM），`Content-Disposition` 帶檔名，例：`支出_2026-11-06.csv`、`代墊款_2026-11-09.csv`。不寄信。不論筆數多少都當下下載；後端分批讀、邊讀邊輸出（沒有 `Content-Length`）。
- **有任何一筆有圖檔** → `202`：`{ "id": "uuid", "status": "queued" }`。背景產生，完成或失敗寄信給發起人並寫站內通知。

### 錯誤

| 狀態 | `error` | 時機 |
|---|---|---|
| 403 | `FORBIDDEN` | 員工 |
| 422 | `INVALID_SCOPE` | 範圍不正確（含 `full`、`period`） |
| 422 | `INVALID_KIND` | 類型不正確（含 `all`） |
| 422 | `IDS_REQUIRED` | single 不是恰好 1 筆、selected 沒帶 |
| 422 | `TOO_MANY_IDS` | selected 超過 100 筆 |
| 422 | `INVALID_DATE` | 日期格式錯或起日晚於迄日 |
| 422 | `INVALID_FILTER` | `filters` 不是物件、帶了不認得的參數或型別不對 |
| 422 | `INVALID_AMOUNT` | 代墊款 `amountMin`／`amountMax` 不是數字 |
| 422 | `NO_RECORDS` | 範圍內沒有紀錄（含勾選的都已進垃圾桶、單筆在垃圾桶、代墊款單筆是草稿或別家公司、目前篩選沒有紀錄） |

## 2. 查詢 `GET /api/data-exports/:id`

同公司管理員都可查（不限發起人）。

```jsonc
{
  "id": "uuid",
  "scope": "filtered",
  "kind": "expense",
  "scopeLabel": "支出 2026/11/01–2026/11/30",
  "recordCount": 42,
  "withAttachments": true,
  "background": true,             // false = 當下下載，沒有存檔
  "status": "queued" | "processing" | "completed" | "failed",
  "createdAt": "ISO 8601",
  "completedAt": "ISO 8601" | null,
  "expiresAt": "ISO 8601" | null, // 背景產生完成才有
  "expired": false,
  "requestedBy": { "id": "uuid", "name": "王管理" },
  "files": [                      // 完成且未失效才有；其餘為 []
    { "key": "expense_csv", "kind": "csv", "filename": "支出_2026-11-06.csv", "byteSize": 1234 },
    { "key": "attachments_zip", "kind": "zip", "filename": "圖檔_2026-11-06.zip", "byteSize": 5678901 }
  ]
}
```

- `key`：`expense_csv`、`income_csv`、`reimbursement_csv`、`attachments_zip`。一次最多兩個（該類型的 CSV＋ZIP）。
- `scopeLabel` 規則：單筆「支出 單筆」「代墊款 單筆」、勾選「代墊款 勾選 5 筆」（筆數為勾選的 id 數）、filtered 有發生日期區間「支出 2026/11/01–2026/11/30」、只帶一端「支出 2026/11/01 起」「支出 至 2026/11/30」、沒有區間「收入 全部」（其他篩選不寫進文字）。稽核日誌列表的 `targetLabel` 同此文字。

## 3. 下載 `GET /api/data-exports/:id/files/:key`

回 `{ "url": "/api/data-exports/download/<token>" }`，短效簽章網址（到下一個整點再加一小時失效，綁使用者）。前端直接 `location` 跳轉，瀏覽器串流下載，不需 Bearer。

- 已失效（`expiresAt` 已過）→ `410 EXPORT_EXPIRED`「下載連結已失效，請重新匯出」。取網址與實際下載兩處都檢查。
- 尚未完成、失敗、或沒有這個 key → `404 NOT_FOUND`。
- 簽章網址無效、過期、使用者已非同公司管理員 → `404`。

## 4. 站內通知（Notification.kind）

| kind | payload |
|---|---|
| `data_export_ready` | `dataExportId`、`scopeLabel`、`recordCount`、`expiresAt` |
| `data_export_failed` | `dataExportId`、`scopeLabel` |

收件人為發起人。點擊導向 `/admin/exports/:dataExportId`。

## 5. Email

完成信、失敗信寄給發起人，連結 `${FRONTEND_BASE_URL}/admin/exports/:id`（前端下載頁；未登入由前端導向登入再回來）。完成信附失效時間。

## 6. 稽核日誌

每次發起寫一筆：`targetType: "data_export"`、`action: "export"`、`targetId` 為 DataExport id。`after`：

```jsonc
{
  "scope": "filtered",
  "kind": "expense",
  "criteria": {
    "dateFrom": "2026-11-01", "dateTo": "2026-11-30",
    "filters": { "categoryIds": ["uuid", ...], "categoryNames": ["交通費", ...], "q": "..." }
  },
  // single／selected：{ "ids": [...] }
  // filtered：dateFrom／dateTo 沒選就不出現；filters 只記有選的條件；categoryNames 是發起當下的類別名稱，順序同 categoryIds
  // （類別之後改名或永久刪除，日誌仍顯示當時的名稱；不是本公司的類別記 null）
  "recordCount": 42,
  "withAttachments": true
}
```

`recordCount` 為發起當下的筆數；背景產生以產生當下為準，更新在 DataExport 上，不改日誌。下載不寫日誌。

## 7. 檔案內容

- CSV：UTF-8 BOM、一筆一列；日期 `YYYY-MM-DD`、金額為數字（同代墊款「全部紀錄」匯出）。品項合併一欄，多個以「；」分隔；圖檔欄列 ZIP 內檔名，多張以「；」分隔。
- 支出欄：發生日期、發票日期、應付日期、實付日期、文件類型、賣方、統一編號、發票號碼、類別、帳戶、稅別、未稅金額、稅額、含稅金額、付款狀態、來源、說明、品項、圖檔。
- 收入欄：發生日期、發票日期、應收日期、實收日期、文件類型、客戶、統一編號、發票號碼、類別、帳戶、稅別、未稅金額、稅額、含稅金額、收款狀態、說明、品項、圖檔。
- 代墊款欄：沿用「全部紀錄」頁原本 CSV 匯出的欄位（申請人、說明、類別、金額、發生日期、發票日期、狀態、建立時間），另加品項、圖檔。
- ZIP：不分資料夾，檔名「發生日期_賣方或客戶或申請人_原始檔名」，同名加 `(2)`、`(3)`（不分大小寫）；名稱空白時略過該段。

## 7-1. 已移除

- 代墊款「全部紀錄」原本的 `GET /api/reimbursements/export?format=csv|xlsx` 已移除，改用本 API（`kind: "reimbursement"`）。
- 跨模組完整匯出（`scope: "full"`、`kind: "all"`）首版不提供，隨用量頁面再議。

## 8. 排程

每小時（第 30 分）執行一次：

- 清除 `expiresAt` 已過的匯出檔，DataExport 本身保留。匯出檔不計入公司儲存空間。
- **逾時回收**：發起後超過 **3 小時**仍是 `queued`／`processing` 的（背景工作卡住，例如機器重啟），標成 `failed`，刪除產生到一半的檔案，照失敗流程寄失敗信、寫 `data_export_failed` 站內通知。因為每小時檢查一次，卡住的匯出最晚約 4 小時內會變成失敗並通知。之後原本的背景工作就算跑完，也不會改回完成、不會再寄信。
- 不限制同公司同時進行的匯出數量（規格允許同時發起多個）。
