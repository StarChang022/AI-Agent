## Why

新 PRD（`docs/資料模型.md` §一）確立雙 model 決策：`Reimbursement`（代墊款請款）與 `Expense`（支出）業務語意、生命週期、會計科目都不同。但現有 codebase 的 `Expense`／`ExpenseStatus`／`useExpenseStore`／`expenses.json` 對應到的實際上是新 PRD 的 `Reimbursement` — 「員工提交、走 6 狀態機、需簽核」。

Phase 1 之後要新增真正屬於「支出」語意的 `Expense`（一般支出登錄，無簽核）。若不先把舊 identifier rename，後續兩者會撞名。此 change 的目的就是把 identifier 拉正，讓下一個 change（`add-general-expense-module`）可以在乾淨的 namespace 下擴充。

## What Changes

- **Rename 現有 `Expense` 系列 identifier 為 `Reimbursement`**（純機械 rename，不改任何行為）：
  - Type：`Expense` → `Reimbursement`、`ExpenseStatus` → `ReimbursementStatus`、`ExpenseCategory` 保留（此欄位屬於雙方共用的類別語意，Phase 2 才改為動態）
  - Store：`useExpenseStore` → `useReimbursementStore`；檔名 `stores/expenses.ts` → `stores/reimbursements.ts`；`STORAGE_KEY 'quickey.expenses'` → `'quickey.reimbursements'`（見下方 Impact 註記）
  - Mock：`mocks/expenses.json` → `mocks/reimbursements.json`；import 名稱更新
  - Constants：`constants/expense.ts` 內若有直接的 identifier 名稱（例：`CATEGORY_LABELS`/`PAYMENT_METHOD_LABELS`）保留；檔案本身暫留 `constants/expense.ts` 名稱（`ExpenseCategory` 尚未拆），下一個 change 才動
  - Views/Components：`views/front/ExpenseFormView.vue`、`views/front/ExpenseDetailView.vue`、`components/AdminExpenseDetail.vue`、`views/admin/RecordsView.vue`、`views/admin/ReviewView.vue`、`views/admin/PayoutView.vue`、`views/admin/DashboardView.vue`、`views/front/HomeView.vue`、`views/front/HistoryView.vue`、`layouts/AdminLayout.vue`、`utils/approval.ts`、`components/StatusBadge.vue` 內的 identifier（import、type 標註、變數名）改為對應的 Reimbursement 版本
  - Route name：**不動**（`admin-records`、`admin-review`、`admin-payout`、`front-history`、`front-expense-detail`、`front-expense-edit`、`front-new` — 這些對外語意仍是「請款」；rename 只針對程式碼 identifier）
- **UI 中文字全部不動**：`「請款」「請款記錄」「新增請款」`等所有 label 保持原樣（見 Non-goals）
- **View 檔名不動**：`ExpenseFormView.vue`、`ExpenseDetailView.vue`、`AdminExpenseDetail.vue` 暫留原名（下一個 change 才會有真正名為 `Expense` 的新 view 需要區隔命名，屆時再一併處理）

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
（無 — 純內部 identifier rename，不影響任何 spec-level 行為，`.openspec.yaml` 已設 `skip_specs: true`）

## Impact

**動到的檔案**
- `frontend/src/types/domain.ts` — Expense/ExpenseStatus interface 改名為 Reimbursement/ReimbursementStatus
- `frontend/src/stores/expenses.ts` → `frontend/src/stores/reimbursements.ts`（rename 檔案，內容裡 identifier 一起改）
- `frontend/src/mocks/expenses.json` → `frontend/src/mocks/reimbursements.json`（rename 檔案）
- `frontend/src/utils/approval.ts` — type import 改名
- `frontend/src/constants/expense.ts` — `Expense` import 改為 `Reimbursement`（檔名暫不動）
- `frontend/src/components/StatusBadge.vue` — type import 改名
- `frontend/src/components/AdminExpenseDetail.vue` — type import、prop type 改名（檔名不動）
- `frontend/src/views/admin/DashboardView.vue`
- `frontend/src/views/admin/RecordsView.vue`
- `frontend/src/views/admin/ReviewView.vue`
- `frontend/src/views/admin/PayoutView.vue`
- `frontend/src/views/front/HomeView.vue`
- `frontend/src/views/front/HistoryView.vue`
- `frontend/src/views/front/ExpenseFormView.vue`（檔名不動）
- `frontend/src/views/front/ExpenseDetailView.vue`（檔名不動）
- `frontend/src/layouts/AdminLayout.vue`（若有 useExpenseStore 引用）
- `frontend/src/router/index.ts` — 只改可能出現的 store import；route name 保持

**不動的檔案**
- CLAUDE.md、design.md、dev-style.md、docs/ 全部
- 前台 `LoginView.vue`、後台 `LoginView.vue`
- 其他無關 view（`UsersView.vue`、`ExpensesView.vue` stub、`CategoriesView.vue` stub、`BudgetsView.vue` stub）
- `types/domain.ts` 內的 `Role`、`User`、`Department`、`ApprovalStep`、`ApprovalProgress`、`PaymentMethod`、`ExpenseCategory` 完全不動

**LocalStorage key 遷移**
`STORAGE_KEY` 從 `quickey.expenses` 改為 `quickey.reimbursements`。開發環境使用者的既有請款資料會失效並改讀 seed（可接受，僅影響 dev），Prototype 階段不需要寫遷移碼。若擔心可先手動清 localStorage。

**Non-goals（此 change 不做）**
- 不新增任何功能（Step 1.2 以後才做）
- 不改 UI 中文字（「請款」等 label 保留原樣）
- 不改 route path 或 name
- 不改 `ExpenseCategory` 型別（那屬於 Phase 2 categorization 議題）
- 不動 `views/front/ExpenseFormView.vue`／`views/front/ExpenseDetailView.vue`／`components/AdminExpenseDetail.vue` 的 **檔名**（下一個 change 才會有名稱衝突需求）
- 不改行為、不改狀態機、不改任何 mock 資料的內容（欄位／值皆保留）
- 不加測試
