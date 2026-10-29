## 1. 前置

- [x] 1.1 `pnpm add driver.js`（已於 change 提出時完成，1.8.0 已寫入 `frontend/package.json`）

## 2. Onboarding store

- [x] 2.1 新增 `frontend/src/stores/onboarding.ts`：`useOnboardingStore`；STORAGE_KEY `quickey.onboarding.v1`；`completedUserIds: string[]`；load 時 normalize（非陣列 → 空陣列，見 Decision 3）
- [x] 2.2 `watch(completedUserIds, deep, save)`；`try/catch` 包 setItem 以容 localStorage 不可用（見 Decision 3 fallback）
- [x] 2.3 query `isCompletedFor(userId: string): boolean`（`arr.includes`）
- [x] 2.4 action `markCompletedFor(userId: string)`：若不在陣列則 push；已在就 no-op
- [x] 2.5 action `reset(userId: string)`：從陣列移除；找不到就 no-op（供「重跑導覽」使用）
- [x] 2.6 全檔 JSDoc 引用 design.md Decision 2 / 3

## 3. 目標元素標記

- [x] 3.1 `views/admin/DashboardView.vue`：於 `<PageHeader ... />` 外層 wrapper 加 `data-tour="dashboard-welcome"`
- [x] 3.2 `views/admin/ExpensesView.vue`：於「新增支出」按鈕加 `data-tour="expenses-new-button"`
- [x] 3.3 `views/admin/RecordsView.vue`：於主 DataTable 容器加 `data-tour="records-table"`
- [x] 3.4 `views/admin/ReviewView.vue`：於待簽核清單容器加 `data-tour="review-queue"`
- [x] 3.5 `views/admin/PayoutView.vue`：於待發放清單容器加 `data-tour="payout-list"`
- [x] 3.6 `views/admin/CategoriesView.vue`：於「新增類別」按鈕加 `data-tour="categories-add-button"`
- [x] 3.7 `views/admin/BudgetsView.vue`：於預算表格加 `data-tour="budgets-table"`
- [x] 3.8 `views/admin/UsersView.vue`：於「邀請員工」按鈕加 `data-tour="users-invite-button"`
- [x] 3.9 `views/front/HomeView.vue`：於 welcome / KPI 區加 `data-tour="home-welcome"`
- [x] 3.10 `views/front/ExpenseFormView.vue`：於表單容器加 `data-tour="new-form"`
- [x] 3.11 `views/front/HistoryView.vue`：於 DataTable 加 `data-tour="history-table"`

## 4. useOnboardingTour composable

- [x] 4.1 新增 `frontend/src/composables/useOnboardingTour.ts`；import `driver` from `driver.js` 與 CSS `import 'driver.js/dist/driver.css'`
- [x] 4.2 定義兩個常數：`ADMIN_STEPS: TourStep[]`（8 步，依 spec Requirement 2 admin 表格）、`EMPLOYEE_STEPS: TourStep[]`（3 步，依 spec Requirement 2 employee 表格）；`useOnboardingTour()` 內依 `auth.role` 選擇對應 steps（見 Decision 11）
- [x] 4.3 module-scope 存 `driverInstance: DriverInstance | null`（見 Decision 9）
- [x] 4.4 `useOnboardingTour()` factory：inject `useRouter`、`useAuthStore`、`useOnboardingStore`；return `{ startTour }`
- [x] 4.5 `startTour()`：若已有 instance 先 `destroy`；new `driver({ steps, showProgress: true, allowClose: true, onDestroyed })`；呼叫 `driverInstance.drive()`
- [x] 4.6 `onDestroyed` hook：若 `auth.currentUser` 存在，`onboarding.markCompletedFor(currentUser.id)`（正常結束、X 關閉、Esc 都走這裡，見 Decision 9）
- [x] 4.7 每步 `onNextClick` hook：先 `await router.push({ name: nextStep.routeName })` → `await waitForSelector(nextStep.selector, 500)` → 若 target 找到則 `target.scrollIntoView({ block: 'center', behavior: 'smooth' })` + `await new Promise(r => setTimeout(r, 300))` → `driverInstance.moveNext()`；若 target 找不到則以 `element: undefined`（center fallback）方式 moveNext（見 Decision 5 / 7 / 12）
- [x] 4.8 `waitForSelector(selector, timeout)` helper：polling 每 50ms 一次 `document.querySelector`，逾時 return null
- [x] 4.9 全檔 JSDoc 引用 design.md Decision 4 / 5 / 7 / 9 / 11 / 12
- [x] 4.10 driver 初始化 options 加 `popoverClass: 'quickey-tour-popover'`、每步 step 一律 `side: 'auto'`（見 Decision 6）

## 5. 首頁自動觸發

- [x] 5.1 `views/admin/DashboardView.vue` `<script setup>`：import `useOnboardingTour`、`useOnboardingStore`、`useAuthStore`
- [x] 5.2 `onMounted` 內：若 `auth.role === 'admin'` 且 `auth.currentUser` 存在且 `onboarding.isCompletedFor(currentUser.id) === false` → `await nextTick()` → `startTour()`
- [x] 5.3 確認觸發條件不會因 dashboard 內部 `computed` 重算而重複觸發（`onMounted` 只跑一次即可）
- [x] 5.4 `views/front/HomeView.vue` `<script setup>`：對稱加相同觸發邏輯，條件改為 `auth.role === 'employee'`

