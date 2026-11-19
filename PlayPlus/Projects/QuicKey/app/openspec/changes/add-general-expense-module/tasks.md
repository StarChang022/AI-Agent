> **實作進度快照（2026-09-08 · 二次微調）**
>
> - ✅ A + B + C + **D 已完成**：type/domain / constants / stores / api 骨架 / 新增支出表單重構（單一表單、去 tab、多筆分頁 state）/ 統一支出列表（含操作放大鏡 + 匯入按鈕）/ 代墊款核准 → 建立支出流程（Dialog + 雙向 expenseId）/ PayoutView 發放同步 Expense / **BatchImportDialog PDF/Excel 匯入 → stageImportedPages → ExpenseFormView 分頁載入**
> - ✅ **D 章節 e2e 已通過瀏覽器手動 QA**（2026-09-08）：admin → /admin/expenses → 匯入 → Dialog → 上傳 pdf → 開始辨識 → 3 筆預覽 → 載入表單編輯 → 分頁表單「共 3 筆」+ 第 1/2 頁欄位正確
> - 🔀 已在下方 in-line 標註「實作決策」的偏離項：
>   - **主表單 1 表單 = 1 支出**（2026-09-08 定案）：`<input>` 拿掉 `multiple`、`attachments` 上限 1、`startRecognize` 固定單頁；多張收據場景改走 D 章節匯入 Dialog（Decision 16 已刷新）
>   - **FormPageData 型別抽出**（2026-09-08）：`frontend/src/types/expense-form.ts` 集中定義，讓 store 的 `stagedImports` 與 BatchImportDialog 共用；ExpenseFormView 由 inline 改為 import
>   - 5.2 取消「繼續加入圖片」按鈕；5.3 開始辨識改 primary；5.7 「營業稅額 NT$ X 元」**2026-09-08 二次微調時補回**（僅 taxAmt > 0 顯示）；5.8 品項小計改 disabled InputNumber、欄位加 label；**手機版品項雙行（品名+刪除 / 數量+單價+小計）**；5.15 必填擴充統編/廠商/付款狀態；9.7 操作欄一律放大鏡開 ExpenseDetail；10.A.1 Dialog 加「實付廠商」欄；10.D.3 revertPaid 反向同步 Expense 不做（Decision 8）；11.8 ExpenseDTO 新欄位補齊仍為 open
>   - **2026-09-08 二次微調（本輪）**：
>     - §5.6 統一編號加 `/^\d{8}$/` 8 碼驗證
>     - §5.6 發票號碼欄位拆兩欄（英文 2 碼 + 數字 8 碼）；提交時 join 為 `AB-12345678`
>     - §5.9 費用類別由 `Select` 改 `AutoComplete`：點擊 input 出下拉、無比對時列「新增類別「XX」+」→ 選擇後 `expenses.addCustomCategory` 寫入 store（`localStorage quickey.customCategories.v1`）；placeholder 改「請選擇類別」
>     - §5.20（新增）ExpenseFormView 支援編輯模式：router 加 `admin-expense-edit`（path `expenses/:id/edit`），onMounted 讀 `route.params.id` → 從 store 預填欄位；submit 走 `updateExpense` + 直接改 `payoutStatus/payoutDate`；找不到 id → toast + `router.replace` 回列表
>     - §9.7 操作欄改「... Menu」新增「編輯 / 刪除」動作；「操作」表頭文字移除（`header=""`）；放大鏡查看詳情仍保留
>     - §10.D.2 開放「未成立支出的代墊款」直接發放：移除 `needsExpenseFirst` disabled；`markPaid` 內 `if (target.expenseId)` guard 讓沒 Expense 時自動跳過 sync
> - 對應更新：`proposal.md`、`design.md`（Decisions 4/8/9/16 已刷新）、`specs/expense-management/spec.md`（Requirement「一般支出列表無付款動作」與「代墊款來源列導向 PayoutView」等 scenario 已對齊）



## 1. Type / Domain

- [x] 1.1 `frontend/src/types/domain.ts`：新增 `ExpenseSource`、`PayoutStatus`、`ExpenseAttachment` interface
- [x] 1.2 `frontend/src/types/domain.ts`：新增 `Expense` interface 基本欄位（id、source、sourceRefId?、vendor?、taxId?、invoiceNo?、preTaxAmt?、taxAmt?、amount、category、date、note?、attachments、payoutStatus、payoutDate?、createdBy、createdAt、updatedAt）；**Expense 不含 payoutMethod**（見 design.md Decision 8）
- [x] 1.3 新增 `TaxRate` union（`'business_5'` | `'exempt_0'`）與 `DocumentType` union（`'invoice'` | `'receipt'`）
- [x] 1.4 新增 `ExpenseItem` interface（`name: string`、`quantity: number`、`unitPrice: number`、`subtotal: number`）
- [x] 1.5 `Expense` interface 加欄位：`taxRate: TaxRate`、`documentType: DocumentType`、`tags: string[]`、`items: ExpenseItem[]`
- [x] 1.6 註解說明 Expense 與 Reimbursement 差異、引用 docs/資料模型.md §2.2、§2.3
- [x] 1.7 `Reimbursement` 加 `expenseId: string | null`（雙向連動；null 表示「已核准但未成立支出」；註解說明用途）



