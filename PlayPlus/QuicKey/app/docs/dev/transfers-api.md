# 資金移轉 API 合約（feat/fund-transfers）

規格來源：PRD 第 18～21 條；資料模型 §2.2、§2.9、§2.10、§3.4、§4.3、§六。

下方欄位都是 wire format（snake_case）；`api/service.ts` 會轉成 camelCase。

全部 API **僅 admin**，員工回 403 `{ error: "forbidden" }`。資料都限定在呼叫者的公司；別家公司的 id 一律當成找不到。

錯誤一律帶 `error`（代碼）與 `message`（可直接顯示）。

---

## 1. 資金移轉

| 方法 | 路徑 | 用途 |
|---|---|---|
| GET | `/api/transfers` | 列表、垃圾桶 |
| GET | `/api/transfers/:id` | 單筆，垃圾桶內的也查得到 |
| POST | `/api/transfers` | 新增 |
| PATCH | `/api/transfers/:id` | 編輯，垃圾桶內的回 404 |
| DELETE | `/api/transfers/:id` | 進垃圾桶，任何時候都可以 |
| PATCH | `/api/transfers/:id/restore` | 還原 |
| DELETE | `/api/transfers/:id/purge` | 永久刪除，只限垃圾桶內的 |

### 列表 `GET /api/transfers`

| 參數 | 說明 |
|---|---|
| `discarded` | `true` 時回垃圾桶；不帶回未刪除的（和支出、帳戶相同） |
| `date_from`、`date_to` | 移轉日期區間，含頭尾，格式 `YYYY-MM-DD`；格式不對時視同沒帶 |
| `from_account_id` | 轉出帳戶 |
| `to_account_id` | 轉入帳戶 |
| `page`、`per_page` | 預設每頁 10 筆，上限 100 |

未刪除的依移轉日期新到舊；垃圾桶依刪除時間新到舊。

回傳 `{ data: [...], meta: { total, page, page_size } }`。

### 回傳形狀 Transfer

單筆：

```json
{
  "id": "uuid",
  "from_account": { "id": "uuid", "name": "永豐-總公司" },
  "to_account": { "id": "uuid", "name": "零用金" },
  "amount": 5000.0,
  "fee": 15.0,
  "transfer_date": "2026-11-02",
  "note": "提領零用金",
  "attachments": [{ "id": "uuid", "filename": "a.png", "mime_type": "image/png", "byte_size": 12345, "url": "/api/files/…" }],
  "fee_expense_id": "uuid",
  "created_by": { "id": "uuid", "name": "王管理" },
  "deleted_at": null,
  "deleted_by": null,
  "created_at": "2026-11-02T10:00:00+08:00",
  "updated_at": "2026-11-02T10:00:00+08:00"
}
```

- 列表回同樣的形狀，只少了 `attachments`。
- `deleted_by`：`{ id, name }`，只有垃圾桶內的紀錄有值。
- `fee_expense_id`：手續費目前對應的支出；手續費為 0 時是 `null`。移轉在垃圾桶時仍保留，但那筆支出也在垃圾桶，`GET /api/expenses/:id` 回 404，不要放連結。
- `attachments` 和支出同一個結構與限制（實體檔案），見 `attachments-api.md`。

### 新增 `POST /api/transfers`

```json
{
  "from_account_id": "uuid",
  "to_account_id": "uuid",
  "amount": 5000,
  "fee": 15,
  "transfer_date": "2026-11-02",
  "note": "提領零用金",
  "attachment_ids": []
}
```

- `fee`、`note`、`attachment_ids` 選填；`attachment_ids` 是要掛上的暫存檔 id（見 `attachments-api.md` 第 3 節，編輯時同樣只帶新加的）；`fee` 沒帶或空字串視為 0。
- 回 201 與單筆形狀。手續費大於 0 時同時產生手續費支出，不另發通知。

### 編輯 `PATCH /api/transfers/:id`

欄位同新增，只送要改的。回 200 與單筆形狀。

同步手續費支出：

- 手續費大於 0 且已有支出：同步金額、發生日期、應付日期、實付日期（三個都是移轉日期）、帳戶（轉出帳戶）。
- 手續費改為 0：該支出進垃圾桶，`fee_expense_id` 清空。
- 手續費從 0 改回大於 0：產生新的一筆，舊的留在垃圾桶。

