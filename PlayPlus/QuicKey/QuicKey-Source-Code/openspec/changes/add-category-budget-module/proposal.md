## Why

Phase 1 已建立 `Expense` 主線與統一支出列表，Phase 2 已把費用類別改成 store 管理；但目前 `views/admin/BudgetsView.vue` 仍是空殼（顯示「本模組開發中」）。財務／管理員無法對每個費用類別設定月／年預算、也看不到執行率與是否超支。此 change 對應 `docs/實作流程.md` §五 Phase 3 與 `docs/資料模型.md` §3.5，讓 admin 能為任一使用中類別設月／年預算，並即時看到「該期間內實際支出 / 預算 / 剩餘額度 / 餘額」的狀況與超支提示，同時透過「基本預算」範本 + 一鍵套用降低每月／每年重設的成本。

## What Changes

- **新增 `Budget` 與 `BudgetTemplate` domain model 與相關型別**：
  - Type：`BudgetCycle`（`'month' | 'year'`）、`Budget` interface（含 `id`、`categoryId`、`cycle`、`amount`、`periodStart`、`periodEnd`、`createdAt`、`updatedAt`；唯一約束由 `(categoryId, cycle, periodStart)` 三欄組合決定）、`BudgetTemplate` interface（含 `id`、`categoryId`、`cycle`、`amount`、`createdAt`、`updatedAt`；唯一約束 `(categoryId, cycle)`）
  - Mock：`frontend/src/mocks/budgets.json`（seed 數筆，涵蓋月預算、年預算、正常 / 超支不同狀態）與 `frontend/src/mocks/budget-templates.json`（seed 數筆，每 cycle 2-3 筆代表性類別的基本值）
  - Store：`frontend/src/stores/budgets.ts`（`useBudgetsStore`；預算 action `upsertBudget`（`amount === 0` → 刪除該筆記錄；`amount < 0` → 錯誤）、`removeBudget`、`removeBudgetBy`；範本 action `upsertTemplate`、`removeTemplate`、`findTemplate`、`applyTemplatesToPeriod`；查詢 `findBudget`、`computeUtilization`；STORAGE_KEY `quickey.budgets.v1` 與 `quickey.budget-templates.v1`；export `monthPeriod` / `yearPeriod` 期間 helper 供 view 使用）
- **改寫後台「類別預算」頁**：`frontend/src/views/admin/BudgetsView.vue`
  - 頁面頂端：PrimeVue **SelectButton** 切換「月預算 / 年預算」cycle（切換影響整個頁面的檢視期間單位）；右上角「基本預算設定」按鈕開啟 Dialog 編輯當前 cycle 的 template；右側期間切換器（`< 2026 年 9 月 >` 或 `< 2026 年 >`），並在偏離「今日期間」時顯示「本月 / 本年」快速返回按鈕；期間切換器旁「套用基本預算」按鈕，點擊前需 ConfirmDialog 二次確認（明示會覆寫已編輯金額）
  - 表格列 = **所有使用中類別**（已停用類別不列出）；欄位：類別、預算、實際、**剩餘**（進度條 + %）、**餘額**（金額）
  - 「預算」欄支援 inline 編輯：未設定時顯示「＋ 設定預算」按鈕；已設定時點擊金額進入 InputNumber + 右側 [儲存][取消] icon 按鈕；**Enter=儲存、Esc=取消，blur 不觸發任何動作**（避免誤觸）；儲存時若金額 = 0 → 視為「取消該期間預算」並刪除記錄，回到未設定狀態
  - 「剩餘」欄：進度條 fill 依「剩餘 / 預算」（無支出 = 滿；耗用增加 = 減少；超支 = 空條 + 「超支」Tag）+ 右側百分比 tabular-nums；顏色分段 >20% primary、1-20% warning、≤0% danger；未設預算時進度條為灰底、百分比顯示「—」
  - 「餘額」欄：`預算 − 實際` 之金額；未設預算顯示「—」；正值 primary 色系；負值紅色警示色（前綴 `−` 符號）
  - 手機（<768px）改為卡片式：每張卡片顯示類別名稱、預算 / 實際 / 剩餘進度條 / 餘額；所有操作（inline 編輯、開基本預算 Dialog、套用基本預算）於手機上完整可用
  - **「基本預算設定」Dialog**：依當前檢視 cycle 開啟（月 cycle 開月 template、年 cycle 開年 template）；列出所有使用中類別 + InputNumber 欄位；底部 [儲存][取消] 按鈕；Dialog 內以說明文字強調「儲存基本預算不會自動改動任何月/年預算，需點『套用基本預算』才會套用到當前檢視期間」