## 2. 類別常數與過渡選項

- [x] 2.1 `frontend/src/constants/expense.ts`：`GENERAL_EXPENSE_CATEGORY_OPTIONS` 內含 13 個簡化會計科目（交通費/差旅費/伙食費/文具用品/郵電費/水電瓦斯費/廣告費/交際費/修繕費/教育訓練費/保險費/租金支出/其他費用）
- [x] 2.2 新增 `CATEGORY_ACCOUNT_CODES` map；每個科目對應會計科目代碼
- [x] 2.3 檔案上方 comment 明確標示「Phase 2 categories store 完成後移除」
- [x] 2.4 新增 `TAX_RATE_OPTIONS`：`[{value:'business_5', label:'營業稅 5%', rate:0.05}, {value:'exempt_0', label:'免稅 / 收據 0%', rate:0}]`；並新增 `getTaxRateValue(v)` helper 供表單雙向連動使用
- [x] 2.5 新增 `DOCUMENT_TYPE_OPTIONS`：`[{value:'invoice', label:'發票'}, {value:'receipt', label:'收據'}]`；並新增 `INVOICE_NUMBER_REGEX = /^[A-Za-z]{2}-?\d{8}$/`
- [x] 2.6 `ExpenseCategory` union 擴充涵蓋 13 新科目 + 保留舊 material/tool/service 供代墊款相容



## 3. Mock 資料

- [x] 3.1 `frontend/src/mocks/expenses.json`：seed 7 筆（6 筆一般 + 1 筆 reimbursement 轉入）；涵蓋 pending / paid 兩狀態、日期近 3 個月分布
- [x] 3.2 seed 補上新欄位（`taxRate`、`documentType`、`tags`、`items`）；`exp-seed-03`（鼎泰豐）帶 3 筆品項；`exp-seed-02`、`exp-seed-05` 各帶一個 tag
- [x] 3.3 seed 涵蓋較多新會計科目：office / travel / meal / training / business_travel（不再只有舊 3 類）



## 4. Expense store

- [x] 4.1 新增 `frontend/src/stores/expenses.ts`：`useExpenseStore` + `STORAGE_KEY = 'quickey.expenses.v2'`；load from localStorage or seed
- [x] 4.2 CRUD action：`addExpense(input, options: { paidNow: boolean })`、`updateExpense(id, input)`、`removeExpense(id)`（`paidNow=true` 時 store 內自動填 `payoutDate=今日`）
- [x] 4.3 定義查詢 helper：`byStatus(status)` computed、`bySource(source)` computed、`findById(id)` computed
- [x] 4.4 normalize helper：處理 attachments 從舊格式的 fallback；補上新欄位（taxRate/documentType/tags/items）預設值
- [x] 4.5 `addExpense` input 支援新欄位：`taxRate`、`documentType`、`tags`、`items`
- [x] 4.6 新增 `allTags` computed：從全部 expenses 的 tags 匯總去重（用於自訂類別 autocomplete）
- [x] 4.7 新增中繼站 action `stageImportedPages(pages)` / getter `takeImportedPages()`：批次匯入 Dialog → 新增支出頁的資料交接（一次性使用，取用後清空）；`stagedImports: ref<FormPageData[] | null>` 為 store 內私有 state，不寫入 localStorage（重整 = 放棄匯入）
- [x] 4.8 新增 action `addFromReimbursement(reimbursement, adjustments, reviewerId)`：由代墊款轉入建立 Expense；adjustments 型別 = `{ vendor: string | null; category: ExpenseCategory; payoutStatus: PayoutStatus; tags: string[] }`；固定填 `source='reimbursement'`, `sourceRefId=reimbursement.id`, `documentType='receipt'`, `taxRate='exempt_0'`, `taxId=null`, `invoiceNo=null`, `preTaxAmt=null`, `taxAmt=null`, `items=[]`, `amount=reimbursement.amount`, `date=reimbursement.incurredAt`, `note=reimbursement.description`；**vendor 由 Dialog 讓 admin 填入實際外部廠商**（非員工姓名；spec 已同步）；回傳新 Expense 供 caller 取 id 回填 `Reimbursement.expenseId`
- [x] 4.9 新增 action `markExpensePaidById(id)`：由 PayoutView 呼叫，將對應 Expense.payoutStatus 設 paid、payoutDate=今日（用於代墊款發放連動）



## 5. 新增支出頁（單一表單設計，欄位順序更新）

**欄位順序（由上到下）**：憑證 → 開始辨識 button → 發票/收據 radio → 交易日期/統編/廠商/發票號碼 → **稅率 3 欄** → **品項** → **費用類別+付款狀態並排** → **自訂類別** → 備註