**日期檢查**：新增、編輯、還原都檢查移轉日期不可早於兩個帳戶的起始月份。帳戶端會擋住起始月份調到移轉之後（見第 4 節），所以垃圾桶外的移轉不會出現日期早於起始月份的情況，編輯時不用另外判斷。

### 刪除、還原、永久刪除

- `DELETE /api/transfers/:id`：回 `{}`。手續費支出一併進垃圾桶。
- `PATCH /api/transfers/:id/restore`：回單筆形狀，手續費支出一併還原。移轉日期早於任一帳戶起始月份時回 409 `TRANSFER_DATE_BEFORE_OPENING`，帶 `sides`，訊息指出是哪個帳戶。
- `DELETE /api/transfers/:id/purge`：回 `{}`。所有指向它的支出一併永久刪除，包含先前手續費改為 0 留在垃圾桶的。

### 錯誤

新增、編輯都是 422（還原見上方，是 409）。帳戶相關的多帶 `sides`，告訴前端是哪個欄位：`"from"` 轉出、`"to"` 轉入，兩邊都有問題時兩個都列。

| 代碼 | 情況 | `sides` |
|---|---|---|
| `ACCOUNT_REQUIRED` | 沒選帳戶 | 有 |
| `SAME_ACCOUNT` | 轉出、轉入相同 | `["from", "to"]` |
| `ACCOUNT_NOT_FOUND` | 帳戶不存在、別家公司或在垃圾桶 | 有 |
| `TRANSFER_DATE_BEFORE_OPENING` | 移轉日期早於帳戶起始月份，訊息會寫出帳戶名稱 | 有 |
| `INVALID_TRANSFER_DATE` | 沒填或格式不對 | 無 |
| `INVALID_AMOUNT` | 金額要大於 0，最多兩位小數 | 無 |
| `INVALID_FEE` | 手續費不可為負，最多兩位小數 | 無 |
| `ATTACHMENT_NOT_FOUND` | 要掛上的圖檔找不到或不是自己上傳的 | 無 |
| `TOO_MANY_ATTACHMENTS` | 圖檔超過 5 張 | 無 |

一次回第一個錯誤。

```json
{
  "error": "TRANSFER_DATE_BEFORE_OPENING",
  "message": "移轉日期早於「零用金」（2026-05）的起始月份，請先把帳戶的起始月份和起始金額往前調",
  "sides": ["to"]
}
```

---

## 2. 支出

列表、垃圾桶列表、單筆都多三個欄位：

| 欄位 | 說明 |
|---|---|
| `transfer_id` | 手續費支出指回的移轉；其他支出是 `null`。移轉在垃圾桶時一樣能用 `GET /api/transfers/:id` 查 |
| `restorable` | 可不可以還原。手續費支出一律 `false` |
| `purgeable` | 可不可以永久刪除。移轉目前對應的手續費支出是 `false`；手續費改為 0 留下的是 `true` |

- `source` 多一個值 `transfer_fee`；來源篩選用 `source=transfer_fee`。`source=general` 不含手續費支出。
- 來源代墊款已作廢的支出，`restorable` 仍是 `true`，按下去維持回 409 `REIMBURSEMENT_VOIDED`，行為和現在一樣。
- 手續費支出的 `vendor` 是 `null`，`note` 是「資金移轉手續費」。

手續費支出呼叫下列 API 一律回 409 `TRANSFER_FEE_LOCKED`：`PATCH /api/expenses/:id`、`pay`、`revert-pay`、`adjust-payout-date`、`DELETE /api/expenses/:id`、`restore`。

`purge` 只有 `purgeable=true` 的可以，否則回同一個代碼。移轉在垃圾桶時，手續費改為 0 留下的舊支出仍可單獨永久刪除，因為還原移轉用不到它。

---

## 3. 類別

