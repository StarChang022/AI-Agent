# expense-management Specification

## Purpose
定義後台一般支出（Expense）模組的資料模型、單一整合表單的新增支出頁（含 OCR 手動觸發、發票／收據 radio、稅率選擇器、品項列表、自訂 tags）、Excel 匯入獨立 Dialog、以及統一支出列表的雙 source 合流呈現。此 capability 對應 `docs/資料模型.md` §2.2、§2.3、§4.2、§5.1 與 `docs/sitemap.md` 內「支出管理／支出列表」「支出管理／新增支出」兩個模組。此 capability 不涵蓋 Reimbursement 的簽核流程（另屬既有代墊款 capability）、事後付款動作（見 design.md Decision 8）、類別自訂（Phase 2）與預算（Phase 3）。

## ADDED Requirements

### Requirement: Expense 資料模型雙 source 區分

系統 SHALL 以 `Expense.source` 欄位區分 `'general'`（一般支出）與 `'reimbursement'`（由代墊款轉入）。`Expense` MUST 具備下列欄位：`taxRate: 'business_5' | 'exempt_0'`（稅率選擇）、`documentType: 'invoice' | 'receipt'`（憑證類型）、`tags: string[]`（自訂類別）、`items: ExpenseItem[]`（品項列表）。所有查詢 MUST 能同時取回或依 source 篩選。

#### Scenario: 建立一般支出

- **WHEN** 行政人員經由「新增支出」頁儲存一筆支出
- **THEN** 系統 MUST 建立 `Expense` 記錄 `source='general'`、`sourceRefId=null`
- **AND** 該筆立即出現在支出列表

#### Scenario: 依 source 篩選

- **WHEN** 使用者在支出列表選擇「來源 = 代墊款」
- **THEN** 列表 MUST 只顯示 `source='reimbursement'` 的支出（本 change 內以 view 層讀 reimbursements store 映射）

### Requirement: Expense 付款狀態於建立時決定（MVP 不含事後付款動作）

系統 SHALL 於「新增支出」表單提供 `payoutStatus` 欄位（Select，選項 `'pending'` / `'paid'`），使用者於建立當下決定狀態。`payoutStatus='paid'` 時 `payoutDate` MUST 記為當下日期。Expense **不記錄** `payoutMethod`（付款方式，見 design.md Decision 8）。MVP UI **不含**事後「標記已付款」或「取消付款」動作。

#### Scenario: 建立時保留預設 pending

- **WHEN** 使用者建立支出且未變更付款狀態預設
- **THEN** `Expense.payoutStatus` MUST 為 `'pending'`、`payoutDate` MUST 為 `null`

#### Scenario: 建立時設 paid

- **WHEN** 使用者於表單將付款狀態設為 `'paid'`
- **THEN** `Expense.payoutStatus` MUST 為 `'paid'`
- **AND** `Expense.payoutDate` MUST 為當下日期

#### Scenario: 支出列表操作欄一律為放大鏡（開 ExpenseDetail Dialog）

- **WHEN** 使用者於支出列表看任一列（不論 `source='general'` 或 `source='reimbursement'`）
- **THEN** 該列的「操作」欄 MUST 只顯示放大鏡（`pi-search-plus`）icon 按鈕，`aria-label="查看詳情"`
- **AND** 點擊時 MUST 開啟 `ExpenseDetail` Dialog 顯示該筆完整資訊（憑證、品項、標籤、來源、關聯代墊款）
- **AND** 操作欄 MUST NOT 顯示任何付款相關按鈕（「標記已付款」「取消付款」「到發放頁」皆不呈現）；代墊款來源的付款動作由 `PayoutView` 承擔、`ExpenseDetail` 內以「來源代墊款」區塊顯示連結資訊

### Requirement: 新增支出頁採單一整合表單

系統 SHALL 提供 `/admin/expenses/new` 頁面，採用**單一整合表單**設計。主表單處理「圖片憑證 OCR」+「手動輸入」；PDF 與 Excel 批次匯入走列表 header 的獨立「匯入」Dialog（見「批次匯入 Dialog」）。表單 MUST NOT 使用 tab 分流。

#### Scenario: 憑證上傳位置與規格

