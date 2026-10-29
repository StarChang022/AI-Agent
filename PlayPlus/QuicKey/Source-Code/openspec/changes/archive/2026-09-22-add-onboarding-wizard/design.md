## Context

- Prototype 前端 Phase 1～5 已完成，8 個後台核心模組 + 3 個前台核心頁面皆可實際操作。
- CLAUDE.md 明確要求「後台管理頁面必須支援手機瀏覽」，員工前台更是手機為主（外勤送單常見）——本次 tour 兩種 viewport 都必須完整支援。
- AdminLayout 與 FrontLayout 使用者選單目前結構對稱（都是「修改密碼」+「登出」+ `UserBadge`），加「新手導覽」項目可平行複製。
- 現有 Pinia store 慣例：所有 store 存 `quickey.<name>.v1` 到 localStorage、`watch(state, deep, save)`、載入時 `normalize` 舊 shape（見 `stores/invitations.ts`、`stores/categories.ts`）。
- 現有 role guard 已把 employee 擋在 admin 區域外、admin 擋在 front 區域外（`router/index.ts` beforeEach）；tour 觸發時只需依 role 選 steps 即可，不用另做權限判斷。

見 proposal.md - Why 節。

## Goals / Non-Goals

**Goals：**
- 首次 admin 登入 dashboard、首次 employee 登入 home 皆 100% 觸發、體感為「歡迎」而非「打擾」。
- 桌機（≥ 640px）與手機（375px）皆為 first-class：所有步驟 tooltip 完整顯示、target 準確打亮、跨頁跳轉不失手。
- 員工前台 3 步流暢跑完，桌機與手機皆能操作（員工手機使用率高）。
- 完成狀態 per-user 隔離，同瀏覽器多帳號測試不互相干擾。
- 「重跑導覽」入口一次即可、不論身處哪一頁都能觸發。
- Admin / employee 共用同一套 composable 與樣式覆寫，只有 steps 陣列不同。

**Non-Goals（design 層特有邊界，proposal 未列的）：**
- 不做 tour 進度中斷續跑（跑到第 5 步關掉，下次重跑仍從第 1 步開始）。
- 不做每步「必須做完某動作才能下一步」的強制交互（純資訊性 tooltip）。
- 不做 tour 分析追蹤（完成率、跳出步驟）。

## Decisions

### Decision 1：Tour 套件選 driver.js

**採納**：driver.js 1.8.0（MIT，~10KB gzipped，活躍維護，vanilla JS API）。

**理由**：
- 生態最活躍，維護穩定；相較之下 vue3-tour 已多年沒動、shepherd.js bundle 太大（~50KB）。
- Vanilla JS API 反而是優點——不綁定 Vue 版本，未來升 Vue 4 也不受影響。
- Driver.js 自帶鍵盤導航（Tab / Enter / Esc）、aria 屬性、popover 自動避開視窗邊緣（`side: 'auto'`），無障礙成本 0。

**替代方案**：
- 自己刻 `<TourOverlay>` component：省 10KB 依賴，但要自己處理 spotlight 挖空、tooltip 定位、resize、scroll 事件、鍵盤 focus trap、aria。開發成本 3～5 天遠高於整合 driver.js 半天。
- vue3-tour / shepherd.js：見上。

### Decision 2：State 拆一支新的 `stores/onboarding.ts`，不塞進 `auth.ts`

**採納**：新增 `stores/onboarding.ts`，`auth.ts` 完全不動。

**理由**：
- Auth store 職責是「當前登入使用者身份」；onboarding 完成狀態是「每個 user id 個別的偏好」，語意不同。
- Onboarding 資料是「歷史狀態集合」（哪些 user 已完成），跟 auth 的「單一 currentUser」形狀不合。
- 未來若加更多 onboarding-like 偏好（例如「已看過某公告」「已關閉某提示」），一支專屬 store 可統一收納。

