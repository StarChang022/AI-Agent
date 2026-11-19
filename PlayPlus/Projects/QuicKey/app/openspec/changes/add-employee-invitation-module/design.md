## Context

見 `proposal.md`（Why、What Changes）與 `specs/employee-invitation/spec.md`（Requirements）。既有相關資產：

- `stores/users.ts`：既有 CRUD 4 個 action（create / update / remove / resetPassword），需擴充 `activeAndInvitedCount` / `canInviteMore` 兩個 query 與 `status` normalize
- `stores/auth.ts`：已提供 `login(email, password)` 與 `logout()`，Accept 頁自動登入直接呼叫；`currentUser` 響應式，Accept 頁「已登入時提示」讀此值判斷
- `views/admin/UsersView.vue`：目前的「新增人員」Dialog 直接填 email + password 建帳號，需改寫成「邀請員工」Dialog；「編輯 / 重設密碼 / 刪除」既有互動保留
- `router/index.ts`：`beforeEach` 已支援 `meta.public = true`，可直接掛 `/invite/accept` 公開路由；掛在 top-level（非 FrontLayout / AdminLayout 內）
- 種子 `mocks/users.json`：4 筆 seed 沒有 `status` 欄位，需要 normalize 補齊避免 legacy shape 破 UI
- QA checklist：本 change 產出 `docs/QA_list/QA_邀請員工.md`（尚未存在），Phase 3 / Phase 2 已有先例（QA_類別預算.md / QA_類別管理.md）

Prototype 階段限制（依 `CLAUDE.md`）：不建後端、僅動 Pinia mock；狀態由 store 直接改；不寫測試；接後端時 store 內改 fetch，view 幾乎不動。

## Goals / Non-Goals

**Goals**

- Admin 能以「email + 姓名」為單位發邀請並取得可貼給員工的邀請連結
- Employee 能透過連結一次完成「設密碼 → 建帳號 → 登入 → 進前台」（姓名沿用邀請時 admin 填的）
- Employee 可於前台自助修改密碼；admin 無管道插手員工密碼（Decision 14）
- 「員工上限 10」規則由 store 強制、UI 即時顯示名額
- Invitation 記錄與 User 記錄雙軌並存、UsersView 於同一表格呈現、未接受邀請不佔用完整 User 欄位
- 一次性下架部門功能，避免 Prototype 階段累積技術債（Decision 16）
- 後端 API 契約於此 change 一併定型（TS 型別 + JSDoc endpoint 描述）

**Non-Goals**

- 真正的 email 寄送、SMTP 整合、寄送記錄（Stage B）
- 忘記密碼 email 重設流程（Stage B）；MVP 員工忘記密碼須由 admin 刪帳號後重邀（已知限制，見 Decision 14）
- 批次邀請（一次多個 email）；MVP 一次一個
- 邀請連結可自訂過期時間；MVP 固定 3 天
- 邀請人 `invitedByUserId` 於 UI 呈現（欄位存但不顯示）
- Employee status suspended / left 的操作 UI；MVP 只用 active / invited 兩態，欄位保留 4 態符合 `docs/資料模型.md` §3.2
- 部門功能（本 change 拿掉，未來若復活需另開 change 並重新設計 schema）
- 修改密碼強度細分（大小寫混合、特殊字元等）；MVP 只要求 ≥ 8 碼、與舊密碼不同
- 員工前台個人資料頁的其他欄位（頭像、電話、通知偏好）

## Decisions

### Decision 1：Invitation 與 User 保持分離、Accept 時才建 User

**選擇**：Invitation 是獨立 store、獨立 seed；接受前 User 表中 NOT 存在該人；Accept action 內部同時 push 新 User + 更新 Invitation.acceptedAt。UsersView 顯示時把兩份資料 merge 成一個 rows 陣列。

**理由**：符合 `docs/資料模型.md` §3.2、§3.3 的欄位形狀（User 有 passwordHash 必填；Invitation 只有 token / expiresAt）；接後端後 Invitation 與 User 也是不同 table，此模型直接對齊。若在 users 內先建一筆 status='invited' 的 pending user，密碼欄位得填假值或允許 null，反而破壞既有 users 陣列的形狀（未來 passwordHash 是 not-null）。