- **WHEN** 使用者進入新增支出頁
- **THEN** 表單第一列 MUST 為「憑證（發票／收據；圖片）」上傳區，佔獨立一列
- **AND** label 下方 MUST 有小字備註「1 張憑證 = 1 筆支出；僅接受 jpg/png，PDF 與 Excel 請走列表右上「匯入」批次流程」
- **AND** 上傳輸入 MUST 使用 `accept="image/*"`；**MUST NOT 加 `multiple`**（1 表單 = 1 支出）；**MUST NOT 接受 PDF/Excel**（走列表右上「匯入」入口）
- **AND** `attachments` 上限 MUST 為 1；若已有附件，新選檔 MUST 覆蓋既有；使用者若要換圖 MUST 先按縮圖右上「×」移除
- **AND** 手機瀏覽時 MUST 提供「拍照」（`capture="environment"`）與「從檔案選擇」兩種操作

#### Scenario: 由匯入進入時隱藏憑證區

- **WHEN** 使用者由批次匯入 Dialog 導入新增支出頁（`fromImport = true`）
- **THEN** 表單第一列的「憑證上傳區塊」MUST 隱藏
- **AND** 表單直接顯示「憑證類型 → 交易日期 …」等欄位
- **AND** 使用者 MUST NOT 於此頁補上傳圖片（批次匯入場景下憑證由原檔案承載；此頁只做欄位核對）

#### Scenario: 「開始辨識」按鈕觸發 OCR

- **WHEN** 使用者上傳 1 張圖片憑證
- **THEN** 憑證縮圖區下方 MUST 顯示「開始辨識」primary 按鈕
- **WHEN** 使用者點擊「開始辨識」
- **THEN** 系統 MUST 顯示 loading 狀態（stub 1.5s）
- **AND** 完成後 MUST 自動填入以下欄位（於當前頁）：交易日期、統一編號、廠商、發票號碼、費用類別、稅率、未稅金額、稅額、含稅金額、品項（2-3 筆）
- **AND** 系統 MUST 保持單頁狀態（`pages = []`、`isMultiPage = false`）；圖片路徑固定 1 表單 = 1 支出
- **AND** 系統 MUST 顯示 toast「辨識完成，欄位已自動帶入，請核對後儲存」
- **AND** 若當時無任何圖片 attachment，「開始辨識」按鈕 MUST 不顯示

#### Scenario: OCR 填入欄位可手動編輯

- **WHEN** OCR 自動填入某欄位（含日期、金額、發票號碼、品項等）
- **THEN** 該欄位 MUST 保持可編輯狀態
- **AND** 使用者 MAY 隨時手動修改任一 OCR 填入的欄位

#### Scenario: 發票／收據類型 radio

- **WHEN** 使用者於表單填寫資料
- **THEN** 表單 MUST 提供 `documentType` radio（選項「發票」與「收據」），預設「發票」

#### Scenario: 發票號碼驗證（發票模式）

- **WHEN** `documentType='invoice'` 且使用者按「建立」
- **THEN** 發票號碼欄位 MUST 為必填
- **AND** 格式 MUST 符合 2 英文碼 + 8 數字碼（允許可選連字號，例如 `AB-12345678` 或 `AB12345678`）
- **AND** 不符時 MUST 顯示 inline error

#### Scenario: 發票號碼驗證（收據模式）

- **WHEN** `documentType='receipt'`
- **THEN** 發票號碼欄位 MUST 為選填、MUST NOT 強制格式驗證

#### Scenario: 欄位順序（由上到下）

- **WHEN** 使用者進入新增支出頁
- **THEN** 表單欄位順序 MUST 為：
  1. 憑證上傳
  2. 「開始辨識」按鈕（有 attachment 時顯示）
  3. 發票／收據 radio
  4. 交易日期 / 統一編號 / 廠商 / 發票號碼（grid）
  5. 稅率並排 3 欄（未稅 / 稅率 / 含稅）
  6. 品項列表
  7. 費用類別 + 付款狀態（並排一列）
  8. 自訂類別（tags）
  9. 備註

#### Scenario: 費用類別與付款狀態並排

- **WHEN** 使用者看主要欄位區塊
- **THEN** 費用類別（Select）與付款狀態（Select）MUST 並排顯示於同一列
- **AND** 此列**上方** MUST 為「品項列表」
- **AND** 此列**下方** MUST 為「自訂類別」

