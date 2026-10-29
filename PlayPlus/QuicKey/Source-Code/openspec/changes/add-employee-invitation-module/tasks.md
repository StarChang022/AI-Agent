## 1. Type / Domain

- [x] 1.1 `frontend/src/types/domain.ts`：新增 `Invitation` interface（`id / email / name / token / expiresAt / acceptedAt: string | null / revokedAt: string | null / invitedByUserId: string | null / createdAt`）；JSDoc 引用 `docs/資料模型.md` §3.3 與 Decision 2 / 3 / 8
- [x] 1.2 `User` 加 `status: 'active' | 'invited' | 'suspended' | 'left'`；JSDoc 說明 MVP 實際只用 `active`；註記 `invited` 於 users store 內不會出現（見 Decision 1 / 9）
- [x] 1.3 移除 `Department` interface 與 `User.departmentId` 欄位（Decision 16）；同步刪除相關 JSDoc

## 2. Mock 資料

- [x] 2.1 `frontend/src/mocks/users.json`：既有 4 筆 seed 補 `status: "active"`；同時移除 `departmentId` 欄位
- [x] 2.2 刪除 `frontend/src/mocks/departments.json` 整檔
- [x] 2.3 新增 `frontend/src/mocks/invitations.json`：3 筆 seed
  - 1 筆「有效未接受」：`email: "pending@example.com"`, `name: "待入職"`, `token: "seed-token-pending"`, `expiresAt` 為今日 + 2 天, 其餘為 null / 現在
  - 1 筆「已過期」：`email: "expired@example.com"`, `name: "過期邀請"`, `token: "seed-token-expired"`, `expiresAt` 為今日 − 1 天
  - 1 筆「已撤回」：`email: "revoked@example.com"`, `name: "已撤回"`, `token: "seed-token-revoked"`, `revokedAt` 為今日 − 1 天

## 3. Invitations store

- [x] 3.1 新增 `frontend/src/stores/invitations.ts`：`useInvitationsStore`；STORAGE_KEY `quickey.invitations.v1`；load from localStorage or seed；`watch(invitations, deep, save)`
- [x] 3.2 `normalizeInvitation` 補齊 legacy shape
- [x] 3.3 computed `activeInvitations`：filter `acceptedAt == null && revokedAt == null && new Date(expiresAt) > new Date()`（Decision 4）
- [x] 3.4 query `findByToken(token)`：回傳 raw Invitation（含過期 / 撤回），呼叫端自行分派錯誤畫面
- [x] 3.5 query `findValidByEmail(email)`：於 `activeInvitations` 內以 email（case-insensitive）查詢
- [x] 3.6 action `create({ email, name })`（Decision 7）：
  - email trim + lowercase 後檢查格式（`/^[^\s@]+@[^\s@]+\.[^\s@]+$/`）→ 不合法 return `{ ok: false, error: 'INVALID_EMAIL' }`
  - 呼叫 `useUsersStore().canInviteMore()` → false 則 return `{ ok: false, error: 'AT_LIMIT' }`
  - 檢查 `useUsersStore().findByEmail(email)` 存在且 `status === 'active'` → return `{ ok: false, error: 'EMAIL_IN_USE' }`
  - 檢查 `findValidByEmail(email)` 存在 → return `{ ok: false, error: 'EMAIL_PENDING' }`
  - 通過 → 產生 `token = crypto.randomUUID()`、`expiresAt = now + 3 days`、`invitedByUserId = useAuthStore().currentUser?.id ?? null`；push；return `{ ok: true, invitation }`