**替代方案**：先在 users 建 status='invited' + password=''，Accept 時 update password + status='active'。放棄理由：破壞 users store 的資料形狀假設；password 欄位一 nullable 就會影響既有 login 邏輯的 null check；查「有效未接受邀請數」還是得 join，額外複雜度。

**推論**：UsersView 的表格 rows 需要一個 merge computed；後端 API 也是分兩個 endpoint（`/users` 與 `/invitations`），Stage C 對接時 view 端只需要換 data source。

### Decision 2：Token 用 `crypto.randomUUID()`（36 chars）

**選擇**：`invitations.create` 內部呼叫 `crypto.randomUUID()` 作為 token 值。所有現代瀏覽器（含 Chrome / Firefox / Safari 15.4+）與 Node.js 19+ 皆支援。

**理由**：足夠隨機（122 bits）；不需要另外引入 uuid 套件；資料模型註記「隨機字串 32+ chars」，UUID 36 chars 符合；後端未來若換 nanoid 32 chars 也不衝突（token 只需保證每筆邀請唯一，長度非契約）。

**替代方案**：`Math.random().toString(36).slice(2)`。放棄：熵不足、可預測。
**替代方案**：`nanoid` 套件。放棄：Prototype 不必增依賴。

**推論**：Stage B 後端可自行選用 secure random（如 Node crypto.randomBytes(32).toString('hex') 或 nanoid），前後端不同格式不影響任何契約。

### Decision 3：過期時間固定 now + 3 天，以 ISO 字串儲存

**選擇**：`create` 時 `expiresAt = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString()`。過期比對用 `new Date(expiresAt) < new Date()`。

**理由**：對齊 `docs/資料模型.md` §3.3「預設 3 天」；ISO 字串可安全存 JSON localStorage（Date 物件序列化會丟失型別）。

**推論**：若日後需要延長過期，改常數即可；後端 endpoint MUST 在 request body 忽略 expiresAt（後端算），前端契約 `CreateInvitationRequest` 不含此欄位。

### Decision 4：「有效邀請」判斷條件由 store computed 集中處理

**選擇**：`useInvitationsStore().activeInvitations` computed 回傳「acceptedAt == null && revokedAt == null && expiresAt > now」的邀請陣列。所有需要「有效」判斷的呼叫端（UsersView 列表、名額計算、email 重複檢查、Accept 頁 token 有效性）都經過此邏輯。

**理由**：避免三個以上 caller 各自寫「三個欄位都要滿足」的判斷、日後多加一個條件（例如「company 停用」）只需改一處。

**推論**：`findByToken` 回傳 raw Invitation（含過期 / 撤回），呼叫端再依 status 分派錯誤畫面；不用預先過濾，因為 Accept 頁需要區分「找不到」「過期」「撤回」三種錯誤。

### Decision 5：Accept 頁掛在 top-level route、不套用任何 layout

**選擇**：`router/index.ts` top-level 加 `{ path: '/invite/accept', name: 'invitation-accept', meta: { public: true }, component: () => import('@/views/InvitationAcceptView.vue') }`。頁面自帶 minimal chrome（logo + 卡片），不套 FrontLayout（前台側邊欄）或 AdminLayout（後台側邊欄）。

**理由**：Accept 頁是「訪客第一次接觸產品」的重要頁面，不該混淆為前台/後台功能；沒有 sidebar 干擾；已登入身分時的「請先登出」提示也不需帶側邊欄。

**替代方案**：嵌到 FrontLayout 內。放棄：登入前訪客不該看到「我的請款 / 首頁」等前台選單，會混淆使用情境。

**推論**：Router guard `beforeEach` 內 `isPublic` 分支已支援；不需加特例。

### Decision 6：已登入身分開啟 Accept 頁採「顯示提示 + 提供登出按鈕」，不自動登出

**選擇**：Accept 頁 setup 時檢查 `auth.currentUser`；若非 null，顯示 warning 卡片與「登出」按鈕，隱藏表單。點登出後 `auth.logout()`；因為 auth store 是 reactive，`currentUser` 變 null → 頁面自動切回 token 驗證 → 顯示表單。