#### Scenario: 自訂類別多選 chip autocomplete

- **WHEN** 使用者於「自訂類別」欄位點擊或輸入
- **THEN** 系統 MUST 提供 chip 多選 autocomplete 下拉
- **AND** suggestions MUST 來自 `useExpenseStore.allTags` computed（歷史 tags 匯總去重）
- **AND** 使用者 MAY 鍵入新 tag（Enter 加入）
- **AND** 一筆 Expense MUST 可指定 0 至多個 tags
- **AND** 資料 MUST 存於 `Expense.tags: string[]`

#### Scenario: 稅率 3 欄設計

- **WHEN** 使用者看金額區塊
- **THEN** 系統 MUST 顯示 3 欄並排：未稅金額（InputNumber）、稅率 Select、含稅金額（InputNumber）
- **AND** 稅率選項 MUST 為「營業稅 5%」與「免稅或收據 0%」
- **AND** 稅率下方 MUST 顯示「營業稅額為 X 元」的即時計算文字

#### Scenario: 未稅 ↔ 含稅 雙向連動

- **WHEN** 使用者編輯「未稅金額」
- **THEN** 系統 MUST 自動計算「含稅金額」（`round(未稅 × (1 + rate))`）
- **WHEN** 使用者編輯「含稅金額」
- **THEN** 系統 MUST 自動反推「未稅金額」（`round(含稅 / (1 + rate))`）
- **WHEN** 使用者切換稅率
- **THEN** 未稅金額 MUST 保留、含稅金額 MUST 依新稅率重算

#### Scenario: 品項欄位（多筆）

- **WHEN** 使用者於品項區塊操作
- **THEN** 系統 MUST 提供品項列表（每列欄位：品項名稱、數量、單價、小計）
- **AND** 使用者 MUST 可新增一列與刪除某列
- **AND** 「小計」欄位 MUST 由數量 × 單價 自動計算
- **AND** OCR 觸發時 MUST 自動填入 2–3 筆示範品項

#### Scenario: 備註欄位位置

- **WHEN** 使用者滾動到表單底部
- **THEN** 備註（Textarea）MUST 為表單最後一個欄位

#### Scenario: 表單欄位驗證

- **WHEN** 使用者按「建立」但缺必填（費用類別、含稅金額、交易日期；發票模式下的發票號碼）
- **THEN** 系統 MUST 顯示 inline 錯誤並阻止儲存
- **AND** 系統 MUST focus 至第一個錯誤欄位

#### Scenario: 建立成功流轉

- **WHEN** 使用者按「建立」且驗證通過
- **THEN** 系統 MUST 建立 Expense 並顯示 toast
- **AND** MUST 導回 `/admin/expenses`

### Requirement: 批次匯入 Dialog（PDF + Excel 統一入口，走「開始辨識」流程）

系統 SHALL 於 `/admin/expenses` PageHeader 右上角提供「匯入」次要按鈕。點擊 MUST 開啟 `BatchImportDialog`，Dialog **同時接受 PDF 與 Excel（xlsx）兩種格式**。上傳流程 MUST 沿用主表單的「開始辨識」模式：先顯示上傳的檔案卡片與 Message severity="info" 說明「示範用途、實際解析由後端整合」；出現「開始辨識」按鈕；點擊觸發 1.5s stub loading；完成後 MUST 直接 stage 3 筆固定假資料、關閉 Dialog 並導向 `/admin/expenses/new`。**Dialog 內 MUST NOT 顯示預覽 DataTable**；預覽動線由新增支出頁的分頁 UI 承擔（見「分頁表單支援多筆支出」）。系統 MUST NOT 真正解析 PDF 或 xlsx 內容。

#### Scenario: 開啟批次匯入 Dialog

- **WHEN** 使用者於支出列表點右上「匯入」按鈕
- **THEN** 系統 MUST 開 Dialog，包含上傳區與示範說明

#### Scenario: 上傳 PDF 或 Excel

- **WHEN** 使用者於 Dialog 上傳一份 PDF 或 xlsx
- **THEN** Dialog MUST 顯示檔案卡片（含檔名、大小）與「開始辨識」按鈕
- **AND** 未上傳前「開始辨識」按鈕 MUST 不顯示