- [x] 3.7 action `revoke(id)`（Decision 8）：找到目標 → 若 `acceptedAt` 非 null return false；否則設 `revokedAt = new Date().toISOString()`
- [x] 3.8 action `accept({ token, password })`（Decision 11 / 15；**不含 name 參數，name 沿用 invitation.name**）：
  - `findByToken(token)`：null → return `{ ok: false, error: 'NOT_FOUND' }`
  - `revokedAt` 非 null → return `{ ok: false, error: 'REVOKED' }`
  - `acceptedAt` 非 null → return `{ ok: false, error: 'ALREADY_USED' }`
  - `new Date(expiresAt) < new Date()` → return `{ ok: false, error: 'EXPIRED' }`
  - 通過 → 呼叫 `useUsersStore().create({ name: invitation.name, email: invitation.email, password, role: 'employee', status: 'active' })` 拿到 user；設 `invitation.acceptedAt = new Date().toISOString()`；return `{ ok: true, user, email: invitation.email }`
- [x] 3.9 全檔 JSDoc 註解引用 `docs/資料模型.md` §3.3、§5.3 與 design.md Decision 1 / 2 / 3 / 4 / 7 / 8 / 11 / 15

## 4. Users store 調整

- [x] 4.1 `frontend/src/stores/users.ts`：`create` 型別移除 `departmentId`；內部強制 `status: 'active'`（若 caller 未傳）
- [x] 4.2 `update` 型別移除 `departmentId`；只允許改 `name`、`role`（不允許改 email / password）
- [x] 4.3 移除既有 `resetPassword` action（Decision 14）
- [x] 4.4 新增 action `updatePassword(id, newPassword)`：找到 user 直接寫入新密碼；找不到 return false（舊密碼驗證由 view 端負責）
- [x] 4.5 `normalizeUser` 補齊舊 seed 缺 `status` 欄位（fallback `'active'`）；移除 `departmentId` 欄位
- [x] 4.6 query `activeAndInvitedCount()`：回傳「users 中 role='employee' 且 status='active' 的人數」+「invitations store activeInvitations 中 email 尚未在 users 出現的筆數」；`import { useInvitationsStore } from './invitations'`
- [x] 4.7 query `canInviteMore()`：`activeAndInvitedCount() < 10`

## 5. 部門功能下架（Decision 16）

- [x] 5.1 `frontend/src/utils/approval.ts`：移除 `Department` import 與 `buildApprovalProgress` 的 `_departments: Department[]` 參數；同步更新函式簽章與 JSDoc
- [x] 5.2 `frontend/src/stores/reimbursements.ts`：移除 `import departmentsData from '@/mocks/departments.json'`；兩處 `buildApprovalProgress(filer, users.all, departmentsData)` 改為 `buildApprovalProgress(filer, users.all)`
- [x] 5.3 `frontend/src/views/admin/RecordsView.vue`：移除 `departmentsData` import、`departmentOptions` computed、`draft.departmentId` / `applied.departmentId` 欄位、部門篩選 Select、部門顯示欄、`employeeDepartmentId` / `departmentName` helper；同步更新 `activeFiltersCount` 邏輯（少一個維度）
- [x] 5.4 `frontend/src/views/admin/ReviewView.vue`：移除 `departmentsData` import、部門顯示欄、`employeeDepartmentId` / `departmentName` helper
- [x] 5.5 `frontend/src/views/admin/PayoutView.vue`：移除 `departmentsData` import、部門顯示欄、`employeeDepartmentId` / `departmentName` helper
- [x] 5.6 `frontend/src/components/AdminExpenseDetail.vue`：移除 `departmentsData` import、`departmentNameOf` helper、詳情頁「部門」欄

## 6. Router 與 Public route

- [x] 6.1 `frontend/src/router/index.ts`：top-level 加 `{ path: '/invite/accept', name: 'invitation-accept', meta: { public: true }, component: () => import('@/views/InvitationAcceptView.vue') }`
- [x] 6.2 `frontend/src/router/index.ts`：FrontLayout children 加 `{ path: 'account', name: 'front-account', component: () => import('@/views/front/AccountView.vue') }`
- [x] 6.3 確認 `beforeEach` 對 `isPublic` 分支已允許未登入訪客訪問（既有行為，無需改動）

## 7. InvitationAcceptView 新頁

