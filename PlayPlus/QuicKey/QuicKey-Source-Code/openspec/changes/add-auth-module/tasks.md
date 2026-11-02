# Tasks — add-auth-module

> Stage B 第一個 change。前置 `feat/backend-scaffold` 已完成 Rails 8 骨架。
> 本 change 分兩個階段：**A. Backend Rails 實作** → **B. Frontend UI + 契約檔補齊**。
> 每章節做完走 QA checklist（見 §5）。

## 1. Gemfile 與環境

- [ ] 1.1 `backend/Gemfile` 新增：`gem "bcrypt", "~> 3.1.7"`（uncomment 現有 scaffold 註解那行）、`gem "jwt", "~> 2.8"`、`gem "rack-cors"`
- [ ] 1.2 `bundle install`；確認 `Gemfile.lock` 更新
- [ ] 1.3 `bin/rails credentials:edit`（或用 `EDITOR="code --wait"`）新增 `jwt_secret_base: <64 chars random>`；驗證 `Rails.application.credentials.jwt_secret_base` 能讀出
- [ ] 1.4 `config/initializers/cors.rb`：allow_origins `http://localhost:5173`（Vite dev），methods `[:get, :post, :put, :patch, :delete, :options, :head]`，headers `:any`，expose `["Authorization"]`

## 2. User model + migration

- [ ] 2.1 `bin/rails g migration CreateUsers email:string:uniq password_digest:string name:string role:string status:string last_login_at:datetime`；migration 檔加：`t.index :email, unique: true`、`role` 加 `default: 'employee', null: false`、`status` 加 `default: 'active', null: false`
- [ ] 2.2 `bin/rails db:migrate`
- [ ] 2.3 新 `app/models/user.rb`：
  - `has_secure_password`
  - `validates :email, presence: true, uniqueness: { case_sensitive: false }, format: /@/`
  - `validates :name, presence: true`
  - `validates :password, length: { minimum: 8 }, if: -> { password.present? }`
  - `enum :role, { superadmin: 'superadmin', employee: 'employee' }, prefix: :role`
  - `enum :status, { active: 'active', invited: 'invited' }, prefix: :status`
  - `before_save { self.email = email.downcase.strip }`
- [ ] 2.4 rails console 手動測：建立 User、驗 password、確認 unique / length 驗證觸發

## 3. PasswordResetToken model + migration

- [ ] 3.1 `bin/rails g migration CreatePasswordResetTokens user:references token_digest:string expires_at:datetime used_at:datetime`；migration 加 `t.index :token_digest, unique: true`
- [ ] 3.2 `bin/rails db:migrate`
- [ ] 3.3 新 `app/models/password_reset_token.rb`：
  - `belongs_to :user`
  - `scope :active, -> { where(used_at: nil).where('expires_at > ?', Time.current) }`
  - `def used?; used_at.present?; end`
  - class method `self.generate_for(user)` → 產生 raw token（`SecureRandom.urlsafe_base64(32)`）→ create record with `token_digest: Digest::SHA256.hexdigest(raw), expires_at: 30.minutes.from_now` → 回 `[record, raw]`
  - class method `self.find_valid_by_raw(raw)` → 算 digest → `active.find_by(token_digest: digest)`

## 4. JwtService + Authenticatable concern

- [ ] 4.1 新 `app/services/jwt_service.rb`：
  - `self.encode(user_id:, exp: 7.days.from_now)` → 回 JWT string（HS256、payload `{ user_id:, exp: exp.to_i, iat: Time.current.to_i }`）
  - `self.decode(token)` → 回 payload hash 或 raise `JWT::DecodeError`
  - secret 從 `Rails.application.credentials.jwt_secret_base`
- [ ] 4.2 新 `app/controllers/concerns/authenticatable.rb`：
  - `included` 時 `before_action :authenticate!`
  - `authenticate!`：從 request.headers['Authorization'] 抽 Bearer token → `JwtService.decode` → 取 `user_id` → `@current_user = User.find(user_id)` → 失敗回 `render json: { error: 'unauthorized' }, status: :unauthorized`
  - `current_user` reader
- [ ] 4.3 `app/controllers/application_controller.rb` include `Authenticatable`（讓所有 controller 預設要 auth；auth_controller 用 `skip_before_action :authenticate!` opt-out）

## 5. Auth controller + routes

