## Context

見 `proposal.md`（Why、What Changes）與 `specs/category-budgets/spec.md`（Requirements）。既有相關資產：

- `stores/expenses.ts`：Phase 1 已完成，`useExpenseStore().expenses` 陣列即為執行率計算來源
- `stores/categories.ts`：Phase 2 已完成，`active` computed 提供未停用類別集合、`findName` / `findAccountCode` 提供 fallback 查表
- `views/admin/BudgetsView.vue`：目前為 EmptyState 空殼（`本模組開發中`）
- Sidebar `admin-budgets` route 已在 `router/index.ts` 就位
- QA checklist：`docs/QA_list/QA_類別預算.md` 已完成、10 節使用者情境
- 資料模型 §3.5 已定義欄位形狀：`id / companyId / categoryId / cycle / amount / periodStart / periodEnd`，唯一約束 `(companyId, categoryId, cycle, periodStart)`

Prototype 階段限制（依 `CLAUDE.md`）：不建後端、僅動 Pinia mock；狀態由 store 直接改；不寫測試；接後端時 store 內改 fetch，view 幾乎不動。

## Goals / Non-Goals

**Goals**

- 讓 admin 對每個使用中類別於任意月／年設定 / 修改 / 移除預算
- 執行率即時反映 expenses store 內容變化（新增／刪除 Expense 立即刷新）
- 支援同類別月＋年預算並存、獨立管理
- 未設預算類別也在表格出現（提供 zero-cost 補預算入口）
- 後端 API 契約於此 change 一併定型（TS 型別 + JSDoc endpoint 描述）

**Non-Goals**

- 依部門 / 專案分組（見 `docs/資料模型.md` §八 擴充預留，MVP 不做）
- 預算超支自動 email 通知（Phase 7 補）
- 匯入 / 匯出預算（Phase 7 補）
- 拖曳排序類別（沿用 categories store 現有 sortOrder）
- 前台員工端可見預算（預算是 admin 內部工具）
- 後端實作與資料遷移（Stage B）
- 基本預算自動 materialize 到未來期間（採手動套用，見 Decision 13）
- 「套用基本預算」的 per-category 選擇性套用（採一次覆寫全部，見 Decision 14）
- 月 template / 年 template 互相推算或自動同步 — 12 倍 / 除 12 語意在非均勻分佈類別（旅費、訓練、年繳訂閱、獎金）會誤導；未來若擴充，僅接受形式為「每 row 一顆『套用至年預算』/『套用至月預算』icon 按鈕、單向、手動、只寫入另一 cycle template（**不動 Budget 記錄**）」，NOT 做 live sync 也 NOT 做批次全表推算

## Decisions

### Decision 1：Budget 存「一筆一期間」而非「連續金額表」

**選擇**：每一筆 Budget 對應 (categoryId, cycle, periodStart) 唯一組合；不同月份完全獨立記錄。

**理由**：對齊 `docs/資料模型.md` §3.5 已定義的 schema；DB migration 直接對應；月與月間的預算沒有「連續」的業務意義（預算是一次性 target）；Stage B 後端可直接照本 schema 建表。

**替代方案**：把「每月都適用」的預算存一筆，讀取時展開。放棄理由：業務常見情境是「某月調整」，一次一期間存法更直觀且易稽核。

**推論**：切到下個月時預設「未設定」，admin 若要延用上月金額需自行輸入（未來可加「複製上月」快捷；目前 Non-Goal）。

### Decision 2：執行率即時計算，不快取

**選擇**：`computeUtilization(categoryId, cycle, periodStart, periodEnd)` 於每次呼叫時對 `expenses.value` 陣列做線性掃描加總；不寫入 store、不快取。

**理由**：Prototype 期資料量小（seed 7 筆、實測 admin 手動填不會破百）；避免快取失效問題（新增 / 刪除 / 標記付款 Expense 都要通知）；Vue reactive system 已能自動偵測 `expenses` 陣列變化並重算 computed。

**替代方案 A**：在 expenses store 內維護一份「按類別 × 月份」的 aggregate map。放棄：增加同步負擔、跟 UI reactive 系統重疊。
**替代方案 B**：由 view 端直接讀 expenses 加總。放棄：把跨 store 業務邏輯散進 view，未來後端 endpoint（`GET /budgets?includeUtilization=true`）也不方便對齊。

