## Purpose

規範 Quickey 在使用者首次登入後所觸發的新手導覽（onboarding tour）行為，涵蓋後台 admin 8 步 + 前台 employee 3 步核心模組的引導順序、每步跳轉與打亮規則、結束/跳過語意、per-user 完成狀態的持久化、「重跑導覽」入口的行為與可及性，以及桌機與手機兩種 viewport 的完整支援。此 capability 只描述 tour 的觸發與流程，不描述被打亮各個 view 的內部行為。

## ADDED Requirements

### Requirement: 首次登入使用者進入該角色首頁時自動觸發對應 tour

系統 SHALL 在使用者首次登入且尚未完成 onboarding 時，於進入該角色首頁時自動啟動對應 tour：admin → `admin-dashboard` 觸發 8 步後台 tour；employee → `front-home` 觸發 3 步前台 tour。系統 MUST 以 per-user 為單位判斷「已完成」；同一瀏覽器登入不同帳號 MUST 分別追蹤。

#### Scenario: 全新 admin 首次登入

- **WHEN** admin 使用未在 `quickey.onboarding.v1` completedUserIds 內的 user id 登入並被導至 `/admin/dashboard`
- **THEN** 頁面 mount 完畢後 admin tour 自動啟動於第一步（welcome）

#### Scenario: 全新 employee 首次登入

- **WHEN** employee 使用未在 completedUserIds 內的 user id 登入並被導至 `/app/home`
- **THEN** 頁面 mount 完畢後 employee tour 自動啟動於第一步（welcome）

#### Scenario: 已完成 onboarding 的使用者再度登入

- **WHEN** 使用者的 user id 已存在於 completedUserIds
- **THEN** 進入該角色首頁不觸發 tour

#### Scenario: 同一瀏覽器切換帳號

- **WHEN** 已完成 onboarding 的 A 登出，未完成的 B 登入
- **THEN** B 依然被觸發 tour（per-user 隔離），且觸發的是 B 角色對應的 tour

### Requirement: Tour 依角色與固定順序走過核心模組

系統 SHALL 依使用者角色選擇對應的固定步驟序列。順序 MUST NOT 因資料狀態或 viewport 改變。桌機（≥ 640px）每步 MUST 同步打亮左側 sidebar 對應的 nav item；手機 sidebar 位於 drawer 內預設隱藏，不受此規則影響。

**Admin tour（10 步）：**

| 步驟 | 標題 | Route Name | 目標 UI | Sidebar 打亮項 |
|---|---|---|---|---|
| 1 | 歡迎使用 Quickey | `admin-dashboard` | dashboard PageHeader 區塊 | 儀表板 |
| 2 | 建立支出 | `admin-expenses` | 「新增支出」按鈕 | 支出管理 |
| 3 | 填寫支出內容 | `admin-expense-new` | 支出表單容器 | 支出管理 |
| 4 | 查看支出列表 | `admin-expenses` | 支出 DataTable | 支出管理 |
| 5 | 檢視請款記錄 | `admin-records` | 請款記錄 DataTable | 請款記錄 |
| 6 | 簽核代墊款 | `admin-review` | 待簽核清單容器 | 簽核 |
| 7 | 發放核銷款項 | `admin-payout` | 待發放清單容器 | 發放 |
| 8 | 設定費用類別 | `admin-categories` | 「新增類別」按鈕 | 類別管理 |
| 9 | 建立第一筆預算 | `admin-budgets` | 預算表格 | 預算管理 |
| 10 | 邀請員工 | `admin-users` | 「邀請員工」按鈕 | 人員管理 |

**Employee tour（3 步）：**

| 步驟 | 標題 | Route Name | 目標 UI |
|---|---|---|---|
| 1 | 歡迎使用 Quickey | `front-home` | HomeView welcome 區 |
| 2 | 送出代墊款請款 | `front-new` | 表單容器 |
| 3 | 追蹤請款進度 | `front-history` | DataTable |

#### Scenario: Admin tour 從第一步開始

- **WHEN** admin tour 啟動
- **THEN** 使用者看到位於 dashboard PageHeader 附近的 welcome tooltip，標題為「歡迎使用 Quickey」

#### Scenario: Employee tour 從第一步開始

- **WHEN** employee tour 啟動
- **THEN** 使用者看到位於 HomeView welcome 區的 tooltip，標題為「歡迎使用 Quickey」

#### Scenario: Admin 從第 2 步進入第 3 步

- **WHEN** 使用者於「建立支出」步驟按「下一步」
- **THEN** 路由自動導向 `admin-expense-new`
- **AND** tooltip 打亮該頁面的支出表單容器
- **AND** 桌機下 sidebar 的「支出管理」項目仍保持打亮（跨深頁不切換）

#### Scenario: Admin 桌機下 sidebar 同步打亮

- **WHEN** admin tour 進行至任一步（桌機 viewport）
- **THEN** 左側 sidebar 對應的 nav item MUST 顯示打亮樣式（primary 色底 + 邊框）
- **AND** 前一步的 sidebar 打亮 MUST 移除