**理由**：自動登出會偷偷刪除使用者當前工作階段（可能正在後台審核），是破壞性行為；讓使用者主動決定較安全。

**替代方案 A**：自動登出並直接顯示表單。放棄：破壞性、無提示。
**替代方案 B**：redirect 到 login 頁面。放棄：使用者會忘記自己是在接受邀請、離開頁面就找不回 token。

**推論**：不會出現 race condition，因為 `auth.logout()` 是 sync + reactive 觸發重繪。

### Decision 7：Email 重複檢查於三處但只有一份規則（invitations store 內）

**選擇**：`invitations.create({ email, name })` 內部依序做名額檢查、email 重複檢查，都不通過則 return `{ ok: false, error }`。View 端不重複這些檢查，直接顯示 error 訊息。email 重複的定義為「exists in users where status='active'」或「exists in activeInvitations where email 相同（case-insensitive）」。

**理由**：規則集中在 store 便於 unit 化與後端對照；view 只負責 UI 呈現。

**推論**：`create` 的回傳值需要能傳遞 error 種類，採用 discriminated union `{ ok: true; invitation: Invitation } | { ok: false; error: 'AT_LIMIT' | 'EMAIL_IN_USE' | 'EMAIL_PENDING' | 'INVALID_EMAIL' }`；view 依 error 種類產不同錯誤文案。

### Decision 8：撤回動作為軟刪除（設 revokedAt）而非硬刪

**選擇**：`revoke(id)` 只設 `revokedAt = now`，不從 store 陣列移除。已撤回的邀請不出現於 UsersView 列表、不計名額，但 Accept 頁若打進來仍可回覆「邀請已撤回」的具體錯誤。

**理由**：Accept 頁必須能區分「無此 token」與「有 token 但已撤回」；後者提供更好的錯誤訊息（例如「請聯絡貴公司管理員」）。硬刪除會退化成前者。

**替代方案**：硬刪 + Accept 頁只有「連結無效」錯誤。放棄：錯誤訊息不夠準確，被邀請人可能懷疑是自己貼錯連結。

### Decision 9：`User.status` 欄位新增為 union 4 值但 MVP 只用 active

**選擇**：`User.status: 'active' | 'invited' | 'suspended' | 'left'`；`invited` 保留但 users store 內實際不會出現此值（因為 Invitation 未接受前 User 不存在，見 Decision 1）；`suspended` / `left` 保留但 MVP UI 不觸發、只保留欄位為未來擴充。

**理由**：對齊 `docs/資料模型.md` §3.2 定義的 4 值 union，避免日後型別遷移；MVP 實際只用 active，簡化 UI。

**推論**：seed users normalize 都填 `status: 'active'`；users.create 內部固定填 `active`；未來擴充 UI 時 users store 可能加 `suspend(id)` / `restore(id)` action，不需再動 type。

### Decision 10：複製邀請連結採 `navigator.clipboard.writeText` + prompt fallback

**選擇**：優先呼叫 `navigator.clipboard.writeText(url)`；若 Promise reject（例如 non-secure context、權限拒絕）則 fallback 為 `window.prompt('複製這個邀請連結：', url)` 讓使用者手動選取 Ctrl+C。成功複製後 toast 提示。

**理由**：現代瀏覽器 secure context 都支援 clipboard API；prompt fallback 不需要在 DOM 建臨時 textarea + `document.execCommand('copy')` 這種已 deprecated 的路徑。

**替代方案**：只支援 clipboard API、失敗顯示錯誤 toast。放棄：對非 https 開發環境不友善（本地 pnpm dev 用 http://localhost:5173 可以，但若部署到未升 https 的預覽環境會全壞）。

### Decision 11：Accept 成功流程採「先建 User → 標 acceptedAt → 自動登入 → 導頁」順序 + try/catch 保護

**選擇**：`invitations.accept({ token, name, password })` 內部：
1. 驗 token 有效性；invalid 直接 return error
2. 呼叫 `useUsersStore().create({ name, email, password, role: 'employee', status: 'active', departmentId: null })`
3. 找到對應 invitation 設 acceptedAt
4. 回傳 `{ ok: true, user }`
5. View 端 await 拿到 user 後呼叫 `auth.login(email, password)`，成功則 `router.push({ name: 'front-home' })`