**推論**：接後端後 `computeUtilization` 內部改成呼叫 `GET /budgets/utilization?cycle=X&periodStart=Y`；view 端不動。

### Decision 3：Period 語意採「本地時區 YYYY-MM-DD 字串比對」

**選擇**：`periodStart` / `periodEnd` 存 `YYYY-MM-DD`（本地時區）；期間內判定用 `e.date >= periodStart && e.date <= periodEnd` 字串比較（因為 ISO 日期字串字典序 = 時間序）。

**理由**：`Expense.date` 已是 `YYYY-MM-DD` 字串；統一格式避免時區歧義（若某人在 UTC-8、輸入 2026-09-30 但轉 UTC 變 2026-10-01 會誤歸入下月）。字串比對 O(n) 一次遍歷即可、無 Date 物件建構開銷。

**替代方案**：用 Date 物件比對 timestamps。放棄：時區風險（Expense.date 是「當地日」概念，非 UTC instant）。

### Decision 4：Store 名稱 `useBudgetsStore`（複數）

**選擇**：`stores/budgets.ts` 內 export `useBudgetsStore`，對齊 `useCategoriesStore`（複數）與領域概念「多筆 Budget 記錄的集合」。

**理由**：跟 `useExpenseStore`（單數）不一致但符合 pattern 分歧的歷史脈絡（expenses 早期以「單一支出列表」思維命名，budgets 是新加、直接用複數）。若未來要重命名，再獨立做 rename change。

### Decision 5：CRUD API 為 `upsertBudget` + `removeBudget` + `removeBudgetBy`

**選擇**：

- `upsertBudget(input)`：新增或更新 (categoryId, cycle, periodStart) 對應那筆；若存在則覆寫 amount + updatedAt，否則建立
- `removeBudget(id)`：以 id 硬刪
- `removeBudgetBy(categoryId, cycle, periodStart)`：Convenience，讓 view 不必先查 id

**理由**：view 端操作情境是「在某類別某期間設 / 改」，upsert 語意直觀；避免 view 先 findBudget 再判斷 add／update 兩條分支。與 `useCategoriesStore.addCategory`（純新增）不同是因為 category 沒有天然唯一 key、budgets 有；語意不同用不同 action。

**替代方案**：分 `createBudget` + `updateBudget`。放棄：view 邏輯更複雜、無收益。

### Decision 6：Period helper 於 store 檔內 export function（非 store method）

**選擇**：`monthPeriod(refDate: Date)` / `yearPeriod(refDate: Date)` 為 top-level export function，不掛在 store instance。

**理由**：純函數、無 store state 依賴；view 只是想從「當前檢視日期」算出 periodStart / periodEnd 字串；掛 store 反而讓 view 為了 helper 而 useBudgetsStore 顯得語意錯亂。與 `utils/format.ts` 內的 `formatDate` 同性質。

**推論**：若未來多個 view 使用，可考慮抽到 `utils/period.ts`；目前只 BudgetsView 用，就近放 store 檔。

### Decision 7：預設檢視期間 = 今日期間，切換 cycle 重置為今日期間

**選擇**：進頁預設 cycle='month' + refDate=今日；切 cycle 時 refDate 重置為當前 cycle 對應的今日期間。

**理由**：避免「切到年預算後停留在 6 月」這類無語意的狀態；今日期間永遠是 admin 最常看的一個。

**替代方案**：保留 refDate 不變。放棄：admin 在月/年間切換是常見動作，保留舊值容易讓人誤以為「這是我剛才看的期間」但其實不是。

### Decision 8：桌面 inline InputNumber + 手機 Dialog；Enter/Esc 為鍵盤快捷

**選擇**：
- **桌面（≥ 768px）**：已設定金額的 cell 為按鈕，點擊切換到 InputNumber，右側緊鄰兩顆 icon 按鈕：`pi-check`（儲存）與 `pi-times`（取消）。Enter 觸發 `commitEdit()`；Esc 或點「取消」觸發 `cancelEdit()`；**blur 不觸發任何動作**。
- **手機（< 768px）**：卡片內點金額或「＋ 設定」→ 開一個專屬 Dialog（Header = 「XX 預算」、Body = InputNumber + 提示「金額設為 0 = 取消此類別當期預算」、Footer = [取消][儲存]）；Enter 亦可觸發儲存。桌面與手機共用同一份 `saveBudget(row, amount)` 邏輯。