#### Scenario: 開始辨識直接導頁

- **WHEN** 使用者點「開始辨識」
- **THEN** 系統 MUST 顯示 loading 狀態（stub 1.5s，`aria-busy="true"`）
- **AND** 完成後 MUST 呼叫 `expenses.stageImportedPages(drafts)` 把 3 筆固定假資料 stage 到 store
- **AND** MUST `emit('update:visible', false)` 關閉 Dialog
- **AND** MUST `router.push({ name: 'admin-expense-new' })` 導向新增支出頁
- **AND** MUST NOT 於 Dialog 內顯示預覽 DataTable 或「載入表單編輯」按鈕（2026-09-08 決策：預覽動線改由表單頁的分頁 UI 承擔）

#### Scenario: 匯入資料含足夠必填欄位

- **WHEN** 使用者於 Dialog 點「開始辨識」
- **THEN** 3 筆固定假資料每筆 MUST 包含：`documentType='invoice'`、`taxId`（8 碼統編）、`vendor`、`invoiceNo`（符合 `INVOICE_NUMBER_REGEX`）、`taxRate='business_5'`、`preTaxAmt`、`taxAmt`、`amount`、`category`、`items[]`（1–2 筆品項）
- **AND** `payoutStatus` MUST 為 `null`（保留給使用者顯性決定；表單驗證會擋）
- **AND** 三筆 category MUST 涵蓋不同會計科目（`travel` / `meal` / `office`）

#### Scenario: 新增支出頁載入匯入資料

- **WHEN** `ExpenseFormView.vue` `onMounted`
- **THEN** 系統 MUST 呼叫 `expenses.takeImportedPages()` 檢查是否有 stage 資料
- **AND** 若非 null，MUST 設 `fromImport = true`、clone 每筆到 `pages` 陣列、`loadPageData(pages[0])`
- **AND** MUST 顯示 info toast「已載入 N 筆匯入資料，請逐筆核對後按「建立」」
- **AND** MUST 於分頁元件顯示（因 `pages.length > 1`）

### Requirement: 分頁表單支援多筆支出

系統 SHALL 於 `ExpenseFormView.vue` 內部維護 `pages: FormPageData[]` 陣列與 `currentPageIndex: number` 狀態，每頁 = 一項支出。當 `pages.length > 1` 時，MUST 於「建立」按鈕上方顯示 `ExpenseFormPagination` 元件。單頁時 MUST 不顯示分頁元件。

#### Scenario: 單頁狀態不顯示分頁元件

- **WHEN** `pages.length === 1`
- **THEN** 分頁元件 MUST 不顯示

#### Scenario: 多頁狀態顯示分頁元件

- **WHEN** `pages.length > 1`
- **THEN** 分頁元件 MUST 顯示於「建立」按鈕上方
- **AND** 元件內容 MUST 包含：文字「第 X 筆 / 共 Y 筆」、上一頁 `<` 按鈕、Y 個頁碼指示 dot（當前頁 active 高亮）、下一頁 `>` 按鈕
- **AND** 整體以 pill 圓角容器包覆（白底 + border）

#### Scenario: 圖片上傳固定單頁

- **WHEN** 使用者於主表單憑證區塊上傳 1 張圖片並點「開始辨識」
- **THEN** 系統 MUST 只填入 1 頁 OCR stub（`pages = []`、`isMultiPage = false`）
- **AND** 主表單 MUST NOT 支援多張圖片上傳；`<input>` MUST NOT 加 `multiple`
- **AND** 多張收據場景 MUST 改由批次匯入 Dialog 承接（見下方）

#### Scenario: 批次匯入觸發多頁

- **WHEN** 使用者由「批次匯入」Dialog 載入 N 筆（PDF/Excel）
- **THEN** 系統 MUST 於新增支出頁生成 N 頁分頁表單（`pages.length = N`）

#### Scenario: 切頁保留當前編輯

- **WHEN** 使用者於當前頁編輯欄位後點分頁元件切至另一頁
- **THEN** 系統 MUST 先將當前頁的表單狀態同步回 `pages[currentPageIndex]`
- **AND** 載入 `pages[newIndex]` 為當前表單狀態
- **AND** 切頁動作 MUST NOT 顯示額外 confirm

