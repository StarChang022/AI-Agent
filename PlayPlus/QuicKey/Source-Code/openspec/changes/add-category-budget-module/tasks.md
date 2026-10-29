## 1. Type / Domain

- [x] 1.1 `frontend/src/types/domain.ts`：新增 `BudgetCycle` union（`'month' | 'year'`），註解指向 `docs/資料模型.md` §3.5
- [x] 1.2 新增 `Budget` interface：`id / categoryId / cycle / amount / periodStart / periodEnd / createdAt / updatedAt`；註解說明唯一約束、業務規則（同類別可月＋年並存、期間獨立、與 Expense 加總關聯計算執行率、amount=0 語意由 store 層過濾為刪除記錄）
- [x] 1.3 新增 `BudgetTemplate` interface：`id / categoryId / cycle / amount / createdAt / updatedAt`；註解說明唯一約束 `(categoryId, cycle)`、與 Budget 的關係（獨立記錄、僅於使用者點「套用基本預算」時 materialize 為 Budget）

## 2. Mock 資料

- [x] 2.1 新增 `frontend/src/mocks/budgets.json`：至少 6 筆 seed，涵蓋
  - 2026-09 月預算：travel、office、meal 至少各一筆
  - 2026 年預算：office、meal、training、business_travel 至少各一筆
  - 需搭配既有 expenses seed 造出「正常」「低使用率」「零支出」「超支」四種狀態
- [x] 2.2 seed 期間欄位符合 Decision 3：月為 `YYYY-MM-01` / 該月最後一天；年為 `YYYY-01-01` / `YYYY-12-31`
- [x] 2.3 新增 `frontend/src/mocks/budget-templates.json`：至少 5 筆 seed
  - cycle=month：travel $3,000、meal $2,000、office $1,500
  - cycle=year：training $60,000、business_travel $40,000
  - 至少留一個使用中類別**沒有**對應 template，用於驗證「套用時跳過無 template 類別」情境

## 3. Budgets store

- [x] 3.1 新增 `frontend/src/stores/budgets.ts`：`useBudgetsStore`；STORAGE_KEY `quickey.budgets.v1` 與 `quickey.budget-templates.v1` 兩把；load from localStorage or seed；`watch(budgets, deep, save)` 與 `watch(templates, deep, save)` 各一
- [x] 3.2 `normalizeBudget` / `normalizeTemplate` 補齊舊資料缺欄位（避免 legacy shape 破 UI）
- [x] 3.3 action `upsertBudget(input)`：
  - `amount === 0` → 尋找 `(categoryId, cycle, periodStart)` 現有記錄並刪除（等同 `removeBudget`），回傳 `{ deleted: true, id }` 或 no-op
  - `amount < 0` → 回 null 不處理（view 端 toast 錯誤）
  - `amount > 0` 且已存在 → 更新 amount + updatedAt
  - `amount > 0` 且不存在 → 新增
- [x] 3.4 action `removeBudget(id)`：以 id 硬刪；找不到回 false
- [x] 3.5 action `removeBudgetBy(categoryId, cycle, periodStart)`：convenience，內部找 id 後轉呼叫 `removeBudget`
- [x] 3.6 query `findBudget(categoryId, cycle, periodStart)`：回傳單筆或 null
- [x] 3.7 query `computeUtilization(categoryId, cycle, periodStart, periodEnd)`：呼叫 `useExpenseStore()`、依日期字串比對加總；回傳 `{ budget, actual, utilization, remainingRatio, remainingAmount, isOverBudget }`；未設預算時 utilization / remainingRatio / remainingAmount 皆為 null、isOverBudget=false
- [x] 3.8 export top-level `monthPeriod(refDate)` / `yearPeriod(refDate)` helper（純函數，回傳 `{ periodStart, periodEnd }` 本地時區字串）
- [x] 3.9 action `upsertTemplate(input)`：
  - `amount === 0` → 尋找 `(categoryId, cycle)` 現有記錄並刪除（等同 `removeTemplate`）
  - `amount < 0` → 回 null
  - `amount > 0` → upsert
- [x] 3.10 action `removeTemplate(categoryId, cycle)`：以 unique key 刪除；找不到回 false
- [x] 3.11 query `findTemplate(categoryId, cycle)`：回傳單筆或 null
- [x] 3.12 action `applyTemplatesToPeriod(cycle, refDate)`：
  - 依 `monthPeriod` / `yearPeriod` 由 refDate 算出當前 `periodStart / periodEnd`
  - 對該 cycle 所有 `amount > 0` 的 template，執行 `upsertBudget(categoryId, cycle, periodStart, periodEnd, amount)` 覆寫既有 Budget
  - `amount = 0` 或無 template 的類別跳過
  - 回傳更新筆數 count
