# 固定收支與類別垃圾桶 API 合約（feat/recurring-transactions）

規格來源：PRD 第 17、18、21 條；資料模型 §2.2、§2.6、§2.8、§2.9、§3.4、§4.3、§六；`docs/QA_list/QA_固定收支.md`、`docs/QA_list/QA_類別管理.md`。

下方欄位都是 wire format（snake_case）；`api/service.ts` 會轉成 camelCase。

全部 API **僅 admin**，員工回 403 `{ error: "forbidden" }`（`GET /api/categories` 除外，維持員工可取下拉）。資料都限定在呼叫者的公司；別家公司的 id 一律當成找不到。

錯誤一律帶 `error`（代碼）與 `message`（可直接顯示）。本文件新增的代碼都有 `message`。

名詞：

- **期數（period）**：`YYYY-MM`。每月週期是該月；每年週期是該年設定的那個月，例如每年 3 月 15 日的 2026 年那期是 `2026-03`。
- **週期日**：這一期的紀錄日期。月份沒有這一天時落在當月最後一天（31 號遇 2 月、每年 2/29 遇平年）。
- **當期**：今天所在月份的那一期。每月週期是當月；每年週期只有今天所在的月份是週期月份才算當期，其他月份沒有當期，「從當期開始」就是下一個週期月份。
- **進行中／歷史**：還有下一期可產生是進行中；沒有下一期就是歷史。

---

## 1. 固定收支範本

### 回傳形狀 RecurringTemplate

列表與單筆形狀相同，沒有肥大欄位。

```json
{
  "id": "uuid",
  "direction": "expense",
  "name": "辦公室租金",
  "category": { "id": "uuid", "name": "租金支出", "account_code": "6112", "is_archived": false, "deleted_at": null },
  "account": { "id": "uuid", "name": "永豐-總公司" },
  "document_type": "invoice",
  "tax_rate": "business_5",
  "counterparty": "大樓管理公司",
  "tax_id": "12345678",
  "amount": 21000.0,
  "frequency": "monthly",
  "day_of_month": 5,
  "month_of_year": null,
  "start_month": "2026-08",
  "end_month": null,
  "status": "active",
  "generated_count": 3,
  "last_generated_period": "2026-10",
  "next_period": "2026-11",
  "next_date": "2026-11-05",
  "start_month_locked": true,
  "restorable": true,
  "deleted_at": null,
  "deleted_by": null,
  "created_by": { "id": "uuid", "name": "王管理" },
  "created_at": "...",
  "updated_at": "..."
}
```

- `direction`：`income`（固定收入）、`expense`（固定支出）。建立後不可改，PATCH 帶了也忽略。
- `category.is_archived`、`category.deleted_at`：類別目前的狀態。任一個有值時，前端可先擋還原與延長，後端也會擋。
- `counterparty`：廠商或客戶，產生紀錄時帶入支出的 `vendor`、收入的 `customer`。
- `frequency`：`monthly` 或 `yearly`。`month_of_year` 只有 `yearly` 才有值（1–12），`monthly` 時帶了也存 null。
- `day_of_month`：1–31。
- `status`：`active`（進行中）、`history`（歷史）、`trash`（垃圾桶）。
- `generated_count`：已產生的紀錄筆數，**不含垃圾桶內的紀錄**，所以不要用它判斷開始月份能否改。
- `start_month_locked`：已產生過紀錄時為 true，開始月份不可改。紀錄全部被刪掉也仍是 true。**判斷能否改開始月份請用這個欄位。**
- `last_generated_period`：已產生到第幾期，沒有產生過是 null。
- `next_period`、`next_date`：下一期與它的週期日；歷史範本是 null。垃圾桶內的範本回 null。
- `restorable`：類別啟用中（未停用、不在垃圾桶）時為 true。只有垃圾桶內的範本才需要看。
- `deleted_by`：`{ id, name }` 或 null，垃圾桶的「操作人」。

### 路徑

