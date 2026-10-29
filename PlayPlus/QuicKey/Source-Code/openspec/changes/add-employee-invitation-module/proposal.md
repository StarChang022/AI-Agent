## Why

MVP 需要 admin 能自行擴充公司員工名單，讓員工能上前台登入送出代墊款請款；目前 `views/admin/UsersView.vue` 只提供「直接建立帳號並填密碼」的臨時流程，違反 PRD「以 email 邀請連結、由員工自訂密碼」的最終流程（`docs/資料模型.md` §5.3、`docs/產品延伸分工討論.md` §4），且缺少「員工上限 10 人」的強制約束與「未接受邀請」的暫留狀態，無法安全交付給第一批客戶。此 change 對應 `docs/實作流程.md` §五 Phase 5，把邀請 → 接受 → 自動登入的完整流程做進來、並讓 UsersView 從「帳密建帳號」轉為「邀請 + 撤回」為主的操作模型。

同時本 change 順手完成兩件與員工帳號直接相關的清理工作：（1）**下架部門欄位**——MVP 不做部門功能（見 `docs/實作流程.md` §九「超出 MVP 範圍」與 `docs/sitemap.md` 第 19 列），現行 code 有 `Department` type、`departments.json` seed、UsersView / RecordsView 部門選單、Payout / Review / AdminExpenseDetail 顯示部門欄，全部一次清掉避免未來累積技術債；（2）**新增員工前台修改密碼頁**——為了配合「管理員不能重設員工密碼」的設計取捨（見 design.md Decision 14），員工必須要有自助修改密碼的入口，否則忘記密碼就完全鎖死。

## What Changes

### 主線：邀請員工模組

- **新增 `Invitation` domain type 與 User.status 欄位**：
  - `types/domain.ts`：新增 `Invitation` interface（`id / email / name / token / expiresAt / acceptedAt / revokedAt / invitedByUserId / createdAt`）；`User` 加 `status: 'active' | 'invited' | 'suspended' | 'left'`（欄位定義對齊 `docs/資料模型.md` §3.2、§3.3）
  - `mocks/users.json`：既有 4 筆 seed 補上 `status: 'active'`；同時拿掉 `departmentId` 欄位（見下方部門下架章節）
  - `mocks/invitations.json`：3 筆 seed 涵蓋「有效未接受」「已過期」「已撤回」三種狀態，供 UsersView 呈現與 Accept 頁錯誤分類驗收使用
- **新增 `stores/invitations.ts`**：`useInvitationsStore`；action `create({ email, name })`、`revoke(id)`、`accept({ token, password })`、query `findByToken(token)`、`findValidByEmail(email)`、computed `activeInvitations`（未接受、未撤回、未過期）；STORAGE_KEY `quickey.invitations.v1`；`watch(invitations, deep, save)`；`create` 內部呼叫 `useUsersStore().canInviteMore()` 檢查總員工數（`active + invited`）是否 ≥ 10
- **調整 `stores/users.ts`**：`create` 內部設 `status: 'active'`；新增 query `activeAndInvitedCount()`、`canInviteMore()`；`updatePassword(id, newPassword)` action（供員工前台修改密碼使用；驗舊密碼由 view 端負責）；`normalizeUser` 補齊舊 seed 缺 `status` 欄位並移除 `departmentId`
- **改寫 `views/admin/UsersView.vue`**：
  - 拿掉「新增人員」的 email/password 快建流程，改為「邀請員工」Dialog（填 email + name；不填密碼）
  - 拿掉「重設密碼」按鈕（見 design.md Decision 14；改由員工前台自助）
  - 拿掉「部門」欄與部門選單（部門下架，見下方章節）
  - 「編輯」按鈕保留，可改姓名與 role（不改 email，不改密碼）
  - 表格增列「已邀請」rows：欄位對齊「姓名 / Email / 狀態（Tag `使用中` / `已邀請`）/ 操作」；有效未接受邀請 row 的操作只提供「複製邀請連結」與「撤回邀請」
  - 頁頂顯示「員工名額：X / 10」；達上限時「邀請員工」按鈕 disabled 並附 tooltip
  - 「複製邀請連結」透過 `navigator.clipboard.writeText` 複製並跳 toast；失敗時 fallback 為 prompt 顯示 URL
- **新增 `views/InvitationAcceptView.vue` + public route `/invite/accept`**：
  - 驗 URL query `token`：無 token、找不到、已過期、已撤回、已接受、已登入身分 → 各自對應錯誤畫面
  - Token 有效 → 顯示唯讀 email + 唯讀姓名（由邀請時 admin 填）+ 密碼 + 確認密碼；提交呼叫 `invitations.accept`，內部建立 status='active' 的 User + 標 `acceptedAt` + 呼叫 `auth.login(email, password)` 自動登入
  - 已登入身分開啟 → 提示「請先登出再開啟邀請連結」+ 「登出」按鈕
- **新增 `frontend/src/api/invitations.ts`**：TS-only 契約
- **新增 `docs/QA_list/QA_邀請員工.md`**：涵蓋邀請 / 撤回 / 名額 / 重複 email / Accept 各種情境
- **同步 `docs/實作流程.md`**：§三 進度表 Phase 5 「邀請員工」列狀態改 ✅（附今日日期）

### 附帶：員工前台修改密碼

