# 帳戶 API 合約（feat/accounts）

規格來源：PRD 第 18、20、21 條；資料模型 §2.2、§2.6、§2.9、§4.3；`docs/QA_list/QA_帳戶設定.md`。

下方欄位都是 wire format（snake_case）；`api/service.ts` 會轉成 camelCase。FormData 的 key 維持 snake_case。

全部 API **僅 admin**，員工回 403 `{ error: "forbidden" }`。資料都限定在呼叫者的公司；別家公司的 id 一律當成找不到。

---

## 1. 帳戶 CRUD

### 回傳形狀 Account

```json
{
  "id": "uuid",
  "name": "永豐-總公司",
  "currency": "TWD",
  "opening_amount": 100000.0,
  "opening_month": "2026-10-01",
  "references": { "expenses": 3, "incomes": 0, "recurring_templates": 0, "transfers": 0 },
  "deletable": false,
  "deleted_at": null,
  "deleted_by": null,
  "created_at": "...",
  "updated_at": "..."
}
```

- `opening_amount`：起始金額，視為 `opening_month` 月初的餘額。
- `opening_month`：起始月份，回傳該月第一天。這個月之前的月份不顯示該帳戶。
- `references`：各來源的引用筆數，**含垃圾桶內的紀錄**。前端請逐 key 處理，不要寫死。
- `deletable`：`references` 全為 0 時才是 true。用來在按刪除前就顯示原因。
- `deleted_by`：`{ id, name }` 或 null，垃圾桶的「操作人」。

欄位很少，所以列表與單筆形狀相同，沒有單筆 GET。

### 路徑

| 方法 | 路徑 | 說明 |
|---|---|---|
| GET | `/api/accounts?page=&per_page=&discarded=` | 帳戶設定頁列表，分頁信封 `{ data, meta: { total, page, page_size } }`，依建立時間舊到新。`discarded=true` 取垃圾桶，依刪除時間新到舊 |
| GET | `/api/accounts/options` | **下拉選單用，全量不分頁**，見下方 |
| GET | `/api/accounts/:id/opening-month-impact?opening_month=2026-08` | 起始月份改成指定月份時，有幾筆會不計入現金流，見第 1.1 節。只查詢，不寫入 |
| POST | `/api/accounts` | body `{ name, opening_amount, opening_month? }`，回 201 + Account。沒帶 `opening_month` 時為當月。帶了 `account_type` 一律忽略 |
| PATCH | `/api/accounts/:id` | body `{ name?, opening_amount?, opening_month? }`，回 Account。垃圾桶內的帳戶回 404 |
| DELETE | `/api/accounts/:id` | 進垃圾桶，回 `{}`。被引用時回 409 |
| PATCH | `/api/accounts/:id/restore` | 還原，回 Account |
| DELETE | `/api/accounts/:id/purge` | 永久刪除，回 `{}`。仍被引用時回 409 |

`GET /api/accounts/options` 回傳：

```json
{
  "data": [ { "id": "uuid", "name": "零用金", "opening_month": "2026-08-01" } ],
  "last_used_account_id": "uuid 或 null"
}
```

新增、編輯、刪除的稽核走 `GET /api/audit-logs?target_type=account&target_id=:id`。起始金額、起始月份變更在 `before`、`after` 的 `opening_amount`、`opening_month`。

`opening_month` 傳 `YYYY-MM` 或 `YYYY-MM-DD`，後端一律轉成該月第一天。範圍 2000 年 1 月至當月，建立、修改、impact 查詢都驗證。

`opening_month` 也在 `/accounts/options` 回傳：單筆表單選完日期或帳戶後，實收／實付日期早於它就顯示「不計入現金流」的提示。後端不擋，這種紀錄照常儲存，只是不計入該帳戶的現金流與餘額。待收款、待付款不受影響。

### 1.1 起始月份往後調的提示筆數

二次確認視窗打開前呼叫 `GET /api/accounts/:id/opening-month-impact?opening_month=2026-08`：

```json
{
  "opening_month": "2026-08-01",
  "outside_cash_flow_count": 5,
  "outside_cash_flow": { "expenses": 3, "incomes": 2 },
  "blocking_transfer_count": 0,
  "earliest_transfer_date": null
}
```

- 算的是「改成這個月份後，實收／實付日期早於它的已付款、已收款筆數」，不含待付款、待收款與垃圾桶內的紀錄。
- 這是改完後的總筆數，原本就不計入的也算在內。
- 0 筆時不用顯示提示。`outside_cash_flow` 只算收支，不含資金移轉；移轉會直接擋下調整，見 `transfers-api.md` 第 4 節。
- 錯誤同下表的 `INVALID_OPENING_MONTH`，帳戶不存在回 404。

### 錯誤

一律帶 `message`，可直接顯示。

