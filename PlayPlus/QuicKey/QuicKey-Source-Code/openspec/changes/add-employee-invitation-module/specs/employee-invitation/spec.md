## Purpose

管理員以 email 邀請員工加入公司、被邀請人透過連結設密碼並自動登入的能力。定義邀請資料模型、發送 / 撤回 / 接受行為、10 人員工上限規則、UsersView 呈現邀請與現有員工的混合列表、以及公開 Accept 頁的錯誤分類與成功流程。此 capability 不描述帳號登入細節（見 auth）、不描述員工資料的其他操作（如編輯、重設密碼、刪除），只描述「邀請」這個概念被建立、撤回、接受、過期的方式。對應 `docs/資料模型.md` §3.2、§3.3、§5.3、`docs/實作流程.md` §五 Phase 5。

## ADDED Requirements

### Requirement: 邀請資料模型

系統 SHALL 為每筆邀請保存以下欄位：所屬公司（MVP 單一公司隱含）、被邀請人 email、被邀請人姓名、隨機 token、邀請人 id、過期時間、接受時間（未接受為 null）、撤回時間（未撤回為 null）、建立時間。系統 SHALL 保證每筆邀請的 token 唯一。系統 SHALL 允許同 email 存在多筆邀請記錄（例如撤回後重發）。

#### Scenario: 建立邀請時填入 email 與姓名

- **WHEN** admin 在後台員工管理頁點「邀請員工」並填入 email `new@example.com` 與姓名「新同事」，點「發送邀請」
- **THEN** 系統 SHALL 建立一筆 email = `new@example.com`、姓名 = 「新同事」的邀請記錄
- **AND** token SHALL 為隨機字串
- **AND** 過期時間 SHALL 為今日起算 3 天後的同一時刻
- **AND** 接受時間、撤回時間 SHALL 為 null

#### Scenario: 同 email 撤回後可重發

- **WHEN** admin 撤回一封 email = `new@example.com` 的既有邀請
- **AND** 立即以同一 email 再發一封新邀請
- **THEN** 系統 SHALL 建立新的邀請記錄（新 token、新過期時間），既有已撤回記錄 NOT 被刪除

### Requirement: 邀請發送前的名額與重複檢查

系統 SHALL 於發送邀請前檢查：（1）公司員工名額；（2）email 是否已被使用。名額計算 SHALL 為「現有 role='employee' 且 status='active' 的人數」加上「未接受、未撤回、未過期的邀請數」之總和；此總和 SHALL NOT 超過 10。email 重複判斷：已存在 status='active' 的 User 或存在「未接受、未撤回、未過期」的 Invitation 者，SHALL 視為重複、拒絕發送並回饋錯誤原因。已過期或已撤回的邀請 NOT 計入重複判斷、亦 NOT 計入名額。

#### Scenario: 達到 10 人上限時無法邀請

- **WHEN** 公司目前有 8 位 active 員工 + 2 筆有效邀請（合計 10）
- **AND** admin 嘗試再發第 11 封邀請
- **THEN** 「邀請員工」按鈕 SHALL disabled、並附提示（例如「已達員工上限 10 人」）
- **AND** 若強制觸發（例如程式流程）建立邀請 SHALL 被拒絕並回錯誤

#### Scenario: 撤回一筆邀請釋放名額

- **WHEN** 公司目前有 8 位 active 員工 + 2 筆有效邀請（合計 10）
- **AND** admin 撤回其中 1 筆邀請
- **THEN** 名額顯示 SHALL 立即更新為 9 / 10
- **AND** 「邀請員工」按鈕 SHALL 恢復可用

#### Scenario: Email 已被現有員工使用

- **WHEN** `existing@example.com` 已存在 status='active' 的 User
- **AND** admin 以同 email 發邀請
- **THEN** 系統 SHALL 拒絕、顯示錯誤（例如「該 email 已在名單」）
- **AND** NOT 建立任何 Invitation 記錄

#### Scenario: Email 已有有效未接受邀請

