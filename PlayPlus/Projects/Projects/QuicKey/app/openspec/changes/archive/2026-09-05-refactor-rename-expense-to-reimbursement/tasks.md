## 1. Type / Domain

- [x] 1.1 `frontend/src/types/domain.ts`：`Expense` interface 改名為 `Reimbursement`；`ExpenseStatus` 型別改名為 `ReimbursementStatus`；註解「請款」保留；`ExpenseCategory`、`PaymentMethod` 保持不動

## 2. Store 檔案 rename

- [x] 2.1 把 `frontend/src/stores/expenses.ts` 檔名改為 `frontend/src/stores/reimbursements.ts`
- [x] 2.2 檔內：`useExpenseStore` → `useReimbursementStore`、`defineStore('expenses', ...)` 的 store id 改為 `'reimbursements'`、`STORAGE_KEY = 'quickey.expenses'` → `'quickey.reimbursements'`
- [x] 2.3 檔內：`Expense`／`ExpenseStatus` 型別 import 換成 `Reimbursement`／`ReimbursementStatus`；區域變數 `expenses`／`expense` 改為 `reimbursements`／`reimbursement`
- [x] 2.4 檔內：所有 function 內語意 `AddInput`／`addExpense`／`removeExpense`／`updateDraft`／`voidExpense` 內部指涉的變數改用 `reimbursement`；action 名（`addExpense` 等）改為 `addReimbursement`／`removeReimbursement`／`voidReimbursement`
- [x] 2.5 檔內：`normalizeExpense` helper → `normalizeReimbursement`；`seedExpenses` import 改為 `seedReimbursements`

## 3. Mock 檔名

- [x] 3.1 把 `frontend/src/mocks/expenses.json` 檔名改為 `frontend/src/mocks/reimbursements.json`；內容一字不動

## 4. Utils / Constants

- [x] 4.1 `frontend/src/utils/approval.ts`：`Expense`／`ExpenseStatus` type import 改名；helper function signature 中的 `expense` 參數若有的話改為 `reimbursement`
- [x] 4.2 `frontend/src/constants/expense.ts`：檔案內 `Expense`／`ExpenseStatus`／`ExpenseCategory` import 改名（`ExpenseCategory` 保留不改）；檔名保留（見 design Decision 3）

## 5. 共用元件

- [x] 5.1 `frontend/src/components/StatusBadge.vue`：`ExpenseStatus` type import 改為 `ReimbursementStatus`；prop `status: ExpenseStatus` 改為 `status: ReimbursementStatus`
- [x] 5.2 `frontend/src/components/AdminExpenseDetail.vue`：`Expense`／`ExpenseStatus` import、prop `expense: Expense` 改為 `reimbursement: Reimbursement`、內文所有 `expense.xxx` 改為 `reimbursement.xxx`；檔名不動（見 design Decision 4）

## 6. 前台 Views

- [x] 6.1 `frontend/src/views/front/HomeView.vue`：`useExpenseStore` → `useReimbursementStore`；`Expense`／`ExpenseStatus` type import 改名；區域變數 `expenses` 改為 `reimbursements`
- [x] 6.2 `frontend/src/views/front/HistoryView.vue`：`useExpenseStore` → `useReimbursementStore`；`Expense`／`ExpenseStatus` type import 改名；區域變數 `expenses` 改為 `reimbursements`
- [x] 6.3 `frontend/src/views/front/ExpenseFormView.vue`：`useExpenseStore` → `useReimbursementStore`；action 呼叫（`addExpense`／`updateDraft`）對應 `addReimbursement`／`updateDraft`；type import 改名；檔名保留（見 design Decision 4）
- [x] 6.4 `frontend/src/views/front/ExpenseDetailView.vue`：`useExpenseStore` → `useReimbursementStore`；action 呼叫改名（`removeExpense` → `removeReimbursement`、`withdrawToDraft` 保留）；type import 改名；檔名保留

## 7. 後台 Views

- [x] 7.1 `frontend/src/views/admin/DashboardView.vue`：store 引用改為 `useReimbursementStore`；`Expense`／`ExpenseStatus` type import 改名；區域變數 `expenses` 改為 `reimbursements`
- [x] 7.2 `frontend/src/views/admin/RecordsView.vue`：同上，包括 `<template>` 內 `Expense` type 標註（`data as Expense` → `data as Reimbursement`）；`selected.value = data as Expense` 相關全部改名；標題 `PageHeader title="請款記錄"` 不動；`AdminExpenseDetail :expense="selected"` prop 改為 `:reimbursement="selected"`
- [x] 7.3 `frontend/src/views/admin/ReviewView.vue`：同 7.2 規則
- [x] 7.4 `frontend/src/views/admin/PayoutView.vue`：同 7.2 規則；action 呼叫 `markPaid`／`revertPaid`／`voidExpense` → `voidReimbursement`

## 8. Layout / Router

- [x] 8.1 `frontend/src/layouts/AdminLayout.vue`：若 script 有 import expense store／type，跟著改名（UI 中文字不動）
- [x] 8.2 `frontend/src/router/index.ts`：`views/admin/ExpensesView.vue` import 路徑不動（那是新頁的 stub，語意是「支出」不是「請款」）；只調整 `.expense`／`.expenses` 若出現在此檔案的動態 import／註解；route name `admin-records`／`admin-review`／`admin-payout`／`front-history` 保留不動

## 9. 驗收

- [x] 9.1 全 codebase `grep -rn "useExpenseStore\|from '@/stores/expenses'\|from '@/mocks/expenses.json'" frontend/src` 結果為空
- [x] 9.2 全 codebase `grep -rn ": Expense\b\|: ExpenseStatus\b\|<Expense>\|Expense\\[\\]" frontend/src`（不含 `ExpenseCategory`、`ExpenseFormView`、`ExpenseDetailView`、`ExpensesView`、`AdminExpenseDetail`、`quickey.expense-tool` 這類殘留檔名／product name）結果為空
- [x] 9.3 `pnpm --dir frontend build` 通過（TS 無錯、Vite 無錯）
- [x] 9.4 人工 QA checklist：
  - [ ] 前台以 `ming@example.com` 登入 → 首頁「我的請款」統計數字與 rename 前一致（或 seed 重載後為 seed 的值）
  - [ ] 前台「我的請款」列表顯示所有 seed 請款
  - [ ] 前台「新增請款」表單可送出 → 記錄出現在列表
  - [ ] 前台請款詳情頁能開啟；draft 可編輯／可刪除；rejected 可重送
  - [ ] 後台以 `admin@example.com` 登入 → Dashboard 顯示的數字正常
  - [ ] 後台「請款記錄」列表可篩選、可點開詳情 dialog
  - [ ] 後台「簽核」列表可 approve／reject
  - [ ] 後台「發放」可標記 paid、可 revert paid
  - [ ] 任何頁面文字都仍是「請款／請款記錄／新增請款」等中文；沒有出現「代墊款」或英文 `Reimbursement`

## 10. Archive

- [x] 10.1 `pnpm --dir frontend build` 再跑一次確認 OK
- [ ] 10.2 `openspec archive refactor-rename-expense-to-reimbursement` 讓 change 進入 archive