| 狀態 | `error` | 時機 |
|---|---|---|
| 422 | `INVALID_NAME` | 名稱空白或超過 50 字 |
| 422 | `INVALID_OPENING_AMOUNT` | 起始金額空白、不是數字、小於 0、或超過 9,999,999,999.99 |
| 422 | `INVALID_OPENING_MONTH` | 起始月份空白、格式錯誤，或不在 2000 年 1 月至當月之間（POST 完全沒帶這個 key 時用當月，不算錯誤） |
| 409 | `DUPLICATE_NAME` | 名稱重複，另帶 `account`（撞到的那筆） |
| 409 | `ACCOUNT_IN_USE` | 刪除或永久刪除時仍被引用，另帶 `references` |
| 409 | `OPENING_MONTH_AFTER_TRANSFER` | 起始月份調到資金移轉日期之後，另帶 `transfer_count`、`earliest_transfer_date`，見 `transfers-api.md` 第 4 節 |
| 404 | `not_found` | 找不到（包含別家公司的 id） |

**名稱重複**：比對時不分大小寫、忽略前後空格，**垃圾桶內的帳戶也算重複**。撞到垃圾桶內的帳戶時，`account.deleted_at` 有值，`message` 會請使用者去還原或永久刪除。因為垃圾桶內的名稱不會被佔走，**還原永遠不會撞名**，不需要處理。

---

## 2. 上一次使用的帳戶

- **由後端算**，不存前端，換裝置也一致。
- 值為「這位使用者最新建立、不在垃圾桶的一筆收支目前的帳戶」，依建立時間判斷，從 `GET /api/accounts/options` 的 `last_used_account_id` 取得。
- 範圍：使用者個人，支出、收入共用。
- 手動新增、Excel 匯入、代墊款核准都算，因為它們都會建立收支。編輯既有紀錄不算。
- 從未用過，或那個帳戶已刪除，回 null，表單預設留空。
- 每次打開表單重新取一次，不要快取；剛新增完回到表單時值會變。
- 批次憑證逐筆核對時「帶上一張所選」是前端的畫面狀態，後端只給第一張的預設值。

---

## 3. 支出、收入

- `POST /api/expenses`、`POST /api/incomes`：`account_id` **必填**（含待付款、待收款）。批次匯入憑證最後也是走這兩支，不另外處理。
- `PATCH /api/expenses/:id`、`PATCH /api/incomes/:id`：帶了 `account_id` 才改，任何狀態都可以改，寫入稽核（`before`、`after` 含 `account_id`、`account_name`）。帶空值回 `ACCOUNT_REQUIRED`。
- `/pay`、`/collect` 不收帳戶，沿用紀錄上的帳戶。
- Summary 與單筆都多一個 `account: { id, name }`。

| 狀態 | `error` | 時機 |
|---|---|---|
| 422 | `ACCOUNT_REQUIRED` | 沒帶或帶空值 |
| 422 | `ACCOUNT_NOT_FOUND` | 帳戶不存在、屬於別家公司，或在垃圾桶 |

**剛好有人同時刪除帳戶時**：檢查通過後、存檔前帳戶被刪掉，會回 422 `validation_failed`，`details.account_id` 有錯誤訊息，請使用者重新選帳戶。

**帳戶進垃圾桶的舊紀錄如何顯示**：不會發生。只要有紀錄引用（含垃圾桶內的紀錄），帳戶就不能刪除，所以 `account` 一定有值，名稱也永遠是最新的。

---

## 4. Excel 匯入

- 範本新增「帳戶」欄（選填），排在「類別」後面。標題可以缺，缺少時視為整欄空白，舊範本仍可用。
- 有填且找得到：依名稱比對本公司未刪除的帳戶，不分大小寫。
- 空白：帶入上一次使用的帳戶。
- 有填但找不到或在垃圾桶：該筆**仍可匯入**，名稱列入預覽的 `accounts`，由使用者選既有帳戶對應。比照類別對應，**依名稱**選一次，同名的列全部套用，**不提供新增**。
- 空白且沒有上一次使用的帳戶：該筆不匯入，`messages` 列出原因。
- 公司沒有任何未刪除的帳戶：preview 與 import 都整份退回 422 `NO_ACCOUNTS`，`message` 提示先建立帳戶。
- 實收／實付日期早於帳戶起始月份：**照常匯入**。帳戶已確定的列在預覽是 `warning`，`messages` 有「實付日期早於帳戶「X」的起始月份，不計入現金流」。畫面標示請用下方的 `outside_cash_flow`，不要比對訊息文字。要使用者對應帳戶的列，預覽時還不知道帳戶，不會標示，由完成畫面的筆數涵蓋。

preview 回傳多一個 `accounts`，只列**會被匯入**的單據用到的名稱，每個名稱（不分大小寫）一項：