- [ ] 5.1 `config/routes.rb`：
  ```
  namespace :api do
    scope :auth do
      post :register, to: 'auth#register'
      post :login, to: 'auth#login'
      post :logout, to: 'auth#logout'
      scope :password do
        post :forgot, to: 'auth#forgot_password'
        post :reset, to: 'auth#reset_password'
      end
    end
  end
  ```
- [ ] 5.2 新 `app/controllers/api/auth_controller.rb`：
  - `skip_before_action :authenticate!, only: [:register, :login, :forgot_password, :reset_password]`（logout 需 auth；其他 public）
  - `#register`：params `email, password, name` → `User.create!(role: 'superadmin', status: 'active', ...)` → 回 `{ user: {...}, token: JwtService.encode(user_id: user.id) }` status 201；重複 email 回 422
  - `#login`：params `email, password` → `User.find_by(email: email.downcase)` → `user&.authenticate(password)` → 成功回 `{ user, token }` + 更新 `last_login_at`；失敗回 401 `{ error: 'invalid_credentials' }`
  - `#logout`：`head :no_content`（stateless；前端負責清 token）
  - `#forgot_password`：params `email` → user 存在 → `PasswordResetToken.generate_for(user)` → `UserMailer.password_reset(user, raw_token).deliver_later` → 一律回 202 `{ message: 'If the email exists, a reset link has been sent.' }`（見 design.md Decision 5）
  - `#reset_password`：params `token, new_password` → `PasswordResetToken.find_valid_by_raw(token)` → nil 回 400 `{ error: 'invalid_or_expired_token' }` → 找到則 `token.user.update!(password: new_password)` + `token.update!(used_at: Time.current)` → 回 200 `{ user, token: <new JWT> }`（reset 完自動登入，見 Decision）
- [ ] 5.3 加 user serializer：`user.as_json(only: [:id, :email, :name, :role, :status])`（放 controller 內 private method 即可，MVP 不用 blueprint 之類）

## 6. UserMailer（stub 版）

- [ ] 6.1 `bin/rails g mailer UserMailer password_reset`
- [ ] 6.2 `app/mailers/user_mailer.rb#password_reset(user, raw_token)`：
  - `@reset_url = "#{Rails.configuration.frontend_base_url}/reset-password?token=#{raw_token}"`
  - **stub 版**：`Rails.logger.info "[MVP-stub] Password reset URL for #{user.email}: #{@reset_url}"`；`mail` 呼叫改為 `return true`（避免 SMTP 連線）
  - 加 comment：`# TODO(stage-b-9-smtp): 接 SMTP 後恢復 mail() call`
- [ ] 6.3 `config/application.rb` 或新 initializer 設 `config.frontend_base_url = ENV.fetch('FRONTEND_BASE_URL', 'http://localhost:5173')`

## 7. DB seeds

- [ ] 7.1 `db/seeds.rb`：建立 3 個 dev-only user 對齊 `frontend/src/mocks/users.json`
  - `admin@example.com` role `superadmin` password `password123`
  - `ming@example.com` role `employee` password `password123`
  - `zhang@example.com` role `employee` password `password123`
- [ ] 7.2 `bin/rails db:seed`；rails console 驗 `User.count == 3`

## 8. Backend 手動 QA（curl / Postman）

- [ ] 8.1 `bin/rails s`
- [ ] 8.2 註冊：`curl -X POST http://localhost:3000/api/auth/register -H 'Content-Type: application/json' -d '{"email":"new@example.com","password":"password123","name":"New User"}'` → 201 + `token`
- [ ] 8.3 登入：`curl -X POST http://localhost:3000/api/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@example.com","password":"password123"}'` → 200 + `token`
- [ ] 8.4 錯密碼：登入用錯 password → 401
- [ ] 8.5 忘記密碼：`curl -X POST http://localhost:3000/api/auth/password/forgot -d '{"email":"admin@example.com"}'` → 202；`tail log/development.log` 看到 `[MVP-stub] Password reset URL: ...` 印出
- [ ] 8.6 從 log 抓 raw token，reset：`curl -X POST http://localhost:3000/api/auth/password/reset -d '{"token":"<raw>","new_password":"newpass1234"}'` → 200；再用新密碼登入成功
- [ ] 8.7 過期 token：手動於 rails console `PasswordResetToken.last.update(expires_at: 1.hour.ago)` → reset endpoint 回 400
- [ ] 8.8 二次使用：同一 token reset 兩次 → 第二次回 400
- [ ] 8.9 帳號枚舉防護：forgot 用不存在 email → 一樣回 202（不揭露）