#### Scenario: 多頁「建立」逐頁驗證

- **WHEN** 使用者於多頁狀態點「建立」
- **THEN** 系統 MUST 依序驗證每一頁的必填欄位
- **AND** 若任一頁驗證失敗，MUST 跳至該頁並 focus 第一個錯誤欄位並顯示 inline error
- **AND** 若全部頁面驗證通過，系統 MUST 一次建立所有頁面對應的 Expense
- **AND** 全部建立成功後 MUST 顯示 toast「已建立 N 筆支出」並導回列表

#### Scenario: 頁面數不可手動增減（MVP）

- **WHEN** 使用者於分頁表單狀態
- **THEN** 系統 MUST NOT 提供「新增頁」或「刪除當前頁」按鈕
- **AND** 頁面數僅由 OCR 辨識結果或匯入資料決定

### Requirement: 統一支出列表直讀 expenses store

系統 SHALL 在 `/admin/expenses` 顯示 `expenses store` 內全部 `Expense`。**MUST NOT** 於 view 層讀 reimbursements store 做映射；代墊款來源的支出資料由「代墊款核准 → 建立 Expense」流程真正建立（見「代墊款核准時可選擇同時建立支出」）。列表 MUST 提供欄位：日期、類別、金額、廠商／對象、來源（一般支出／代墊款）、付款狀態、操作。**不含付款方式欄**（Expense 不記錄，見 design.md Decision 8）。

#### Scenario: 直讀 expenses store

- **WHEN** 使用者進入 `/admin/expenses`
- **THEN** 列表 MUST 顯示 `expenses store` 內所有 Expense（包含 source='general' 與 source='reimbursement'）
- **AND** 不再有 view-mapping 邏輯或虛擬 `r-<id>` key

#### Scenario: 未成立支出的已核准代墊款不出現

- **WHEN** 有 `Reimbursement.status='approved'` 但 `expenseId == null`（admin 核准時未同時建立支出）
- **THEN** 支出列表 MUST NOT 顯示這筆
- **AND** 使用者需先於 `ReviewView` 已處理清單按「新增支出」補建立

#### Scenario: 支出列表篩選

- **WHEN** 使用者操作篩選器
- **THEN** 系統 MUST 支援下列篩選維度：
  - 來源（一般支出 / 代墊款 / 全部）
  - 類別（13 個簡化會計科目 + 3 個舊代墊款相容類別 material/tool/service）
  - 日期區間（費用發生日）
  - 付款狀態（全部 / 待付款 / 已付款）
- **AND** 使用者點「清除篩選」時 MUST 一鍵歸零所有 filter

#### Scenario: 進入新增支出頁

- **WHEN** 使用者在支出列表點右上角「新增支出」按鈕
- **THEN** router MUST 導向 `admin-expense-new`

### Requirement: API 契約檔提供 Stage B 後端依據

系統 SHALL 在 `frontend/src/api/expenses.ts` 提供純 TypeScript 型別契約，供 Stage B 後端與 Stage C 串接使用。契約 MUST 涵蓋以下 endpoint 對照：

| Endpoint | Request Type | Response Type | MVP UI 呼叫 |
|---|---|---|---|
| `POST /expenses` | `CreateExpenseRequest` | `ExpenseDTO` | ✅ |
| `PATCH /expenses/:id` | `UpdateExpenseRequest` | `ExpenseDTO` | ✅ |
| `GET /expenses` | `ListExpensesQuery`（query params） | `ExpenseDTO[]` | ✅ |
| `PATCH /expenses/:id/pay` | `PayExpenseRequest` | `ExpenseDTO` | ❌ 保留給後端 |
| `PATCH /expenses/:id/revert-pay` | `RevertPayRequest`（可為 `{}`） | `ExpenseDTO` | ❌ 保留給後端 |

`ExpenseDTO` MUST 涵蓋所有 `Expense` 欄位（含 `taxRate`、`documentType`、`tags`、`items`）。每個型別上方 MUST 有 JSDoc 註記對應 endpoint path 與 HTTP method；未來 MVP 不呼叫的 endpoint（`pay` / `revert-pay`）MUST 在 JSDoc 明確標示「MVP UI 不呼叫，保留給後端」。此檔 MUST NOT 含實作邏輯（不 import runtime 依賴），僅 TS 型別。