**理由**：桌面 inline 編輯批次調整多列快、視覺不打斷；手機 inline 難以呈現「輸入框 + 兩顆 icon 按鈕」的橫向排列（sub-14px 空間），且點擊 miss-tap 風險高，改用 Dialog 讓輸入更聚焦、按鈕更大更好按。共用 save 邏輯避免兩份分支漂移。blur 不觸發是為了避免使用者「想切到別的類別編輯，剛才的改動被 blur 意外儲存」的案例。

**替代方案 A**：手機也用 inline（原方案）。放棄：sub-14px 螢幕下輸入框 + 兩顆 icon 擠不下，實測 miss-tap 率高。
**替代方案 B**：桌面也走 Dialog。放棄：批次調整 N 列變 N 次開 Dialog，效率低。
**替代方案 C**：blur = 儲存。放棄：使用者測試中多次發生誤儲存。

**推論**：InputNumber 的 `ref` 用同一個變數 `editInputRef`，靠 v-if 只渲染 focus 中的那個；nextTick 內 focus + select 讓 admin 直接改。編輯狀態若使用者切列或關頁面，暫不 warn（MVP 邊界）。

### Decision 9：金額 = 0 語意為「取消該期間預算」；負值才是錯誤

**選擇**：`upsertBudget` 內若 `amount === 0` → 尋找對應 (categoryId, cycle, periodStart) 記錄並刪除（等同 `removeBudget`），若無記錄則 no-op；view 端 toast「已取消預算」。若 `amount < 0` 回 null 且 view 端 toast「金額不得為負數」，NOT 儲存。

**理由**：取消原本 trash icon 動作，將「移除」與「編輯」統一為同一個 InputNumber 入口；使用者輸入 0 = 「不編列此預算」語意直觀；執行率計算對「無記錄」與「amount=0」都視為未設預算，兩者行為一致。同時避免 0/0 除法或分母為 0 的 NaN。

**替代方案 A**：保留 trash icon + 拒絕 amount = 0（原方案）。放棄：UI 動作重複、使用者常直覺以 0 表達「取消」，錯誤訊息反而困惑。
**替代方案 B**：`amount = 0` 允許儲存（Budget 記錄存 0）。放棄：造成「未設定 vs 已設定為 0」兩種語意混淆、破壞執行率邏輯。

**推論**：後端 `POST /budgets` 若收到 amount = 0 應回 400 引導呼叫 `DELETE`；前端 `upsertBudget` 自行代理該轉換避免 view 端多分支。負值為 422。

### Decision 10：桌面表格 vs 手機卡片切換點 `md`（≥768px）

**選擇**：DataTable 於 `md:` 以上顯示，手機用 `<ul>` 卡片列表；沿用 CategoriesView / ExpensesView 的斷點。

**理由**：對齊既有 admin 頁面手機化模式；後台頁面必須手機能操作（依 `CLAUDE.md`）。

### Decision 11：剩餘視覺 — 反轉進度條 + 百分比 + 超支 Tag；並列「餘額」金額欄

**選擇**：欄位由原「執行率」改為「剩餘」，語意為「還剩多少額度」。
- 進度條 fill 依 `(budget − actual) / budget`：無支出 = 滿（100%）、逐步消耗 = 減少、超支 = 空（0% fill）
- 顏色分段：>20% 剩餘 → primary；1-20% 剩餘 → warning；≤0% → danger + 「超支」Tag
- 右側百分比：`Math.max(0, Math.round((budget - actual) / budget * 100))`；tabular-nums；超支時顯示 0%
- 未設預算 → 進度條灰底 + 百分比顯示「—」
- 新增獨立「餘額」欄位：`budget − actual` 金額；未設預算顯示「—」；正值 primary 色系；負值紅色警示色（前綴 `−` 符號）

**理由**：使用者反饋「執行率」語意（越高越差）反直覺；反轉為「剩餘」後「滿條 = 安全 / 空條 = 警訊」符合日常心智；額外提供「餘額」金額欄，讓 admin 直接看到「還能花多少」的絕對數字（百分比對小預算失準）。`design.md` 顏色 tokens（`--color-status-rejected` / `--color-status-review` / `primary-500`）沿用不變。

**替代方案 A**：保留執行率 % 但把 bar 反向 fill。放棄：文字與 bar 語意不一致更混亂。
**替代方案 B**：只保留「餘額」金額欄、拿掉進度條。放棄：進度條掃視快、對批次審視有價值。

