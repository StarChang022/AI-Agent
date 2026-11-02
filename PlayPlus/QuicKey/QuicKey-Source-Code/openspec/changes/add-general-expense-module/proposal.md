## Why

前置 change `refactor-rename-expense-to-reimbursement` 已把舊 `Expense` identifier 全部改成 `Reimbursement`，namespace 清空後現在要真正實作 PRD 的雙 model 架構（`docs/資料模型.md` §一）。

新 `Expense`（一般支出）代表「公司直接對外部廠商付款」的支出，不走簽核。它跟 `Reimbursement` 的差別是：登錄後立即成立、只有 `pending` / `paid` 兩狀態、可由行政人員多種方式輸入（拍照 OCR、圖片／PDF 上傳、Excel 匯入、手動建立）。同時後台「支出列表」是雙軌合流的統一入口 — 一般支出 + 已核准的代墊款一起顯示，用 `source` 欄位區分。

此 change 對應 `docs/實作流程.md` §五 Phase 1 Step 1.2–1.5。完成後 Phase 1 就結束。

## What Changes

- **新增 `Expense` domain model**（不同於 rename 掉的舊 `Expense`）：
  - Type：`Expense`（含 `source: 'general' | 'reimbursement'`、`sourceRefId?`、`payoutStatus: 'pending' | 'paid'`、`payoutDate?`、廠商/發票/稅額欄位、`attachments`、`items: ExpenseItem[]`、`tags: string[]`、`taxRate: 'business_5' | 'exempt_0'`、`documentType: 'invoice' | 'receipt'`、`createdBy`）
  - 支援 union：`ExpenseSource`、`PayoutStatus`、`TaxRate`、`DocumentType`；`ExpenseItem` interface（`name`, `quantity`, `unitPrice`, `subtotal`）
  - Mock：`frontend/src/mocks/expenses.json`（seed 一般支出、涵蓋 pending / paid 兩狀態、多個新科目、部分帶品項與 tags）
  - Store：`frontend/src/stores/expenses.ts`（`useExpenseStore`；action `addExpense`、`updateExpense`、`removeExpense`、`byStatus`、`bySource`、`allTags` computed；STORAGE_KEY `quickey.expenses.v2`）
  - **MVP 不含** `markPaid` / `revertPaid` action — 付款狀態於「新增支出」表單建立當下決定，事後不做標記/取消付款動作（見 design.md Decision 8）
- **新增後台「新增支出」頁**：`frontend/src/views/admin/ExpenseFormView.vue`
  - **單一表單設計**（不使用 tab）：憑證圖片 OCR 與手動輸入都走同一個表單；PDF 與 Excel 批次匯入拆到獨立 Dialog（見下）
  - 欄位順序（從上到下）：
    1. 憑證上傳（獨立一列）：label「憑證（發票／收據）」+ 小字備註「.jpg .png」；只接受圖片；手機支援拍照或選檔
    2. 上傳後憑證下方顯示「開始辨識」按鈕；點擊 → 1.5s loading stub → 自動填入下方欄位 → toast「辨識完成」；**OCR 填入的所有欄位保持可手動編輯**
    3. 發票／收據 radio（`documentType`），預設「發票」
    4. 交易日期 / 統一編號 / 廠商 / 發票號碼（grid）
    5. 稅率並排 3 欄：未稅金額 / 稅率 dropdown / 含稅金額；稅率下方顯示「營業稅額為 X 元」；未稅 ↔ 含稅 雙向連動
    6. 品項列表（可手動新增／刪除；OCR stub 也會填入 2–3 筆假品項）
    7. 費用類別 + 付款狀態（並排一列）
    8. 自訂類別 tags（多選 chip autocomplete）
    9. 備註（表單最底）
  - 發票號碼驗證：`documentType='invoice'` 時必填、格式 2 英文碼 + 8 數字碼；`documentType='receipt'` 時選填、不驗證
  - **一表單一支出**：手動填表與圖片上傳路徑固定 1 表單 = 1 支出；`<input type="file">` 拿掉 `multiple`、`attachments` 上限為 1；「多張收據」場景改走批次匯入 Dialog
  - **多筆支出分頁（僅限批次匯入）**：由「匯入」Dialog（PDF/Excel）載入 N 筆時，表單內部維護 `pages: FormPageData[]` 陣列；`pages.length > 1` 才於「建立」按鈕上方顯示分頁元件（`第 X 筆 / 共 Y 筆` + prev/next 按鈕 + dot pagination），使用者可切頁逐筆檢視／編輯
  - 提交按鈕：單顆「建立」；多頁時「建立」會逐頁驗證，任一頁有錯 → 跳至該頁並 focus 錯誤欄位；驗證通過一次建立所有頁面對應的支出
  - 儲存後 toast + 導回支出列表
