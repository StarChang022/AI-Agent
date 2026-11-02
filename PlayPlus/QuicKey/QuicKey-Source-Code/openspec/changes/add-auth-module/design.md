## Context

Stage B 起手第一個 change。前置 `feat/backend-scaffold` 剛完成 Rails 8 API-only + PostgreSQL 骨架。此 change 從空骨架開始寫第一個 domain（Auth），同時把前端未登入態的「忘記密碼」流程 UI 補齊（前端 mock 階段，Stage C 才真接 API）。

「User 是否建 Company 一起」是關鍵範圍決定：PRD 說 admin 註冊時自動產生公司；但 Auth phase 若把 Company + 多租戶隔離都做進來，PR 會爆炸。此處採取「先做 User only，Company 下一個 change 疊上去」的取捨（見 Decision 1）。

## Goals / Non-Goals

**Goals：**

- 一個完整可跑的 JWT-based auth flow：註冊 → 登入 → 登出 → 忘記密碼 → 重設密碼
- 前端 UI 完備（含 `/forgot-password`、`/reset-password?token=xxx` 兩個 public view）
- 後端 endpoint 對齊未來 Stage C 串接需要的 request / response shape
- 密碼安全：bcrypt hash、token digest（不存 raw token）、rate-limit-friendly response（reset endpoint 不揭露帳號存在與否）
- Peggy（後端新手）能理解每一段 code 的職責

**Non-Goals：**

- Company / 多租戶隔離：留給下一個 change `add-company-module`
- Invitation 流程：屬於 `add-employee-invitation-module`（前端已完成，後端串接留給該 change）
- Email 真的寄出：MVP 用 log stub（Stage B item 9 才接 SMTP）
- Token blacklist / server-side session：MVP 用 stateless JWT，登出僅前端 discard token（見 Decision 4）
- Refresh token：MVP 用單一 access token + 較長 TTL；未來付費階段再加（見 Decision 3）
- Rate limiting on login / forgot：MVP 不做（Stage B 進 Stage C 前另補；用 rack-attack）
- OAuth（Google 登入）：付費階段考量
- 2FA：MVP 不做

## Decisions

### Decision 1：Auth phase 只做 User，Company 拆成下一個 change

- **選擇**：`User` model 先不含 `company_id` FK；register endpoint 只建 User。下一個 change `add-company-module` 補 `Company` model、migration 加 `company_id` FK + backfill、修改 register endpoint 讓它同時建 Company + User。
- **理由**：Auth 本身已涵蓋 5 個 endpoint + JWT + Mailer + 前端 3 個 view/store 修改，範圍不小；把多租戶隔離、Company 建立、Invitation 系統一起做會讓 PR 難審。分階段做每個 PR 都能獨立驗證。
- **代價**：Auth phase 完成的當下，PRD「註冊自動建公司」還沒實現；`add-company-module` 完成前不能真正給客戶用。
- **對前端影響**：前端 `stores/auth.ts` 目前用 mock users（`admin@example.com`），本 change 只加 forgotPassword / resetPassword mock action；Login / Register 的 mock 對後端切換等 Stage C。

### Decision 2：JWT 存 localStorage 而非 httpOnly cookie

- **選擇**：Access token 儲存在瀏覽器 `localStorage`（key `quickey.auth.token`），前端每次 request 自帶 `Authorization: Bearer <token>` header。
- **理由**：
  - MVP 前後端同域部署可預期，httpOnly cookie 也能用；但 localStorage 對前端 dev 較直觀（Peggy 前端熟）
  - CORS 較簡單（不用處理 credentials true + samesite）
  - PWA（Quickey 有裝）配 localStorage 較無跨頁面同步問題
- **代價**：XSS 若發生會直接偷到 token（cookie httpOnly 不會）。緩解：前端不引外部 script、審核依賴、CSP header 於部署時補
- **未來遷移**：若付費階段要 SSO / 跨域，改為 httpOnly cookie；影響面在 `frontend/src/api/client.ts`（Stage C 建）與 `Authenticatable` concern
- **參考**：`frontend/src/api/users.ts` 內註解「`Authorization: Bearer <access_token>`」已預設此策略

### Decision 3：單一 access token，TTL 7 天，不做 refresh token

- **選擇**：`JwtService.sign` payload 含 `user_id`、`exp`（7 天後）、`iat`；不發 refresh token
- **理由**：refresh token 增加至少一個 endpoint + rotation logic + revocation table，MVP 不必要；7 天 TTL 對商用工具體驗尚可接受（每週登入一次）
- **代價**：token 有效期內若被盜用無法主動撤銷（MVP 也沒做 blacklist，屬同一取捨）
- **未來擴充**：升級付費階段時加 refresh token + jti blacklist；`JwtService` interface 已預留 payload 擴充空間