| 方法 | 路徑 | 說明 |
|---|---|---|
| GET | `/api/recurring-templates?direction=&tab=&page=&per_page=` | 列表，見下方 |
| GET | `/api/recurring-templates/:id` | 單筆，垃圾桶內的也查得到 |
| POST | `/api/recurring-templates/preview` | 儲存時會產生幾筆的預覽，見第 1.1 節。只查詢，不寫入 |
| POST | `/api/recurring-templates` | 建立並補齊已過的期數，回 201 + RecurringTemplate，另多一個 `backfilled_count` |
| PATCH | `/api/recurring-templates/:id` | 編輯，回 RecurringTemplate，當場產生時多一個 `backfilled_count`，見第 1.2 節。垃圾桶內的範本回 404 |
| DELETE | `/api/recurring-templates/:id` | 進垃圾桶，回 `{}`。任何時候都可以 |
| PATCH | `/api/recurring-templates/:id/restore` | 還原，回 RecurringTemplate，見第 1.3 節 |
| DELETE | `/api/recurring-templates/:id/purge` | 永久刪除，回 `{}`。已產生的紀錄保留，`recurring_template_id` 清空，`recurring_period` 保留 |
| GET | `/api/recurring-templates/:id/records?page=&per_page=` | 範本產生的紀錄，見第 1.4 節 |

**列表**：

- `direction` 必填，`income` 或 `expense`，其他值回 422 `INVALID_DIRECTION`。
- `tab`：`active`（預設）、`history`、`trash`。
- 分頁信封 `{ data, meta: { total, page, page_size, counts } }`，預設每頁 10 筆。進行中、歷史依建立時間新到舊，垃圾桶依刪除時間新到舊。
- `meta.counts` 一次回全部分頁的數量，不受 `direction`、`tab` 影響，不用打四次：

```json
{
  "counts": {
    "income":  { "active": 2, "history": 1, "trash": 0 },
    "expense": { "active": 5, "history": 0, "trash": 1 }
  }
}
```

POST、PATCH、preview 的 body：

```json
{
  "direction": "expense",
  "name": "辦公室租金",
  "category_id": "uuid",
  "account_id": "uuid",
  "document_type": "invoice",
  "tax_rate": "business_5",
  "counterparty": "大樓管理公司",
  "tax_id": "12345678",
  "amount": "21000",
  "frequency": "monthly",
  "day_of_month": 5,
  "month_of_year": null,
  "start_month": "2026-08",
  "end_month": null
}
```

PATCH 是 partial，帶了才改。`end_month` 帶 null 或空字串表示持續產生。

### 1.1 補產生預覽

`POST /api/recurring-templates/preview`，建立、編輯都用，吃表單當下的值。會用到 `frequency`、`day_of_month`、`month_of_year`、`start_month`、`end_month`；編輯時多 `template_id`、`category_id`，其他欄位帶了也忽略。

```json
{
  "backfill_count": 3,
  "backfill_periods": [ "2026-08", "2026-09", "2026-10" ],
  "has_periods": true,
  "next_period": "2026-11",
  "next_date": "2026-11-05",
  "message": null
}
```

- `backfill_count`：送出後立即產生的筆數；0 就不用提示。建立當天剛好是週期日時，當期算在內。
- `has_periods`：false 表示開始到結束月份之間一期都沒有，`message` 是給使用者看的原因，例如「開始到結束月份之間沒有任何一期，請調整週期或月份」。這時儲存會被擋，前端可先擋下。已產生過紀錄的範本不檢查，恆為 true。
- 週期欄位本身不合法時，回和建立相同的 422。
- **編輯時要帶 `template_id`**：用範本現況加表單的值，和 PATCH 走同一段邏輯，算出這次儲存實際會產生的筆數。沒帶的欄位用範本現有的值。
  - `category_id`：這次編輯的類別，請帶表單當下的值。歷史範本回到進行中時，類別擋不擋是看這個值，沒帶就看範本現有的類別；同一次編輯換了類別卻沒帶，會被舊類別擋下。
  - 錯誤和 PATCH 相同：類別被擋回 409 `CATEGORY_IN_TRASH`、`CATEGORY_ARCHIVED`，開始月份鎖定回 409 `START_MONTH_LOCKED`，換成不能用的類別回 422 `CATEGORY_NOT_FOUND`、`CATEGORY_WRONG_KIND`。
  - 範本不存在、在垃圾桶內或屬於別家公司時回 404。

### 1.2 編輯的規則

