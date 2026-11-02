# auth Specification

## Purpose

定義 Quickey 的認證（Authentication）能力：註冊、登入、登出、忘記密碼、重設密碼。此 capability 對應 `docs/實作流程.md` §六 Stage B 建議順序 item 1，是所有其他後端 endpoint 的前置能力（其他 controller 皆需 `authenticate!` before_action）。

此 capability **不涵蓋**：Company 多租戶隔離（下一個 change）、Invitation 流程（另一個 change）、真的 email 寄送（Stage B 收尾 SMTP）、Token blacklist / refresh token（未來付費階段）。

## ADDED Requirements

### Requirement: 註冊 endpoint 建立 superadmin User

系統 SHALL 提供 `POST /api/auth/register`，接受 `email`、`password`、`name`，建立 `User` 記錄 `role='superadmin'`、`status='active'`，並回傳該 user 資料與 JWT access token。

#### Scenario: 首次註冊成功

- **WHEN** 前端送 `{ email: "new@example.com", password: "password123", name: "New User" }`
- **AND** 該 email 尚未存在
- **THEN** 系統 MUST 建立 User `role='superadmin'`, `status='active'`
- **AND** 回傳 status 201 with body `{ user: { id, email, name, role, status }, token: <JWT> }`
- **AND** JWT payload MUST 含 `user_id`, `exp` (7 days), `iat`

#### Scenario: 重複 email 註冊失敗

- **WHEN** 前端送註冊請求，email 已存在
- **THEN** 系統 MUST 回傳 status 422 with body `{ error: 'email_taken' }`
- **AND** 不建立新 User

#### Scenario: 密碼過短

- **WHEN** 前端送註冊請求，password 長度 < 8
- **THEN** 系統 MUST 回傳 status 422 with body `{ error: 'validation_failed', details: { password: ['too_short'] } }`

#### Scenario: 缺欄位

- **WHEN** 前端送註冊請求，缺 email / password / name 任一
- **THEN** 系統 MUST 回傳 status 422

### Requirement: 登入 endpoint 以 bcrypt 驗密碼並回傳 JWT

系統 SHALL 提供 `POST /api/auth/login`，接受 `email`、`password`。驗證通過時回傳 user 資料與新 JWT。失敗時不揭露是「email 不存在」或「密碼錯誤」。

#### Scenario: 登入成功

- **WHEN** 前端送 `{ email, password }` 對應到存在的 User 且 bcrypt 驗證通過
- **THEN** 系統 MUST 回傳 status 200 with `{ user, token }`
- **AND** 系統 MUST 更新該 User 的 `last_login_at`

#### Scenario: 密碼錯誤

- **WHEN** 前端送 `{ email, password }`，email 存在但 bcrypt 驗證失敗
- **THEN** 系統 MUST 回傳 status 401 with body `{ error: 'invalid_credentials' }`

#### Scenario: Email 不存在

- **WHEN** 前端送 `{ email, password }`，email 不存在於 DB
- **THEN** 系統 MUST 回傳 status 401 with body `{ error: 'invalid_credentials' }`（與密碼錯誤同樣回應，避免帳號枚舉）

### Requirement: 登出 endpoint 為 stateless no-op

系統 SHALL 提供 `POST /api/auth/logout`，需要合法 JWT 才能呼叫；回應成功但不做 server-side session 銷毀（stateless JWT，MVP 不做 blacklist）。

#### Scenario: 已登入登出

- **WHEN** 前端帶合法 JWT 呼叫 logout
- **THEN** 系統 MUST 回傳 status 204
- **AND** 前端負責清除 localStorage 內 token

#### Scenario: 未帶 token

- **WHEN** 前端未帶 Authorization header 或 token 無效
- **THEN** 系統 MUST 回傳 status 401

### Requirement: 忘記密碼 endpoint 不揭露 email 是否存在

系統 SHALL 提供 `POST /api/auth/password/forgot`，接受 `email`。無論該 email 是否存在，皆回傳 status 202 with 同一訊息，避免帳號枚舉。若 email 存在，系統 MUST 產生 30 分鐘內有效的 reset token 並寄送信件（MVP 為 log stub）。

#### Scenario: 已註冊 email 送出 forgot

- **WHEN** 前端送 `{ email: "admin@example.com" }`，該 email 已註冊
- **THEN** 系統 MUST 產生 `PasswordResetToken` 記錄：
  - `token_digest` = SHA256(raw_token)（raw_token 為 32-byte urlsafe_base64）
  - `expires_at` = 30 分鐘後
  - `used_at` = null
- **AND** 系統 MUST 呼叫 `UserMailer.password_reset(user, raw_token).deliver_later`
- **AND** 系統 MUST 回傳 status 202 with `{ message: 'If the email exists, a reset link has been sent.' }`

#### Scenario: 未註冊 email 送出 forgot（帳號枚舉防護）

- **WHEN** 前端送 `{ email: "nobody@example.com" }`，該 email 不存在
- **THEN** 系統 MUST NOT 建立 `PasswordResetToken`
- **AND** 系統 MUST NOT 寄送任何 email
- **AND** 系統 MUST 回傳 status 202 with **同樣訊息** `{ message: 'If the email exists, a reset link has been sent.' }`