- [x] 3.13 全檔 JSDoc 註解引用 `docs/資料模型.md` §3.5 與 design.md Decision 2 / 3 / 5 / 6 / 9 / 13 / 14

## 4. API 契約

- [x] 4.1 新增 `frontend/src/api/budgets.ts`：只 export TS 型別、無 runtime 值
- [x] 4.2 `BudgetDTO`：server → client 資源；欄位對齊 `Budget` interface
- [x] 4.3 `CreateBudgetRequest`：`POST /budgets`；JSDoc 標記後端 MUST 驗證 amount > 0（0 → 引導 DELETE、負值 → 422）、(categoryId, cycle, periodStart) 唯一（重複回 409）、期間符合 cycle 定義（否則 422）
- [x] 4.4 `UpdateBudgetRequest`：`PATCH /budgets/:id`；MVP 只允許 `{ amount }`；改期間 / 類別走 delete + create
- [x] 4.5 `ListBudgetsQuery`：`GET /budgets`；filter `categoryId?` / `cycle?` / `periodStart?`
- [x] 4.6 `DeleteBudgetResponse`：`DELETE /budgets/:id`；無 soft-delete
- [x] 4.7 `BudgetTemplateDTO`：server → client 資源；欄位對齊 `BudgetTemplate` interface
- [x] 4.8 `UpsertBudgetTemplateRequest`：`PUT /budget-templates`（單一 endpoint 處理建立與更新）；欄位 `{ categoryId, cycle, amount }`；JSDoc 標記後端 MUST 驗證 amount ≥ 0（0 → 刪除既有 template；<0 → 422）、cycle 值合法
- [x] 4.9 `ListBudgetTemplatesQuery`：`GET /budget-templates`；filter `cycle?`
- [x] 4.10 `ApplyBudgetTemplatesRequest` / `ApplyBudgetTemplatesResponse`：`POST /budget-templates/apply`；request `{ cycle, periodStart, periodEnd }`；response `{ appliedCount, skippedCount }`

## 5. BudgetsView 頁面

- [x] 5.1 改寫 `frontend/src/views/admin/BudgetsView.vue`：拿掉 EmptyState 空殼；引入 PageHeader、AmountText、EmptyState、PrimeVue DataTable / Button / InputNumber / SelectButton / Tag / Dialog、useConfirm、useToast
- [x] 5.2 頁首：PageHeader title="類別預算" size="admin"；actions slot 放「基本預算設定」按鈕（icon `pi-cog` + 文字，secondary 樣式）
- [x] 5.3 Cycle 切換：PrimeVue `<SelectButton>`，options `[{ label: '月預算', value: 'month' }, { label: '年預算', value: 'year' }]`；`aria-label="切換預算週期"`
- [x] 5.4 期間切換器：`<` icon button + 期間 label（tabular-nums、min-w-[8rem] center）+ `>` icon button；aria-label 依 cycle 為「上個月／下個月」或「上一年／下一年」
- [x] 5.5 「本月／本年」快速返回按鈕：只在 refDate ≠ 今日對應期間時出現；點擊 refDate 重置
- [x] 5.6 選 cycle 時 refDate 重置為當前 cycle 的今日期間（Decision 7）
- [x] 5.7 「套用基本預算」按鈕：位於期間切換器旁；點擊觸發 `useConfirm().require`，訊息「將覆寫當前期間所有類別已編輯的預算金額，是否繼續？」，acceptProps severity=`danger`、acceptLabel「確認套用」；accept 後呼叫 `applyTemplatesToPeriod(cycle, refDate)` + toast「已套用 N 筆基本預算到 {期間}」；只在有至少一筆 amount > 0 的當前 cycle template 時 enabled，否則 disabled 並附 tooltip「尚無基本預算」
- [x] 5.8 資料 rows computed：對 `categories.active` 每個 c，呼叫 `budgets.computeUtilization`，組成 `{ category, budgetId, budgetAmount, actual, utilization, remainingRatio, remainingAmount, isOverBudget }`
- [x] 5.9 桌面 DataTable（`hidden md:block`）欄位：
  - 類別（name + accountCode 小字）
  - 預算（inline 編輯 / CTA）
  - 實際（AmountText）
  - **剩餘**（進度條 + 百分比 + 超支 Tag）
  - **餘額**（AmountText；負值以警示色呈現、前綴 `−`；未設預算「—」）
- [x] 5.10 「預算」cell 三態：
  - `v-if edit.categoryId === row.category.id` → InputNumber + 右側 [儲存 `pi-check`][取消 `pi-times`] icon 按鈕
  - `v-else-if budgetAmount === null` → 「＋ 設定預算」primary-600 文字按鈕
  - `v-else` → AmountText + pencil icon 按鈕整體可點