- [x] 5.1 `ExpenseFormView.vue`：移除 4 個 tab；改為單一表單佈局；表單以 section grouping 分區塊，section 之間用間距分隔
- [x] 5.2 憑證區塊（表單最上、獨立一列）
  - Label「憑證（發票／收據；圖片）」、下方小字備註「1 張憑證 = 1 筆支出；僅接受 jpg/png，PDF 與 Excel 請走列表右上「匯入」批次流程」
  - `accept="image/*"`；`<input>` **不加** `multiple`（2026-09-08 決策：1 表單 = 1 支出）；**不接受 PDF/Excel**（走列表右上「匯入」按鈕）
  - `onAttachmentChange` 只取 `files[0]`；已有附件時 assignment 覆蓋（`attachments.value = [新]`），使用者需先按縮圖右上「×」移除才能換圖
  - 已上傳圖片以縮圖 grid 呈現；**點擊縮圖開 Dialog 放大檢視**（避開 overflow-hidden 遮擋關閉鈕）
  - 手機瀏覽時提供「拍照」（`capture="environment"`）與「從檔案選擇」兩種按鈕；桌機只顯示「加入圖片」
  - **實作決策**：不顯示「繼續加入圖片」二次上傳按鈕；上傳後上傳按鈕消失、只保留「開始辨識」primary 按鈕
- [x] 5.3 「開始辨識」按鈕（憑證區塊下方，取代原上傳按鈕位置）
  - 只要 attachments 有 1 張圖片就顯示；沒有時只顯示上傳按鈕
  - **樣式為 primary**（原規劃 outlined，實作改為 primary 以強化主要動作）
  - 辨識中變 disabled + 顯示 loading spinner；避免重複觸發
  - 點擊 → 1.5s stub loading → 以 `makeStubForIndex(0)` 填單頁 stub、`pages = []`、`currentPageIndex = 0` → toast「辨識完成，欄位已自動帶入，請核對後儲存」
  - **實作決策（2026-09-08）**：主表單 1 表單 = 1 支出，此路徑固定單頁；多張收據場景改走批次匯入 Dialog（§7）觸發多頁 state
- [x] 5.4 stub 資料（由 `makeStubForIndex(i)` 產生；圖片路徑僅呼叫 i=0，i≥1 樣板保留給 D 章節批次匯入使用）：
  - i=0：`documentType='invoice'`、`date=今日`、`taxId='12345678'`、`vendor='福華文具行'`、`invoiceNo='AB-98765432'`、`category='office'`、`taxRate='business_5'`、`preTaxAmt=1200`、`taxAmt=60`、`amount=1260`、items=3 筆（A4 影印紙／原子筆／文件夾）
  - i=1：`vendor='萊爾富便利商店'`、`taxId='87654321'`、`invoiceNo='CD-11223344'`、`preTaxAmt=95`、`amount=100`、`category='meal'`、items=咖啡 1 筆
  - i≥2：沿用 i=0 樣板 + vendor 補「（分店 N）」
  - `payoutStatus=null`（保留為使用者顯性決定；驗證會擋，符合 Decision 8 精神）
- [x] 5.5 發票／收據 radio（`documentType`）；預設「發票」；改變時觸發發票號碼欄位驗證規則切換
- [x] 5.6 主要欄位 grid：交易日期 `DatePicker`、統一編號 `InputText`（8 碼數字）、廠商 `InputText`、發票號碼 `InputText`（發票模式顯示 hint「格式：AB-12345678」）
- [x] 5.7 稅率並排 3 欄（**位於發票號碼下方**）
  - 未稅金額 `InputNumber` currency TWD
  - 稅率 `Select` 綁 `TAX_RATE_OPTIONS`
  - 含稅金額 `InputNumber` currency TWD
  - **實作決策**：稅率下方**不顯示**「營業稅額為 XX 元」小字（使用者要求刪除；稅額直接反映在 3 欄運算內；spec.md 已同步）
  - 雙向連動：`preTaxAmt` 改變 → 自動填 `amount`；`amount` 改變 → 自動反推 `preTaxAmt`；用 `taxLinkGuard` flag 避免無限循環
  - 切換稅率 → `preTaxAmt` 保留、`amount` 依新稅率重算
  - 四捨五入：`amount = round(preTaxAmt * (1 + rate))`；`preTaxAmt = round(amount / (1 + rate))`
- [x] 5.8 品項區塊（**位於稅率下方**）
  - grid 顯示每一列品項；**每欄位上方有欄位 label**（品項 / 數量 / 單價 / 小計）
  - 欄位：品項名稱 `InputText`、數量 `InputNumber`、單價 `InputNumber`、小計（**disabled** `InputNumber`，顯示自動計算的 quantity × unitPrice；實作決策：從 read-only text 改為 disabled InputNumber 保持視覺一致）、刪除按鈕
  - 「新增品項」按鈕（+ icon）新增空白列
  - 至少 0 列可通過 validation（品項為選填）
  - OCR 觸發時依 5.4 stub 資料填入 3 筆
- [x] 5.9 費用類別 `Select`（選項顯示科目名 + 代碼）＋ 付款狀態 `Select`（PAYOUT_STATUS_OPTIONS）並排一列（**位於品項下方**）
- [x] 5.10 自訂類別區塊（**位於費用類別下方**）
  - PrimeVue `AutoComplete` multiple + chip 模式
  - `suggestions` 綁 `useExpenseStore.allTags`（reactive）
  - 使用者可鍵入新 tag（Enter 加入）
  - 佔位符提示「輸入或選擇分類…」