**理由**：MVP 為記憶體操作，實務上不會失敗；try/catch 只包在 view 端最外層以防萬一（例如 localStorage 滿）。真的接後端後 server 那邊會做交易一致性，前端 accept 是一次 POST 一次 fetch 拿 auth token。

**推論**：`users.create` 需回傳新建的 User 供 accept action 用（既有已如此）；acceptedAt 標的時間應為 accept 完成的當下，非 users.create 前，避免半成品。

### Decision 12：UsersView 表格的 rows 排序—員工在前、邀請在後，各自依名字 A-Z

**選擇**：`rows` computed 先 `[...usersActive].sort(byName)`，再 concat `[...invitationsActive].sort(byEmail)`；不做交錯排序。

**理由**：兩類 row 的操作項不同，交錯排序會讓 UI 看起來凌亂；分兩區更容易掃視「誰已加入、誰還沒接受」。

**替代方案**：全部依 createdAt 排序、混雜。放棄：使用者難分辨；相同 UX 已被 Category 頁面用「使用中 + 已停用」分區驗證過。

### Decision 13：手機版員工列表沿用桌機表格 + 水平捲動；「已邀請」列的兩顆操作按鈕仍需觸控可用

**選擇**：不做卡片式手機版（既有 UsersView 也是表格 + 手機捲動）；只確保「複製邀請連結」「撤回邀請」按鈕在手機 44px touch target。字級沿用 styles/index.css `.p-datatable` 全域覆寫。

**理由**：MVP 員工數 ≤ 10，表格短、資訊少；卡片式反而增加開發成本；對齊既有 UsersView 手機互動慣例。

**推論**：若日後員工數上限放寬到 50+，可另開 change 做卡片式改版。

### Decision 14：管理員 UsersView 不可重設員工密碼；改由員工前台自助

**選擇**：拿掉 UsersView 既有的「重設密碼」按鈕與對應 dialog；改在員工前台新增 `/app/account` 頁面提供「修改密碼」三欄表單（舊 + 新 + 確認）。管理員需改自己的密碼也走同一 `/app/account` 頁面（無管理員專屬入口）。

**理由**：
- 安全性：讓管理員能一鍵重設任何員工密碼會讓「管理員 = 全公司資料掌控者」，MVP 客戶敏感度不宜；且會被日後 audit log 需求追殺
- 職責分明：帳號憑證屬個人所有，改密碼是個人責任
- 對齊 PRD 「以 email 邀請 → 員工自訂密碼」的自主原則

**替代方案 A**：保留 UsersView「重設密碼」，同時提供員工前台自助。放棄：既然員工能自助，管理員插手就沒必要；且違反上述安全性理由。
**替代方案 B**：由 email 發「重設密碼連結」（類邀請機制）。放棄：Stage B 才有 email 寄送；MVP 期間會導致「員工忘記密碼 = 完全鎖死」。

**推論**：因為 MVP 無 email 寄送、無忘記密碼流程，「員工忘記密碼」的唯一救援路徑是「管理員刪除該員工帳號 + 重新邀請」；此路徑會遺失該員工的既有代墊款請款關聯（employeeId FK 會變成 orphan）。此已知限制列入 QA 註記，Stage B 後端上線後補「email 重設密碼」endpoint 解決。

### Decision 15：Accept 頁的姓名欄唯讀，不允許被邀請人自改

**選擇**：Invitation.name 於邀請發送時由 admin 填入；Accept 頁的姓名欄以 disabled input 或純文字呈現，被邀請人不能修改。若姓名有誤，被邀請人需請 admin 撤回並重新邀請。

**理由**：
- 通訊錄一致性：admin 發邀請時已與新同事對齊姓名認知（例如「李小明」vs「Michael Lee」），若被邀請人自改，UsersView 顯示的姓名與 admin 認知會不同步、造成後續代墊款簽核時「這誰？」的疑惑
- 語意單一化：姓名屬管理範疇（admin 決定要怎麼稱呼員工），密碼屬個人範疇（本人決定登入憑證）；Accept 頁只讓被邀請人管理個人範疇的資料
- 減少表單認知負擔：Accept 頁是新使用者第一次接觸產品，欄位越少完成率越高；把姓名決定權留給 admin 也讓被邀請人少一個猶豫點