- [x] 5.11 InputNumber 用 `mode="currency" currency="TWD" locale="zh-TW" :max-fraction-digits="0" :min="0"`；`ref="editInputRef"`；nextTick focus + select；`@keyup.enter="commitEdit"` `@keyup.esc="cancelEdit"`；**NOT** 綁 `@blur`
- [x] 5.12 `commitEdit(row)`：
  - `amount === null / NaN / undefined` → toast「請填寫金額」
  - `amount < 0` → toast「金額不得為負數」
  - `amount === 0` → 呼叫 upsertBudget（內部走 delete 路徑）+ toast「已取消預算」
  - `amount > 0` 且等於原金額 → cancelEdit（不 toast）
  - `amount > 0` 且不同 → upsertBudget + toast「已設定預算 / 已更新預算」
- [x] 5.13 `cancelEdit()`：reset edit state；Esc / 點取消 icon 按鈕觸發
- [x] 5.14 剩餘 cell：
  - `barWidth`：`remainingRatio == null` → 0（灰底 hairline）；否則 `Math.max(0, remainingRatio) * 100 %`
  - `barClass`：三色分段 `remainingRatio > 0.2` → primary；`0 < remainingRatio ≤ 0.2` → warning；`remainingRatio ≤ 0` → danger + hairline
  - 百分比文字：未設預算 `—`；否則 `Math.max(0, Math.round(remainingRatio * 100)) + '%'`
  - 超支 Tag（severity="danger" value="超支"）：`isOverBudget === true` 時出現
- [x] 5.15 餘額 cell：
  - `remainingAmount == null` → AmountText 顯示「—」
  - `remainingAmount >= 0` → AmountText 一般色
  - `remainingAmount < 0` → 前綴 `−` + `text-status-rejected` class（絕對值格式化）
- [x] 5.16 手機卡片列表（`md:hidden`）：`<ul>` + `<li>` 卡片；每張卡片顯示
  - 類別名稱 + accountCode + 超支 Tag（若適用）
  - Grid 兩欄：預算（inline 編輯） / 實際
  - 剩餘進度條 + 百分比
  - 餘額（獨立行、正負色）
- [x] 5.17 空狀態：若 `categories.active.length === 0` → EmptyState「尚無使用中類別 / 請先到類別管理新增」（不進入表格）
- [x] 5.18 手機版樣式檢查：字級 ≤ 14px，PrimeVue InputNumber / SelectButton / Dialog 若超過需 styles/index.css 覆寫（或在 view 內 scoped `:deep(.p-inputtext) { font-size: 13px }`）
- [x] 5.19 「基本預算設定」Dialog：
  - PrimeVue `<Dialog>`；`v-model:visible="templateDialogVisible"`
  - Header 標題依 cycle：「基本月預算」或「基本年預算」
  - 頂部說明文字（`text-xs text-neutral-600`）：「儲存基本預算不會自動改動任何月/年預算，需點『套用基本預算』才會套用到當前檢視期間」
  - Body：`<ul>` 每個使用中類別一列，左邊類別名稱 + accountCode，右邊 InputNumber（`mode="currency" currency="TWD" :min="0"`）綁 draft state
  - Footer：[取消][儲存] 兩顆 Button（primary 儲存）
- [x] 5.20 Dialog 開啟時：`draft` 初始化為當前 cycle 所有使用中類別的 template amount（找不到則 0）；storage 一份 clone
- [x] 5.21 Dialog 儲存：對每個 `draft[categoryId]`：
  - `> 0` → `upsertTemplate({ categoryId, cycle, amount })`
  - `=== 0` → `removeTemplate(categoryId, cycle)`
  - `< 0` → toast 錯誤 + 中止儲存（保留 Dialog 開啟）
  - 成功後 toast「已儲存基本預算」+ 關閉 Dialog
- [x] 5.22 Dialog 取消：Esc / 點取消 / 點遮罩 → 直接關閉、不 apply draft

## 6. 進度文件同步

- [x] 6.1 `docs/實作流程.md` §三 進度表：Phase 3 「類別預算」列狀態改 ✅（附今日日期）
- [x] 6.2 `docs/QA_list/QA_類別預算.md`：新增章節涵蓋「基本預算設定」「套用基本預算」「金額 0 = 取消」「餘額欄」「剩餘欄」等本 change 新行為

## 7. 手動驗收

- [x] 7.1 執行 `pnpm build` 確認 TypeScript 型別檢查通過（Vite build 內含）
- [x] 7.2 執行 `pnpm dev`，以 admin@example.com 登入後台 → 進入「類別預算」
- [x] 7.3 依 `docs/QA_list/QA_類別預算.md`（含 6.2 補充章節）逐條人工核對（勾選 → 通過）
- [x] 7.4 手機模擬（DevTools 375px）確認卡片式呈現、Dialog 與所有操作可用