- [x] 5.11 備註 `Textarea` 位於表單最底
- [x] 5.12 發票號碼驗證邏輯
  - `documentType='invoice'`：必填、regex `INVOICE_NUMBER_REGEX = /^[A-Za-z]{2}-?\d{8}$/`
  - `documentType='receipt'`：選填、不驗證
  - 切換 documentType 時清除發票號碼欄位的 error state
- [x] 5.13 提交按鈕：單顆「建立」（primary）；旁邊「取消」（outlined，導回 /admin/expenses）；多頁時「建立」文案改為「建立 N 筆」— 多頁部分依 C 章節
- [x] 5.14 （已移除：付款方式欄位不在 MVP 範圍；見 design.md Decision 8）
- [x] 5.15 表單 validation：**必填欄位擴充為** 費用類別、含稅金額 > 0、交易日期、**統一編號、廠商、付款狀態**（依實作回饋補上）；發票模式下的發票號碼必填 + 格式；不通過時 inline error + `scrollToFirstError` focus 第一個錯誤欄位並 `scrollIntoView`
- [x] 5.16 儲存成功 → toast「支出已建立」→ `router.push({ name: 'admin-expenses' })`；多頁 toast 依 C 章節
- [x] 5.17 PageHeader `#actions` slot：「返回列表」次要按鈕（outlined + 箭頭 icon）
- [x] 5.18 手機版
  - 所有 grid 改為單欄堆疊（欄位、稅率 3 欄、品項列）
  - submit 按鈕列固定於底部或全寬
  - 憑證區塊「拍照」按鈕使用 `capture="environment"`
- [x] 5.19 無障礙
  - icon-only 按鈕加 `aria-label`
  - 憑證上傳 label `for` 對應 input id
  - 發票/收據 radio 用 `<fieldset>` + `<legend>` 或 `role="radiogroup"` 加 `aria-label`
  - Toast / Message 有 `role="alert"`
  - 品項列表刪除按鈕加 `aria-label`「刪除第 N 列品項」
  - 圖片預覽 Dialog focus trap + ESC 關閉
  - 分頁元件 `<nav aria-label="表單分頁">`、dot 有 `aria-label`「第 N 頁」+ `aria-current="page"`、prev/next 有 `aria-label`「上一頁」／「下一頁」



## 6. 分頁表單（多筆支出）

- [x] 6.1 `ExpenseFormView.vue` 內部 state：`pages: FormPageData[]`、`currentPageIndex: number`、`isMultiPage` computed；`FormPageData` 型別涵蓋所有表單欄位（**attachments 為整份表單共用**，MVP 簡化決策）
- [x] 6.2 切頁邏輯：`onPageChange(newIndex)` 先呼叫 `syncCurrentPageState()` 把 refs 寫回 `pages[currentPageIndex]`，再 load `pages[newIndex]` 至 refs；不觸發 confirm；`loadPageData` 同步清空 fieldErrors
- [x] 6.3 新增 `frontend/src/components/ExpenseFormPagination.vue`
  - props：`total: number`、`current: number`（0-based）
  - emit：`change(index)`
  - 顯示：`第 X 筆 / 共 Y 筆` + prev `<` + Y 個 dot（active 為 primary 圓角矩形；非 active 為灰圓點 hover 深灰）+ next `>`
  - 整體 pill 容器：`rounded-full bg-white border border-[var(--color-hairline)] px-3 py-1.5` 樣式
  - prev / next 到邊界時 disabled
  - 手機版：文字改 `text-[11px]`；`total > 5` 時 dot 只在 sm+ 顯示（手機用箭頭 + 頁碼文字瀏覽）
  - 無障礙：`<nav aria-label="表單分頁">`、每 dot 有 `aria-label`「第 N 頁」+ 當前頁 `aria-current="page"`、prev/next 有 `aria-label`
- [x] 6.4 `ExpenseFormView.vue` 於「建立」按鈕上方 conditional render 分頁元件（`v-if="isMultiPage"`）；「建立」label 於多頁時改為 `建立 N 筆`
- [x] 6.5 多頁生成 entrypoint：`startRecognize`（圖片路徑）固定 push 單頁 stub 到 refs 並清空 `pages`；**多頁只由 D 章節批次匯入 Dialog 觸發**（呼叫 `stageImportedPages(pages)` 中繼；新增支出頁掛載時 `takeImportedPages()` → `pages = ...`、`currentPageIndex=0`、`loadPageData(pages[0])`；toast 文案「已載入 N 筆匯入資料，逐筆核對後可一次建立」）— 依賴 §7 BatchImportDialog
- [x] 6.6 多頁「建立」邏輯
  - `syncCurrentPageState` 凍結目前頁 → 迴圈 i=0..N-1：`loadPageData(pages[i])` + `validate()`；有錯 `scrollToFirstError` 直接 return
  - 全部通過 → for each `createOneExpense(p)` → toast「已建立 N 筆支出」→ 導回列表