#### Scenario: Admin 手機下 sidebar 打亮

- **WHEN** admin tour 進行至任一步（375px viewport）
- **THEN** sidebar drawer 預設隱藏，MUST NOT 有可見的 sidebar 打亮效果
- **AND** tour 仍照常打亮頁面內 target

#### Scenario: Employee 從第 2 步進入第 3 步

- **WHEN** 使用者於「送出代墊款請款」步驟按「下一步」
- **THEN** 路由自動導向 `front-history`
- **AND** tooltip 打亮 HistoryView DataTable

#### Scenario: 最後一步

- **WHEN** admin 於第 8 步（邀請員工）或 employee 於第 3 步（追蹤請款進度）按「完成」
- **THEN** tour 關閉
- **AND** 使用者停留於當前頁面（不再自動導頁）

### Requirement: 每步按「下一步」自動導頁、target scroll into view、再打亮

系統 SHALL 在使用者按「下一步」時，依序執行：路由跳轉至下一步 route → 等待目標 DOM 元素出現（500ms timeout）→ 將 target 捲入視窗中央 → 顯示 tooltip 與 spotlight。系統 MUST 允許目標元素於路由轉換後有短暫延遲；若逾時仍找不到目標，MUST 於頁面中央顯示該步 tooltip（fallback），不得崩潰或跳過。系統 MUST 確保 fold 以下的 target 也能被打亮且 tooltip 完整顯示。

#### Scenario: 路由切換後 target 立刻可用

- **WHEN** 使用者按「下一步」，路由切換至新頁
- **THEN** 系統於目標元素上顯示 tooltip 與遮罩挖空

#### Scenario: Target 延遲出現

- **WHEN** 目標頁面因資料 loading 導致目標元素於 300ms 後才 mount
- **THEN** 系統等待 mount 後才顯示 tooltip（不出現 tooltip 亂飛的情況）

#### Scenario: Target 位於 fold 下方

- **WHEN** 目標元素位於當前 viewport 可視區域以外
- **THEN** 系統 MUST 於 highlight 前將 target 捲入視窗中央（`scrollIntoView({ block: 'center' })`）

#### Scenario: Target 不存在

- **WHEN** 目標頁面的目標元素因未來重構被移除，selector 找不到
- **THEN** 系統於頁面中央以無挖空遮罩形式顯示該步 tooltip（不崩潰、不跳過）

### Requirement: 右上角「結束導覽」按鈕可隨時結束並記為完成；點遮罩不觸發

系統 SHALL 於每步 tooltip 右上角持續顯示一個文字按鈕，label 為「結束導覽」。使用者點擊 MUST 立刻關閉 tour、標記該 user 為已完成、不再自動觸發。系統 MUST 允許鍵盤 Esc 有相同效果。系統 MUST NOT 因使用者點畫面遮罩區（tooltip 以外的暗色 overlay）而關閉 tour；點遮罩 MUST 為 no-op，避免使用者為了瀏覽被打亮的元素而不小心關閉。系統 MUST NOT 對「剛離開的那一步」與「已走完全部步數」在完成語意上做區分——皆一致寫入 completedUserIds。

#### Scenario: 使用者中途按「結束導覽」

- **WHEN** 使用者於任一步（未至最後一步）點右上角「結束導覽」按鈕
- **THEN** tour 關閉
- **AND** 該 user id 被加入 completedUserIds
- **AND** 使用者重新整理頁面後不會再自動觸發 tour

#### Scenario: 使用者按 ESC 鍵

- **WHEN** 使用者在任一步按下鍵盤 ESC
- **THEN** 效果等同點「結束導覽」（tour 關閉並記為完成）

#### Scenario: 使用者點畫面遮罩區

- **WHEN** 使用者在任一步點擊 tooltip 以外的暗色遮罩
- **THEN** tour MUST NOT 關閉，仍停留於當前步驟

#### Scenario: 使用者走完最後一步

- **WHEN** 使用者於最後一步按「完成」
- **THEN** tour 關閉
- **AND** 該 user id 被加入 completedUserIds

### Requirement: 「新手導覽」入口位於使用者選單且永久可用

系統 SHALL 於 AdminLayout 與 FrontLayout 右上角使用者選單（`UserBadge` 展開的選單）各加入一項「新手導覽」，位於「修改密碼」上方，icon `pi pi-compass`。此選項 MUST 對登入使用者永久可見（不論是否已完成 onboarding）；點擊 MUST 清除該 user 的完成狀態並導向該角色首頁，讓對應 tour 從第一步重新開始。

#### Scenario: 已完成 onboarding 的 admin 點「新手導覽」

- **WHEN** admin 於使用者選單點擊「新手導覽」
- **THEN** 該 user id 從 completedUserIds 移除
- **AND** 路由導向 `admin-dashboard`
- **AND** dashboard mount 後 admin tour 從第一步啟動