**替代方案**：
- 塞進 auth store：形狀不合、混淆職責。
- 塞進 User model / users store：等於每個 user object 都要多一欄 onboardingCompletedAt——但這個資訊未來後端也不見得會存在 User 表（多半會分表存 UserPreference）。

### Decision 3：完成狀態 per-user、存 `string[]`（user id 陣列）

**採納**：localStorage key `quickey.onboarding.v1`，value 為 `string[]` 的已完成 user id。

**理由**：
- 同一台電腦切換帳號很常見（開發 / demo / 客戶多人共用），若用單一 boolean 會被第一個完成的 user「覆蓋」到其他人。
- 陣列形狀最簡單，`isCompletedFor(id)` = `arr.includes(id)`；相較 `Record<id, boolean>` 少一層 key 存取。
- 未來若要加時間戳（何時完成），可平滑升為 `{ userId; completedAt }[]` 並在 normalize 補齊舊格式。

**替代方案**：
- 用 boolean（單一 key）：多帳號共用瀏覽器會互相干擾。
- 存進 User model：需要動 mocks/users.json；未來後端接進來又要遷移，成本高。

### Decision 4：跨頁 target selector 用 `data-tour="xxx"` attribute，不用 class / id

**採納**：於各 view 目標元素加 `data-tour="xxx"`（例：`data-tour="expenses-new-button"`）；driver.js `element: '[data-tour="expenses-new-button"]'`。

**理由**：
- 與 CSS class / component logic 完全解耦——樣式或元件重構不會意外打斷 tour。
- 名稱本身有語意（`expenses-new-button` vs `.p-button`），未來若某 target 被移除，grep 一次就找得到。
- HTML 標準屬性，不需 lint 規則額外允許。
- Testing-library / Cypress 也吃這種 attribute，未來加 E2E 測試可共用。

**替代方案**：
- 用 CSS class：跟樣式綁死，改一次 button 樣式可能誤炸 selector。
- 用 id：全域唯一難維護（同一按鈕元件多實例會撞 id）。
- 用 ref + expose：Vue-only、tour composable 要拿 component instance 麻煩。

### Decision 5：跨頁跳轉用 `router.push` + `nextTick` 而非 driver.js 內建 async hook

**採納**：`onNextClick` 內先 `router.push({ name: step.routeName })`，再 `await nextTick()` + polling 等 target 出現（見 Decision 7 timeout），最後才 `driver.moveNext()`。

**理由**：
- driver.js 的 async hook 假設 DOM 一直存在同一頁；Vue Router 換頁會 unmount 舊 view + mount 新 view，DOM 節點瞬間被替換。
- 需要「等到新頁面 DOM 出現對應 selector」才能 highlight，這個 wait 邏輯必須由我們控制。
- `nextTick` 只保證 Vue 重繪一次，若目標元素在 `onMounted` 內 fetch 資料後才 render，需要額外 polling（見 Decision 7）。

**替代方案**：
- 用 driver.js `onNext` 直接 moveNext：新頁面還沒 mount，selector 找不到 → tooltip 亂飛或 crash。

### Decision 6：桌機與手機皆為 first-class，透過 `scrollIntoView` + `side: 'auto'` + mobile-specific 樣式覆寫達成

**採納**：所有 tour 步驟前一律 `target.scrollIntoView({ block: 'center', behavior: 'smooth' })`（見 Decision 12）；tooltip 一律 `side: 'auto'` 讓 driver.js 依 viewport 空間自動選方向；`@media (max-width: 639.98px)` 內 popover `max-width: 320px` + 字級 ≤ 14px + `padding-bottom: env(safe-area-inset-bottom)`。

**理由**：
- 員工前台使用率手機 > 桌機（外勤送單常見），若手機端 tour 卡住等於員工 tour 形同虛設；admin 端雖桌機為主，但外出處理審核也常在手機。
- Driver.js 內建 `side: 'auto'` 已能處理絕大多數定位問題，不需自己判斷 viewport。
- 手機主要卡點是 popover 寬度超出視窗（driver.js 預設 max-width 400px），一次 CSS 覆寫解決。
- iOS Safari 底部有主頁指示器 / bottom bar，safe-area padding 避免按鈕被擋。