- **只影響尚未產生的期數**，已產生的紀錄不動。
- **`backfilled_count`**：這次編輯有改到開始月份、週期、週期日，或歷史範本回到進行中時才有，可能是 0。沒改到這些時不回傳，週期日已過的期數留給每日檢查。送出前請用 preview（帶 `template_id`）提示筆數。
- `start_month`：`start_month_locked=true` 時，帶了不同的值回 409 `START_MONTH_LOCKED`。還沒產生過紀錄時可改；改到過去時，儲存當下補齊已過的期數。
- `end_month`：不可早於 `start_month`；可以早於已產生的期數，已產生的紀錄不受影響，範本會變歷史。
- **改週期日**：當期還沒產生、新的週期日已過 → **儲存當下**產生。例：今天 2 號，週期日 5 改 1，當下產生當期一筆；改 3 不產生；當期已產生就不重複。
- **改週期（每月↔每年、改月份）**：已過的期數不補，從今天所在的月份開始依新週期產生；當期週期日已過時**儲存當下**產生。例：
  - 每年 3 月已產生 `2026-03`，11 月改成每月且週期日已過：不補 4～10 月，只產生 `2026-11` 一筆。
  - 每月已產生到 10 月，11 月改成每年 12/15：`2026-12` 要產生。
  - 每年週期改月份時同一年只一筆：已產生 `2026-03`，11 月改成每年 12 月，下一期是 `2027-12`。
- **歷史範本回到進行中**（結束月份往後延，或改週期後又有下一期）：中間漏掉的期數不補，從當期開始；當期週期日已過且尚未產生的，**儲存當下**立即產生一筆。類別在垃圾桶回 409 `CATEGORY_IN_TRASH`，已停用回 409 `CATEGORY_ARCHIVED`。
- **還沒產生過紀錄的範本**改週期、週期日：比照建立，開始月份到今天週期日已過的期數都會補齊，例如開始月份 `2026-09`、每年 12 月改成每月，當下補 9～11 月三筆。
- 換類別、換帳戶時，新的類別要是啟用中，新的帳戶要未刪除。沒有換的話，舊值即使已停用也不會擋編輯。

### 1.3 還原

- 類別在垃圾桶回 409 `CATEGORY_IN_TRASH`，已停用回 409 `CATEGORY_ARCHIVED`，提示先還原或重新啟用類別。歷史範本也一樣。
- 不補垃圾桶期間的期數，從當期開始；當期週期日已過且尚未產生的，立即產生一筆。回傳多一個 `backfilled_count`。
- 每年週期的週期月份落在垃圾桶期間就不補：每年 3/15 的範本 2 月進垃圾桶、11 月還原，下一期是 `2027-03`。
- 還原後沒有下一期就回到歷史。

### 1.4 範本產生的紀錄

`GET /api/recurring-templates/:id/records?page=&per_page=`，分頁信封，依期數新到舊，**不含垃圾桶內的紀錄**。

```json
{
  "data": [
    {
      "id": "uuid",
      "kind": "expense",
      "recurring_period": "2026-10",
      "date": "2026-10-05",
      "amount": 21000.0,
      "status": "pending",
      "settled_at": null,
      "invoice_no": null,
      "account": { "id": "uuid", "name": "永豐-總公司" }
    }
  ],
  "meta": { "total": 3, "page": 1, "page_size": 10 }
}
```

- `kind`：`expense` 或 `income`，決定點開時打 `getExpense(id)` 還是 `getIncome(id)`。
- `status`：支出是 `pending`、`paid`；收入是 `uncollected`、`collected`。
- `settled_at`：付款日或收款日。待付款、待收款時畫面請隱藏（PRD 第 10 條），可能有舊值。

### 錯誤

| 狀態 | `error` | 時機 |
|---|---|---|
| 422 | `INVALID_DIRECTION` | 不是 `income`、`expense` |
| 422 | `INVALID_NAME` | 名稱空白或超過 50 字 |
| 422 | `INVALID_COUNTERPARTY` | 廠商或客戶空白或超過 100 字 |
| 422 | `CATEGORY_NOT_FOUND` | 類別不存在、屬於別家公司、已停用或在垃圾桶 |
| 422 | `CATEGORY_WRONG_KIND` | 類別的類型和收支方向不同 |
| 422 | `ACCOUNT_REQUIRED`、`ACCOUNT_NOT_FOUND` | 同帳戶 API |
| 422 | `INVALID_DOCUMENT_TYPE` | 不是 `invoice`、`receipt` |
| 422 | `INVALID_TAX_RATE` | 不是 `business_5`、`exempt_0` |
| 422 | `TAX_ID_REQUIRED` | 文件類型為發票但沒填統一編號 |
| 422 | `INVALID_TAX_ID` | 統一編號不是 8 碼數字 |
| 422 | `INVALID_AMOUNT` | 空白、不是數字、小於等於 0、超過兩位小數，或超過 9,999,999,999.99 |
| 422 | `INVALID_SCHEDULE` | `frequency`、`day_of_month`、`month_of_year` 不合法 |
| 422 | `INVALID_MONTH` | 開始或結束月份格式錯誤、早於 2000-01，或結束早於開始 |
| 422 | `NO_PERIODS` | 開始到結束月份之間沒有任何一期 |
| 409 | `START_MONTH_LOCKED` | 已產生過紀錄，不可改開始月份 |
| 409 | `CATEGORY_IN_TRASH` | 類別在垃圾桶，不可還原，也不可把結束月份往後延 |
| 409 | `CATEGORY_ARCHIVED` | 類別已停用，不可還原，也不可把結束月份往後延 |
| 404 | `not_found` | 找不到（包含別家公司的 id） |

