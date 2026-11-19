# 垃圾桶批次還原與永久刪除 API

規格：`docs/產品規格文件.md` 第 18 條「批次還原與永久刪除」。只有支出、收入提供，其他垃圾桶維持逐筆操作。

## 1. Endpoint

| Method | Path | Body |
|---|---|---|
| POST | `/api/expenses/batch_restore` | `{ ids: [...] }` |
| POST | `/api/expenses/batch_purge` | `{ ids: [...], void_comment?: string }` |
| POST | `/api/incomes/batch_restore` | `{ ids: [...] }` |
| POST | `/api/incomes/batch_purge` | `{ ids: [...] }` |

權限同單筆：只有管理員，員工回 403。

## 2. 回應

整批檢查通過就回 200，不論每筆成功或失敗：

```json
{
  "succeeded": ["id1", "id3"],
  "failed": [
    { "id": "id2", "error": "REIMBURSEMENT_VOIDED", "message": "來源代墊款已作廢，不可還原；要還原請先到請款記錄取消作廢" }
  ]
}
```

- `succeeded`、`failed` 的順序同送出的 `ids`；重複的 id 只處理一次。
- `message` 是給使用者看的中文，可以直接顯示。
- 失敗的紀錄留在垃圾桶，資料不動。

整批不處理的情況（回 422，什麼都不做）：

| `error` | 情況 |
|---|---|
| `IDS_REQUIRED` | `ids` 沒帶、不是陣列或是空的 |
| `TOO_MANY_IDS` | 去掉重複後超過 50 筆 |

## 3. 每筆的處理

每筆各自一個交易，一筆失敗不影響其他筆。判斷和單筆 `restore`、`purge` 用同一份程式（`app/services/expense_trash.rb`、`income_trash.rb`），單筆不能做的，批次列為失敗：

| `error` | 適用 | 情況 |
|---|---|---|
| `NOT_FOUND` | 全部 | 不在本公司的垃圾桶：別家公司的、不在垃圾桶的、已永久刪除的、id 格式不對 |
| `TRANSFER_FEE_LOCKED` | 支出還原 | 資金移轉產生的手續費支出 |
| `REIMBURSEMENT_VOIDED` | 支出還原 | 來源代墊款已作廢 |
| `TRANSFER_FEE_LOCKED` | 支出永久刪除 | 移轉目前對應的手續費支出（移轉在垃圾桶）。手續費改為 0 留下的可以刪 |
| `VOID_REQUIRED` | 支出永久刪除 | 來源代墊款尚可作廢，但 `void_comment` 沒帶或空白 |
| `VALIDATION_FAILED` | 全部 | 資料驗證失敗，`message` 是驗證訊息 |
| `FAILED` | 全部 | 其他資料庫錯誤 |

**支出永久刪除與作廢**：來源代墊款尚可作廢（審核中、駁回、已核准）的那幾筆，用同一個 `void_comment` 一起作廢，作廢原因去掉前後空白後寫入。來源代墊款已作廢、或不是代墊款產生的，直接刪，不看 `void_comment`。

稽核日誌和單筆相同，每筆各寫一筆：還原寫 `restore`，永久刪除寫 `purge`，連帶作廢的代墊款另寫 `void`。

## 4. 前端事先判斷

垃圾桶列表（`GET /api/expenses?discarded=true`）每筆已有：

- `restorable`：`false` 是手續費支出，不可還原。
- `purgeable`：`false` 是移轉目前對應的手續費支出，不可永久刪除。
- `source_reimbursement_status`：來源代墊款目前狀態。為 `in_review`、`rejected`、`approved` 時，永久刪除會一起作廢。`voided` 時不可還原。

「其中 N 筆的來源代墊款會同時作廢」的 N ＝ 選取的列中 `purgeable` 為 `true`、`source_reimbursement_status` 為上述三種之一的筆數。

## 5. 單筆 API 的錯誤回應

單筆 `restore`、`purge`、支出 `DELETE`（連帶作廢）的錯誤代碼與 HTTP 狀態不變，回應多帶 `message`：`{ error, message }`。
