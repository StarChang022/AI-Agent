# admin-navigation Specification

## Purpose
Quickey 後台的側邊欄資訊架構與 navigation 行為規範。定義 sidebar 分組、各項目對應的路由、role 權限過濾、mobile drawer 行為，以及 stub 頁面的呈現方式。此 capability 只描述 navigation 本身，不描述各個 view 的內部行為。
## Requirements
### Requirement: Sidebar 分三大群組呈現

系統 SHALL 於後台 sidebar 以固定順序呈現三個分組：主選單、請款、系統。每個分組上方 MUST 顯示分組標題，分組之間 MUST 有視覺區隔（例如上方留白）。分組順序不可隨 role 改變。分組定義對齊 `docs/sitemap.md` 的模組結構。

#### Scenario: 使用者以 admin 身分進入後台

- **WHEN** admin 登入後進入 `/admin/dashboard`
- **THEN** sidebar 從上到下依序顯示：主選單、請款、系統 三個分組標題與其項目

#### Scenario: 使用者以 finance 身分進入後台

- **WHEN** finance 登入後進入 `/admin/dashboard`
- **THEN** sidebar 從上到下依序顯示三個分組（順序與 admin 一致），只是「系統」分組內因 role 過濾看不到「員工管理」

### Requirement: 「主選單」分組包含兩個日常操作項目

系統 SHALL 在「主選單」分組下依序呈現兩個項目，屬於使用者每日檢視/登錄的操作面：

| Sidebar Label | Route Name | Sitemap 模組對應 | 狀態 | Role |
|---|---|---|---|---|
| 儀表板 | `admin-dashboard` | 儀表板／後台儀表板 | 既有 | 全 admin/finance |
| 支出管理 | `admin-expenses` | 支出管理／支出列表 | stub | 全 admin/finance |

#### Scenario: 使用者點擊「儀表板」

- **WHEN** 使用者在 sidebar 點擊「儀表板」
- **THEN** router 導向 `admin-dashboard`

#### Scenario: 使用者點擊「支出管理」

- **WHEN** 使用者在 sidebar 點擊「支出管理」
- **THEN** router 導向 `admin-expenses`
- **AND** 頁面顯示 stub empty state 與「本模組開發中」文案

### Requirement: 「請款」分組包含代墊款流程的兩個頁面

系統 SHALL 在「請款」分組下依序呈現兩個項目，每個項目 MUST 連結到既有的 admin view，label 沿用既有名稱：

| Sidebar Label | Route Name | Purpose |
|---|---|---|
| 請款記錄 | `admin-records` | 顯示所有代墊款請款記錄（全狀態） |
| 簽核 | `admin-review` | 顯示待簽核的請款佇列與已處理紀錄；核准後自動建立對應支出，付款流程在「支出管理」完成 |

#### Scenario: 使用者點擊「請款記錄」

- **WHEN** 使用者在 sidebar 點擊「請款記錄」
- **THEN** router 導向 `admin-records`，該項目在 sidebar 顯示 active 樣式

#### Scenario: 使用者點擊「簽核」

- **WHEN** 使用者在 sidebar 點擊「簽核」
- **THEN** router 導向 `admin-review`

### Requirement: 「系統」分組包含三個組態管理項目

系統 SHALL 在「系統」分組下依序呈現三個項目，屬於後台組態/管理性質（設定一次後定期調整，非日常操作），與「主選單」的日常操作分開歸類：

| Sidebar Label | Route Name | Sitemap 模組對應 | 狀態 | Role |
|---|---|---|---|---|
| 費用類別 | `admin-categories` | 支出管理／費用類別 | stub | 全 admin/finance |
| 預算管理 | `admin-budgets` | 預算管理／類別預算 | stub | 全 admin/finance |
| 員工管理 | `admin-users` | 員工管理 | 既有 | admin only |

#### Scenario: 使用者點擊「費用類別」

- **WHEN** 使用者在 sidebar 點擊「費用類別」
- **THEN** router 導向 `admin-categories`
- **AND** 頁面顯示 stub empty state 與「本模組開發中」文案