- 類別形狀多 `system_key`：手續費類別是 `"transfer_fee"`，其他是 `null`。
- `include_usage=true` 時，手續費類別的 `deletable`、`archivable` 為 `false`，`blocked_reason` 有說明，`purgeable` 為 `false`。
- 停用、刪除、永久刪除手續費類別回 409 `CATEGORY_SYSTEM_RESERVED`。
- 可以改名，也可以選給一般支出和員工請款使用。手動選這個類別的紀錄不鎖定，照一般規則編輯與刪除；`TRANSFER_FEE_LOCKED` 只看 `source=transfer_fee`，不看類別。
- 公司缺手續費類別時，建立有手續費的移轉會自動補上，規則同既有公司補類別：有同名支出類別就沿用，停用中或在垃圾桶的恢復為使用中，沒有則新增，不寫稽核。前端不用處理。

---

## 4. 帳戶

- `references` 多 `transfers`：轉出、轉入都算，含垃圾桶內的移轉。有移轉的帳戶 `deletable` 為 `false`，刪除回 409 `ACCOUNT_IN_USE`。
- 起始月份不可調到垃圾桶外的移轉日期之後，轉出、轉入都算。`PATCH /api/accounts/:id` 回 409 `OPENING_MONTH_AFTER_TRANSFER`：

```json
{
  "error": "OPENING_MONTH_AFTER_TRANSFER",
  "message": "有 3 筆資金移轉的日期早於這個起始月份，最早為 2026-02-15，請先修改移轉日期或刪除移轉",
  "transfer_count": 3,
  "earliest_transfer_date": "2026-02-15"
}
```

- 垃圾桶內的移轉不擋調整，但之後還原會被擋（第 1 節）。
- `GET /api/accounts/:id/opening-month-impact` 多兩個欄位，讓前端在送出前提示。`outside_cash_flow_count`、`outside_cash_flow` 維持只算收支，不含移轉。

```json
{
  "opening_month": "2026-08-01",
  "outside_cash_flow_count": 5,
  "outside_cash_flow": { "expenses": 3, "incomes": 2 },
  "blocking_transfer_count": 3,
  "earliest_transfer_date": "2026-02-15"
}
```

`blocking_transfer_count` 大於 0 時，這個月份存不了；沒有時 `earliest_transfer_date` 是 `null`。

---

## 5. 現金流報表

`GET /api/reports/cashflow` 帶 `account_id`（單一帳戶）時，`rows[]` 與 `total` 多兩個欄位：

| 欄位 | 說明 |
|---|---|
| `transfer` | 移轉淨額，轉入為正、轉出為負 |
| `transfer_count` | 這一期的移轉筆數。轉入、轉出相抵時 `transfer` 是 0，用這個判斷有沒有移轉 |

- `cash_in`、`cash_out` 不含移轉，維持真實收支。
- `net` ＝ `cash_in` − `cash_out` ＋ `transfer`，所以期初＋淨現金流＝期末。
- 選所有帳戶時這兩個 key 不回，也不查移轉。
- 垃圾桶外的移轉一律計入。
- Excel 匯出：單一帳戶時多一欄「資金移轉」，在「付款」和「淨流」之間，合計列同步。

---

## 6. 稽核

`GET /api/audit-logs?target_type=transfer&target_id=uuid`。

新增、永久刪除的內容（`create` 的 `after`、`purge` 的 `before`）：

```json
{
  "from_account_id": "uuid", "from_account_name": "永豐-總公司",
  "to_account_id": "uuid", "to_account_name": "零用金",
  "amount": 5000.0, "fee": 15.0, "transfer_date": "2026-11-02", "note": "提領零用金"
}
```

`update` 只列有變動的欄位：`from_account_id`、`to_account_id`、`amount`、`fee`、`transfer_date`、`note`、`attachments`（檔名陣列；新掛上或刪除已存圖檔時）；帳戶有變時兩邊都補 `from_account_name` 或 `to_account_name`。`delete`、`restore` 是 `deleted_at`。

**手續費支出的標記**：手續費支出的每筆異動都帶 `via: "transfer_fee"`，顯示「資金移轉手續費自動產生」。

| 動作 | 位置 |
|---|---|
| `create`、`update`、`delete`、`restore` | `after.via` |
| `purge` | `before.via`（`after` 是 `null`） |

判斷時用 `(entry.after ?? entry.before)?.via`。手續費支出的 `target_type` 仍是 `expense`，`source` 是 `transfer_fee`。