- **WHEN** `pending@example.com` 已有一封未接受、未撤回、未過期的邀請
- **AND** admin 以同 email 發第二封邀請
- **THEN** 系統 SHALL 拒絕、顯示錯誤（例如「該 email 已發送邀請，請先撤回既有邀請再重發」）

#### Scenario: Email 對應邀請已過期，可重新邀請

- **WHEN** `expired@example.com` 已有一封過期未接受邀請（且未撤回）
- **AND** 公司名額未滿
- **AND** admin 以同 email 發邀請
- **THEN** 系統 SHALL 允許建立新邀請記錄（不會被視為重複）

### Requirement: 邀請 email 假寄（Prototype 階段）

系統於 Prototype 階段 SHALL NOT 真實寄送 email；改為於發送成功後於 UsersView 對該筆邀請提供「複製邀請連結」按鈕，讓 admin 手動貼給員工。邀請連結格式 MUST 為 `<origin>/invite/accept?token=<token>`。此需求於 Stage B 對接 SMTP / Resend 後 SHALL 被 REMOVED。

#### Scenario: 邀請發送後可複製連結

- **WHEN** admin 成功發送邀請
- **THEN** UsersView 該筆邀請列 SHALL 顯示「複製邀請連結」按鈕
- **AND** 點擊該按鈕 SHALL 將 `<origin>/invite/accept?token=<token>` 複製到系統剪貼簿
- **AND** 提示 admin 已複製（例如 toast「已複製邀請連結」）

#### Scenario: 剪貼簿權限被拒的 fallback

- **WHEN** 瀏覽器拒絕 clipboard 權限（例如非 secure context）
- **THEN** 系統 SHALL 以 fallback 方式（例如 prompt 對話框內顯示 URL）讓 admin 手動選取複製
- **AND** NOT 拋 uncaught error

### Requirement: 邀請撤回

系統 SHALL 允許 admin 撤回任一未接受的邀請。撤回動作 SHALL 記錄 `revokedAt` 為當下時間（軟刪除），底層記錄 NOT 從資料中移除，以保留歷史；撤回後該筆邀請 NOT 再出現於 UsersView 的名單、NOT 計入名額。已接受的邀請 SHALL NOT 允許撤回。

#### Scenario: 撤回未接受邀請

- **WHEN** admin 於 UsersView 點某筆有效邀請的「撤回邀請」並於 ConfirmDialog 確認
- **THEN** 系統 SHALL 設 `revokedAt` 為當下時間
- **AND** 該筆邀請 SHALL 從 UsersView 列表消失
- **AND** 該 token 之後開啟 Accept 頁 SHALL 顯示「邀請已撤回」錯誤

#### Scenario: 撤回時須二次確認

- **WHEN** admin 點「撤回邀請」按鈕
- **THEN** 系統 SHALL 顯示 ConfirmDialog（例如「確定撤回對 xxx@example.com 的邀請？」）
- **AND** 提供「確認撤回」與「取消」兩顆按鈕
- **AND** 點「取消」SHALL NOT 撤回

#### Scenario: 已接受的邀請不允許撤回

- **WHEN** 邀請已被接受（`acceptedAt` 非 null）
- **THEN** UsersView SHALL NOT 顯示該邀請的撤回按鈕（該筆已轉為員工列，操作項為員工的編輯 / 重設密碼 / 刪除）

### Requirement: 邀請接受頁的公開路由

系統 SHALL 提供公開路由 `/invite/accept`，NOT 需要登入即可訪問。頁面 SHALL 從 URL query `token` 取得邀請 token 並依 token 的狀態切換顯示：（a）token 有效 → 表單；（b）token 無 / 找不到 → 「連結無效」錯誤；（c）token 過期 → 「連結已過期」錯誤；（d）token 已撤回 → 「邀請已撤回」錯誤；（e）token 已接受 → 「邀請已使用」錯誤，附「前往登入」連結。

#### Scenario: 開啟不含 token 的連結

- **WHEN** 訪客開啟 `/invite/accept` 無 query
- **THEN** 頁面 SHALL 顯示「連結無效」錯誤（不顯示表單）

#### Scenario: 開啟含未知 token 的連結

- **WHEN** 訪客開啟 `/invite/accept?token=notfound123`
- **THEN** 頁面 SHALL 顯示「連結無效」錯誤