- [x] 6.7 分頁狀態下的離開頁確認：`hasAnyInput()` 於 multi-page 時 sync 當前頁後檢查全部 pages 是否任一有內容；沿用既有 `onBeforeRouteLeave` confirm dialog
- [x] 6.8 分頁元件手機版：文字與 dot 尺寸縮小（`text-[11px] sm:text-xs`）；`total <= 5` 全顯示 dot；`total > 5` 手機隱藏 dot（`hidden sm:flex`）改用文字 + prev/next 瀏覽



## 7. 批次匯入 Dialog（PDF + Excel 統一入口）

- [x] 7.1 新增 `frontend/src/components/BatchImportDialog.vue`（使用 `v-model:visible` 雙向綁定 open state）
- [x] 7.2 Dialog 內容
  - 檔案上傳區：`accept=".pdf,.xlsx,.xls,application/pdf,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"`；label「點擊上傳 PDF 或 Excel」（不加 `multiple`：MVP 單檔）
  - 未上傳時顯示 dropzone 樣式（`border-2 border-dashed` + cloud-upload icon）
  - 上傳後：檔案卡片（檔名 truncate、KB/MB 大小 tabular-nums、`pi-file-pdf` / `pi-file-excel` 依副檔名切換）+ 圓形「移除」按鈕
  - 「開始辨識」primary 按鈕（`pi-sparkles`；`!file || isRecognizing` 時 disabled）
  - Message severity="info"「示範用途、實際解析由後端整合」
- [x] 7.3 「開始辨識」流程（2026-09-08 決策：跳過預覽 DataTable，直接導頁）
  - 點擊 → 1.5s stub loading（按鈕變 disabled + `pi-spin pi-spinner` + `aria-busy="true"`）
  - loading 結束 MUST 直接 `expenses.stageImportedPages(drafts)` → `emit('update:visible', false)` → `router.push({ name: 'admin-expense-new' })`
  - **Dialog 內不再顯示預覽 DataTable 或「載入表單編輯」按鈕**；預覽動線改由新增支出頁的分頁 UI 承擔（見 §6）
- [x] 7.4 假資料 3 筆固定（PDF 與 Excel 共用；由 `makeStubDrafts()` 產生；補齊統編/發票號/品項讓表單能通過必填驗證，只剩 payoutStatus 待使用者補選）：
  - `{ category:'travel', amount:350, vendor:'台北大車隊', taxId:'03795302', invoiceNo:'MA-88776655', taxRate:'business_5', preTaxAmt:333, taxAmt:17, items:[{name:'計程車車資（信義區→內湖）', qty:1, unit:350, sub:350}] }`
  - `{ category:'meal', amount:220, vendor:'Starbucks 統一星巴克', taxId:'80072795', invoiceNo:'SB-11223344', taxRate:'business_5', preTaxAmt:210, taxAmt:10, items:[{拿鐵 Grande 150}, {肉桂捲 70}] }`
  - `{ category:'office', amount:890, vendor:'金石堂書局', taxId:'12345678', invoiceNo:'AB-98765432', taxRate:'business_5', preTaxAmt:848, taxAmt:42, items:[{A4 影印紙 5 包 500}, {原子筆 30 支 390}] }`
  - `documentType='invoice'`、`incurredAt=今日`、`payoutStatus=null`、`tags=[]`（付款狀態保留給使用者顯性決定）
- [x] 7.5 stage 動線由 §7.3「開始辨識」直接完成；不再有獨立的「載入表單編輯」按鈕
- [x] 7.6 `ExpenseFormView.vue` 於 `onMounted` 時檢查 `useExpenseStore.takeImportedPages()`，若非 null 則 `fromImport = true` + clone 到 `pages` 陣列（`incurredAt` 用 `new Date(...)` 重建避免 stage 期間物件被凍結）、`currentPageIndex=0`、`loadPageData(pages[0])`；顯示 info toast「已載入 N 筆匯入資料，請逐筆核對後按「建立」」
- [x] 7.6.a `fromImport = true` **時，表單第一列的憑證上傳區塊 (**`v-if="!fromImport"`**) MUST 隱藏**（2026-09-08 決策：批次匯入場景下憑證由原檔案承載，此頁只做欄位核對）
- [x] 7.7 手機版 Dialog 全寬顯示：`:style="{ width: 'min(92vw, 560px)' }"` + `:breakpoints="{ '640px': '96vw' }"`
- [x] 7.8 無障礙：PrimeVue Dialog 內建 focus trap + ESC 關閉；「開始辨識」loading 有 `aria-busy="true"`；上傳 input 有 `aria-label="上傳 PDF 或 Excel"`；檔案卡片移除按鈕有 `aria-label`「移除 檔名」；辨識中「取消」與「移除」皆 disabled 避免競態

- **e2e 驗證通過（2026-09-08 初版）**：admin 登入 → /admin/expenses → 匯入 → Dialog 開 → 注入 test-invoices.pdf → 開始辨識 → 直接跳轉 /admin/expenses/new → toast「已載入 3 筆匯入資料」→ 憑證區塊隱藏 → 第 1 頁台北大車隊 preTax 333 amount 350（含統編、發票號、品項）→ 分頁元件「第 X 筆 / 共 3 筆」+「建立 3 筆」皆正確



## 8. Router