#### Scenario: MVP 階段 email 寄送為 stub

- **WHEN** `UserMailer#password_reset` 被觸發
- **THEN** 系統 MUST 寫 log `[MVP-stub] Password reset URL for <email>: <url>`
- **AND** 系統 MUST NOT 嘗試連 SMTP server
- **AND** `<url>` MUST 為 `<frontend_base_url>/reset-password?token=<raw_token>`

### Requirement: 重設密碼 endpoint 驗 token 一次性且未過期

系統 SHALL 提供 `POST /api/auth/password/reset`，接受 raw `token` 與 `new_password`。系統 MUST 以 SHA256(token) 比對 `PasswordResetToken.token_digest`，並驗證該 token 未使用 (`used_at IS NULL`) 且未過期 (`expires_at > NOW()`)。驗證通過後更新密碼、標記 token 已使用，並回傳新 JWT 讓使用者自動登入。

#### Scenario: 合法 token reset 成功

- **WHEN** 前端送 `{ token: "<raw>", new_password: "newpass123" }`
- **AND** 對應的 `PasswordResetToken` 記錄 `used_at=null` 且 `expires_at > now`
- **THEN** 系統 MUST 更新該 User 的 `password_digest`
- **AND** 系統 MUST 更新 `PasswordResetToken.used_at = NOW()`
- **AND** 系統 MUST 回傳 status 200 with `{ user, token: <new JWT> }`

#### Scenario: 過期 token

- **WHEN** 前端送合法格式 token，但對應記錄 `expires_at <= now`
- **THEN** 系統 MUST 回傳 status 400 with `{ error: 'invalid_or_expired_token' }`
- **AND** 系統 MUST NOT 更新 password

#### Scenario: 已使用 token

- **WHEN** 前端送 token 對應記錄 `used_at IS NOT NULL`
- **THEN** 系統 MUST 回傳 status 400 with `{ error: 'invalid_or_expired_token' }`

#### Scenario: 不存在 token

- **WHEN** 前端送不存在於 DB 的 token
- **THEN** 系統 MUST 回傳 status 400 with `{ error: 'invalid_or_expired_token' }`

#### Scenario: 新密碼過短

- **WHEN** 前端送合法 token，但 new_password 長度 < 8
- **THEN** 系統 MUST 回傳 status 422 with `{ error: 'validation_failed', details: { password: ['too_short'] } }`
- **AND** 系統 MUST NOT 更新 password 或標記 token 已使用

### Requirement: JWT 儲存於前端 localStorage，`Authorization: Bearer <token>` header 傳遞

前端 SHALL 將 JWT 存於 `localStorage['quickey.auth.token']`；打受保護 endpoint 時 MUST 於 request header 加 `Authorization: Bearer <token>`。後端 `Authenticatable` concern MUST 從此 header 解出 token 並設 `current_user`。

#### Scenario: 合法 token 存取受保護 endpoint

- **WHEN** 前端 request header 含 `Authorization: Bearer <valid-jwt>`
- **THEN** 後端 MUST 解出 `user_id`、設 `current_user = User.find(user_id)`
- **AND** 後端 controller action 可透過 `current_user` 使用該 user

#### Scenario: 無 token 存取受保護 endpoint

- **WHEN** 前端 request header 無 Authorization 或 token 無效
- **THEN** 後端 MUST 回傳 status 401 with `{ error: 'unauthorized' }`

### Requirement: 前端提供未登入態的忘記／重設密碼頁

前端 SHALL 提供兩個 public route（不需要登入即可存取）：
- `/forgot-password`（`ForgotPasswordView.vue`）
- `/reset-password?token=<raw_token>`（`ResetPasswordView.vue`）

`beforeEach` router guard MUST 對 `meta.public === true` 的 route 放行未登入使用者。

#### Scenario: 未登入者可存取忘記密碼頁

- **WHEN** 未登入使用者導航至 `/forgot-password`
- **THEN** 系統 MUST 顯示 `ForgotPasswordView`（不 redirect 到登入頁）

#### Scenario: Reset 頁缺 token 顯示錯誤

- **WHEN** 使用者導航至 `/reset-password` 而未帶 `?token=` query
- **THEN** `ResetPasswordView` MUST 顯示「連結無效或已過期」+ 「回登入」連結
- **AND** MUST NOT 顯示新密碼輸入表單

#### Scenario: 忘記密碼頁一律顯示同一成功訊息

- **WHEN** 使用者在 `/forgot-password` 輸入 email 送出
- **THEN** 頁面 MUST 顯示「若該 email 已註冊，重設連結已寄出，請至信箱查看」訊息
- **AND** 不區分 email 是否存在（對齊後端 Decision 5）

### Requirement: 登入頁提供「忘記密碼？」連結

`views/front/LoginView.vue` 與 `views/admin/LoginView.vue` MUST 在登入表單底部顯示 `<router-link to="/forgot-password">忘記密碼？</router-link>`。

#### Scenario: 前台登入頁

- **WHEN** 使用者查看 `/login`
- **THEN** 登入按鈕下方 MUST 顯示「忘記密碼？」連結

#### Scenario: 後台登入頁

- **WHEN** 使用者查看 `/admin/login`
- **THEN** 登入按鈕下方 MUST 顯示「忘記密碼？」連結