**收據的稅別**：文件類型為收據時一律存 `exempt_0`，帶什麼都一樣，和手動新增、Excel 匯入一致。

---

## 2. 產生的紀錄

- 就是一般的支出、收入，可編輯、切換狀態、刪除。
- 帶入範本的類別、帳戶、文件類型、稅別、廠商或客戶、統一編號、金額。`note` 是範本名稱，`date` 是週期日，發票號碼與附件留空。
- 未稅金額與稅額依含稅金額和稅別計算，算法同 Excel 匯入。
- 一律待付款、待收款。支出的預計付款日以產生當天為登錄日，依公司付款日規則帶入；補齊時是建立當天。
- `created_by` 與稽核操作人都是範本建立者。
- 排程每天台北 00:30 跑，比 09:00 的逾期通知早。停機漏跑的期數，下一次會全部補上。

---

## 3. 支出、收入

### 回傳

列表與單筆都多兩個欄位，也包含 `/expenses/pending-batches` 的 rows：

```json
{ "recurring_template_id": "uuid 或 null", "recurring_period": "2026-10 或 null" }
```

- **`recurring_period` 有值就顯示「固定」**。`source` 不新增值，固定支出的 `source` 仍是 `general`。
- `recurring_template_id` 有值才連回範本；範本永久刪除後是 null，「固定」標示仍在。範本在垃圾桶時仍有值，`GET /api/recurring-templates/:id` 查得到。

### 篩選

| API | 參數 | 結果 |
|---|---|---|
| `GET /api/expenses` | `source=general` | 一般支出，**不含固定** |
| `GET /api/expenses` | `source=reimbursement` | 代墊款 |
| `GET /api/expenses` | `source=recurring` | 只看固定 |
| `GET /api/incomes` | `recurring=true` | 只看固定 |
| `GET /api/expenses`、`GET /api/incomes` | `missing_invoice_no=true` | 只看文件類型為發票、發票號碼空白（NULL 或空字串）的紀錄 |

資料庫的 `source` 沒有 `recurring` 這個值，`source=recurring` 是查詢時以 `recurring_period` 判斷。`recurring=false` 或未帶時收入回全部。

`missing_invoice_no` 未帶或 `false` 時回全部。不限固定收支產生的紀錄，代墊款來源的支出符合條件也會列出；可和其他篩選並用。

`/expenses/pending-batches` 的 `source_meta` 維持 `{ general, reimbursement }`，固定支出算在 `general`。

### 其他

- 編輯固定產生的紀錄時，發票號碼可以留空。後端原本就不要求發票號碼。
- 上一次使用的帳戶不看固定產生的紀錄（`last_used_account_id`、Excel 匯入空白帳戶）。

---

## 4. 類別

### 回傳形狀

`GET /api/categories` 帶 `include_usage=true` 時，每筆多：

```json
{
  "usage_count": 12,
  "references": { "expenses": 8, "incomes": 0, "reimbursements": 2, "recurring_templates": 1, "budgets": 1 },
  "active_template_count": 1,
  "deletable": false,
  "archivable": false,
  "purgeable": false,
  "blocked_reason": "有 1 筆進行中的固定收支範本使用此類別，不可停用或刪除"
}
```

- `references`：各來源的引用筆數，**含垃圾桶內的紀錄**。`recurring_templates` 含歷史與垃圾桶內的範本，`budgets` 只算過往期間的預算。之後可能加 key，請逐 key 處理。
- `usage_count`：`references` 的加總。原本收入類別恆為 0，現在會算收入。
- `active_template_count`：進行中的範本筆數，只有這個會擋刪除與停用。
- `deletable`、`archivable`：`active_template_count` 為 0 時才是 true。
- `purgeable`：`references` 全為 0 時才是 true。垃圾桶內的類別才用得到。
- `blocked_reason`：不能刪除、停用時的原因；可以時是 null。

沒帶 `include_usage` 時形狀不變，只多 `deleted_at`（下拉取到的恆為 null）。