**推論**：`Utilization` 型別內同時提供 `utilization`（0-1+）、`remainingRatio`（0-1，超支 cap 為 0，用於 bar fill）、`remainingAmount`（可為負，用於「餘額」欄），view 端直接取用不再計算。

### Decision 12：TypeScript 契約 — `frontend/src/api/budgets.ts`

**選擇**：export `BudgetDTO` / `CreateBudgetRequest` / `UpdateBudgetRequest` / `ListBudgetsQuery` / `DeleteBudgetResponse` 加上 template 相關 `BudgetTemplateDTO` / `UpsertBudgetTemplateRequest` / `ListBudgetTemplatesQuery` / `ApplyBudgetTemplatesRequest` / `ApplyBudgetTemplatesResponse`；JSDoc 註記 endpoint path、method、狀態碼、後端 MUST 驗證項。

**理由**：對齊 `frontend/src/api/expenses.ts`、`frontend/src/api/categories.ts` 已存在的檔案 pattern；Stage B 後端拿這個就能直接 stub controller；Stage C 前端接 fetch 時 type 對得起來。

**推論**：`UpdateBudgetRequest` 只允許 `{ amount: number }`（不改期間與類別）；改期間 / 類別走「delete + create」語意。`UpsertBudgetTemplateRequest` 用 PUT `/budget-templates`（單一 endpoint 處理建立與更新），因為 `(categoryId, cycle)` 是唯一鍵。`ApplyBudgetTemplatesRequest` 帶 `{ cycle, periodStart, periodEnd }`，後端遍歷該 cycle 所有 template 執行 upsert。

### Decision 13：BudgetTemplate 為獨立記錄 + 手動套用

**選擇**：新增 `BudgetTemplate` interface `{ id, categoryId, cycle, amount, createdAt, updatedAt }`，唯一 `(categoryId, cycle)`；獨立於 Budget 存在、獨立 storage key `quickey.budget-templates.v1`；使用者需明確點「套用基本預算」才會將 template 值寫入當前檢視期間的 Budget。編輯 template 本身 SHALL NOT 影響任何已存在的 Budget。

**理由**：對齊主流 SaaS（QuickBooks / Xero 的 budget template + monthly instance）的**手動 materialize** 變體；相比「金額繼承」模型（曾考慮過的替代方案）：
- 無隱式狀態、歷史稽核清楚（過往期間 = 該期間 record 值）
- 「基本預算」與「實際期間預算」在資料模型層完全分離、避免混淆
- 使用者對套用時機有完全控制權
- 消化「不用每月重設」的省力需求

**替代方案 A**：自動繼承（越早期越優先，向後傳播）。放棄：無明確 undo、跨年跳期不合理、稽核不清、amount=0 承擔雙重語意（clear marker）等 10+ 缺點。
**替代方案 B**：Recurring rule 自動 materialize（Ramp / Brex 模式）。放棄：Prototype 過重、需要背景排程或 lazy materialize 邏輯。

**推論**：後端 Stage B 只需 `PUT /budget-templates`（upsert）、`DELETE /budget-templates/:id`、`GET /budget-templates`、`POST /budget-templates/apply` 四個 endpoint；資料表 `budget_templates` 與 `budgets` 分開建立、FK 皆指向 `categories`。

### Decision 14：套用基本預算 = 當期預算完整鏡射基本預算 + ConfirmDialog

**選擇**：`applyTemplatesToPeriod(cycle, refDate)` 於呼叫時對**所有使用中類別**執行 upsert：
- template.amount > 0 → 當期 Budget upsert 為此金額（覆寫既有）
- template.amount = 0 或無 template → upsertBudget(amount=0)；若當期已有 Budget 則刪除（= 「取消預算」語意），若本來未設定則 no-op

UI 於執行前 SHALL 顯示 PrimeVue ConfirmDialog、severity=`danger`，訊息「將覆寫當前期間所有類別的預算金額」。按鈕永遠可點（不因基本預算數量而 disabled）。

**理由**：使用者的心智模型是「基本預算 = 當期預算的完整快照，套用 = 把當期覆寫成快照」。若採「跳過 amount=0」（原設計），則 Dialog 顯示 0 的類別在套用後其當期預算 NOT 被清除，違反「完全鏡射」直覺——這在真實使用中被回報為 bug。改為完全鏡射後：使用者若不想動某類別當期預算，就別按「套用」；若按了，就是要把整組拉齊。覆寫破壞性大所以仍強制二次確認。