- [x] 8.1 `frontend/src/router/index.ts`：admin children 加 `admin-expense-new` route（path: `expenses/new`）；lazy import `views/admin/ExpenseFormView.vue`；order 放在 `admin-expenses` 之後
- [x] 8.2 `admin-expense-new` 不加 `meta.requiredRole`



## 9. 統一支出列表

- [x] 9.1 改寫 `ExpensesView.vue`：PageHeader「支出管理」+ 「新增支出」按鈕
- [x] 9.2 PageHeader `#actions` 補「匯入」次要按鈕（outlined + `pi-upload` icon），點擊 `showImport = true` 開 `BatchImportDialog`；兩顆 button 用 `flex items-center gap-2` 分隔
- [x] 9.3 **移除 view-mapping**：拿掉 `unifiedRows` 內對 reimbursements store 的 filter/map 邏輯；`reimbursementToExpense` 函式刪除；直讀 `expenses.expenses`
- [x] 9.4 排序：日期 DESC；相同日期一般支出優先
- [x] 9.5 篩選 UI：keyword、來源、類別（MultiSelect，選項為 13 科目 + material/tool/service）、日期區間、付款狀態 tab
- [x] 9.6 DataTable columns：日期、類別、金額、廠商/對象、來源 pill、付款狀態 chip、操作（**移除付款方式欄** — 見 design.md Decision 8）
- [x] 9.7 操作欄：**實作決策改為**一律顯示放大鏡 icon（`pi-search-plus`）按鈕，點擊開 `ExpenseDetail` Dialog 顯示完整支出資訊（原規劃 general 顯示「—」、reimbursement 顯示「到發放頁」；改為統一放大鏡以減少視覺分歧、代墊款來源的付款動作由 PayoutView 承擔；spec.md 已同步）
- [x] 9.8 空狀態 EmptyState
- [x] 9.9 手機版：DataTable scroll 策略沿用；action 按鈕小型化
- [x] 9.10 移除 `useUsersStore` 與 `Reimbursement` 相關 import（view-mapping 拿掉後不用了；build 通過）



## 10. 代墊款核准 → 建立支出流程（Reimbursement 側整合）

- [x] 10.A.1 新增 `frontend/src/components/ApproveWithExpenseDialog.vue`
  - Props: `reimbursement: Reimbursement`、`mode: 'approve' | 'approve-only'`（'approve-only' 用於已核准補建立支出）
  - Emits: `close`、`confirmed(payload)`
  - Layout：
    - 標題「核准請款」（approve mode）或「補建立支出」（approve-only mode）
    - 簽核意見輸入 Textarea（approve mode 顯示；approve-only mode 隱藏）
    - Checkbox「同時建立支出？」預設 checked（approve mode）；approve-only mode 已預勾且 disabled
    - 條件展開下方欄位（checked 時顯示）：
      - **實付廠商 InputText**（實作補上：避免用員工姓名當廠商；由 admin 補齊實際外部廠商）
      - 會計科目 Select（13 選 1，預設帶入 `reimbursement.category`）
      - 付款狀態 Select（pending / paid）
      - 自訂類別 tags AutoComplete multiple（suggestions 綁 `useExpenseStore.allTags`）
    - 「取消」outlined + 「確認」primary
- [x] 10.A.2 Dialog 表單 validation：checkbox 勾選時，會計科目與付款狀態為必填；tags 可空
- [x] 10.A.3 Dialog 手機版全寬；tags AutoComplete 手機版 chip 換行
- [x] 10.A.4 無障礙：Dialog 開啟 focus trap；ESC 關閉；checkbox 有 `aria-controls` 指向下方展開區域

- [x] 10.B.1 `useReimbursementStore` 的 `approveCurrentStep` action extend：接受 `options?: { createExpense?: { vendor, category, payoutStatus, tags } }` 參數（vendor 依 10.A.1 補上）
- [x] 10.B.2 若 `options.createExpense` 有值 → 呼叫 `useExpenseStore.addFromReimbursement(reimbursement, options.createExpense, reviewerId)` → 取回 expenseId → 寫入 `reimbursement.expenseId`；另外新增 `createExpenseForApproved` action 給「補建立支出」入口
- [x] 10.B.3 normalizer 補 `expenseId` 預設 null；相容既有 seed 沒有此欄位的情況

- [x] 10.C.1 `views/admin/ReviewView.vue` 待簽核清單「通過」按鈕改為開 `ApproveWithExpenseDialog`（mode='approve'）
- [x] 10.C.2 Dialog `confirmed` → 呼叫 `reimbursements.approveCurrentStep(id, uid, { createExpense: payload.createExpense })`
- [x] 10.C.3 已處理清單加「支出狀態」欄：
  - `expenseId != null` → chip「已成立支出」；查 Expense.payoutStatus paid → 補「已付款」chip
  - `expenseId == null` 且 status='approved' → chip「未成立支出」+「新增支出」按鈕
  - status='rejected' → 「支出狀態」欄空白
  - status='voided' → chip「已作廢」
- [x] 10.C.4 「新增支出」按鈕 → 開同一 Dialog（mode='approve-only'）；confirmed → 呼叫 `expenses.addFromReimbursement` + 寫回 `reimbursement.expenseId`（不動 status）