**替代方案**：姓名預填但可改。放棄理由：上述通訊錄一致性問題；且 admin 一旦改過名的邀請被接受時 name 又被員工改回，會造成 admin 感覺自己的編輯無效。

**推論**：`invitations.accept` action 的參數從原本 `{ token, name, password }` 縮為 `{ token, password }`；User 建立時 name 直接取 `invitation.name`；後端 API `POST /invitations/by-token/:token/accept` request body 對應縮為 `{ password }`。

### Decision 16：部門功能整個下架而非「保留 schema 隱藏 UI」

**選擇**：本 change 一次性拿掉 `Department` type、`departments.json`、`User.departmentId` 欄位、與 6 個 view 內所有部門欄與 helper。不採「保留 schema、隱藏 UI」的保守路徑。

**理由**：
- 未來若做部門，schema 一定會變（要加 role='dept_manager'、加多對多、加簽核鏈綁部門等），現在保留反而是誤導性的技術債
- MVP 只有 1 個 admin + 10 個 employee，部門對簽核 / 預算 / 支出過濾都無業務意義（都是全公司口徑）
- 每個殘留欄位都要在後端 schema 保留 nullable column，Stage B 遷移時要 drop，多做一次遷移
- Prototype 階段 blast radius 可控（6 個檔案，機械式移除），現在不做以後移除只會更痛

**替代方案 A**：只拿 UsersView 的部門欄，其他 view 保留（呈現「—」）。放棄：使用者會看到永遠是「—」的欄，比沒有還混亂；且 `utils/approval.ts` 已有 `_departments` 底線前綴表示未使用參數，就是要清的訊號
**替代方案 B**：把 department 相關 code 只做 dead-code 標記、留 TODO。放棄：dead code 永遠不會被回頭清，且 TypeScript 型別檢查會持續要求維護

**推論**：`utils/approval.ts` 的 `buildApprovalProgress(filer, users, _departments)` 移除 `_departments` 參數；`stores/reimbursements.ts` 兩處呼叫也同步移除；未來若做多層簽核或部門簽核，於當時的 change 內新增乾淨的 schema，不背歷史包袱。

## Risks / Trade-offs

- **[localStorage 被使用者清掉，邀請全消失]** → Prototype 已知限制；QA checklist 註記「清 localStorage 會清邀請」；Stage B 上線後由 server 儲存不受此影響
- **[token 存在 localStorage 而非 secure cookie]** → Prototype 限制；MVP 邀請 token 本來就是「知道 URL 就能用」的低敏感度資料；Stage B 後端會發 short-lived JWT，Accept 流程不會把 token 存 client
- **[已過期邀請可以無限累積於 localStorage]** → 現階段量小可忽略；若 UsersView 需要「歷史邀請」次頁再另做「清理超過 30 天已過期／已撤回記錄」cron；MVP 不需要
- **[Accept 成功流程若 users.create 成功但 acceptedAt 標記失敗（例如剛好 localStorage 滿）]** → 使用者會被 auto-login 但邀請仍顯示未接受，下次同連結重點會顯示已註冊 email；概率極低、MVP 不特別處理（try/catch 包在 view 層 toast 一次錯誤即可）；Stage B 交易性由後端保證
- **[已登入 admin 誤點自己收到的員工邀請]** → Decision 6「顯示提示 + 提供登出按鈕」處理；不會偷偷登出
- **[email 大小寫敏感？]** → 統一 lowercase 存與比對（`email.trim().toLowerCase()`）；避免同 email 大小寫變體被視為不同人
- **[「員工上限 10」在 accept 那一刻若已滿怎辦？]** → accept 內部不再檢查上限（因為建立時已扣名額）；若 admin 在邀請有效期間先撤回其他有效邀請造成名額釋放、又邀請另一人、對方也同時接受，理論上會超過 10；MVP 忽略此邊界（機率極低，Stage B 後端在 accept endpoint 內再做一次上限檢查）