## 9. Frontend API 契約檔

- [ ] 9.1 新 `frontend/src/api/auth.ts`：
  - `interface RegisterRequest { email; password; name; }`
  - `interface LoginRequest { email; password; }`
  - `interface LoginResponse { user: UserDTO; token: string; }`
  - `interface ForgotPasswordRequest { email; }`
  - `interface ForgotPasswordResponse { message: string; }`
  - `interface ResetPasswordRequest { token; newPassword; }`
  - `interface ResetPasswordResponse { user: UserDTO; token: string; }`
  - 各 interface JSDoc 註明 endpoint path + method + status codes + 帳號枚舉防護策略
  - export `AUTH_TOKEN_STORAGE_KEY = 'quickey.auth.token'` 常數（Stage C 用）

## 10. Frontend UI — Forgot / Reset views

- [ ] 10.1 新 `frontend/src/views/ForgotPasswordView.vue`（**放頂層 views/，非 front/ 或 admin/**，因為未登入態共用）：
  - 標題「忘記密碼」+ 說明文字
  - Email InputText + label「Email」+ 必填驗證
  - 送出按鈕 → 呼叫 `authStore.forgotPassword(email)` → 一律顯示訊息「若該 email 已註冊，重設連結已寄出，請至信箱查看」+ 「回登入」連結
  - a11y：`<label for>`、送出時 disable 按鈕、Esc 不觸發任何動作（純表單）
- [ ] 10.2 新 `frontend/src/views/ResetPasswordView.vue`（path `/reset-password?token=xxx`）：
  - `onMounted` 讀 `route.query.token`；缺 token → 顯示「連結無效或已過期」+ 「回登入」連結
  - 表單：新密碼 + 確認新密碼 兩個 Password 欄；至少 8 字驗證、兩個一致驗證
  - 送出 → `authStore.resetPassword(token, newPassword)` → 成功 toast「密碼已重設」→ 導向 `/`（前台首頁）
  - 失敗（過期 / 已用）→ inline error「連結無效或已過期，請重新申請」+ 顯示「回忘記密碼頁」連結
- [ ] 10.3 兩個 view 都用 `PageHeader` 元件保持與現有登入頁一致的視覺
- [ ] 10.4 手機版符合 CLAUDE.md 14px 原則

## 11. Frontend Login views 加「忘記密碼？」連結

- [ ] 11.1 `frontend/src/views/front/LoginView.vue`：登入按鈕下方加 `<router-link to="/forgot-password">忘記密碼？</router-link>`
- [ ] 11.2 `frontend/src/views/admin/LoginView.vue`：同上

## 12. Frontend Router

- [ ] 12.1 `frontend/src/router/index.ts` 加兩條 public route：
  - `{ path: '/forgot-password', component: () => import('@/views/ForgotPasswordView.vue'), meta: { public: true } }`
  - `{ path: '/reset-password', component: () => import('@/views/ResetPasswordView.vue'), meta: { public: true } }`
- [ ] 12.2 確認 `beforeEach` 的 auth guard 對 `meta.public === true` 的 route 放行

## 13. Frontend auth store（mock 階段）

- [ ] 13.1 `frontend/src/stores/auth.ts` 加 action `forgotPassword(email)`：mock 版直接 return `{ ok: true }`；註解「Stage C 換 fetch」
- [ ] 13.2 `frontend/src/stores/auth.ts` 加 action `resetPassword(token, newPassword)`：mock 版接受任何非空 token；password 長度 < 8 → return `{ ok: false, error: 'TOO_SHORT' }`；否則 `{ ok: true }`

## 14. 流程 doc 更新

- [ ] 14.1 `docs/實作流程.md` §六 Stage B 「建議順序」 item 1 加註「進行中 add-auth-module」

## 15. Frontend 手動 QA（前端 mock 態）

- [ ] 15.1 前端 `pnpm dev` → 登入頁「忘記密碼？」連結可點
- [ ] 15.2 `/forgot-password` 輸 email → 送出 → 訊息顯示正確
- [ ] 15.3 手動貼 `/reset-password?token=fake` → 表單顯示、密碼太短驗證觸發、送出 → 導首頁
- [ ] 15.4 手動貼 `/reset-password`（無 token） → 顯示無效連結頁
- [ ] 15.5 手機版兩頁 layout 不歪
