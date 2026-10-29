## Why

Stage B 起手第一個 change。依 `docs/實作流程.md` 六節建議順序 item 1：`Auth（註冊 / 登入 / JWT / 登出 / 密碼重設）— Stage D 用得到`。

現況：
- `backend/` 剛在 `feat/backend-scaffold` scaffold 完 Rails 8 API-only 骨架，`app/controllers/`、`app/models/` 除了 base class 外都是空的
- 前端有 `views/front/LoginView.vue`、`views/admin/LoginView.vue`，都是「查 mock users → set auth store」的假登入；沒有註冊、沒有忘記密碼、沒有 JWT
- `frontend/src/api/` 目錄有 `users.ts`（`PATCH /users/me/password` 已登入改密碼契約）、`invitations.ts`（接受邀請設密碼），**沒有 `auth.ts`**
- Stage D 註冊頁（`docs/實作流程.md` §8.2）依賴這個 change

## What Changes

**後端**（Rails 8 + PostgreSQL）：

- 新增 gems：`bcrypt`（`has_secure_password`）、`jwt`（Access token）、`rack-cors`（CORS 放通 `http://localhost:5173`）
- 新 model 與 migration：
  - `User`：`email`（unique）、`password_digest`、`name`、`role`（`superadmin` / `employee`）、`status`（`active` / `invited`）、`last_login_at?`
  - `PasswordResetToken`：`user_id`、`token_digest`、`expires_at`、`used_at?`
- 新增 `JwtService`（sign / decode）與 `Authenticatable` controller concern（提供 `current_user`、`authenticate!`、`skip_before_action :authenticate! only:` DSL）
- 新增 routes（namespace `/api/auth`）：
  - `POST /api/auth/register` — 建立 User（`role='superadmin'`；本 change 不建 Company，下一個 change `add-company-module` 補）
  - `POST /api/auth/login` — 回 `{ user, token }`；bcrypt 驗 password
  - `POST /api/auth/logout` — 前端 discard token；後端無 server-side session 可清（MVP 不做 token blacklist；設計理由見 design.md Decision 4）
  - `POST /api/auth/password/forgot` — 輸 email，若 user 存在則產 32-byte 隨機 token、`token_digest` 存 DB、寄信；response 一律 `202 accepted`（不揭露 email 是否存在，避免帳號枚舉）
  - `POST /api/auth/password/reset` — 輸 `token` + `new_password`，驗 token 有效且未使用未過期 → 更新 `password_digest` + `used_at`
- `UserMailer#password_reset` — **stub 版**：`Rails.logger.info "[MVP-stub] Password reset URL: #{url}"`；不真的寄 email（實作流程 §六.5 收尾與 Stage B item 9 才接 SMTP）
- CORS 設定：`config/initializers/cors.rb` 放通 `http://localhost:5173`（Vite dev）
- Rails credentials：`Rails.application.credentials.jwt_secret_base`（用 `bin/rails credentials:edit`）

**前端**（Vue 3 + Pinia）：

- 新 `frontend/src/api/auth.ts`：TS 契約檔（`RegisterRequest`、`LoginRequest`、`LoginResponse`、`ForgotPasswordRequest`、`ResetPasswordRequest`）
- 新 `frontend/src/views/ForgotPasswordView.vue`（public，`/forgot-password`）
- 新 `frontend/src/views/ResetPasswordView.vue`（public，`/reset-password?token=xxx`）
- `frontend/src/views/front/LoginView.vue` + `frontend/src/views/admin/LoginView.vue`：底下加「忘記密碼？」連結
- `frontend/src/stores/auth.ts`：新增 mock action `forgotPassword(email)`、`resetPassword(token, newPassword)`（Prototype 階段仍打 mock，Stage C 換成 fetch）
- `frontend/src/router/index.ts`：加 `/forgot-password`、`/reset-password` public route

**流程 doc 更新**：

- `docs/實作流程.md` §六 Stage B item 1 加勾號 → 標「進行中 add-auth-module」

## Impact

- **Affected specs**：新增 capability `auth`
- **Affected code**：
  - `backend/`：新增 `app/models/user.rb`、`password_reset_token.rb`、`app/controllers/api/auth_controller.rb`、`app/services/jwt_service.rb`、`app/controllers/concerns/authenticatable.rb`、`app/mailers/user_mailer.rb`、`db/migrate/*_create_users.rb`、`*_create_password_reset_tokens.rb`、`config/routes.rb`、`config/initializers/cors.rb`
  - `frontend/src/api/auth.ts`（新）
  - `frontend/src/views/ForgotPasswordView.vue`、`ResetPasswordView.vue`（新）
  - `frontend/src/views/front/LoginView.vue`、`frontend/src/views/admin/LoginView.vue`（改）
  - `frontend/src/stores/auth.ts`（改）
  - `frontend/src/router/index.ts`（改）
- **Not affected**：Company、Category、Budget、Reimbursement、Expense 皆屬後續 changes