## 6. Layout 使用者選單

- [x] 6.1 `layouts/AdminLayout.vue`：import `useOnboardingTour`、`useOnboardingStore`（`useAuthStore` 已 import）
- [x] 6.2 `userMenuItems` computed 內於「修改密碼」上方插入新項目：`{ label: '新手導覽', icon: 'pi pi-compass', command: () => { ... } }`
- [x] 6.3 command 內容：`if (!auth.currentUser) return; onboarding.reset(auth.currentUser.id); router.push({ name: 'admin-dashboard' })`（見 Decision 8）
- [x] 6.4 若使用者已在 `admin-dashboard` 頁點擊，`router.push` 是 no-op — 需額外於 command 內呼叫 `startTour()` 以確保無 route 變更也能重跑（或改為 `router.replace` + query 觸發 watcher，任選其一實作）
- [x] 6.5 `layouts/FrontLayout.vue`：對稱 import 相同 store / composable
- [x] 6.6 `userMenuItems` computed 內於「修改密碼」上方插入「新手導覽」項目（同樣 icon / label）
- [x] 6.7 command 內容：同 6.3，但 `router.push({ name: 'front-home' })`
- [x] 6.8 若使用者已在 `front-home` 頁點擊，同 6.4 fallback 處理

## 7. Tour 樣式覆寫

- [x] 7.1 `frontend/src/styles/index.css`：於檔案底部加 `.driver-popover` selector 覆寫背景、border-radius (`--radius-lg`)、box-shadow、padding
- [x] 7.2 覆寫 `.driver-popover-next-btn`、`.driver-popover-close-btn` 使用 Trust Blue tokens（`--color-primary-500` 主色）
- [x] 7.3 檢查 focus outline 未被 `outline: none` 蓋掉（見 spec Requirement 7 鍵盤導航 scenario）
- [x] 7.4 `@media (max-width: 639.98px)` 內 `.driver-popover` `max-width: 320px`、`padding` 縮減、字級 ≤ 14px；`.driver-popover-navigation-btns` 加 `padding-bottom: env(safe-area-inset-bottom)`（見 Decision 6）

## 8. QA checklist

- [x] 8.1 新增 `docs/QA_list/QA_新手導覽.md`，涵蓋章節：
  - 1. 首次觸發（全新 admin 登入自動彈 admin tour / 全新 employee 登入自動彈 employee tour / 已完成的使用者不再觸發）
  - 2. Admin 8 步流轉（每步標題、target 是否正確被打亮、下一步導頁順利）
  - 3. Employee 3 步流轉（每步標題、target、下一步導頁）
  - 4. 隨時關閉（X / Esc 都能結束；關閉後重整不再觸發）
  - 5. 重跑導覽（AdminLayout 使用者選單有「新手導覽」/ FrontLayout 也有 / 點擊後從第 1 步重跑 / 從非首頁點擊也能觸發）
  - 6. Per-user 隔離（A 完成 / B 登入仍會觸發 / admin 與 employee 完成狀態互不干擾）
  - 7. 損毀資料容錯（手動改壞 localStorage 不會白畫面）
  - 8. 桌機（1440px）：admin 8 步 + employee 3 步逐一驗收 tooltip 定位、target 打亮
  - 9. 手機（375px）：admin 8 步 + employee 3 步逐一驗收 target 被 scroll 至中央、tooltip 完整顯示、未被視窗邊緣截切、未擋住 iOS 主頁指示器
  - 10. 樣式（tooltip 圓角與主題色一致 / 鍵盤 focus outline 可見 / 螢幕閱讀器可讀 / 手機字級 ≤ 14px）

## 9. 進度文件同步

- [x] 9.1 `docs/實作流程.md` §三 進度表 Phase 6 「Onboarding 精靈」列狀態改 ✅（附今日日期 2026-09-21）

## 10. 手動驗收

- [x] 10.1 `pnpm build` 通過 TypeScript 型別檢查
- [ ] 10.2 `pnpm dev`：以 `admin@example.com` 登入 → 首次自動彈 admin tour → 依 `QA_新手導覽.md` 逐條核對
- [ ] 10.3 `pnpm dev`：以 `ming@example.com` 登入前台 → 首次自動彈 employee tour → 依 QA 逐條核對
- [ ] 10.4 開新 incognito 分頁測試 per-user 隔離（A 已完成、B 未完成）
- [ ] 10.5 手機模擬（Chrome DevTools 375px）跑完 admin 11 步 + employee 4 步；若手邊有 iOS 裝置以真實 Safari 再走一次

## 11. Follow-ups（依實作與 QA 回饋收斂）

### 11.1 步驟重排