```json
{ "accounts": [ { "name": "銀行", "rows": [ 2, 5 ], "state": "missing" } ] }
```

- `state`：`missing`（找不到）或 `discarded`（在垃圾桶）。
- `rows`：用到這個名稱的單據第一列 Excel 列號，和 `excluded_rows` 同一種列號。前端移除單據後，若某名稱的 `rows` 全被移除，就從對應區拿掉，比照類別。
- `records[].summary.account_name`：可匯入時為這筆會用的帳戶名稱，還沒對應的是檔內寫的名稱；不匯入時為 null。
- `records[].summary.outside_cash_flow`：`true` 表示這筆不計入現金流，`false` 表示計入（含待付款、待收款）；帳戶還要使用者對應、或這筆不匯入時為 `null`。

import 多一個 `account_mapping`（FormData 的 JSON 字串，選填）：

```json
{ "銀行": "既有帳戶的 uuid" }
```

- key 用 preview 回傳的 `name`，比對不分大小寫。對應的選項來自 `GET /api/accounts/options`。
- 沒有 `default_account_id`，也沒有預設對應：`accounts` 裡還會被匯入的名稱都要選。

| 狀態 | `error` | 時機 |
|---|---|---|
| 422 | `INVALID_ACCOUNT_MAPPING` | 有名稱沒選，或 `account_mapping` 不是 JSON 物件 |
| 409 | `ACCOUNT_CHANGED` | 對應到的帳戶已刪除或不存在，或匯入途中帳戶剛好被刪除，**需要重新預覽**，請加進 `IMPORT_REPREVIEW_CODES` |
| 422 | `NO_ACCOUNTS` | 公司沒有任何未刪除的帳戶（preview、import 都會回） |

import 會重新解析檔案；預覽後檔內帳戶被刪掉時，它會變成需要對應但沒選，回 `INVALID_ACCOUNT_MAPPING`，一樣請使用者重新選。

import 成功的回應多一個 `outside_cash_flow_count`：本次建立的紀錄中，實收／實付日期早於帳戶起始月份、不計入現金流的筆數，**包含使用者在預覽對應帳戶的列**。大於 0 時在完成畫面列出。

---

## 5. 代墊款核准

`PATCH /api/reimbursements/:id/approve` body 加 `account_id`（必填），`comment` 不變。錯誤同第 3 節（`ACCOUNT_REQUIRED`、`ACCOUNT_NOT_FOUND`）。

- 帳戶存在連動的支出上，不另外存在代墊款。撥款沿用支出上的帳戶，核准後在支出詳情改帳戶也會沿用。
- 批次通過逐筆呼叫同一支、帶同一個帳戶，可行。
- 員工看不到帳戶：`linked_expense` 只有 admin 才多一個 `account: { id, name }`，員工的回應沒有這個欄位。

---

## 6. 現金流報表

`GET /api/reports/cashflow` 與 `/api/reports/cashflow.xlsx` 吃同一組 query，新增 `account_id`：

- 未帶：所有帳戶合計。
- 有帶：只算該帳戶，待收款、待付款清單也只列該帳戶。
- 帳戶不存在、屬於別家公司或在垃圾桶：422 `ACCOUNT_NOT_FOUND`。

`rows[]` 與 `total` 各多兩個 key：

```json
{ "label": "2026-08", "cash_in": 0, "cash_out": 0, "net": 0, "opening_cash": 50000.0, "closing_cash": 50000.0 }
```

- `opening_cash`（期初）、`closing_cash`（期末）。尚未有任何帳戶開始的期間為 **null，不是 0**，前端顯示「—」。
- `total.opening_cash` 是第一個有值的期間的期初，`total.closing_cash` 是最後一個期間的期末。
- bucket 為季、年時：期初是該期間第一天的餘額，期末是最後一天的餘額。帳戶若在期間中才建立，它的起始金額算進該期間的期初。
- 起始月份之前：該帳戶的收付款**不計入** `cash_in`、`cash_out`，也不計入期初、期末；損益報表照常計入。
- 自訂區間從月中開始時，期初算到 `from` 當天之前。
- 「所有帳戶」檢視中，某帳戶的起始月份是當月時，當月期初會比上月期末多出它的起始金額。單一帳戶檢視沒有這個現象。
- 報表每次依起始金額與收付款即時計算，所以改舊紀錄後數字會跟著變，跨年也不需要設定。
- 資金移轉之後的卡片才會影響這裡。

---

## 7. 帳戶來源與空狀態

- 系統不會自動建立任何帳戶，帳戶一律由使用者在帳戶設定建立。
- 帳戶未被引用時可以刪除，所以公司可能沒有任何帳戶，帳戶設定頁與下拉要處理空狀態。
