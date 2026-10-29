## Why

Quickey 目前後台功能已涵蓋支出、代墊款、類別、預算、員工邀請（Phase 1～5 均完成 ✅），但 admin 首次登入後直接看到儀表板的空狀態，沒有任何線索告訴他「該從哪裡開始使用」——多個模組彼此有工作流關係（登錄支出 → 填寫表單 → 列表確認 → 記錄 → 簽核 → 發放 → 類別 → 預算 → 員工邀請），若不主動引導，早期客戶會卡在 dashboard 不知所措，直接影響試用轉化率。員工前台雖流程單純，仍需一次性引導確認送出請款的入口與追蹤位置，避免員工誤以為「送出後沒下文」而重複提交或改走 email。此 change 對應 `docs/實作流程.md` §五 Phase 6「Onboarding 精靈」，以 driver.js overlay tour 帶 admin 走過 10 步核心流程、員工走過 3 步核心流程，每一步在真實頁面上打亮對應的 UI 元素（桌機同時打亮左側 sidebar 對應項）、tooltip 講解該功能作用；完成或跳過後將 flag 存 localStorage，之後不再自動觸發，但保留「重跑導覽」入口供任何時候重看。

## What Changes

### 主線：Onboarding overlay tour（admin + employee）

- **導入 `driver.js` 套件**（已於本次一併 `pnpm add driver.js`，1.8.0，MIT，~10KB gzipped）：用途為 overlay + spotlight + tooltip；已完成安裝，故 tasks 內不再重複標記
- **新增 `stores/onboarding.ts`**：獨立 store 管理 `completedUserIds: string[]`（存 localStorage `quickey.onboarding.v1`）、`isCompletedFor(userId)`、`markCompletedFor(userId)`、`reset(userId)`；per-user 儲存避免多帳號共用瀏覽器時互相干擾
- **新增 `composables/useOnboardingTour.ts`**：封裝 driver.js 實例；export `startTour()`；內部依 `auth.role` 動態選 steps（`ADMIN_STEPS` 10 步 / `EMPLOYEE_STEPS` 3 步），每步含 `routeName`、`selector`（`[data-tour="xxx"]`）、`title`、`description`、可選 `sidebarRouteName`（深頁面明填以指向 parent sidebar 項）；`onNextClick` hook 內 `router.push(nextStep.routeName)` + polling 等 target 出現（500ms timeout）+ `target.scrollIntoView({ block: 'center', behavior: 'smooth' })` + 300ms 等 scroll 完成 + `driver.moveNext()`；`onHighlightStarted` hook 於每步進入時打亮 sidebar 對應 nav item（透過 `.tour-nav-active` CSS class）；`onDestroyed` hook 清 sidebar highlight + `onboarding.markCompletedFor(currentUser.id)`；tooltip 不設 `side` 讓函式庫依 viewport 自動選方向
- **在 13 個目標 UI 元素上加 `data-tour` attribute**（跨頁 selector 契約）：
  - **後台 admin（10 步）**：
    - `data-tour="dashboard-welcome"` → DashboardView PageHeader（step 1 welcome）
    - `data-tour="expenses-new-button"` → ExpensesView 的「新增支出」按鈕（step 2）
    - `data-tour="expense-new-form"` → admin ExpenseFormView 的表單容器（step 3，深頁）
    - `data-tour="expenses-table"` → ExpensesView 的支出 DataTable（step 4）
    - `data-tour="records-table"` → RecordsView 的 DataTable（step 5）
    - `data-tour="review-queue"` → ReviewView 的簽核清單容器（step 6）
    - `data-tour="payout-list"` → PayoutView 的發放清單容器（step 7）
    - `data-tour="categories-add-button"` → CategoriesView 的「新增類別」按鈕（step 8）
    - `data-tour="budgets-table"` → BudgetsView 的預算表格（step 9）
    - `data-tour="users-invite-button"` → UsersView 的「邀請員工」按鈕（step 10）
  - **前台 employee（3 步）**：
    - `data-tour="home-welcome"` → HomeView 主 KPI 區（step 1 welcome）
    - `data-tour="new-form"` → ExpenseFormView 表單容器（step 2）
    - `data-tour="history-table"` → HistoryView DataTable（step 3）