- **新增 `views/front/AccountView.vue` + route `/app/account`**（掛在 FrontLayout 底下）：
  - 「修改密碼」表單：舊密碼 + 新密碼 + 確認密碼；舊密碼與 store 內密碼比對；不符顯示錯誤
  - 提交成功呼叫 `users.updatePassword(currentUser.id, newPassword)` + toast「密碼已更新」；不強制重新登入
- **FrontLayout sidebar 加「帳號設定」入口**：icon `pi pi-user-edit`，導向 `front-account`
- **新增 `frontend/src/api/users.ts`**：追加 `ChangePasswordRequest`（`{ oldPassword, newPassword }`）契約；MVP 只此一個 endpoint 型別
- QA `docs/QA_list/QA_邀請員工.md` 內含「員工前台修改密碼」章節（不另開檔）

### 附帶：部門功能下架

- **移除 domain type**：`types/domain.ts` 刪除 `Department` interface 與 `User.departmentId` 欄位
- **刪除 seed**：`mocks/departments.json` 整檔刪除
- **簡化 utils**：`utils/approval.ts` 移除 `_departments: Department[]` 參數與 import；同步 `stores/reimbursements.ts` 移除 `departmentsData` import 與傳參
- **UI 清理**：以下 view 移除部門欄與相關 helper
  - `views/admin/UsersView.vue`（原「部門」欄、Dialog 部門選單、驗證）
  - `views/admin/RecordsView.vue`（部門篩選欄、部門顯示欄、`departmentId` 相關 draft/applied 欄位）
  - `views/admin/ReviewView.vue`（部門顯示欄）
  - `views/admin/PayoutView.vue`（部門顯示欄）
  - `components/AdminExpenseDetail.vue`（詳情頁部門欄）

**Non-goals**（明確不做）：
- 真正的 email 寄送（Stage B 後端 SMTP / Resend 整合）；prototype 一律以「複製邀請連結」代替
- 忘記密碼 email 重設流程（Stage B）；MVP 員工需牢記密碼或由管理員「刪除後重新邀請」
- 批次邀請（一次多個 email）
- 邀請連結可自訂過期時間；固定 3 天
- Email 通知記錄頁（Phase 7 才做）
- 部門功能（本 change 拿掉的東西未來若要復活需另開 change）
- 員工個人資料頁的其他欄位（電話、大頭照等）；本 change 只做修改密碼
- 修改密碼強度規則細分（僅要求 ≥ 8 碼、與舊密碼不同；不強制大小寫混合）

## Capabilities

### New Capabilities

- `employee-invitation`：管理員以 email 邀請員工加入公司、被邀請人透過連結設密碼並自動登入的能力
- `user-profile`：員工於前台自行維護個人帳號設定（MVP 只含修改密碼）的能力

### Modified Capabilities

（無：`admin-navigation` 中「員工管理」項目本次不動；部門欄位下架屬純 UI 清理，openspec/specs/ 下未曾為部門建立 capability，因此無 spec 需修改）

## Impact

- **前端 code**：
  - 新檔：`frontend/src/mocks/invitations.json`、`frontend/src/stores/invitations.ts`、`frontend/src/api/invitations.ts`、`frontend/src/api/users.ts`、`frontend/src/views/InvitationAcceptView.vue`、`frontend/src/views/front/AccountView.vue`、`docs/QA_list/QA_邀請員工.md`
  - 修改：`frontend/src/types/domain.ts`（新增 `Invitation`、`User.status`；**移除** `Department`、`User.departmentId`）、`frontend/src/stores/users.ts`（新增 `activeAndInvitedCount` / `canInviteMore` / `updatePassword` / `normalizeUser`；移除 create/update 的 departmentId 處理）、`frontend/src/stores/reimbursements.ts`（移除 `departmentsData` import 與傳參）、`frontend/src/utils/approval.ts`（移除 `Department[]` 參數）、`frontend/src/mocks/users.json`（補 status、移除 departmentId）、`frontend/src/views/admin/UsersView.vue`（改寫）、`frontend/src/views/admin/RecordsView.vue`（移除部門篩選與欄）、`frontend/src/views/admin/ReviewView.vue`（移除部門欄）、`frontend/src/views/admin/PayoutView.vue`（移除部門欄）、`frontend/src/components/AdminExpenseDetail.vue`（移除部門顯示）、`frontend/src/router/index.ts`（加 `/invite/accept` public route 與 `front-account` route）、`frontend/src/layouts/FrontLayout.vue`（sidebar 加「帳號設定」）
  - 刪除：`frontend/src/mocks/departments.json`
- **對其他模組的資料依賴**：`invitations` store 於 `create` / `accept` 呼叫 `useUsersStore()` 檢查上限與建立 User；`users.activeAndInvitedCount` 反向讀 `invitations.activeInvitations`（單向依賴 OK，無循環）
- **API 契約**：新增 `POST /invitations`、`GET /invitations`、`DELETE /invitations/:id`、`GET /invitations/by-token/:token`（public）、`POST /invitations/by-token/:token/accept`（public）、`PATCH /users/me/password`（新加，供修改密碼用）；後端 MVP 不含（Stage B 才實作）
- **資料持久化**：新增 localStorage key `quickey.invitations.v1`
- **文件**：`docs/QA_list/QA_邀請員工.md` 為本 change 產出；`docs/實作流程.md` §三 進度表勾選；`docs/資料模型.md` 已對齊，不需變動
