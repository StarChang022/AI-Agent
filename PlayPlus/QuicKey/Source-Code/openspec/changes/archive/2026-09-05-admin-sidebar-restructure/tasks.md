## 1. 準備 3 個 stub view

- [x] 1.1 新增 `frontend/src/views/admin/ExpensesView.vue`：`<PageHeader title="支出列表" size="admin" />` + `<EmptyState>`，圖示 `pi-file`，文案「本模組開發中，敬請期待」
- [x] 1.2 新增 `frontend/src/views/admin/CategoriesView.vue`：`<PageHeader title="費用類別" size="admin" />` + `<EmptyState>`，圖示 `pi-tag`，文案同上
- [x] 1.3 新增 `frontend/src/views/admin/BudgetsView.vue`：`<PageHeader title="類別預算" size="admin" />` + `<EmptyState>`，圖示 `pi-chart-line`，文案同上

## 2. Router 註冊 stub 路由

- [x] 2.1 在 `frontend/src/router/index.ts` 的 `/admin` children 陣列，於 `dashboard` 之後、`records` 之前新增:`admin-expenses`（path: `expenses`）、`admin-categories`（path: `categories`）、`admin-budgets`（path: `budgets`）
- [x] 2.2 確認 3 個新路由**不加** `meta.requiredRole`（stub 頁 admin/finance 都可看）
- [x] 2.3 lazy import 對應的 stub view

## 3. AppHeader 加入 `#left` slot

- [x] 3.1 修改 `frontend/src/components/AppHeader.vue`：在 logo `<div>` 之前新增 `<slot name="left" />`（若有 slot 才顯示）
- [x] 3.2 確認既有使用 AppHeader 的地方（FrontLayout、其他 login view）無 `#left` slot 內容時外觀無變動

## 4. AdminLayout sidebar 資料結構

- [x] 4.1 在 `frontend/src/layouts/AdminLayout.vue` 的 `<script setup>` 內宣告 `NavItem`（`label`、`icon`、`to`、`allowedRoles?`）與 `NavGroup`（`label`、`items`）型別
- [x] 4.2 用 3 個 groups 定義 `navGroups`：主選單（2 items）、請款（3 items）、系統（3 items），內容依 design.md Decision 5 表格與 PrimeIcons 對照表填入
- [x] 4.3 新增 `visibleGroups` computed：對每個 group 的 items 套用既有 `allowedRoles` 過濾，並隱藏過濾後 items 為空的 group

## 5. AdminLayout sidebar template（桌機版）

- [x] 5.1 改寫 `<aside>` 內的 `<nav>`：`v-for="group in visibleGroups"` 外層，內含分組標題 `<div>` 與項目 loop
- [x] 5.2 項目 template 用 `<RouterLink>`（沿用既有 `active-class="!bg-primary-50 !text-primary-700 font-medium"`）
- [x] 5.3 分組標題樣式：12px 500 muted 灰、上留白 12px（`mt-3`）、首個 group 不加上留白（採用 `groupIndex === 0` 條件）
- [x] 5.4 桌機 `<aside>` class 保持 `w-56 bg-white border-r border-[var(--color-hairline)]`

## 6. AdminLayout mobile drawer

- [x] 6.1 新增 `isMobileOpen = ref(false)` state
- [x] 6.2 用 `watch(() => route.fullPath, ...)` 讓 route 變動自動關閉 drawer（比 `watch(useRoute())` 精確追蹤路徑）
- [x] 6.3 `<aside>` 用 mobile-first：預設 `fixed inset-0 z-40 w-full transform transition-transform`；桌機用 `sm:static sm:z-auto sm:w-56 sm:transform-none sm:transition-none` 覆寫；依 `isMobileOpen` 加 `translate-x-0` 或 `-translate-x-full`
- [x] 6.4 手機版 drawer 內容頂部加關閉按鈕（`pi pi-times`），觸控範圍 44×44px（`w-11 h-11`）
- [x] 6.5 透過 AppHeader `#left` slot 掛入 hamburger 按鈕：`sm:hidden`、`pi pi-bars`，`@click="isMobileOpen = true"`

## 7. 樣式與細節

- [x] 7.1 分組標題 12px、item label `text-sm`（14px）、關閉/漢堡按鈕僅圖示 — 皆 ≤ 14px
- [x] 7.2 桌機 sidebar 分組標題：`padding: 0 12px`，group 之間 `mt-3`（12px）
- [x] 7.3 分組標題用 `<div class="nav-group-title">`，非 button
- [x] 7.4 `.nav-group-title` 只在 AdminLayout 使用（無其他頁面複用），寫在 `<style scoped>` 而非 promote 為 `@utility`

## 8. 驗收

- [x] 8.1 `pnpm --dir frontend build` 通過（TS + Vite 無錯）
- [x] 8.2 人工 QA checklist（使用者確認完成）：
  - [x] 桌機（≥ 640px）：sidebar 顯示 3 分組（主選單 + 請款 + 系統），順序正確
  - [x] 桌機：以 admin 登入「系統」分組內可看到「員工管理」；以 finance 登入「系統」分組內看不到「員工管理」（但仍看得到費用類別、類別預算）；以 employee 登入被 router guard 導回前台
  - [x] 桌機：以 finance 登入看得到「發放」；以 employee 若強闖 `/admin/*` 被 guard 擋
  - [x] 桌機:點擊 8 個 nav item 導向都正確，active 樣式套用正確
  - [x] 桌機：3 個 stub 頁（支出列表 / 費用類別 / 類別預算）顯示 empty state 與「本模組開發中」文案
  - [x] 桌機：「部門管理」「報表」「設定」「專案管理」等 sidebar 完全沒有
  - [x] 手機（375px viewport）：sidebar 默認收合，hamburger 顯示於 top bar 左側
  - [x] 手機：點擊 hamburger → drawer 滿版寬滑入
  - [x] 手機：drawer 右上角關閉按鈕可關 drawer；drawer 內點 nav item → 導向 + drawer 自動關閉
  - [x] 手機：drawer 內所有文字 ≤ 14px
  - [x] 手機：關閉按鈕觸控範圍 ≥ 44×44px
  - [x] Logout confirm dialog 在 drawer 上方正常顯示（z-index 不衝突）
  - [x] Reload 頁面在任一 sidebar item 都能正常 restore active state

## 9. Archive

- [x] 9.1 `pnpm --dir frontend build` 再跑一次確認 OK
- [ ] 9.2 `openspec archive admin-sidebar-restructure` 讓 delta 併入 `openspec/specs/admin-navigation/`
