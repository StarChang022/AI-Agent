## Context

Codebase 內既有 `Expense`／`ExpenseStatus`／`useExpenseStore`／`expenses.json` 對應到的實際上是新 PRD 的 `Reimbursement`（代墊款請款）。詳細動機見 `proposal.md - Why`。

現有 references（`grep` 統計）分佈於 16 個檔案：`types/domain.ts`、`stores/expenses.ts`、`mocks/expenses.json`、`utils/approval.ts`、`constants/expense.ts`、`components/StatusBadge.vue`、`components/AdminExpenseDetail.vue`、`views/front/HomeView.vue`、`views/front/HistoryView.vue`、`views/front/ExpenseFormView.vue`、`views/front/ExpenseDetailView.vue`、`views/admin/DashboardView.vue`、`views/admin/RecordsView.vue`、`views/admin/ReviewView.vue`、`views/admin/PayoutView.vue`、`layouts/AdminLayout.vue`、`router/index.ts`。

## Goals / Non-Goals

**Goals:**
- 讓後續 change（`add-general-expense-module`）可以直接新增名為 `Expense` 的 type / store / mock，不會與現有 identifier 撞名
- Rename diff 純粹是「改名」，方便 review：只有 identifier / import / 檔名變動；不摻雜行為變更、不摻雜 UI 文字修改

**Non-Goals:**
- 不動 UI 中文字（見 proposal.md Non-goals）
- 不改 View 檔名（`ExpenseFormView.vue`、`ExpenseDetailView.vue`、`AdminExpenseDetail.vue`）
- 不改 route name / path
- 不改行為（狀態機、mock 內容）

## Decisions

**Decision 1：識別策略（大範圍 rename 而非 alias）**

- **選擇**：直接 rename identifier，不使用 `export type Expense = Reimbursement` 這種 alias 過渡
- **理由**：Alias 會讓後續加入的「真正的 Expense」與舊 alias 撞名，反而更亂；一次改乾淨對後續 change 是必要前置條件
- **代價**：diff 較大（15+ 檔），但都機械改動

**Decision 2：`ExpenseCategory` 型別保留原名**

- **選擇**：`ExpenseCategory` type 名稱先不動
- **理由**：這個 union（material/tool/travel/service/other）將在 Phase 2 整個換掉（改為 `categoryId: string` 讀 categories store）；此時 rename 為 `ReimbursementCategory` 不但沒好處，還讓 Phase 2 得再改一次。另外 Phase 1 Step 1.2 的新 Expense 也會共用同一個類別欄位，改名反而語意錯亂
- **代價**：identifier 命名一致性暫時不完美，但短期內 Phase 2 就會解決

**Decision 3：檔名 `constants/expense.ts` 暫留**

- **選擇**：這支檔案內容繼續放 `CATEGORY_LABELS`／`CATEGORY_OPTIONS`／`PAYMENT_METHOD_LABELS`（共用常數），檔名不改
- **理由**：這些常數在 Reimbursement 與未來的 Expense 都會用到；改成 `constants/reimbursement.ts` 反而變成把「共用常數」綁到單一 model；改成 `constants/category.ts` 也不完全對（還有 PaymentMethod）
- **代價**：檔名字面上保留「expense」字樣，但語意已是「共用支出/請款常數」；Phase 2 若必要再拆

**Decision 4：View 檔名不動**

- **選擇**：`ExpenseFormView.vue`、`ExpenseDetailView.vue`、`AdminExpenseDetail.vue` 這幾支檔名 Phase 1 Step 1.1 不改
- **理由**：Step 1.3 需要新增 `views/admin/ExpenseFormView.vue`（真正的一般支出登錄頁）。屆時需要一起處理「舊代墊款版的 form view 改名」與「新支出版 form view 命名」，一起做才不會 mid-way 有兩支同名檔。此 change 只把 script 內的 identifier / import 改乾淨即可
- **代價**：檔名與內容 identifier 短暫不一致，但短期（下一個 change）就會解決

**Decision 5：LocalStorage key rename**

- **選擇**：`quickey.expenses` → `quickey.reimbursements`，不寫遷移碼
- **理由**：Prototype 階段 dev 使用者資料無關緊要；寫遷移碼是浪費（Phase 1 之後接後端時本地資料本來也要清）
- **代價**：dev 環境重整 → 現有寫入的請款會失效，回到 seed data

## Risks / Trade-offs

- **Risk：dev 使用者的 localStorage 資料失效** → Mitigation：這是 Prototype，QA 前建議手動清 localStorage 或用無痕視窗；正式使用者尚未存在
- **Risk：某處 identifier rename 漏改導致 build 失敗** → Mitigation：`pnpm build` 通過為驗收條件；TypeScript 會直接抓到 type 錯誤
- **Risk：commit 訊息裡混雜大量 rename + 少量真動作** → Mitigation：此 change 專職 rename，commit 訊息 `refactor: 把 Expense 系列 identifier 改名為 Reimbursement`，diff 一目瞭然
- **Risk：搜尋替換誤傷** → Mitigation：不做「全 codebase blind replace all」；改用檔案清單逐檔手改；`Expense` 字串出現在中文變數名 comment / 其他語境要保留（尤其 UI 中文字 "請款" 已經是 label 不含 Expense 字樣，不會誤傷）

## Migration Plan

不涉及 production migration。開發者本地 dev server 首次啟動時：
1. localStorage 舊 key `quickey.expenses` 內容失效（下一個 change 完成後無用）
2. 新 key `quickey.reimbursements` 從 seed 載入
3. 若需要清理：`localStorage.removeItem('quickey.expenses')` 或直接 devtools 手動清
