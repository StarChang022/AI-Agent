## Why

現有後台 sidebar 是扁平清單（儀表板／請款記錄／簽核／發放／人員管理），無法呈現新 PRD 擴展後的支出管理與預算管理模組，也讓「代墊款」相關的三個頁面在資訊架構上看起來像各自獨立的模組，實際上是同一條流程。

同時 CLAUDE.md 明訂「後台管理頁面必須支援手機瀏覽」，但目前 sidebar 是 `w-56` 固定寬桌機版，手機開後台會被完全遮住。此 change 一併處理。

## What Changes

- **AdminLayout.vue sidebar 重構**：從扁平清單改為 3 個分組（主選單／請款／系統）
- **依 `docs/sitemap.md` 模組結構定義**：sidebar 項目一一對應 sitemap 內「模組」欄位，且僅列**現階段要實作**的（PRD 4 + sitemap 非「後續擴充」）
- **既有 view 直接連接**（route 與 label 維持）：
  - 儀表板 → `admin-dashboard`
  - 員工管理 → `admin-users`（原「人員管理」label 微調）
  - 請款記錄 → `admin-records`
  - 簽核 → `admin-review`
  - 發放 → `admin-payout`
- **新增 3 個 stub view**（現階段要實作、但此 change 只建立 placeholder，實作留給後續 changes）：
  - 支出列表 → `admin-expenses`（對應 sitemap「支出管理／支出列表」）
  - 費用類別 → `admin-categories`（對應 sitemap「支出管理／費用類別」）
  - 類別預算 → `admin-budgets`（對應 sitemap「預算管理／類別預算」）
- **手機版 sidebar drawer**：
  - 新增 hamburger 按鈕（顯示於 `< 640px`）
  - Sidebar 於窄螢幕默認收合、開啟時**滿版寬**（`w-full`）覆蓋主內容
  - 點擊 nav item 或遮罩自動關閉
  - 桌機版行為不變（固定側邊 sidebar）
- **UI 風格延用**現有 Trust Blue tokens、PrimeIcons、utility class；不引入 GitHub demo 的 `qk-*` class

## Capabilities

### New Capabilities
- `admin-navigation`：後台側邊欄資訊架構、分組定義、mobile drawer 行為、role 權限過濾規則

### Modified Capabilities
（無 — 此為專案第一個 archive 的 change；既有代墊款 view 內容不動，只動 sidebar label 與分組歸屬）

## Impact

**動到的檔案**
- `frontend/src/layouts/AdminLayout.vue` — sidebar 主要改動處
- `frontend/src/router/index.ts` — 新增 3 個 stub 路由
- `frontend/src/views/admin/ExpensesView.vue` — 新檔（stub）
- `frontend/src/views/admin/CategoriesView.vue` — 新檔（stub）
- `frontend/src/views/admin/BudgetsView.vue` — 新檔（stub）
- `frontend/src/components/AppHeader.vue` — 新增 `#left` slot 讓 AdminLayout 掛入 hamburger

**不動的檔案**
- 前台（`views/front/*`、`FrontLayout.vue`）完全不動
- 既有 view 檔案（DashboardView / RecordsView / ReviewView / PayoutView / UsersView）內容不動
- Domain 型別、Pinia store 不動
- design.md、dev-style.md、CLAUDE.md

**Non-goals（此 change 不做）**
- 不實作「支出列表 / 費用類別 / 類別預算」的實際功能，只做可導向的 stub 頁（各自另開 change 實作）
- 不做角色簡化 refactor（employee/finance/admin → superadmin/employee 屬另一個 change）
- 不放「後續擴充」的模組到 sidebar（部門管理、多層簽核、正式財報、收入管理、專案管理、報表）
- 不做付費等級 / 訂閱制的 feature gating（PRD 6.5 明訂待付費機制上線後另議）
- 不引入 GitHub demo 的 CSS（`style.css` 內的 `qk-*` class 不搬進來）
- 不改動代墊款狀態機或流程
