## Purpose

員工於前台自行維護個人帳號設定的能力。MVP 僅涵蓋「修改密碼」，係為配合本 change 移除 UsersView 內「重設密碼」按鈕（管理員不再插手員工密碼）後，員工仍能自助更新密碼。未來擴充（如個人資料、通知偏好、雙因素）於此 capability 增補即可。對應 `docs/實作流程.md` §五 Phase 5 附帶項、design.md Decision 14。

## ADDED Requirements

### Requirement: 前台「帳號設定」入口

系統 SHALL 於員工前台的主要導覽（sidebar 或 top nav）提供「帳號設定」入口；點擊 SHALL 導向 `/app/account` 頁面。此入口僅對已登入的 employee 顯示（未登入者由既有 router guard 導回登入頁）。管理員登入後台後 SHALL NOT 於後台看到此入口（管理員需自行改密碼者亦透過同一 `/app/account` 頁面完成，但入口只掛在前台）。

#### Scenario: 員工登入後看到帳號設定入口

- **WHEN** employee 登入前台
- **THEN** 前台主要導覽 SHALL 顯示「帳號設定」項目
- **AND** 點擊 SHALL 導向 `/app/account`

#### Scenario: 未登入訪客不可直接開帳號設定頁

- **WHEN** 未登入訪客直接開啟 `/app/account`
- **THEN** 系統 SHALL 依既有 router guard 將其導向 `/login`

### Requirement: 修改密碼流程

系統 SHALL 於 `/app/account` 頁面提供「修改密碼」表單，欄位為「舊密碼」「新密碼」「確認新密碼」三個必填欄。提交前系統 SHALL 於前端執行以下檢查：（1）舊密碼須與目前登入帳號的密碼相符；（2）新密碼長度 ≥ 8；（3）新密碼須與舊密碼不同；（4）確認新密碼須與新密碼相同。任一檢查失敗 SHALL 顯示對應錯誤且 NOT 更新密碼。全部通過時系統 SHALL 更新該帳號密碼、顯示成功提示，並保持當前登入狀態不強制登出。

#### Scenario: 成功修改密碼

- **WHEN** employee 於「帳號設定」頁面填入正確舊密碼「password123」、新密碼「newpass456」、確認密碼「newpass456」並提交
- **THEN** 系統 SHALL 更新該帳號密碼為「newpass456」
- **AND** 顯示成功提示（例如 toast「密碼已更新」）
- **AND** 當前登入狀態 SHALL NOT 被強制登出

#### Scenario: 舊密碼錯誤

- **WHEN** employee 填入錯誤的舊密碼並提交
- **THEN** 系統 SHALL 顯示錯誤（例如「舊密碼不正確」）
- **AND** NOT 更新任何欄位

#### Scenario: 新密碼長度不足

- **WHEN** employee 填入新密碼「abc1」（4 碼）
- **THEN** 系統 SHALL 顯示錯誤（例如「新密碼長度至少 8 碼」）
- **AND** NOT 更新任何欄位

#### Scenario: 新密碼與舊密碼相同

- **WHEN** employee 填入新密碼與舊密碼皆為「password123」
- **THEN** 系統 SHALL 顯示錯誤（例如「新密碼不可與舊密碼相同」）
- **AND** NOT 更新任何欄位

#### Scenario: 兩次新密碼不一致

- **WHEN** employee 填入新密碼「newpass456」與確認密碼「newpass789」
- **THEN** 系統 SHALL 顯示錯誤（例如「兩次輸入的新密碼不同」）
- **AND** NOT 更新任何欄位

#### Scenario: 修改後可用新密碼登入

- **WHEN** employee 修改密碼成功後登出、再以新密碼登入
- **THEN** 系統 SHALL 接受新密碼並成功登入
- **AND** 舊密碼 SHALL NOT 再被接受

### Requirement: 密碼欄不外洩

系統 SHALL NOT 於「帳號設定」頁面顯示目前密碼的明文或任何提示（例如「目前密碼是 xxxxx」、「密碼長度是 N 碼」等）；密碼欄一律以 password input 型別呈現，值 NOT 顯示於 DOM 明文。

#### Scenario: 密碼欄以遮蔽形式呈現

- **WHEN** employee 於「帳號設定」頁面看到密碼欄
- **THEN** 三個密碼欄 SHALL 皆為 `<input type="password">`（或等效遮蔽形式）
- **AND** 頁面 SHALL NOT 於其他地方顯示目前密碼相關資訊