- **新增「批次匯入」Dialog**：從支出列表右上角「匯入」按鈕觸發；Dialog 接受 **PDF 或 Excel** 兩種格式（統一入口）；上傳後顯示檔案卡片與 Message severity="info"「示範用途、實際解析由後端整合」，並顯示「開始辨識」按鈕（沿用主表單 OCR 模式）；點擊「開始辨識」→ 1.5s stub loading → 顯示 N 筆假預覽表 → 出現「載入表單編輯」按鈕；點擊後將 N 筆預覽資料導入新增支出頁的分頁表單；不真的 parse pdf/xlsx
- **改寫「支出列表」**：`frontend/src/views/admin/ExpensesView.vue`
  - 目前是 stub「本模組開發中」→ 改為 DataTable 顯示日期／類別／金額／來源／付款狀態／操作
  - **資料源直讀 expenses store**（取消原 view-mapping）：`source='reimbursement'` 的 Expense 是由代墊款核准時真正建立的 record（見下方「代墊款核准 → 建立支出」）
  - 「來源」欄用 pill：`一般支出`（primary tone）／`代墊款`（secondary tone）
  - 篩選：keyword、來源、類別（13 簡化會計科目 + 3 舊代墊款相容）、日期區間、付款狀態 tab（`all` / `pending` / `paid`）
  - **列表操作欄一律為放大鏡 icon**：點擊開 `ExpenseDetail` Dialog 顯示完整資訊（憑證縮圖 / 品項 / 稅率 / 自訂類別 / 來源代墊款關聯）；不含「標記已付款」「到發放頁」等付款動作按鈕。代墊款來源的發放動線由 `PayoutView` 承擔
  - PageHeader 右上按鈕：「新增支出」（primary）＋「匯入」（secondary，開批次匯入 Dialog；接受 PDF / Excel）
- **代墊款核准 → 建立支出流程**（新，取代原 Phase 4 排程）
  - `Reimbursement` 加欄位 `expenseId: string | null`（雙向連動；null 表示「已核准但尚未成立支出」）
  - Admin 於 `ReviewView` 待簽核清單按「通過」→ 開新元件 `ApproveWithExpenseDialog`
    - 頂端顯示簽核意見輸入
    - 中段 checkbox「同時建立支出？」**預設勾選（是）**
    - 若勾選 → 展開下方欄位：會計科目（13 選 1，預設帶入 `Reimbursement.category`）、付款狀態（pending / paid）、自訂類別 tags（多選 chip autocomplete）
    - 「確認」執行：
      - Reimbursement.status → `approved`
      - 若勾選：呼叫 `useExpenseStore.addFromReimbursement(reimbursement, adminAdjustments)` 建立 Expense（`source='reimbursement'`、`sourceRefId=reimbursement.id`、`documentType='receipt'`、`taxRate='exempt_0'`、`vendor=員工姓名`、`preTaxAmt=null`、`taxAmt=null`、`invoiceNo=null`、`taxId=null`、`items=[]`、其他由 admin 補齊）；同時 `Reimbursement.expenseId = 新 Expense.id`
      - 若未勾選：僅核准，Reimbursement.expenseId 保持 null
  - Admin 於 `ReviewView` 已處理清單看每筆的「支出狀態」欄：
    - `expenseId != null` → 顯示「已成立支出」chip；若對應 Expense 已 paid → 「已付款」補充
    - `expenseId == null` 且 status=`approved` → 顯示「未成立支出」+「新增支出」按鈕；點擊開同一個 dialog（但簽核意見已存、僅需補建立支出）
  - `PayoutView` 發放邏輯不變（仍操作 Reimbursement）；發放成功時額外連動更新對應 Expense.payoutStatus/payoutDate（透過 Reimbursement.expenseId 找回）
- **前台員工提交請款頁類別下拉**：`frontend/src/views/front/ExpenseFormView.vue` 的類別 Select 改用 `GENERAL_EXPENSE_CATEGORY_OPTIONS`（13 個簡化會計科目），只顯示中文名稱（無會計代碼；員工不需要知道代碼）；讓員工提交時就已完成會計科目分類、admin 審核時直接沿用
- **Router 新增**：`admin-expense-new` → `/admin/expenses/new` → `ExpenseFormView.vue`
- **API 契約檔**：新增 `frontend/src/api/expenses.ts`
  - Export `ExpenseDTO`、`CreateExpenseRequest`、`UpdateExpenseRequest`、`ListExpensesQuery`、`PayExpenseRequest`、`RevertPayRequest` 型別
  - `PayExpenseRequest` / `RevertPayRequest` 型別**保留給後端未來使用**，MVP UI 不呼叫（讓 Stage B 後端可以先按契約做完整 pay/revert-pay endpoint）
  - 每個型別上方 JSDoc 註記對應 endpoint

## Capabilities

### New Capabilities

- `expense-management`：後台一般支出模組（新增支出頁 + 分頁批次表單、統一支出列表、批次匯入 Dialog（PDF/Excel）、`Expense` 雙 source 資料模型、含品項／自訂 tags／稅率選擇器）