#### Scenario: 開啟已過期的邀請連結

- **WHEN** 訪客開啟 `/invite/accept?token=<過期 token>`
- **THEN** 頁面 SHALL 顯示「連結已過期」錯誤
- **AND** NOT 顯示表單、NOT 允許提交

#### Scenario: 開啟已撤回的邀請連結

- **WHEN** 訪客開啟 `/invite/accept?token=<已撤回 token>`
- **THEN** 頁面 SHALL 顯示「邀請已撤回」錯誤

#### Scenario: 開啟已接受的邀請連結

- **WHEN** 訪客開啟 `/invite/accept?token=<已接受 token>`
- **THEN** 頁面 SHALL 顯示「邀請已使用」錯誤
- **AND** 附「前往登入」連結導向 `/login`

### Requirement: 邀請接受成功流程

當 token 有效時，系統 SHALL 顯示表單，欄位為「email（唯讀，帶入邀請 email）」「姓名（唯讀，顯示邀請時 admin 填入的姓名；被邀請人不可修改）」「密碼（必填，最少 8 碼）」「確認密碼（必填、須與密碼一致）」。姓名之所以唯讀，係為避免同名混淆（管理員發邀請時已與新同事對齊姓名認知，若被邀請人自行改名會與管理員通訊錄不一致）；被邀請人若對姓名有異議，應請管理員撤回並重新邀請。提交成功時系統 SHALL 於資料層依序完成：（1）建立 role='employee'、status='active' 的 User 並存密碼、姓名沿用 Invitation.name；（2）標記該 Invitation `acceptedAt`；（3）以新帳號自動登入；（4）導向前台首頁。四個步驟 SHALL 於使用者角度為單一動作，任一失敗 SHALL NOT 留下半成品（例如已建 User 但未標記 acceptedAt）。

#### Scenario: 填完密碼成功接受

- **WHEN** 訪客於有效邀請 Accept 頁看到 email 「pending@example.com」與姓名「待入職」（皆唯讀），輸入密碼與確認密碼皆「password1234」，點「加入公司」
- **THEN** 系統 SHALL 建立一位 status='active'、role='employee' 的新員工，email 為 pending@example.com、姓名為「待入職」（沿用 Invitation.name）
- **AND** 該邀請的 `acceptedAt` SHALL 為當下時間
- **AND** 新帳號 SHALL 自動登入
- **AND** 瀏覽器 SHALL 導向前台首頁 `/app/home`

#### Scenario: 姓名欄位不可修改

- **WHEN** 訪客於有效邀請 Accept 頁嘗試修改「姓名」欄
- **THEN** 該欄 SHALL 為唯讀（例如以 `disabled` 呈現或 render 為純文字）、NOT 接受輸入
- **AND** 頁面 SHALL 提供輔助說明（例如「若姓名有誤，請聯絡貴公司管理員重新邀請」）

#### Scenario: 密碼與確認密碼不一致

- **WHEN** 訪客於表單填入密碼「abc12345」與確認密碼「abc00000」，點「加入公司」
- **THEN** 系統 SHALL 顯示錯誤（例如「兩次輸入的密碼不同」）
- **AND** NOT 建立 User、NOT 標 acceptedAt

#### Scenario: 密碼長度不足

- **WHEN** 訪客於表單填入密碼「abc1」（4 碼）
- **THEN** 系統 SHALL 顯示錯誤（例如「密碼長度至少 8 碼」）
- **AND** NOT 建立 User

#### Scenario: 接受後同一連結不可重用

- **WHEN** 訪客成功接受某邀請
- **AND** 之後再度開啟同一 `/invite/accept?token=<same>` 連結
- **THEN** 頁面 SHALL 顯示「邀請已使用」錯誤（見公開路由需求）

### Requirement: 已登入身分開啟 Accept 頁

當已登入的訪客（無論 admin 或 employee）開啟 `/invite/accept?token=xxx` 時，系統 SHALL NOT 直接處理接受動作；改為顯示提示（例如「請先登出目前身分再開啟邀請連結」），並附「登出」按鈕。點「登出」SHALL 清除登入身分並停留在 Accept 頁面，讓訪客可繼續驗證 token 與填表。