- **AdminLayout sidebar 每個 nav item 加 `data-tour-nav="<route-name>"`**：供 composable 於每步 lookup 對應項；打亮效果透過 `styles/index.css` 內 `.tour-nav-active` class（primary 底色 + 邊框），z-index 高於 driver overlay 讓 sidebar 浮在遮罩上
- **`views/admin/DashboardView.vue` onMounted hook**：若 `auth.role === 'admin'` 且 `onboarding.isCompletedFor(auth.currentUser.id) === false` 則呼叫 `startTour()`；用 `nextTick` 等 DOM 準備好再啟動
- **`views/front/HomeView.vue` onMounted hook**：若 `auth.role === 'employee'` 且未完成 → 相同觸發邏輯
- **`layouts/AdminLayout.vue` 使用者選單加「新手導覽」項目**：位於「修改密碼」上方，icon `pi pi-compass`；command 內 `onboarding.reset(userId)` + `router.push({ name: 'admin-dashboard' })`
- **`layouts/FrontLayout.vue` 使用者選單加「新手導覽」項目**：結構與 AdminLayout 對稱；command 內 `onboarding.reset(userId)` + `router.push({ name: 'front-home' })`
- **新增 `docs/QA_list/QA_新手導覽.md`**：使用者視角驗收清單，涵蓋首次觸發、admin 8 步 + employee 3 步流轉、每步 X 結束、admin/employee 重跑入口、跨帳號隔離、桌機與手機（375px）分別驗收
- **同步 `docs/實作流程.md`**：§三 Phase 6 「Onboarding 精靈」列狀態改 ✅（附今日日期 2026-09-21）

### Non-goals（明確不做）

- **多語系**：tour 內文案硬編中文，MVP 不做 i18n
- **進度中斷續跑**：離開瀏覽器 tab 或重整不記得跑到第幾步；下次仍需從頭重跑（onboardingCompleted 是 boolean，不是 step index）
- **步驟自訂/客戶端可調**：admin 8 步 + employee 3 步順序寫死於 composable，客戶不能改
- **實際互動要求**（例如「必須真的新增一筆支出才能進下一步」）：所有步驟都是資訊性 tooltip，「下一步」不驗證使用者是否做了任何動作
- **Analytics 追蹤**（哪步跳出、完成率）：MVP 不接分析，後端接完再加
- **Tour 步驟依實際資料狀態動態調整**（例如「已有支出時跳過建立支出步驟」）：無條件走完全部步驟

## Capabilities

### New Capabilities

- `onboarding-wizard`：使用者首次登入時依角色觸發對應 overlay tour（admin 8 步 / employee 3 步）、以及事後可透過使用者選單重跑導覽的能力；桌機與手機皆為 first-class 支援

### Modified Capabilities

（無：admin-navigation 只是新增選單項目、屬 UI 增補而非既有 requirement 變更；不動 spec）

## Impact

- **前端 code**：
  - 新檔：`frontend/src/stores/onboarding.ts`、`frontend/src/composables/useOnboardingTour.ts`、`docs/QA_list/QA_新手導覽.md`
  - 修改（後台 admin）：`frontend/src/views/admin/DashboardView.vue`（onMounted 觸發 + `data-tour="dashboard-welcome"`）、`frontend/src/views/admin/ExpensesView.vue`（`data-tour="expenses-new-button"`）、`frontend/src/views/admin/RecordsView.vue`（`data-tour="records-table"`）、`frontend/src/views/admin/ReviewView.vue`（`data-tour="review-queue"`）、`frontend/src/views/admin/PayoutView.vue`（`data-tour="payout-list"`）、`frontend/src/views/admin/CategoriesView.vue`（`data-tour="categories-add-button"`）、`frontend/src/views/admin/BudgetsView.vue`（`data-tour="budgets-table"`）、`frontend/src/views/admin/UsersView.vue`（`data-tour="users-invite-button"`）、`frontend/src/layouts/AdminLayout.vue`（使用者選單加「新手導覽」項目）
  - 修改（前台 employee）：`frontend/src/views/front/HomeView.vue`（onMounted 觸發 + `data-tour="home-welcome"`）、`frontend/src/views/front/ExpenseFormView.vue`（`data-tour="new-form"`）、`frontend/src/views/front/HistoryView.vue`（`data-tour="history-table"`）、`frontend/src/layouts/FrontLayout.vue`（使用者選單加「新手導覽」項目）
  - 修改（樣式）：`frontend/src/styles/index.css`（引入 driver.js 樣式 + 覆寫 popover 風格對齊 Trust Blue tokens；`@media (max-width: 639.98px)` 內 popover `max-width: 320px` + 字級 ≤ 14px + `safe-area-inset-bottom` padding）
  - 依賴：`frontend/package.json` 已加 `driver.js@^1.8.0`
- **對其他 store 的依賴**：`useOnboardingTour` 讀 `auth.currentUser.id` 與 `auth.role`（僅讀，不寫）；`onboarding` store 僅存 completedUserIds，不依賴其他 store
- **無 API 契約**：純前端 UI 行為，無 endpoint；未來後端不需支援
- **資料持久化**：新增 localStorage key `quickey.onboarding.v1`（value: `string[]` of user ids）
- **UI 樣式**：driver.js 預設樣式偏灰藍，需在 `styles/index.css` 內覆寫 popover 背景 / border-radius / 按鈕色以對齊 Trust Blue design tokens；手機視窗尺寸額外覆寫 max-width 與 safe-area padding
- **文件**：`docs/QA_list/QA_新手導覽.md` 為本 change 產出；`docs/實作流程.md` §三 進度表勾選為 ✅
