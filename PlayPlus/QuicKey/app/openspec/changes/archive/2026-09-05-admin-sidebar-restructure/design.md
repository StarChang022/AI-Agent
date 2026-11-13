## Context

現有 `frontend/src/layouts/AdminLayout.vue` 用一個 flat `allNavItems` 陣列渲染 sidebar，透過 `computed` + `allowedRoles` 過濾。此 change 需要引入**分組**這個新概念，同時加上滿版寬 mobile drawer；架構層面有多個決策點值得先寫下來。

**權威來源**：sidebar 結構嚴格對齊 `docs/sitemap.md` 內「模組」欄位（僅列非「後續擴充」的模組），以及 `docs/產品規格文件.md` 第 4 節功能範圍。

參考點：
- 現有 `AdminLayout.vue` — 起點
- `design.md` — Trust Blue tokens、utility class
- `dev-style.md` — 樣式三層架構、手機版 14px 限制

## Goals / Non-Goals

**Goals:**
- 讓「加一個 nav 分組」「加一個 nav 項目」在 code 上是**改資料結構**，不用改 template
- Sidebar 結構直接對應 sitemap 模組，將來 sitemap 有異動時同步窗口清楚
- Mobile drawer 用最少 state 表達（單一 `isOpen` ref），不引入新的 store

**Non-Goals:**
- 不做 sidebar 收合 / 展開 sub-menu（分組永遠展開）
- 不做 sidebar 在桌機的 collapsed-icon-only 狀態
- 不做「即將開放」badge（sidebar 不放遠期功能，所以不需要這個視覺 hint）
- 不改變 role 過濾的既有語意（只是把過濾規則從 flat list 改到 grouped list）
- 不做付費等級 feature gating（PRD 6.5 待定）

## Decisions

### Decision 1：Nav 資料結構用 groups + items 巢狀陣列

**選擇**：把 `allNavItems: NavItem[]` 改成 `navGroups: NavGroup[]`，每個 group 有 `label`、`items: NavItem[]`。

```ts
interface NavItem {
  label: string
  icon: string                  // PrimeIcons class, e.g. 'pi-th-large'
  to: { name: string }          // 所有 item 都可點（無 comingSoon）
  allowedRoles?: Role[]
}
interface NavGroup {
  label: string                 // 分組標題
  items: NavItem[]
}
```

**理由**：sidebar 現在有分組概念，若仍是 flat 就得靠 divider item 混在同一陣列，可讀性差。巢狀結構讓 role 過濾在 group 層面做 `items.length === 0` 隱藏整組成為可能（雖然目前 role 過濾後兩個 group 都還有 items，未來新增分組時有備援）。

### Decision 2：Sidebar 內容一律可點；「後續擴充」模組完全不出現

**選擇**：不做「即將開放」的視覺 hint 或 disabled item。凡 sidebar 出現的項目 MUST 都是可點的實作頁面（或 stub 頁面 = 已註冊 route + empty state）。「後續擴充」的模組（部門管理、報表、設定、專案管理…）根本不放 sidebar。

**理由**：
- Sitemap 已明確劃分「現階段」與「後續擴充」，sidebar 直接鏡射「現階段」即可
- 「即將開放」badge 是 marketing hint，適合放 landing page，不放 sidebar 內
- 減少視覺雜訊，客戶看到的每個項目都能點

**替代方案**（淘汰）：
- 全部放 sidebar，未實作的加 disabled → 淘汰，違反上述原則
- 未實作的隱藏、實作完再加 → 淘汰，因為此 change 就是要把 sitemap 結構落地讓客戶看到，stub 頁做為 placeholder 是必要的

### Decision 3：Mobile drawer 滿版寬 + 單一 `isOpen` ref

**選擇**：`AdminLayout.vue` 內 `const isMobileOpen = ref(false)`，`watch(route, () => { isMobileOpen.value = false })`。手機版 sidebar 用 `w-full`（滿版），從左側 `translate-x` 滑入。桌機版維持 `w-56` 固定。

**理由**：
- **滿版寬**符合使用者要求，也是移動 UX 常見選擇（減少「按半天沒按到」的挫敗感）
- 滿版時**不需要遮罩**（drawer 就是全螢幕），簡化實作
- Drawer 右上角需要**顯式關閉按鈕**（`pi pi-times`），因為沒有遮罩可點
- Route 變動自動關閉：用 `watch(useRoute())` 一行搞定

**手機版斷點**：延用 `dev-style.md` 的 `max-width: 639.98px`（Tailwind 的 `sm:` 對應 `≥ 640px`）。

**替代方案**（淘汰）：
- 部分寬度 drawer + 半透明遮罩 → 淘汰，使用者明確要求滿版
- Pinia store 管理 `isOpen` → 淘汰，overkill

### Decision 4：Stub 頁面用共用元件 `EmptyState`

**選擇**：`ExpensesView.vue`、`CategoriesView.vue`、`BudgetsView.vue` 內容只 render `<PageHeader>` + `<EmptyState>`，文案「本模組開發中，敬請期待」，圖示對應各自模組。