- **新增 API 契約**：`frontend/src/api/budgets.ts`（TS-only：`BudgetDTO`、`CreateBudgetRequest`、`UpdateBudgetRequest`、`ListBudgetsQuery`、`DeleteBudgetResponse`、`BudgetTemplateDTO`、`UpsertBudgetTemplateRequest`、`ListBudgetTemplatesQuery`、`ApplyBudgetTemplatesRequest`、`ApplyBudgetTemplatesResponse`）
- **同步文件**：`docs/實作流程.md` §三 進度表中 Phase 3 標記完成；`docs/QA_list/QA_類別預算.md` 依本 change 新增行為（基本預算 / 套用 / 剩餘 / 餘額 / amount=0 取消）補充後續 QA 章節

**Non-goals**（明確不做）：
- 依部門 / 專案分組的預算（現階段不做，見 `docs/資料模型.md` §八）
- 預算超支自動 email 通知（Phase 7 才做 email 記錄）
- 匯入 / 匯出預算
- 拖曳排序類別（沿用 categories store 現有排序）
- 前台員工端可見預算資訊（預算是 admin 內部工具）
- 基本預算自動 materialize 到未來期間（採手動點擊「套用基本預算」，見 design Decision 13）
- 「套用基本預算」的 per-category 選擇性套用（採一次覆寫全部，見 design Decision 14）
- 月 template / 年 template 互相推算或自動同步（12 倍 / 除 12 皆不做，避免多數類別非均勻月分佈造成的誤導）；未來若擴充，走「每 row 一顆『套用至年預算』/『套用至月預算』icon 按鈕、單向、手動、僅寫入另一 cycle template（不影響 Budget 記錄）」形式，NOT 做 live sync

## Capabilities

### New Capabilities

- `category-budgets`：管理員為費用類別設定月／年預算與基本預算範本，並即時查看剩餘額度、餘額與超支狀況的能力。涵蓋 Budget 與 BudgetTemplate 資料模型、CRUD 行為、套用範本流程、期間邏輯、剩餘 / 餘額計算規則、以及 BudgetsView 的呈現與互動。

### Modified Capabilities

（無：admin-navigation 中的「類別預算」項目已存在，本 change 只填實其內容，不改 navigation 行為）

## Impact

- **前端 code**：
  - 新檔：`frontend/src/mocks/budgets.json`、`frontend/src/mocks/budget-templates.json`、`frontend/src/stores/budgets.ts`、`frontend/src/api/budgets.ts`
  - 修改：`frontend/src/types/domain.ts`（新增 `BudgetCycle`、`Budget`、`BudgetTemplate`）、`frontend/src/views/admin/BudgetsView.vue`（改寫）
- **對其他模組的資料依賴**：`budgets` store 於 `computeUtilization` 內呼叫 `useExpenseStore()` 讀取 `expenses` array 加總。無反向依賴（expenses / categories store 不動）；不引入循環相依。
- **對其他模組的 UI 影響**：無。Dashboard 若未來要顯示「本月類別執行率」再另行整合，本 change 不動 Dashboard。
- **API 契約**：新增 `POST /budgets`、`PATCH /budgets/:id`、`DELETE /budgets/:id`、`GET /budgets`；`PUT /budget-templates`（upsert）、`DELETE /budget-templates/:id`、`GET /budget-templates`、`POST /budget-templates/apply`（套用到指定期間）；後端 MVP 不含（Stage B 才實作）。
- **資料持久化**：localStorage key `quickey.budgets.v1` 與 `quickey.budget-templates.v1`；重整頁面 / 關瀏覽器狀態保留。
- **QA**：已有 `docs/QA_list/QA_類別預算.md` 覆蓋 10 節使用者情境，開發完成後依此人工驗收；本 change 新增行為（基本預算 / 套用 / 剩餘 / 餘額 / amount=0 取消）將於實作階段補充該 QA 對應章節。