#### Scenario: 使用者點擊「預算管理」

- **WHEN** 使用者在 sidebar 點擊「預算管理」
- **THEN** router 導向 `admin-budgets`
- **AND** 頁面顯示 stub empty state 與「本模組開發中」文案

#### Scenario: admin 點擊「員工管理」

- **WHEN** admin 在 sidebar 點擊「員工管理」
- **THEN** router 導向 `admin-users`

#### Scenario: 非 admin 使用者的員工管理項目

- **WHEN** finance 或 employee 開啟後台 sidebar
- **THEN** 「系統」分組仍顯示（內含費用類別、預算管理），但不含「員工管理」項目（既有 role 過濾行為保留）

### Requirement: 「後續擴充」的模組 MUST NOT 出現於 sidebar

系統 SHALL 不在 sidebar 顯示 `docs/sitemap.md` 中標記為「後續擴充（現階段不進行）」的模組，也不顯示 PRD 未列出的模組。此包含（不限於）：部門管理、多層簽核、正式財報、收入管理、專案管理、報表、設定。

#### Scenario: 使用者查看完整 sidebar

- **WHEN** 使用者展開後台 sidebar
- **THEN** sidebar 內 MUST 沒有「部門管理」「報表」「設定」「專案管理」「多層簽核」「正式財報」「收入管理」等任一項目

### Requirement: Mobile drawer 行為（滿版寬）

系統 SHALL 在 viewport 寬度 `< 640px` 時將 sidebar 收合為 drawer；MUST 於 top bar 顯示 hamburger 按鈕；點擊 hamburger MUST 開啟 sidebar drawer；drawer 開啟時 MUST 以**裝置滿版寬**（`w-full`）呈現，主內容區被覆蓋；點擊 drawer 內 nav item 或右上角關閉按鈕 MUST 關閉 drawer。桌機版（`≥ 640px`）行為 MUST 不變（固定側邊 sidebar，寬 `w-56`）。

#### Scenario: 手機使用者開啟 sidebar

- **WHEN** viewport 寬度為 375px 且使用者點擊 top bar 的 hamburger
- **THEN** sidebar 以 drawer 形式從左側滑入
- **AND** drawer 寬度佔滿裝置螢幕（`w-full`），完全覆蓋主內容區

#### Scenario: 手機使用者從 drawer 選單導向

- **WHEN** drawer 開啟狀態下使用者點擊「請款記錄」
- **THEN** router 導向 `admin-records`
- **AND** drawer 自動關閉

#### Scenario: 手機使用者關閉 drawer

- **WHEN** drawer 開啟狀態下使用者點擊 drawer 右上角關閉按鈕
- **THEN** drawer 關閉且不變更當前路由

#### Scenario: 桌機使用者切換視窗大小

- **WHEN** 使用者在桌機（≥ 640px）瀏覽後台
- **THEN** sidebar 固定顯示於左側（w-56），top bar MUST NOT 顯示 hamburger 按鈕

### Requirement: Sidebar UI 樣式承襲既有 design tokens

系統 SHALL 使用既有的 Trust Blue design tokens（`--color-primary-*`、`--color-hairline`、`--radius-*` 等）與 PrimeIcons 圖示。MUST NOT 引入 GitHub quickey demo 專用的 `qk-*` CSS class。分組標題、active item、hover state 的顏色 MUST 對齊現有 sidebar 的樣式規範。手機版所有 sidebar 文字 MUST ≤ 14px。

#### Scenario: 主題色與現有 UI 一致

- **WHEN** 使用者在 sidebar 上看到 active 項目
- **THEN** 該項目 MUST 使用 `--color-primary-50` 底色與 `--color-primary-700` 文字（沿用現有 `active-class` 規則）

#### Scenario: 圖示來源

- **WHEN** sidebar 呈現任一項目
- **THEN** 圖示 MUST 為 PrimeIcons（`pi pi-*`），MUST NOT 直接嵌入 SVG

#### Scenario: 手機版字級

- **WHEN** 使用者在 375px viewport 開啟 drawer
- **THEN** 所有 nav item label、分組標題文字 MUST ≤ 14px