- [x] 10.D.1 `views/admin/PayoutView.vue`：`markPaid` action 執行後，若 `reimbursement.expenseId != null`，額外呼叫 `expenses.markExpensePaidById(reimbursement.expenseId)` 同步 Expense.payoutStatus
- [x] 10.D.2 ~~PayoutView 列表若某筆~~ `expenseId == null`~~，「標記已發放」按鈕 disabled~~ **2026-09-08 二次微調放寬**：`approved` 一律可發放（`canPayThis` 只需 status='approved'）；`markPaid` 內 `if (target.expenseId)` guard 讓沒 Expense 的代墊款自動跳過 Expense 同步、只更新 Reimbursement 狀態
- [ ] 10.D.3 `revertPaid` 反向同步 Expense — **實作決策：不做**。Decision 8 已定 MVP 不做 Expense 的事後付款/取消付款動作；revertPaid on Reimbursement 只還原 Reimbursement.status，不會反向改動已成立的 Expense.payoutStatus。若要保留一致性 Phase 2 再補

- [x] 10.E.1 `views/front/ExpenseFormView.vue`：類別 Select `options` 改為 `GENERAL_EXPENSE_CATEGORY_OPTIONS`
- [x] 10.E.2 類別下拉**只顯示中文名稱**（不顯示會計代碼）— 直接用 `option-label="label"` 不用 custom template

- [x] 10.F.1 `mocks/reimbursements.json`：既有 seed 全部補上 `paymentMethod`、`expenseId` 欄位；exp-003 指向 `exp-seed-r-01`、其餘為 null
- [x] 10.F.2 `mocks/expenses.json`：新增 `exp-seed-r-01`（source='reimbursement', sourceRefId='exp-003', documentType='receipt', taxRate='exempt_0', vendor='特力屋內湖店'）作為代墊款轉入 demo
- [x] 10.F.3 seed 涵蓋「未成立支出的 approved 代墊款」情境：exp-002 為 approved 且 expenseId=null，供 QA 驗證 ReviewView「新增支出」按鈕與 PayoutView disabled 動線



## 11. API 契約

- [x] 11.1 新增 `frontend/src/api/expenses.ts` + 模組 doc
- [x] 11.2 `ExpenseDTO` 對應 `Expense`
- [x] 11.3 `CreateExpenseRequest` + JSDoc `POST /expenses`
- [x] 11.4 `UpdateExpenseRequest`（`Partial<CreateExpenseRequest>`）+ JSDoc `PATCH /expenses/:id`
- [x] 11.5 `ListExpensesQuery` + JSDoc `GET /expenses`
- [x] 11.6 `PayExpenseRequest` + JSDoc `PATCH /expenses/:id/pay`
- [x] 11.7 `RevertPayRequest` + JSDoc `PATCH /expenses/:id/revert-pay`
- [ ] 11.8 補上 `ExpenseDTO` / `CreateExpenseRequest` 新欄位：`taxRate`、`documentType`、`tags`、`items`；**移除** `payoutMethod` 欄位（`payoutMethod` 已移除 ✓；新欄位仍待補）
- [x] 11.9 為 `PayExpenseRequest` / `RevertPayRequest` 的 JSDoc 加註「MVP UI 不呼叫，保留給後端」
- [x] 11.10 從 `PayExpenseRequest` 移除 `method` 欄位（因 Expense 不再記錄 payoutMethod）



## 12. 樣式細節

- [x] 12.1 來源 pill：一般支出 primary、代墊款 secondary
- [x] 12.2 付款狀態 chip：pending 琥珀、paid 綠
- [x] 12.3 稅率 3 欄：桌面 grid-cols-3、gap 一致；手機版單欄堆疊
- [x] 12.4 品項列表：每列欄位對齊；小計改為 disabled InputNumber（見 5.8）
- [x] 12.5 tag chip：secondary tone；chip 之間 gap 一致
- [x] 12.6 「開始辨識」按鈕：**primary + camera icon**（原規劃 outlined，改為 primary 強化主要動作）；辨識中 loading 樣式
- [x] 12.7 分頁元件：pill 容器、active dot 為 primary 圓角矩形、非 active dot 為灰圓點
- [x] 12.8 檢查所有文字手機版 ≤ 14px



## 13. 驗收