### 路徑

| 方法 | 路徑 | 說明 |
|---|---|---|
| DELETE | `/api/categories/:id` | 進垃圾桶，回 `{}`。進行中範本使用時回 409 `CATEGORY_IN_USE_BY_TEMPLATE` |
| GET | `/api/categories/trash?kind=&page=&per_page=` | 垃圾桶列表，分頁信封，預設每頁 10 筆，依刪除時間新到舊 |
| PATCH | `/api/categories/:id/restore` | 還原，回 Category。原本停用的仍為停用 |
| DELETE | `/api/categories/:id/purge` | 永久刪除，回 `{}`。有任何引用時回 409 `CATEGORY_IN_USE` |
| PATCH | `/api/categories/:id/archive` | 既有。進行中範本使用時回 409 `CATEGORY_IN_USE_BY_TEMPLATE` |

- 垃圾桶列表每筆是上面帶 usage 的形狀，另有 `deleted_at`、`deleted_by: { id, name }`。
- 進垃圾桶比照停用：清除基本預算與當期、未來的預算，還原後不恢復。`is_archived` 不動。
- 垃圾桶內的類別不可編輯：`PATCH /:id`、`archive`、`unarchive` 回 404，`reorder` 回 `INVALID_IDS`。

### 名稱重複

POST、PATCH 維持 409 `DUPLICATE_NAME` + `category`，多帶 `message`。**同類型的垃圾桶內類別也算重複**。撞到垃圾桶內的類別時，`category.deleted_at` 有值，`message` 會請使用者去還原或永久刪除。

### 錯誤

| 狀態 | `error` | 時機 | 另帶 |
|---|---|---|---|
| 409 | `CATEGORY_IN_USE_BY_TEMPLATE` | 進行中範本使用，不可刪除、停用 | `templates: [{ id, name }]` |
| 409 | `CATEGORY_IN_USE` | 仍被引用，不可永久刪除 | `references` |

### 其他 API 的行為改變

- `GET /api/categories`（含 `archived=true`）不含垃圾桶內的類別。員工取得的下拉也一樣。
- 新增支出、收入、代墊款、預算、基本預算時，類別在垃圾桶回 422 `CATEGORY_NOT_FOUND`。
- 編輯既有紀錄時，類別沒換就不擋，表單可以把原本的垃圾桶類別原樣送回；換成另一個垃圾桶內的類別才回 `CATEGORY_NOT_FOUND`。
- 單筆與列表的 `category` 仍回原名，前端編輯表單的下拉要自己把目前的類別放進選項。

### Excel 匯入

預覽的 `categories[].state` 多一個值 `discarded`：檔內的類別名稱和垃圾桶內的類別相同。`creatable=false`，不提供新增與重新啟用，只能對應到既有類別，沒選時回 `INVALID_CATEGORY_MAPPING`。

---

## 5. 帳戶

`references` 多一個 key `recurring_templates`（前端是 `recurringTemplates`），含歷史與垃圾桶內的範本。大於 0 時不可刪除，走原本的 `ACCOUNT_IN_USE`，`message` 會列出「N 筆固定收支範本」。

---

## 6. 稽核

查詢走 `GET /api/audit-logs?target_type=&target_id=`。

| 對象 | `target_type` | 動作 |
|---|---|---|
| 固定收支範本 | `recurring_template` | `create`、`update`、`delete`、`restore`、`purge` |
| 類別 | `category` | `delete`、`restore`、`purge` |

**固定收支自動產生**：`target_type` 是 `expense` 或 `income`，`action` 仍是 `create`，`actor_name` 是範本建立者；以 `after.via === "recurring"` 區分，比照 Excel 匯入的 `via: "excel_import"`。`after` 另有 `recurring_template_id`、`recurring_period`。

前端請在 `constants/auditLog.ts` 的 `via` 對照加上 `recurring: '固定收支自動產生'`。

---

## 7. 已確認事項

以下五點用戶已確認：

1. **類別已停用時的還原與延長**：一起擋（`CATEGORY_ARCHIVED`）。
2. **方向**：建立後不可改。
3. **開始月份鎖定**：只要產生過就鎖，即使紀錄全刪了。
4. **每年週期選不存在的日期**（例如 4/31）：視為當月最後一天，不擋。
5. **開始與結束月份**：不設上限。

## 8. 本機測試

排程只在 production 跑。本機要手動跑一次每日產生：

```bash
cd backend && bin/rails runner "GenerateRecurringRecordsJob.perform_now"
```
