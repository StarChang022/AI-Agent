# 收支日期欄位 API

規格來源：PRD 第 10、23 條；`docs/資料模型.md` §2.2、§2.6、§3.1、§5.4（2026-11-05 定案）。
欄位名稱為後端 snake_case，前端經 `service.ts` 轉成 camelCase。

## 1. 欄位

| 畫面名稱 | 支出 | 收入 | 必填 | 說明 |
|---|---|---|---|---|
| 發生日期 | `date` | `date` | 是 | 損益歸屬 |
| 發票日期 | `invoice_date` | `invoice_date` | 發票必填 | 收據一律存 null，前端送什麼都會清掉 |
| 應付／應收日期 | `planned_payout_date` | `planned_collection_date` | 是 | 待收付分組、逾期判斷 |
| 實付／實收日期 | `paid_at` | `collected_at` | 已收付時必填 | 現金流歸屬；改回待收付時保留 |
| （支出）是否手動改過應付日期 | `planned_payout_manual` | — | — | 收入沒有這個欄位 |
| （支出）應付日期自動值 | `auto_planned_payout_date` | — | — | 只在單筆回傳；null = 建立當下公司關閉付款日 |

列表（Summary）與單筆都回 `date`、`invoice_date`、應付／應收日期、實付／實收日期。

發票沒帶 `invoice_date`：422 `{ error: "validation_failed", details: { invoice_date: [...] } }`。

## 2. 支出的應付日期

### 自動值

- 新增（含 Excel 匯入、固定支出產生）：從登錄當天（含當天）往後找最近的公司付款日，存成 `auto_planned_payout_date`，之後不再變動。
- 代墊款核准：從核准當天往後找。
- 付款日 29～31 遇到較短的月份，退到該月最後一天。例：付款日 25，11/25 登錄 → 11/25；11/26 登錄 → 12/25。
- 公司關閉付款日：`auto_planned_payout_date` 為 null，應付日期為發生日期。
- 前端預覽：用 `GET /api/payout-schedule` 的付款日自己算（`utils/payoutSchedule.ts`），算法同後端 `PayoutSchedule.snapshot`。

### 新增、編輯時送 `planned_payout_date`

| 送出的值 | 結果 |
|---|---|
| 沒帶這個 key | 新增：用預設值（自動值，沒有時為發生日期）。編輯：不動，但沒手動改過且自動值為 null 時跟著發生日期改 |
| 編輯時，和更新前的應付日期相同 | 視為沒改：手動狀態不變，沒手動改過且自動值為 null 時照樣跟著發生日期 |
| 日期，和預設值相同 | 存入，`planned_payout_manual = false` |
| 日期，和預設值不同 | 存入，`planned_payout_manual = true` |
| `null` 或空字串 | 改回自動排程：還原為自動值（null 時為發生日期），`planned_payout_manual = false` |

「預設值」用的是**這次送出後**的發生日期。前端編輯時一律連同應付日期送出：沒動過就送原值（後端會跟著發生日期改），使用者改過就送新值。

已付款的支出也可以改應付日期。

### `PATCH /api/expenses/:id/adjust-payout-date`

body `{ date: "YYYY-MM-DD" | null }`，只限待付款。規則同上表：有日期時和預設值不同才算手動；`null` 改回自動排程。

## 3. 收入的應收日期

- 新增時沒帶：等於發生日期。
- 有帶 `planned_collection_date`：照存。
- 沒帶、但改了發生日期（例如 Excel 匯入、只改發生日期）：應收日期等於**原本的**發生日期才跟著改，不同就不動。
- 沒有「改回自動排程」。

## 4. 標記已收付、改回待收付

- `PATCH /api/expenses/:id/pay`、`PATCH /api/incomes/:id/collect`：前端帶確認視窗的 `paid_at`／`collected_at`；沒帶時為今天（不再用應付日期）。
- `PATCH /api/expenses/:id/revert-pay`、`PATCH /api/incomes/:id/revert-collect`：狀態改回待收付，`paid_at`／`collected_at` 保留，應付／應收日期不變。前端「曾標記過的帶回原值」用保留下來的日期。

## 5. 待收付分組

`GET /api/expenses/pending-batches`、`GET /api/incomes/pending-batches`，一次回全部待付款／待收款（不分頁）：

```json
{
  "groups": [
    { "key": "0000-overdue", "date": "2026-10-28", "overdue": true,  "total": 3200, "count": 2, "rows": [] },
    { "key": "2026-11-25",   "date": "2026-11-25", "overdue": false, "total": 1500, "count": 1, "rows": [] }
  ]
}
```

- 依應付／應收日期分組。日期早於公司時區（台北）今天的合成一組逾期，排最前面，`date` 為組內最早的日期；當天不算逾期。其餘依日期由近到遠。
- 公司關閉付款日時，待付款照樣分組。
- 支出每組多 `source_meta: { general, reimbursement }`。`rows` 為列表精簡格式，不含圖檔與品項；詳情請重打單筆 API。

## 6. 系統產生的紀錄

| 來源 | 發生日期 | 發票日期 | 應付／應收日期 |
|---|---|---|---|
| 代墊款核准 | 請款的發生日期（`incurred_at`） | 請款的發票日期（`invoice_date`） | 從核准當天找付款日 |
| 固定收支 | 週期日 | 發票時同發生日期 | 支出：從產生當天找付款日；收入：同發生日期 |
| 移轉手續費 | 移轉日期 | 收據，無 | 移轉日期；編輯移轉時一起同步 |

## 7. 代墊款請款

- 欄位：發生日期 `incurred_at`（必填，預設今天）、發票日期 `invoice_date`。沒有應付日期與實付日期：應付日期在核准轉成支出時計算，實付日期就是撥款日。
- `invoice_date`：文件類型為發票時必填，收據一律存 null（發票改成收據時清空）。**草稿不擋**，比照金額、發生日期、類別等其他必填欄位，送出或駁回後重送時才檢查；沒填時回 422 `validation_failed`，`details.invoice_date`。
- 建立、更新（含送出、駁回後重送）都收 `invoice_date`；列表與單筆都回傳。權限不變：員工只能改自己的草稿或駁回單。
- 請款編輯是整份覆寫，沒帶 `invoice_date` 等於清空。
- 匯出（CSV／Excel）欄位：「發生日期」（原「費用日」）、「發票日期」。
- 既有資料：Migration `20261105000002` 把發票請款的 `invoice_date` 補成 `incurred_at`。

## 8. Excel 匯入

範本與解析見 `docs/資料模型.md` §5.4。後端重點：

- 標題：`發生日期`、`發票日期`、`應付日期`／`應收日期`、`實付日期`／`實收日期`（原「日期／開立日」「付款日／收款日」）。缺「發生日期」或「發票日期」標題整份退回。
- 發票的發生日期空白時帶發票日期；收據空白不匯入。
- 應付／應收日期空白依上方預設規則；看不懂依預設並列出；支出有填且和自動值不同算手動修改。
- 已收付但實付／實收日期空白，以發生日期代入並列出。
- 預覽 `summary` 多 `invoice_date`、`planned_date`（Excel 有填的應付／應收日期，空白為 null）。

## 9. 既有資料

Migration `20261105000001`：發票的 `invoice_date` 補 `date`；應付日期為 null 的補 `date`；收入的應收日期補 `date`。之後兩個欄位改為必填。

## 10. 報表

現金流報表的待收款清單多 `planned_collection_date`，依應收日期排序；待付款清單依應付日期排序。Excel 匯出的欄名改為「應收日期」「應付日期」。