- [x] 7.1 新增 `frontend/src/views/InvitationAcceptView.vue`（Decision 5：不套用任何 layout；頁面自帶 minimal chrome + 卡片）
- [x] 7.2 引入：`useRoute`, `useRouter`, `useInvitationsStore`, `useAuthStore`, `useToast`；PrimeVue Button / InputText / Password / Message
- [x] 7.3 從 `route.query.token` 取 token；`ref` `state` 為以下六態之一：`'ready'` / `'not_found'` / `'expired'` / `'revoked'` / `'already_used'` / `'logged_in'`
- [x] 7.4 computed state：優先判 `auth.isLoggedIn` → `'logged_in'`；否則 `findByToken` + status 分派；`invitation` 保留給表單預填
- [x] 7.5 form state：`password`、`passwordConfirm`；`formError: string`（**無 name 欄位**，Decision 15）
- [x] 7.6 `validate()`：`password.length < 8` → 「密碼長度至少 8 碼」；`password !== passwordConfirm` → 「兩次輸入的密碼不同」
- [x] 7.7 `submit()`：validate 通過 → `invitations.accept({ token, password })`；`ok=true` → `auth.login(email, password)` → 成功則 `router.replace({ name: 'front-home' })`；auto-login 失敗 fallback toast + 保留頁面
- [x] 7.8 logged_in 狀態：顯示 warning 卡片 + 「登出」按鈕；點擊呼叫 `auth.logout()`（Decision 6）
- [x] 7.9 錯誤狀態卡片：not_found / expired / revoked 顯示對應文案；already_used 附「前往登入」連結導 `/login`
- [x] 7.10 表單 email 欄與姓名欄以唯讀 InputText 或純文字呈現（Decision 15）；姓名下方附輔助文字「若姓名有誤，請聯絡貴公司管理員」
- [x] 7.11 卡片樣式：使用既有 `.card` utility class + design tokens；頁面 min-h-screen bg-neutral 底色置中；顯示 Quickey logo + 標題
- [x] 7.12 手機字級檢查：表單 label / 按鈕 / input ≤ 14px

## 8. 員工前台 AccountView 新頁

- [x] 8.1 新增 `frontend/src/views/front/AccountView.vue`（掛在 FrontLayout 下）
- [x] 8.2 引入 `useAuthStore`, `useUsersStore`, `useToast`；PrimeVue InputText / Password / Button / Message
- [x] 8.3 PageHeader title="帳號設定" size="front"（或依 FrontLayout 現有 header pattern）
- [x] 8.4 顯示當前登入帳號 email（唯讀）與姓名（唯讀）作為身份確認
- [x] 8.5 「修改密碼」表單：三個 password input（舊、新、確認新）；每欄 `<label for>` 綁定
- [x] 8.6 `validate()`（依 `user-profile` spec）：
  - 舊密碼與 `auth.currentUser.password` 比對；不符 → 「舊密碼不正確」
  - 新密碼 `< 8` → 「新密碼長度至少 8 碼」
  - 新密碼 === 舊密碼 → 「新密碼不可與舊密碼相同」
  - 新密碼 !== 確認新密碼 → 「兩次輸入的新密碼不同」
- [x] 8.7 `submit()`：validate 通過 → `users.updatePassword(currentUser.id, newPassword)` + toast「密碼已更新」；不登出；清空三個欄位
- [x] 8.8 FrontLayout `layouts/FrontLayout.vue`：sidebar 加「帳號設定」nav item，icon `pi pi-user-edit`，`to: { name: 'front-account' }`
- [x] 8.9 手機字級檢查

## 9. UsersView 改寫