**理由**：既有 `frontend/src/components/EmptyState.vue` 已有這種 pattern。stub 頁不應該 hardcode 樣式。此 change 只做 sidebar → stub 頁跳轉，實際功能各自另開 change（例：`admin-expenses-list`、`admin-categories-crud`、`admin-budgets`）。

### Decision 5：Sidebar 結構最終定案

```
[主選單] — 日常操作與監控
  - 儀表板         → admin-dashboard      (既有)
  - 支出列表       → admin-expenses       (stub - 待另 change 實作)

[請款] — 代墊款流程
  - 請款記錄       → admin-records        (既有)
  - 簽核           → admin-review         (既有)
  - 發放           → admin-payout         (既有, finance/admin)

[系統] — 組態與管理
  - 費用類別       → admin-categories     (stub - 待另 change 實作)
  - 類別預算       → admin-budgets        (stub - 待另 change 實作)
  - 員工管理       → admin-users          (既有, admin only)
```

**分組理由**：
- **主選單**：使用者每天登入第一眼會看的東西（儀表板監控、支出登錄）
- **請款**：代墊款是一條獨立流程，狀態機、待辦清單、操作對象都跟一般支出不同，獨立分組讓資訊架構清楚
- **系統**：設定一次或定期維護的組態面（類別/預算/員工），跟日常操作分開，避免主選單被組態項目稀釋

**PrimeIcons 對應**（決定圖示以避免 apply 時再猶豫）：

| Item | Icon |
|---|---|
| 儀表板 | `pi-th-large` |
| 支出列表 | `pi-file` |
| 費用類別 | `pi-tag` |
| 類別預算 | `pi-chart-line` |
| 員工管理 | `pi-users` |
| 請款記錄 | `pi-list` |
| 簽核 | `pi-check-square` |
| 發放 | `pi-send` |

### Decision 6：AppHeader 加 `#left` slot 供 hamburger 使用

**選擇**：在 `components/AppHeader.vue` 現有的 `#nav` / `#right` 之外，新增一個 `#left` slot，位於 logo 之前。AdminLayout 在此 slot 塞入 hamburger 按鈕（只在 `sm:hidden` 顯示）。

**理由**：現有 AppHeader 兩個 slot 都不適合放 hamburger（`#nav` 是桌機 nav，`#right` 是使用者選單）。加一個新的 slot 對其他 layout 完全無影響（沒填就沒東西）。

**替代方案**（淘汰）：
- 在 AdminLayout 內自己重建 header → 淘汰，會複製 AppHeader 的樣式邏輯
- 用 `provide/inject` 讓 header 感知 hamburger 狀態 → 淘汰，過度耦合

## Risks / Trade-offs

- **Risk**: Mobile drawer 全螢幕覆蓋，若使用者不知道右上角有關閉按鈕會找不到出口 → **Mitigation**: 關閉按鈕用明顯的 `pi pi-times` 圖示 + 較大的觸控範圍（min 44×44px），且 route 變動會自動關閉，所以只要點任何 nav item 也能出去
- **Risk**: Stub 頁面若沒有清楚文案，使用者以為系統壞了 → **Mitigation**: 文案「本模組開發中，敬請期待」，並考慮加預計上線日期（例：「預計 2026 Q4 上線」）— 但實際文字待 PM/行銷定案，此 change 先寫佔位版
- **Risk**: role 過濾邏輯搬到巢狀結構後可能漏過濾 → **Mitigation**: template 用 computed `visibleGroups`，group.items 過濾後為空的 group 隱藏
- **Trade-off**: 分 3 組（2/3/3 = 8 item）而非平鋪，是為了讓「日常操作 / 代墊款流程 / 系統組態」在資訊架構上明確分開；使用者第一次進入時能快速理解「主選單看數字、請款是我要走的流程、系統是設定的地方」
- **Note**: 「類別預算」歸「系統」而非「主選單」，係將其視為「設定一次後定期調整」的組態（設定各類別的上限）。若未來 UX 觀察到使用者更頻繁把它當作日常監控用（例：每天檢查是否超支），再考慮挪回主選單或另做「預算概況」dashboard 卡片。

## Migration Plan

此 change 不涉及資料遷移或使用者狀態，屬純 UI/router 結構調整：

1. 開發前：確認 `chore/rebrand-quickey` branch 是乾淨的（`git status` 只有未追蹤 `.claude/` `openspec/`）
2. 新增 3 個 stub view 檔（`ExpensesView.vue`、`CategoriesView.vue`、`BudgetsView.vue`）
3. 修改 router（新增 3 個 stub route）
4. 修改 `AppHeader.vue`（加 `#left` slot）
5. 改寫 `AdminLayout.vue`（sidebar 資料結構 + drawer）
6. `pnpm build` 通過
7. 依 tasks.md 的 QA checklist 人工驗收
8. `openspec archive admin-sidebar-restructure`

Rollback：直接 `git checkout` 覆蓋這些檔案即可，無 DB / localStorage migration。