- [x] 11.1.1 admin 首步從「儀表板歡迎」改為「新增支出按鈕」（歡迎詞併入第 1 步描述）
- [x] 11.1.2 admin 尾步（儀表板）改到第 10 位，收尾整體 KPI + 圖表
- [x] 11.1.3 employee 首步從「首頁 KPI」改為「新增代墊款圖片上傳區」（歡迎詞併入第 1 步描述）
- [x] 11.1.4 employee 尾步（首頁一覽）改到第 3 位

### 11.2 新增「新手導覽」入口導覽步驟（admin 第 11 步 / employee 第 4 步）

- [x] 11.2.1 `stores/onboarding.ts`：新增 `userMenuOpen: ref<boolean>` state + `setUserMenuOpen(open)` action（純 UI 暫態,不進 localStorage）
- [x] 11.2.2 `components/UserBadge.vue`：`watch(onboarding.userMenuOpen)` → 為 true 時 dispatch click 到 trigger button 打開 popup、為 false 時 `menuRef.hide()`；trigger button 加 `ref` + `data-tour="user-menu-trigger"`
- [x] 11.2.3 `layouts/AdminLayout.vue` + `layouts/FrontLayout.vue`：`userMenuItems` 的「新手導覽」項目加 `class: 'tour-onboarding-item'`（PrimeVue Menu 會套到對應 `<li>`）
- [x] 11.2.4 `useOnboardingTour.ts`：`TourStep` 新增 `preAction?: () => void | Promise<void>`
- [x] 11.2.5 `transitionToStep` 在切 route 之後、`waitForSelector` 之前呼叫 `preAction`（await 若回傳 Promise）
- [x] 11.2.6 `ADMIN_STEPS` 追加第 11 步：`routeName: 'admin-dashboard'` + `selector: '.tour-onboarding-item'` + `preAction: () => useOnboardingStore().setUserMenuOpen(true)`
- [x] 11.2.7 `EMPLOYEE_STEPS` 追加第 4 步：`routeName: 'front-home'` + 同上
- [x] 11.2.8 `onPrevClick`：若當前步有 `preAction`,先呼叫 `onboarding.setUserMenuOpen(false)` 再退,避免 popup 卡在畫面上蓋住上一步 target
- [x] 11.2.9 `onDestroyed`：一併呼叫 `onboarding.setUserMenuOpen(false)` 讓「結束導覽」與「完成」都會關掉 popup
- [x] 11.2.10 z-index 策略：不特別提升 menu overlay z-index,讓 driver.js 遮罩(~10000)自然蓋過 PrimeVue Menu popup(~1000),透過 SVG 挖空效果只讓「新手導覽」項目被打亮,其他 menu item 一同 dim
- [x] 11.2.11 更新 admin 第 1 步描述「接下來 X 步」數字：10 → 11
- [x] 11.2.12 更新 employee 第 1 步描述「接下來 X 步」數字：3 → 4

### 11.3 QA 反饋修正

- [x] 11.3.1 admin 第 2 步(填寫支出內容)：`data-tour` 從整個 `<form>` 改到僅 `<div v-if="!fromImport">`(憑證上傳區),讓 highlight 範圍精準
- [x] 11.3.2 employee 第 1 步(新增代墊款)：`data-tour="new-form"` 從 `<form>` 拿掉,改到 `<div id="field-receipts">` 並改名為 `expense-upload-area`,聚焦圖片上傳而非整張表單
- [x] 11.3.3 admin 第 8 步(建立第一筆預算)：`data-tour="budgets-page"` 從內層表格 wrapper 移到最外層容器,PageHeader 標題不被 highlight 切掉；步驟設 `scrollBlock: 'start'`
- [x] 11.3.4 admin 第 10 步(儀表板)：`data-tour="dashboard-overview"` 移到最外層容器,涵蓋 KPI + 圖表；步驟設 `scrollBlock: 'start'`,避免 KPI 卡片頂部被切
- [x] 11.3.5 employee 第 1 步：`scrollBlock` 從 `'start'` 改為 `'nearest'`,避免頁面往下捲讓 PageHeader 消失
- [x] 11.3.6 admin 第 5、6 步(簽核／發放)：wrapper class 從 `overflow-hidden` 改為 `overflow-x-auto`,手機／平板下可水平捲動看到右側行動按鈕
- [x] 11.3.7 `useOnboardingTour.ts` 新增 `scrollToRight?: boolean` step 屬性 + `scrollTargetToRight()` helper：viewport < 1024px 時 smooth-scroll target 到最右；於 `transitionToStep` 內與 vertical scroll 同步觸發,避免延遲

### 11.4 Race condition 修正

- [x] 11.4.1 `useOnboardingTour.ts` export `isActive()` 判斷 driver 實例是否存在
- [x] 11.4.2 `views/admin/DashboardView.vue` `onMounted` 加 `if (isActive()) return`,避免尾步導回 dashboard remount 時再次觸發 startTour(會造成兩層遮罩 + 兩張 popover)
- [x] 11.4.3 `views/front/HomeView.vue` `onMounted` 加同樣 `isActive()` guard(尾步導回首頁時 remount)
- [x] 11.4.4 `onPrevClick` 補上與 `onNextClick` 對稱的 route + waitForSelector 邏輯,避免退回上一步時 fallback 到中央 tooltip 且無 highlight