#### Scenario: 契約檔僅有型別

- **WHEN** 檢視 `frontend/src/api/expenses.ts`
- **THEN** 檔案 MUST 只 export TS `type` 或 `interface`，MUST NOT export function、class 或 constant

#### Scenario: pay/revert-pay 註記 MVP 不呼叫

- **WHEN** 工程師閱讀 `PayExpenseRequest` 與 `RevertPayRequest` 的 JSDoc
- **THEN** MUST 有明確註記「MVP UI 不呼叫」

### Requirement: 簡化會計科目下拉，Phase 2 改由 categories store 提供

系統 SHALL 在 `frontend/src/constants/expense.ts` 新增 `GENERAL_EXPENSE_CATEGORY_OPTIONS`（13 個簡化會計科目）與 `CATEGORY_ACCOUNT_CODES`（科目代碼對照 map）。Phase 2 完成後（categories store 上線）此常數 MUST 移除，改讀 categories store。過渡期間 MUST 在常數上方以註解標示「Phase 2 待移除」以防遺忘。

#### Scenario: 簡化會計科目顯示

- **WHEN** 使用者於新增支出頁展開類別下拉
- **THEN** 選項 MUST 為 13 個簡化會計科目：交通費、差旅費、伙食費、文具用品、郵電費、水電瓦斯費、廣告費、交際費、修繕費、教育訓練費、保險費、租金支出、其他費用
- **AND** 每個選項右側 MUST 顯示對應會計科目代碼（例如「交通費  6272」）

#### Scenario: 過渡實作標記

- **WHEN** 工程師閱讀 `frontend/src/constants/expense.ts`
- **THEN** `GENERAL_EXPENSE_CATEGORY_OPTIONS` 上方 MUST 有註解說明是 Phase 2 前的過渡實作，並列出移除時機

### Requirement: 代墊款核准時可選擇同時建立支出

系統 SHALL 於 `Reimbursement` 加 `expenseId: string | null` 欄位。Admin 於 `ReviewView` 對代墊款按「通過」時，MUST 開啟 `ApproveWithExpenseDialog`，內含 checkbox「同時建立支出？」（**預設勾選**）。若勾選，Dialog MUST 展開下方欄位（會計科目、付款狀態、自訂類別 tags）供 admin 補齊；確認 → 系統執行 approve + create Expense（`source='reimbursement'`, `sourceRefId=<reimbursement.id>`）+ 雙向連動（`Reimbursement.expenseId = 新 Expense.id`）。若未勾選，僅執行 approve、`Reimbursement.expenseId` 保持 null。

#### Scenario: 核准並同時建立支出

- **WHEN** admin 於 ReviewView 按「通過」某筆 in_review 的 Reimbursement
- **THEN** 系統 MUST 開 `ApproveWithExpenseDialog`
- **AND** Dialog checkbox「同時建立支出？」MUST 預設勾選
- **AND** 下方會計科目、付款狀態、自訂類別 tags 3 欄 MUST 展開顯示
- **AND** 會計科目 MUST 預設帶入 `Reimbursement.category`
- **WHEN** admin 補齊欄位並按「確認」
- **THEN** `Reimbursement.status` MUST 變為 `'approved'`
- **AND** 系統 MUST 建立 `Expense`：
  - `source='reimbursement'`
  - `sourceRefId=<reimbursement.id>`
  - `vendor=<員工姓名>`
  - `amount=<reimbursement.amount>`
  - `category=<admin 所選會計科目>`
  - `date=<reimbursement.incurredAt>`
  - `note=<reimbursement.description>`
  - `documentType='receipt'`
  - `taxRate='exempt_0'`
  - `taxId=null`、`invoiceNo=null`、`preTaxAmt=null`、`taxAmt=null`、`items=[]`
  - `tags=<admin 所選>`
  - `payoutStatus=<admin 所選>`、若 paid 則 `payoutDate=今日`
  - `createdBy=<admin.id>`
- **AND** `Reimbursement.expenseId` MUST 為新 Expense 的 id

#### Scenario: 核准但暫緩建立支出