### Decision 4：Logout 不做 server-side blacklist

- **選擇**：`POST /api/auth/logout` 只回 `204`；前端負責清 localStorage token；後端不維護 revoked jti 表
- **理由**：MVP JWT stateless；blacklist 需 Redis / DB 查 + 每次 request 檢查，增加複雜度與延遲。設 7 天 TTL 已控制風險
- **代價**：真被盜 token 直到 exp 前都能用
- **未來擴充**：加 `revoked_tokens` table + Redis cache；`Authenticatable#authenticate!` 內加 `if RevokedTokens.include?(jti) then 401`

### Decision 5：Forgot password endpoint 一律回 202，不揭露 email 是否存在

- **選擇**：`POST /api/auth/password/forgot` 收到 email 後：
  - User 存在 → 產 token → 寄信（stub）→ response `202 { message: 'If the email exists, a reset link has been sent.' }`
  - User 不存在 → 不做任何動作 → response **仍然** `202 { message: 'If the email exists, a reset link has been sent.' }`
- **理由**：防止帳號枚舉攻擊（attacker 用 forgot endpoint 探哪些 email 已註冊）
- **代價**：user 不小心打錯 email 時不會即時得知
- **UX 緩解**：前端 `ForgotPasswordView` 提交後統一顯示「若該 email 已註冊，重設連結已寄出，請至信箱查看」；不區分成功／失敗態

### Decision 6：Reset token 存 digest（SHA-256），不存 raw

- **選擇**：Server 產 32-byte 隨機 raw token → URL 只包 raw token → DB 存 `Digest::SHA256.hexdigest(raw)` 於 `token_digest` 欄位
- **理由**：即使 DB 洩漏，攻擊者拿 digest 換不出 raw token，不能重設密碼
- **實作**：Login endpoint 收 raw token → 算 digest → `PasswordResetToken.find_by(token_digest: digest)` → 驗 `expires_at > Time.current && used_at.nil?`

### Decision 7：Reset token 30 分鐘過期、單次使用

- **選擇**：`PasswordResetToken.expires_at = 30.minutes.from_now`；成功 reset 後 `used_at = Time.current`；同一 token 二次使用回 400
- **理由**：30 分鐘足夠 user 收信 + 點連結；single-use 防止重放攻擊
- **邊界**：user 連按兩次 forgot → 產兩個 token，兩個都有效直到 exp；接受此複雜度，未寫「作廢舊 token」邏輯

### Decision 8：Password 最短 8 字、無強度規則（MVP）

- **選擇**：backend `validates :password, length: { minimum: 8 }`；不強制大小寫混合 / 數字 / 符號
- **理由**：Stage B 快速交付優先；強制規則常增加 UX friction 且未必更安全（passphrase 好）
- **對齊**：`frontend/src/api/invitations.ts` 註解已提「password 長度 ≥ 8」；本 change 保持一致

### Decision 9：Register endpoint MVP 不做 email 驗證（confirm email）

- **選擇**：`POST /api/auth/register` 建立 User 後立即回 login token；不寄 confirm email
- **理由**：MVP 註冊即用；email confirm 加一次 email 往返、attrition 上升
- **未來擴充**：付費階段加 `User.email_verified_at` 欄位 + `POST /api/auth/email/verify` endpoint

### Decision 10：Role 建立時強制為 `superadmin`

- **選擇**：`POST /api/auth/register` 建立的 User `role='superadmin'`（自己註冊 = 開公司的老闆）；`employee` 只能透過 Invitation 建立（另一個 change 的範圍）
- **理由**：與 PRD 一致（`docs/資料模型.md` §3.3 User 角色）；註冊入口不開放 employee 直接自建

## Migration Plan

Prototype 階段無 production migration，dev 階段：

1. `bin/rails db:create` 建 quickey_development
2. `bin/rails db:migrate` 跑 users + password_reset_tokens
3. seeds：`db/seeds.rb` 建立 3 個 dev-only user（對齊 `frontend/mocks/users.json` 的 admin/ming/zhang）方便前後端串接時同帳號能登入

## Open Questions

- Email 從哪個 sender address 寄？→ MVP stub 階段不需要；接 SMTP 時再決定（Gmail 用 `noreply@<your-domain>` 需先設 domain）
- Password reset 連結 base URL 是 `http://localhost:5173`（dev）還是後端提供？→ 建議 `Rails.application.config.frontend_base_url`（env var 覆寫）；本 change 內設 default `http://localhost:5173`
- JWT 演算法 HS256 vs RS256？→ MVP 選 HS256（單一 secret，較簡單）；未來多服務時再改 RS256
- Register 時要不要收 `name` 欄位？→ 是；PRD `User` 有 name 欄位；註冊表單同時填