#### Scenario: 已登入使用者開啟有效邀請連結

- **WHEN** 已以 `admin@example.com` 登入的訪客開啟 `/invite/accept?token=<有效 token>`
- **THEN** 頁面 SHALL 顯示「請先登出目前身分再開啟邀請連結」提示
- **AND** 顯示「登出」按鈕
- **AND** NOT 顯示接受表單

#### Scenario: 已登入使用者點頁內「登出」

- **WHEN** 前一情境下訪客點「登出」按鈕
- **THEN** 目前登入身分 SHALL 被清除
- **AND** 頁面 SHALL 重新載入 / 重算狀態並顯示有效邀請的接受表單

### Requirement: UsersView 呈現「員工 + 邀請」混合列表

系統 SHALL 於後台員工管理頁的單一表格中同時顯示現有員工與有效未接受邀請兩類 row，欄位對齊：姓名、Email、狀態（Tag 顯示「使用中」／「已邀請」）、操作。有效未接受邀請 row 的操作 SHALL 只提供「複製邀請連結」與「撤回邀請」；員工 row 的操作 SHALL 提供「編輯」與「刪除」——「編輯」可修改姓名與 role，但 SHALL NOT 允許修改 email、SHALL NOT 提供任何修改密碼的入口（密碼修改由員工自行於前台完成，見 `user-profile` capability）。頁面上方 SHALL 顯示員工名額進度（例如「3 / 10」）並反映 active + invited 總數。表格 SHALL NOT 顯示「部門」欄（部門功能於 MVP 已下架）。

#### Scenario: 混合列表顯示

- **WHEN** 目前有 3 位 active 員工 + 2 筆有效邀請
- **AND** admin 進入員工管理頁
- **THEN** 表格 SHALL 顯示 5 列
- **AND** 前 3 列狀態欄顯示「使用中」、後 2 列顯示「已邀請」（順序不強制）
- **AND** 「已邀請」列操作欄只出現「複製邀請連結」「撤回邀請」
- **AND** 「使用中」列操作欄只出現「編輯」「刪除」，NOT 出現「重設密碼」

#### Scenario: 編輯員工限制範圍

- **WHEN** admin 於「使用中」列點「編輯」
- **THEN** Dialog 內 SHALL 只提供姓名 / role 兩個可編輯欄位
- **AND** Email 欄 SHALL 為唯讀（或於 UI 上不出現，看實作）
- **AND** Dialog 內 SHALL NOT 出現任何「新密碼」欄位

#### Scenario: 名額進度顯示

- **WHEN** 目前有 3 位 active 員工 + 2 筆有效邀請
- **THEN** 頁面上方 SHALL 顯示「員工名額：5 / 10」（或等效文字）

#### Scenario: 過期 / 撤回邀請不顯示

- **WHEN** 系統中存在已過期或已撤回的 Invitation 記錄
- **THEN** 該類邀請 SHALL NOT 出現於員工管理頁列表
- **AND** NOT 計入名額進度

#### Scenario: 表格不顯示部門欄

- **WHEN** admin 進入員工管理頁
- **THEN** 表格欄位 SHALL 只包含姓名 / Email / 狀態 / 操作四欄，NOT 出現「部門」欄

### Requirement: 資料保留

系統 SHALL 於使用者重新整理頁面或關閉瀏覽器後仍保留已建立的邀請記錄（Prototype 階段以瀏覽器 localStorage 存放；Stage B 接後端後改為 server-side 儲存）。

#### Scenario: 重新整理仍保留邀請

- **WHEN** admin 建立一筆邀請後重新整理頁面
- **THEN** 該筆邀請 SHALL 仍出現於員工管理頁的「已邀請」列
- **AND** 邀請連結 SHALL 仍為有效狀態（若未過期）

#### Scenario: 關閉瀏覽器再開啟仍保留

- **WHEN** admin 建立邀請後關閉瀏覽器再重新打開回到員工管理頁
- **THEN** 該筆邀請 SHALL 仍存在