- **WHEN** admin 通過 Dialog 但取消勾選「同時建立支出？」
- **THEN** Dialog MUST 收起下方 3 欄
- **WHEN** admin 按「確認」
- **THEN** `Reimbursement.status` MUST 變為 `'approved'`
- **AND** MUST NOT 建立 Expense
- **AND** `Reimbursement.expenseId` MUST 保持 null

### Requirement: 已處理清單顯示支出狀態並提供補建按鈕

系統 SHALL 於 `ReviewView` 的「已處理」清單加「支出狀態」欄。依 `Reimbursement.expenseId` 與 `status`：

| status | expenseId | 顯示 |
|---|---|---|
| approved | not null | chip「已成立支出」；若對應 Expense.payoutStatus=paid 補顯示「已付款」 |
| approved | null | chip「未成立支出」（琥珀）+ 「新增支出」outlined 按鈕 |
| paid | not null | chip「已成立支出、已付款」 |
| rejected | (any) | 不顯示支出狀態欄（駁回不建 Expense） |
| voided | (any) | chip「已作廢」 |

點擊「新增支出」按鈕 MUST 開 `ApproveWithExpenseDialog` 的 `approveOnly` 模式（Dialog 標題「補建立支出」；不顯示簽核意見輸入；checkbox 已預勾且不可取消勾選；confirm 時只 create Expense + set `Reimbursement.expenseId`）。

#### Scenario: 已成立支出的顯示

- **WHEN** 使用者於已處理清單看某筆 `status='approved'` 且 `expenseId != null` 的 Reimbursement
- **THEN** 支出狀態欄 MUST 顯示「已成立支出」chip

#### Scenario: 未成立支出的按鈕

- **WHEN** 使用者於已處理清單看某筆 `status='approved'` 且 `expenseId == null` 的 Reimbursement
- **THEN** 支出狀態欄 MUST 顯示「未成立支出」chip + 「新增支出」按鈕
- **WHEN** 使用者點「新增支出」
- **THEN** 系統 MUST 開 `ApproveWithExpenseDialog`（`approveOnly` mode）
- **AND** 確認後 MUST 建立對應 Expense 並回填 `Reimbursement.expenseId`

### Requirement: PayoutView 發放時同步更新對應 Expense

系統 SHALL 於 `PayoutView` 對某筆 Reimbursement 標記已發放時，若該筆 `expenseId != null`，MUST 同步更新對應 Expense 的 `payoutStatus='paid'`、`payoutDate=今日`。若 `expenseId == null`（未成立支出的已核准代墊款），發放動作 MUST 被禁用（因為沒有 Expense record 承接付款狀態）。

#### Scenario: 發放連動 Expense

- **WHEN** admin 於 PayoutView 對某筆 `status='approved'` 且 `expenseId != null` 的 Reimbursement 按「標記已發放」
- **THEN** `Reimbursement.status` MUST 變 `'paid'`
- **AND** 系統 MUST 透過 `expenseId` 找回 Expense
- **AND** Expense.payoutStatus MUST 變 `'paid'`
- **AND** Expense.payoutDate MUST 為今日

#### Scenario: 未成立支出的代墊款不可發放

- **WHEN** 有 `Reimbursement.status='approved'` 且 `expenseId == null`
- **THEN** PayoutView 對這筆 MUST 顯示 disabled「標記已發放」按鈕（或 tooltip「請先於審核頁補建立支出」）

### Requirement: 前台員工提交請款頁類別下拉採用簡化會計科目

系統 SHALL 於 `frontend/src/views/front/ExpenseFormView.vue`（員工提交請款頁）的類別 Select 綁 `GENERAL_EXPENSE_CATEGORY_OPTIONS`（13 個簡化會計科目）；選項 MUST **僅顯示中文名稱、不顯示會計代碼**（員工不需要知道代碼）。

#### Scenario: 員工看到的類別下拉

- **WHEN** 員工進入前台提交請款頁展開類別下拉
- **THEN** 選項 MUST 為 13 個簡化會計科目：交通費、差旅費、伙食費、文具用品、郵電費、水電瓦斯費、廣告費、交際費、修繕費、教育訓練費、保險費、租金支出、其他費用
- **AND** MUST NOT 顯示會計代碼