**替代方案**：
- 手機 viewport 直接跳過 tour：等於「這個功能對員工手機使用者不存在」，違反本次需求。
- 手機專屬 tour（底部 Sheet 版）：開發成本翻倍、與桌機 UX 分歧、失去單一 codebase 好處。
- 只做桌機 best-effort（本 change 初版立場）：使用者明確要求兩端都要，改為 first-class。

### Decision 7：Target polling 500ms timeout，逾時走 center fallback

**採納**：`router.push` 後每 50ms 檢查一次 `document.querySelector(selector)`，最多等 500ms；找到就進入 Decision 12 scroll flow；逾時就以「無 spotlight、居中顯示 tooltip」的 fallback 模式呈現該步。

**理由**：
- 500ms 涵蓋所有 lazy-loaded route + `onMounted` 內同步 DOM 建立場景（實測 dashboard fetch mock 資料 <50ms）。
- 逾時不 crash 是 spec 硬需求——若某頁未來重構把 target 刪了，tour 至少還能繼續講內容。
- 50ms 間隔對 CPU 幾乎無感（單個 querySelector 微秒級）。

**替代方案**：
- 不 polling，直接 nextTick 後試一次：對 fetch-first 頁面會失敗。
- 用 MutationObserver：更精準但過度設計，500ms polling 已夠用。
- 逾時就跳過該步：使用者會覺得 tour 在自動快轉、體驗差。

### Decision 8：「重跑導覽」的行為 = reset + push 對應角色首頁，不是「當場啟動」

**採納**：使用者選單「新手導覽」command = `onboarding.reset(userId)` + `router.push({ name: role === 'admin' ? 'admin-dashboard' : 'front-home' })`。對應首頁的 onMounted 觸發邏輯負責啟動 tour。

**理由**：
- Tour 從第一步（welcome）開始才有意義，第一步的 target 一律在角色首頁，直接跳過去最合邏輯。
- 不用在 composable 內同時處理「當場啟動」與「跳頁再啟動」兩條路徑，統一走首頁 onMounted 減少狀態機分支。
- 使用者原本在哪一頁不重要，重跑就是重跑，不需保留上下文。
- Admin 與 employee 走同一段程式碼、只差 route name — 判斷靠 `auth.role`。

**替代方案**：
- 當場啟動：若使用者在 `admin-users` 點重跑，tour 第一步是 dashboard welcome、target 找不到 → 走 fallback 顯示 tooltip 在 users 頁面中央，感覺很怪。

### Decision 9：Tour composable 導出 `startTour()` 單一入口，內部管 driver 實例生命週期

**採納**：`composables/useOnboardingTour.ts` export `useOnboardingTour()` factory，returning `{ startTour }`；driver 實例於 `startTour()` 內 create、在 `onDestroyed` hook 內 `destroy()` + `markCompleted`。

**理由**：
- Driver.js 實例是有狀態的（`driverObj.moveNext()` 讀當前 step index），必須跨呼叫共享一個實例。
- Composable 內 module-scope 存 `driverInstance: DriverInstance | null`，避免每次 `useOnboardingTour()` 都 new 一個。
- `onDestroyed` 是 driver.js 官方的 lifecycle hook（tour 正常結束或 X 關閉都會觸發），統一在此標記完成 = 一個地方寫，兩種路徑受益。

**替代方案**：
- 導出 `startTour` + `nextStep` + `close` 多個 API：component 端要管一堆狀態、易忘同步。
- 每次 `startTour` 都 new：中途重複呼叫會有兩個實例互相衝突。

### Decision 10：Tour 樣式覆寫寫在 `styles/index.css`（全域），不寫 scoped

**採納**：於 `frontend/src/styles/index.css` 底部加一段 `.driver-popover` 系列 selector 覆寫，對齊 Trust Blue tokens；`@media (max-width: 639.98px)` 內加 mobile-specific 覆寫（見 Decision 6）。