- [x] 9.1 `frontend/src/views/admin/UsersView.vue`：改寫「新增人員」為「邀請員工」按鈕；PageHeader actions icon `pi pi-user-plus`
- [x] 9.2 引入 `useInvitationsStore`；PageHeader 下方顯示「員工名額：X / 10」computed
- [x] 9.3 邀請按鈕 disabled 條件：`!users.canInviteMore()`；附 tooltip「已達員工上限 10 人」
- [x] 9.4 `rows` computed（Decision 12）：`usersActive`（filter role/status）依 name 排序 + `kind: 'user'`；concat `invitations.activeInvitations` 依 email 排序 + `kind: 'invitation'`；discriminated union type
- [x] 9.5 DataTable 欄位：姓名 / Email / 狀態 / 操作（**移除部門欄**）
- [x] 9.6 狀態欄：`kind === 'user'` → Tag 「使用中」severity="success"；`kind === 'invitation'` → Tag 「已邀請」severity="info"
- [x] 9.7 操作欄 template v-if 分派
  - `kind === 'user'`：[編輯 / 刪除] 兩顆（**移除「重設密碼」**，Decision 14）
  - `kind === 'invitation'`：[複製邀請連結 / 撤回邀請] 兩顆
- [x] 9.8 「複製邀請連結」handler（Decision 10）：組 `${window.location.origin}/invite/accept?token=${token}` → `navigator.clipboard.writeText` + toast；catch 走 prompt fallback
- [x] 9.9 「撤回邀請」handler：`useConfirm().require`，message「確定撤回對 {email} 的邀請？」，acceptLabel「確認撤回」severity="danger"；accept → `invitations.revoke(id)` + toast
- [x] 9.10 邀請 Dialog（取代原本 create 分支）：`v-model:visible`；欄位 email + name；提交呼叫 `invitations.create({ email, name })`
- [x] 9.11 邀請 Dialog 錯誤處理：
  - `INVALID_EMAIL` → 「Email 格式不正確」
  - `AT_LIMIT` → 「已達員工上限 10 人，請先撤回既有邀請或移除員工」
  - `EMAIL_IN_USE` → 「該 email 已是公司員工」
  - `EMAIL_PENDING` → 「該 email 已有有效邀請，請先撤回既有邀請再重發」
- [x] 9.12 邀請 Dialog 成功流程：`ok=true` 時關閉 Dialog、toast「已發送邀請」
- [x] 9.13 「編輯人員」Dialog：**只保留姓名 + role 兩個可編輯欄位**（移除 email 編輯、移除部門、移除密碼）；Email 以唯讀 label 顯示
- [x] 9.14 拿掉原「新增人員」的 `dialogMode = 'create'` 分支與 `openCreate` 函數；拿掉「重設密碼」的 `dialogMode = 'resetPassword'` 分支、`openResetPassword`、`passwordForm`、`submitResetPassword`
- [x] 9.15 拿掉 `departmentsData` import、`departmentOptions`、`departmentLabel`、部門相關驗證邏輯
- [x] 9.16 手機檢查：確保操作按鈕於 375px viewport 可點

## 10. API 契約

- [x] 10.1 新增 `frontend/src/api/invitations.ts`：只 export TS 型別；檔頭 JSDoc 引用 `docs/資料模型.md` §3.3、§5.3
- [x] 10.2 `InvitationDTO`：server → client 資源；欄位對齊 `Invitation` interface
- [x] 10.3 `CreateInvitationRequest`：`POST /invitations`；body `{ email, name }`；JSDoc 標記後端 MUST 檢查 email 格式、名額（409 `AT_LIMIT`）、email in use（409 `EMAIL_IN_USE`）、email pending（409 `EMAIL_PENDING`）
- [x] 10.4 `ListInvitationsQuery`：`GET /invitations`；filter `includeInactive?: boolean`
- [x] 10.5 `RevokeInvitationResponse`：`DELETE /invitations/:id`；後端 MUST 檢查 acceptedAt=null（否 409）
- [x] 10.6 `GetInvitationByTokenResponse`：`GET /invitations/by-token/:token`（public）；response `{ status: 'valid' | 'expired' | 'revoked' | 'already_used' | 'not_found'; email?; name?; expiresAt? }`
- [x] 10.7 `AcceptInvitationRequest`：`POST /invitations/by-token/:token/accept`（public）；body **`{ password }`**（無 name，Decision 15）；JSDoc 標記後端 MUST 於單一 transaction 內驗 token + create User（name 沿用 Invitation.name）+ set acceptedAt + issue auth token
- [x] 10.8 `AcceptInvitationResponse`：`{ user: UserDTO; authToken: string }`
- [x] 10.9 新增 `frontend/src/api/users.ts`：`ChangePasswordRequest`（`{ oldPassword, newPassword }`）與 `ChangePasswordResponse`（`Record<string, never>`）對應 `PATCH /users/me/password`；JSDoc 標記後端 MUST 驗舊密碼、新密碼長度 ≥ 8、新密碼 ≠ 舊密碼