- [ ] 13.1 全 codebase `grep -rn "useExpenseStore" frontend/src` 至少有 3 個 hit（store 定義 + form view + list view）
- [ ] 13.2 `pnpm --dir frontend build` 通過
- [ ] 13.3 人工 QA checklist：
  - [x] `/admin/expenses`：看到合流列表；PageHeader 右上有「新增支出」+「匯入」
  - [x] 「匯入」按鈕 → 開 Dialog → 未上傳時「開始辨識」disabled
  - [x] Dialog 上傳 PDF → 同樣流程可完成
  - [x] 「載入表單編輯」→ 導到 `/admin/expenses/new`；表單顯示分頁元件「第 1 筆 / 共 3 筆」；每頁欄位為預覽的資料
  - [x] 分頁元件切換：點 next → 表單載入下一頁；當前頁編輯後切換 → 內容保留（切回可看到剛才的編輯）
  - [x] 分頁 prev 到第 1 頁時 disabled、next 到最後頁時 disabled
  - [x] 多頁「建立」→ 全部通過 → toast「已建立 3 筆支出」→ 列表新增 3 筆
  - [x] 多頁「建立」某頁缺必填 → 跳至該頁 + focus 錯誤欄位
  - [x] 「新增支出」→ 進到 `/admin/expenses/new`；表單為單一版面（無 tab）；只有 1 頁時**不顯示**分頁元件
  - [x] 憑證區塊在最上、獨立一列；label + 小字備註「.jpg .png」正確；試上傳 PDF 應被拒絕
  - [ ] 手機版憑證區塊有「拍照」與「選擇檔案」兩種操作
  - [x] 未上傳圖片時「開始辨識」按鈕不顯示
  - [x] 上傳 1 張圖 → 出現「開始辨識」→ 點擊 → loading 1.5s → 欄位（日期/廠商/統編/發票號/類別/稅率/金額/品項）自動填入 → toast「辨識完成」→ 只有 1 頁（不顯示分頁）
  - [x] OCR 填入的所有欄位可手動編輯
  - [x] 選「發票」→ 發票號碼必填、驗證格式 2 英文 + 8 數字；填錯格式按建立 → inline error
  - [x] 選「收據」→ 發票號碼可空、不驗證
  - [x] 欄位順序（由上到下）：憑證 → 發票/收據 radio → 交易日期/統編/廠商/發票號碼 → 稅率 3 欄 → 品項 → 費用類別+付款狀態 → 自訂類別 → 備註
  - [x] 費用類別下拉顯示 13 個科目 + 每個科目右側顯示會計代碼
  - [x] 自訂類別 chip autocomplete：輸入新 tag、選既有 tag、可多選；儲存後再進表單重新載入 suggestions 有這些 tag
  - [x] 稅率 3 欄：填 preTax 1000、稅率 5% → 自動 amount 1050、下方「營業稅額為 50 元」
  - [x] 稅率 3 欄：填 amount 1050 → 自動 preTax 1000
  - [x] 切換稅率為「免稅或收據 0%」→ preTax 1000 保留、amount 變 1000、稅額 0 元
  - [x] 品項可新增列、刪除列；填數量 × 單價 → 小計自動計算
  - [x] OCR 觸發自動填入 3 筆品項；使用者可再增 / 刪
  - [x] 備註欄位在表單最底
  - [ ] 付款狀態選「已付款」→ 建立後 `payoutDate=今日`
  - [x] 缺必填按建立 → inline error + focus 第一錯誤欄位
  - [x] 儲存成功 → toast + 導回列表；列表出現新支出，欄位正確
  - [x] 手機版 375px：所有欄位可填、稅率改單欄堆疊、submit 按鈕可用
  - [x] 手機版品項為雙行：第 1 行品名 + 刪除、第 2 行數量/單價/小計；桌面版仍為單行 grid-cols-12
  - [x] 篩選：來源、類別、日期、付款狀態 tab 都能過濾；「清除」一鍵歸零
  - [x] 未核准的代墊款（draft/in_review/rejected/voided）不出現在列表
  - [x] 已核准但 `expenseId=null` 的代墊款不出現在支出列表
  - [ ] `api/expenses.ts` 打開後看得到 5 個 endpoint 型別；`Pay` / `RevertPay` 有 JSDoc 註記「MVP UI 不呼叫」
  - [x] **代墊款核准流程**：在 ReviewView 對 in_review 代墊款按「通過」→ 開 Dialog；預設勾選「同時建立支出」；下方 3 欄展開；會計科目預設為代墊款既有 category
  - [x] 補齊會計科目 / 付款狀態 / tags → 確認 → Reimbursement 變 approved + 支出列表出現一筆 source='reimbursement' Expense
  - [x] 取消勾選「同時建立支出」→ 下方 3 欄收起；確認 → Reimbursement 變 approved 但支出列表不新增
  - [x] 已處理清單看剛才 approved 但未成立支出的那筆：顯示「未成立支出」chip + 「新增支出」按鈕
  - [x] 按「新增支出」→ 開同一 Dialog（approve-only mode，簽核意見隱藏，checkbox disabled 且已勾）→ 補齊 → 確認 → 支出列表新增一筆
  - [x] 已處理清單該筆狀態變「已成立支出」chip
  - [x] PayoutView 對「未成立支出」的 approved 代墊款「標記已發放」→ 可直接發放（2026-09-08 微調放寬），Reimbursement 變 paid，沒有 Expense 需同步時自動跳過
  - [x] PayoutView 對「已成立支出」的 approved 代墊款「標記已發放」→ Reimbursement 變 paid + 對應 Expense.payoutStatus 也變 paid、payoutDate=今日
  - [x] 前台員工提交請款頁類別下拉為 13 個簡化會計科目、只顯示中文名稱



## 14. Archive

- [ ] 14.1 `pnpm --dir frontend build` 再跑一次
- [ ] 14.2 `openspec archive add-general-expense-module`
- [ ] 14.3 更新 `docs/實作流程.md` §三「當前實作狀況」表格：Phase 1 相關列勾 ✅（支出列表、新增支出）