### Modified Capabilities

（無 — 現有 `admin-navigation` 只需 route 增加一個 stub 導向，不改行為）

## Impact

**新增檔案**

- `frontend/src/mocks/expenses.json`（新）
- `frontend/src/stores/expenses.ts`（新）
- `frontend/src/views/admin/ExpenseFormView.vue`（新）
- `frontend/src/components/BatchImportDialog.vue`（新 — PDF / Excel 批次匯入獨立 Dialog）
- `frontend/src/components/ExpenseFormPagination.vue`（新 — 分頁表單切頁元件）
- `frontend/src/components/ApproveWithExpenseDialog.vue`（新 — 代墊款核准 + 同時建立支出 Dialog）
- `frontend/src/api/expenses.ts`（新，純 TS 契約）

**改動檔案**

- `frontend/src/types/domain.ts`（加 `Expense`、`ExpenseSource`、`PayoutStatus`、`TaxRate`、`DocumentType`、`ExpenseAttachment`、`ExpenseItem`；`ExpenseCategory` union 擴充涵蓋 13 個簡化會計科目 + 保留舊 material/tool/service；**`Reimbursement` 加 `expenseId: string | null`**）
- `frontend/src/constants/expense.ts`（`GENERAL_EXPENSE_CATEGORY_OPTIONS` 13 個科目、`CATEGORY_ACCOUNT_CODES` map、`TAX_RATE_OPTIONS`、`DOCUMENT_TYPE_OPTIONS`）
- `frontend/src/stores/reimbursements.ts`（`approveCurrentStep` extend：支援 `options.createExpense` 附加參數；normalizer 補 `expenseId` 預設 null）
- `frontend/src/views/admin/ExpensesView.vue`（stub → 實際列表；**移除 view-mapping**、直讀 expenses store）
- `frontend/src/views/admin/ReviewView.vue`（通過按鈕改開 `ApproveWithExpenseDialog`；已處理清單加「支出狀態」欄與「新增支出」按鈕）
- `frontend/src/views/admin/PayoutView.vue`（發放時同步更新對應 Expense 的 `payoutStatus`／`payoutDate`；MVP 保留 Reimbursement.status 為主流轉）
- `frontend/src/views/admin/DashboardView.vue`（`CATEGORY_COLORS` 補齊新類別）
- `frontend/src/views/front/ExpenseFormView.vue`（類別 Select 改用 `GENERAL_EXPENSE_CATEGORY_OPTIONS`，只顯示中文名稱）
- `frontend/src/mocks/reimbursements.json`（既有 approved/paid seed 加 `expenseId`）
- `frontend/src/router/index.ts`（新增 `admin-expense-new` route）

**不動檔案**

- CLAUDE.md、design.md、dev-style.md、docs/ 全部
- Reimbursement 簽核狀態機（6 態）與駁回／重送邏輯
- 後台 Records / Categories stub / Budgets stub / Users 完全不動
- Sidebar 資訊架構不動

**類別欄位過渡**
`ExpenseFormView.vue` 與 `ExpensesView.vue` 的類別下拉採用 **13 個簡化會計科目**（依 `docs/產品規格文件.md` §7「保留簡化的會計科目對應」），每項附會計科目代碼：

- 交通費 (6272)、差旅費 (6272)、伙食費 (6203)、文具用品 (6202)、郵電費 (6270)、水電瓦斯費 (6289)、廣告費 (6275)、交際費 (6274)、修繕費 (6273)、教育訓練費 (6285)、保險費 (6280)、租金支出 (6255)、其他費用 (6299)

實作於 `frontend/src/constants/expense.ts` 的 `GENERAL_EXPENSE_CATEGORY_OPTIONS` + `CATEGORY_ACCOUNT_CODES` map。`ExpenseCategory` union 擴充新增 10 個科目 keys（travel/meal/office/other 已存在則沿用），舊 material/tool/service 保留給代墊款既有 mock 相容。

**Phase 2 完成後（categories store 上線）此常數 MUST 移除，改讀 store。**

**Non-goals（此 change 不做）**

- 不做 Phase 4「代墊款 → 支出自動 create」的 store 雙向關聯；此 change「統一列表」的代墊款部分只是 view 層 read-only 映射
- 不做事後標記/取消付款動作；付款狀態於建立當下決定即最終（MVP 定位是「錢花到哪裡」，付款流程管理是後續功能）
- 不做真 OCR、不做真 xlsx 解析、不做真檔案上傳（憑證只暫存 dataUrl）
- 不做真的稅率計算特殊情境（外幣、進口關稅、逾期加計等）
- 不做重複發票偵測（`vendor + date + amount` 撞名檢查屬 Phase 7）
- 不做 Categories store（Phase 2）
- 不做 Budgets 觸發（Phase 3）
- 不改品牌 label、不改 sidebar
- 不加測試