**理由**：
- Driver.js 的 popover 是 append 到 body 而非 component 內，Vue scoped CSS 打不到。
- 全域覆寫用 CSS variable，未來換主題色不用改 tour code。
- 與現有 `.p-button`、`.p-inputtext` 全域覆寫慣例一致（見 dev-style.md 樣式三層架構）。

**替代方案**：
- 用 CSS Modules / :deep：Driver.js DOM 不在 Vue tree 內，:deep 不會傳染。
- 用 driver.js `popoverClass` 加 prefix：仍要在全域 CSS 定義那個 class，等於同一個做法但多一層 indirection。

### Decision 11：單一 composable `useOnboardingTour()` 依 role 選 steps，不做兩支獨立 composable

**採納**：`useOnboardingTour()` 內部依 `auth.role` 決定 `steps = ADMIN_STEPS | EMPLOYEE_STEPS`；driver 實例、完成寫入、X 關閉邏輯、樣式覆寫、fallback 邏輯 100% 共用。

**理由**：
- Admin tour 與 employee tour 唯一差異只有 steps 陣列（route name + selector + title + description）；其餘 100% 相同。
- 兩支獨立 composable 會出現兩份 driver 實例管理、兩份 markCompleted 呼叫、兩份 scroll fallback 邏輯——雙份 bug 風險。
- 未來若加 finance role tour 或 owner role tour，只需新增一個 `FINANCE_STEPS` 常數 + 一個 `role === 'finance'` 分支。

**替代方案**：
- 拆 `useAdminOnboarding` + `useEmployeeOnboarding` 兩支：重複程式碼、增加維護成本。
- 讓 caller 傳 steps 進去：composable 失去封裝、caller 需知道 steps 結構。

### Decision 14：Sidebar 同步打亮改用 CSS class 疊加，不動用 driver.js spotlight

**採納**：AdminLayout 每個 sidebar RouterLink 加 `data-tour-nav="<route-name>"`；composable 於 `onHighlightStarted` hook 內把 `.tour-nav-active` class 加到對應元素；`onDestroyed` 統一清掉所有 `.tour-nav-active`。z-index 設 10001（driver.js overlay 用 10000）讓 sidebar 浮在遮罩之上。

**理由**：
- driver.js 原生只能 spotlight 一個元素——想同時打亮頁面內元素 + sidebar 只能雙軌並行。
- CSS class 疊加最輕量，不影響 sidebar 本身的路由 active 樣式邏輯（Vue Router 用 `active-class` 管理，跟我們的 tour class 不衝突）。
- z-index 提升可讓 sidebar 在遮罩之上呈現，但不影響點擊行為（tour 進行中 sidebar 仍可點——不過我們用 `disableActiveInteraction` 讓 driver 攔截了非 tooltip 的點擊，等於 sidebar 也點不動，符合預期）。
- 手機 sidebar 藏在 drawer 內，drawer 預設 `translate-x: -100%`，沒動它 → 手機自然看不到打亮效果，不需為手機做額外分支。

**替代方案**：
- 用 driver.js 同時 spotlight 兩個元素：函式庫不支援。
- 自製第二個 SVG overlay 幫 sidebar 挖洞：過度設計、遮罩會疊 double 半透明。
- 只打亮 sidebar 不打亮頁面 target：使用者看不到頁面上要教的地方是哪個 UI。

### Decision 13：關閉鈕改「結束導覽」文字按鈕；點遮罩不觸發關閉

**採納**：driver.js `overlayClickBehavior` 設為 no-op function（點遮罩不關閉）；`onPopoverRender` hook 內把 `closeButton.textContent` 改為「結束導覽」；CSS 把原本圓形 icon 改為 border + padding 的文字按鈕。