**替代方案 A**：skip-existing 只補未設定的類別。放棄：使用者已編輯過的個別月份值會「卡住」、基本預算的意義被削弱。
**替代方案 B**：跳過 amount=0 讓使用者 opt-out 部分類別。放棄：語意不直覺，Dialog 顯示 0 但套用後當期預算不變，容易被視為 bug。
**替代方案 C**：套用時 per-category diff dialog 讓使用者逐筆選擇。放棄：批次操作變 N 次確認，違背「一鍵」訴求。

**推論**：`applyTemplatesToPeriod` 回傳實際發生變動（upsert + delete）的筆數，但 UI 端不顯示 count（toast「已套用基本預算到 2026 年 9 月」），因為使用者關心的是「當期是否已鏡射」而不是具體筆數。跨 cycle 不套用（月 template 只影響月預算；年 template 只影響年預算）。

### Decision 15：基本預算 Dialog 承載於「當前檢視 cycle」語境

**選擇**：「基本預算設定」按鈕開啟的 Dialog 對應**當前檢視 cycle** 的 template（月 cycle → 月範本、年 cycle → 年範本）；Dialog 標題為「基本月預算」或「基本年預算」；同一 Dialog 一次列出所有使用中類別 + InputNumber。底部固定 [儲存][取消] 兩顆按鈕；Dialog 上方有明確說明文字：「儲存基本預算不會自動改動任何月/年預算，需點『套用基本預算』才會套用到當前檢視期間」。

**理由**：使用者的心智模型是「我現在在看月預算 / 年預算」；把 Dialog 綁定 cycle context 避免多切一次選項；月與年 template 分別管理與 Budget 記錄的 cycle 概念一致。

**替代方案**：Dialog 內同時列月與年兩欄（tab 或分組）。放棄：使用者一次只關心一個 cycle、Dialog 過長。

**推論**：關閉 Dialog 後回到 BudgetsView，cycle 與期間不變；使用者可再選「套用基本預算」立即生效。Dialog 內 InputNumber 允許 0（等同「未設範本」），儲存邏輯：amount > 0 → upsertTemplate；amount === 0 → removeTemplate（若存在）；amount < 0 → 錯誤提示。

## Risks / Trade-offs

- **[執行率即時計算的效能]** → 資料量小可接受；Stage C 接後端後改為 server-side 聚合，前端不重算。
- **[Prototype localStorage 資料與後端不同步]** → Stage C 時 store 換 fetch 之際同步做 migration script（把 localStorage v1 的資料 POST 到後端一次），或直接視為 wipe（依 Stage C 決策）。目前不處理。兩個 storage key（`quickey.budgets.v1` 與 `quickey.budget-templates.v1`）皆需處理。
- **[基本預算範本與 Budget 記錄脫節]** → 使用者修改 template 後不會自動影響 Budget；若使用者忘了點「套用」，Budget 值不會跟上。這是刻意設計（避免隱式狀態），需在 Dialog 內以文案清楚提示。
- **[類別停用後預算列消失，但底層記錄還在]** → 目的是保留 admin 若解除停用時的資料；副作用是「已停用類別的支出仍計入 Expense 加總」但因該類別列不出現、admin 看不到。可接受（該情境已在 QA §9 覆蓋）。
- **[年預算跨月調整的邊界]** → 若 admin 在 2026-11 修改 2026 年年預算金額，Budget.periodStart 仍是 2026-01-01；執行率 = 2026 年整年支出加總 / 新金額。與規格一致，不特殊處理。

## Migration Plan

無需資料遷移（新 capability、無既有 Budget 資料）。Stage C 接後端時：

1. 後端建 `budgets` 與 `budget_templates` 兩張表，schema 對齊 `docs/資料模型.md` §3.5
2. 前端 `stores/budgets.ts` 內 mutation 改為呼叫 `frontend/src/api/budgets.ts` 定義的 endpoint
3. localStorage `quickey.budgets.v1` 與 `quickey.budget-templates.v1` 於首次接後端時：若 key 存在，POST 到 bulk-import endpoint（Stage B 才決定要不要有）；否則直接讀 server

Rollback：Prototype 階段完全前端，若 view 有問題直接 git revert；localStorage 資料不動。