#### Scenario: 已完成 onboarding 的 employee 點「新手導覽」

- **WHEN** employee 於使用者選單點擊「新手導覽」
- **THEN** 該 user id 從 completedUserIds 移除
- **AND** 路由導向 `front-home`
- **AND** home mount 後 employee tour 從第一步啟動

#### Scenario: admin 在非 dashboard 頁面點「新手導覽」

- **WHEN** admin 目前在 `admin-users` 頁點擊「新手導覽」
- **THEN** 路由導向 `admin-dashboard` 而非在原地啟動
- **AND** tour 從第一步啟動

#### Scenario: 使用者選單順序

- **WHEN** 使用者展開右上角使用者選單
- **THEN** 選單項目由上至下為：新手導覽、修改密碼、登出

### Requirement: 完成狀態以 localStorage per user id 持久化

系統 SHALL 將完成狀態存於 localStorage key `quickey.onboarding.v1`，value 為 `string[]`（user id 陣列）。系統 MUST 於解析損毀 / 非陣列格式時 fallback 為空陣列，不得因 localStorage 損毀導致頁面白畫面。系統 MUST 於瀏覽器不支援 localStorage（隱私模式或空間滿）時 fallback 為 in-memory 狀態；此時 tour 每次登入都會觸發，不視為 bug。

#### Scenario: 首次寫入

- **WHEN** 使用者完成 tour 或按 X
- **THEN** localStorage `quickey.onboarding.v1` 內容含該 user id

#### Scenario: 損毀資料

- **WHEN** localStorage `quickey.onboarding.v1` 內容不是合法 JSON
- **THEN** 系統回退為空陣列（等同全部使用者都未完成），並在下次寫入時覆寫為合法陣列

#### Scenario: localStorage 不可用

- **WHEN** 瀏覽器處於隱私模式且 localStorage.setItem 拋錯
- **THEN** 系統於當前 session 記住完成狀態、不重複觸發，但下次瀏覽器重啟又會觸發

### Requirement: Tour 完整支援手機與桌機兩種 viewport

系統 SHALL 於 375px（手機）與 ≥ 640px（桌機）viewport 皆能完整運行所有 tour 步驟。tooltip MUST NOT 於任一 viewport 被截切；MUST 使用 driver.js 內建 `side: 'auto'` 讓函式庫依 viewport 空間自動選擇上/下/左/右方向；手機端 popover 寬度 MUST 限制在 320px 以內，並保留 `safe-area-inset-bottom` padding 避開 iOS 主頁指示器。

#### Scenario: 375px 執行 admin 第 6 步

- **WHEN** 使用者於 375px viewport 執行 admin 第 6 步（設定費用類別）
- **THEN** target（新增類別按鈕）完整顯示於視窗內
- **AND** tooltip 未被視窗邊緣截切

#### Scenario: 375px 執行 employee 第 2 步

- **WHEN** 使用者於 375px viewport 執行 employee 第 2 步（送出代墊款請款）
- **THEN** 表單容器被打亮
- **AND** tooltip 未擋住「送出」按鈕

#### Scenario: 桌機 1440px 執行任一步

- **WHEN** 使用者於 1440px viewport 執行任一步
- **THEN** tooltip 側邊自動選擇合適方向不重疊主內容

### Requirement: Tour UI 樣式對齊 Trust Blue design tokens

系統 SHALL 覆寫 driver.js 預設樣式，使 tooltip 卡片、按鈕、進度指示與現有 Trust Blue 主題一致：tooltip 圓角 MUST 對齊 `--radius-lg`、主要按鈕背景 MUST 為 `--color-primary-500`、文字色 MUST 為 `--color-ink` 或 `--color-muted`。手機版 tooltip padding 與字級 MUST 縮減以避免超出視窗（≤ 320px 寬）；字級 MUST ≤ 14px 對齊 CLAUDE.md 手機字級規範。系統 MUST 保留 driver.js 的鍵盤導航與 aria 屬性（不移除以維持無障礙）。

#### Scenario: Tooltip 出現

- **WHEN** tour 顯示任一步 tooltip
- **THEN** tooltip 卡片圓角與 Quickey 設計 token 一致（非 driver.js 預設樣式）
- **AND** 「下一步」/「完成」按鈕使用 Trust Blue 主色

#### Scenario: 鍵盤導航

- **WHEN** 使用者用 Tab 鍵移動至 tooltip 按鈕
- **THEN** 按鈕顯示 focus outline，可用 Enter 觸發

#### Scenario: 螢幕閱讀器

- **WHEN** 螢幕閱讀器讀取 tooltip
- **THEN** MUST 唸出 tooltip 的 title 與 description，不因樣式覆寫遺失 aria 標籤

#### Scenario: 手機版字級

- **WHEN** 使用者於 375px viewport 看到 tooltip
- **THEN** tooltip 內文字級 MUST ≤ 14px