**理由**：
- X icon 語意雖通用，但配上「導覽」情境使用者容易誤解為「關掉這一步的說明」而非「結束整個新手導覽」——文字明確表達行為，避免誤觸後又重跑的挫折。
- 點遮罩會關閉是 driver.js 預設，但 tour 情境中使用者常想「點打亮元素旁邊」看看實際 UI，若一點就關會讓人氣餒——尤其手機端點擊區域不精確更容易誤觸。
- 保留 Esc 快捷鍵能結束，符合鍵盤重度使用者習慣。

**替代方案**：
- 保留 X icon：語意較差、且與「修改密碼」Dialog 的 X 語意不同（Dialog 的 X 是關閉這個對話框），tour 情境需要更明確。
- 遮罩點擊 = 前進到下一步（`overlayClickBehavior: 'nextStep'`）：使用者可能誤操作進入下一步、失去閱讀當前步驟的機會。
- 遮罩點擊 = 關閉 tour（預設）：見上述誤觸問題。

### Decision 12：Target scroll strategy 一律用 `scrollIntoView({ block: 'center', behavior: 'smooth' })` + 300ms 等 scroll 完成

**採納**：於 `waitForSelector` 找到 target 後、driver 顯示 tooltip 前，統一呼叫 `target.scrollIntoView({ block: 'center', behavior: 'smooth' })` + `await new Promise(r => setTimeout(r, 300))` 讓 smooth scroll 完成，再 `driverInstance.moveNext()`。

**理由**：
- `block: 'center'` 讓 tooltip 有上下空間可放；沒 scrollIntoView 的話手機 fold 下 target 打亮會定位在視窗外。
- 300ms 為主流瀏覽器 smooth scroll 平均耗時（實測 Chrome/Safari 200-280ms），若不等會出現 tooltip 定位到 scroll 中途座標的 flicker。
- 桌機大螢幕通常不需 scroll（target 已在視窗內），`scrollIntoView` 為 no-op，成本 0。

**替代方案**：
- `{ block: 'nearest' }` 較保守但 tooltip 可能被切邊。
- 不 scroll 讓使用者手動找：手機端體感差。
- 用 IntersectionObserver 判斷是否在視窗內再決定要不要 scroll：過度設計，`scrollIntoView` 本來就會判斷。

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| Driver.js 版本升級破壞樣式覆寫 | package.json 用 `^1.8.0` 允許 patch 自動升；major 升需手動測試 |
| 某頁 view 未來重構把 `data-tour` attribute 刪掉 | fallback 走 center tooltip 不 crash；QA checklist 內含「所有 target 都應被打亮」的目視檢查 |
| localStorage 損毀（例如手動改壞）導致 tour 一直跑 | normalize 遇到非陣列 fallback 為空陣列（等於全部重跑一次），最壞情況使用者按 X 一次即可 |
| 隱私模式使用者每次都被觸發 tour | 已列入 spec Scenario；接受此為隱私模式的固有限制 |
| Tooltip 於 iOS Safari 部分視窗尺寸與底部 nav bar 或主頁指示器重疊 | mobile popover `max-width: 320px` + `padding-bottom: env(safe-area-inset-bottom)`；QA 手機章節逐步驗收 |
| Employee tour 手機使用率高，第 2 步表單容器較大、打亮框可能過大 | QA 手機章節對 employee 3 步逐一驗收；若打亮框過大可縮小 target 到表單 header 而非整個容器 |
| 未來 admin 若擴充 role（例如 finance），觸發條件需擴充 | 現版寫 `role === 'admin' \|\| role === 'employee'`；新 role 需在 composable 內加 `FINANCE_STEPS` 分支 |

## Migration Plan

無 breaking change：
- 現有 admin 與 employee 帳號首次登入時會被觸發 tour（等同新使用者）；這是預期行為，不視為 regression。
- 若客戶希望「上線後既有使用者不要被觸發」，可預先 seed `quickey.onboarding.v1` 為當時使用者名單——但 MVP 不做，因為現階段還沒有正式客戶。
- Rollback：純前端變更，發現問題直接 revert commit 即可；localStorage `quickey.onboarding.v1` 殘留無害（可留可清）。