## 11. QA checklist

- [x] 11.1 新增 `docs/QA_list/QA_邀請員工.md`，涵蓋：
  - 1. 頁面總覽（進入員工管理、名額顯示、按鈕 disabled、無部門欄）
  - 2. 邀請員工（開 Dialog、成功發送、email 格式錯誤、email 已在名單、email 已有邀請、名額已滿）
  - 3. 複製邀請連結（一般複製、剪貼簿權限失敗 fallback）
  - 4. 撤回邀請（Confirm 二次確認、確認後從列表消失、名額釋放、Accept 頁顯示已撤回）
  - 5. 編輯員工（只能改姓名 / role；Email、密碼、部門不出現）
  - 6. Accept 頁 - 錯誤情境（無 token / 未知 token / 過期 / 撤回 / 已使用）
  - 7. Accept 頁 - 成功流程（email 與姓名唯讀、密碼驗證、submit 自動登入導首頁）
  - 8. Accept 頁 - 姓名唯讀行為（嘗試改姓名不接受輸入、附輔助說明）
  - 9. Accept 頁 - 已登入身分（顯示提示、登出後可繼續、原身分不被偷偷登出）
  - 10. 員工前台修改密碼（sidebar 有「帳號設定」入口、舊密碼錯 / 新密碼太短 / 新舊相同 / 兩次不同 / 成功修改 / 修改後可用新密碼登入）
  - 11. 資料保留（重整、關閉瀏覽器）
  - 12. 混合列表（3 位員工 + 2 筆邀請共 5 列、狀態欄不同、操作欄不同）
  - 13. 部門下架（RecordsView 無部門篩選、ReviewView / PayoutView / 詳情頁無部門顯示欄）
  - 14. 已知限制（員工忘記密碼 → admin 只能刪除後重邀、代墊款關聯會斷）

## 12. 進度文件同步

- [x] 12.1 `docs/實作流程.md` §三 進度表：Phase 5 「邀請員工」列狀態改 ✅（附今日日期 2026-09-17）；加註「同 change 附帶完成部門下架 + 員工前台修改密碼」
- [x] 12.2 `docs/實作流程.md` §九「超出 MVP 範圍」若有部門相關描述需同步（若無則跳過）

## 13. 手動驗收

- [x] 13.1 執行 `pnpm build` 確認 TypeScript 型別檢查通過（含部門移除後全 codebase 無 dangling reference）
- [ ] 13.2 執行 `pnpm dev`，以 admin@example.com 登入後台 → 進入「員工管理」→ 依 QA checklist 逐條核對
- [ ] 13.3 手機模擬（DevTools 375px）確認邀請 Dialog、複製 / 撤回按鈕、Accept 頁、AccountView 均可操作
- [ ] 13.4 開新 incognito 分頁測試 Accept 流程：admin 開 UsersView 複製連結 → 貼 incognito → 完成表單 → 自動登入 `/app/home`
- [ ] 13.5 以 employee 登入前台 → 「帳號設定」→ 修改密碼 → 登出 → 用新密碼登入成功
- [ ] 13.6 驗收部門下架：RecordsView 篩選面板無部門選項；Review / Payout / 支出詳情頁無部門欄
