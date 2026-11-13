# 對話 Context 交接（重啟對話用）

> 這份文件是給 Claude 讀的，用來延續之前對話的脈絡。開啟新對話時，請先讀完這份，再讀 `CLAUDE.md`（在 repo 根目錄）與 `docs/dev/design.md`。

## 使用者是誰、想做什麼

正在開發一款 **代墊款管理工具**（給員工提報代墊款、財務審核發放）。使用者以 PM/工程師角度與 Claude 協作，一路釐清 PRD、收斂規格、選技術棧、初始化專案骨架。專案還在 **Prototype 階段（前端 + 假資料，尚未接後端）**。

## 相關文件（依重要性）

| 檔案 | 用途 |
|------|------|
| `./docs/工程師傅代墊款管理工具_PRD.md` | 產品原始需求（PM 的 PRD） |
| `./docs/代墊款管理工具_規格確認_Delta.md` | 相對 PRD 的規格補充/修正（給 PM review 的版本） |
| `CLAUDE.md`（repo 根目錄） | 專案給 Claude 讀的說明（技術棧、結構、慣例） |
| `docs/dev/design.md` | Trust Blue 設計系統規範（動 UI 前務必讀） |
| `/Users/laipeiying/Desktop/notion design-md/DESIGN.md` | Trust Blue 借用底層的原始 Notion 設計系統 |

## 重要決策與其原因（避免重複討論）

### 產品層

- **職級 4 種固定（免費版）**：員工 / 主管 / 財務 / 管理員。付費版才能自訂職級與權限。
- **費用類別 5 種預設（免費版）**：材料 / 工具 / 差旅 / 服務費 / 其他。付費版才能自訂。
- **請款狀態 6 個**（在 `types/domain.ts` 的 `ExpenseStatus`）：
  `draft`（草稿）→ `in_review`（簽核中）→ `approved`（已核銷）→ `paid`（已發放）
  中途可能 `rejected`（駁回，員工修改後重跑完整簽核）
  任何「已核銷前」的記錄可 `voided`（作廢）
- **簽核進度物件 `ApprovalProgress`** 與主狀態解耦，記錄各步驟的候選人、狀態、意見、時間。
- **簽核路徑**（見 `Delta` 文件 D 節）：
  - 員工：部門主管 → 財務
  - 主管：同部門其他主管（僅一人則自審）→ 財務
  - 財務（財務部有主管）：財務主管 → 其他財務（僅一人則自審）
  - 財務（財務部無主管）：跳過 → 其他財務
- **駁回重送**：同筆記錄 `version +1`，重跑完整簽核。舊 `ApprovalProgress` 保留為歷史。
- **作廢**：由財務執行，限已核銷前。
- **核銷 vs 發放**：後台審核頁 **兩個獨立按鈕**，分別執行。
- **通知功能**：沿用原 PRD（免費版 P1，非付費限定）。
- **管理員權限**：沿用原 PRD 第 8 章，實質為 super-user。管理員只登入後台。
- **主管與財務**都可登入前後台（兩者本身也會提報代墊款）。**員工只登入前台，管理員只登入後台**。
- **主管只能看自己部門**，財務不能編輯他人記錄（只能簽核時駁回）。
- **付費版才做**：自訂職級與權限、自訂費用類別、進階報表。
- **不做**：金額分級加簽、「需補件」中間狀態（用駁回代替）。
- **未決**：商業模式（訂閱／人頭／買斷）、舊記錄的資料保留政策。

### 技術層

- **Frontend**：Vue 3.5 + Vite 8 + TypeScript + Tailwind v4（CSS-first `@theme`） + PrimeVue 4.5（Aura theme 客製為 Trust Blue，**不用 5.x 因為引入商業授權 banner**） + PrimeIcons + Pinia + Vue Router + 原生 `fetch`（不裝 axios）
- **Backend**：**Rails**（尚未開發，佔位資料夾），MVP 才會補
- **DB**：PostgreSQL（MVP 才會補）
- **Monorepo 結構（方案 C）**：`quickey/{frontend,backend}/`，兩個獨立 workspace（不用 pnpm workspaces，因為 Rails 是 Ruby，共用 TS 型別無意義）
- **Docker**：MVP 才用（跑 PostgreSQL），現在 Prototype 用不到
- **假資料策略**：JSON 檔當種子（`src/mocks/*.json`）+ Pinia store 管響應式狀態。**不用 MSW**。之後接 API 時，把 store 內的 mutation 改成 `fetch` 呼叫，component 不用動。
- **HTTP client**：**用原生 `fetch`，不裝 axios**。理由：現代瀏覽器已內建、少一個依賴、request/response 攔截需求可用薄薄一層 `api/http.ts` wrapper 解決（Phase 5 才建）。
- **UI 元件庫**：PrimeVue 4.5 with Aura theme 客製為 Trust Blue（Indigo #3b5bdb）。**特意 pin 在 4.x**：PrimeVue 5 引入 PrimeUI 商業授權模型，未帶 license key 會在頁面右下角顯示紅色 "Invalid PrimeUI License" banner（closed shadow DOM 藏不掉）。4.5.5 是 5.0 前最後穩定版，preset API（`definePreset` from `@primeuix/themes`）跟 5 相同，未來要升級也不痛。搭配 `@primeuix/themes@^2.0.3`。
- **設計系統風格**：Trust Blue — 借 Notion 底層 tokens（typography、spacing、rounded、灰階），主色改為 Indigo。因為 Notion 官方設計偏行銷風，不適合內部財務工具。
- **狀態徽章色**：`draft` 灰、`in_review` 橘、`rejected` 紅、`approved` 藍、`paid` 綠、`voided` 淺灰
- **Lint/Format**：ESLint 10 flat config + Prettier 3（單引號、無分號、trailing comma）
- **測試**：MVP 階段不做
- **Package manager**：pnpm 10

### 專案位置與命名

- 專案根：`/Users/laipeiying/Desktop/work/quickey/`
- 使用者的 `Desktop/work/` 是他所有專案的總目錄，不是本專案專用
- 本專案資料夾名：`quickey`（前身叫 `expense-tool`，2026-09 改名）

### 「MVP」的語義釐清

使用者的 PM 說「先做 MVP」，但當時對話中釐清：**目前實際在做的是 Prototype（前端 + 假資料），不是嚴格意義的 MVP**（MVP 需要真後端 + 部署 + 可讓真實用戶使用）。使用者的策略是 Prototype → MVP → v1.0 分階段推進。

## 目前的完成度

### ✅ Phase 1 - 基建（已完成）
- Vite + Vue 3 + TS 初始化
- 裝 Tailwind、Router、Pinia、PrimeVue 4.5 + `@primeuix/themes`、PrimeIcons（**不裝 axios**，之後用原生 `fetch`）
- ESLint / Prettier / TS strict 全設好
- 決定 UI 元件庫：PrimeVue

### ✅ Phase 2 - 骨架（已完成）
- 路由結構 `/login`, `/app/*`, `/admin/login`, `/admin/*`
- `FrontLayout`（手機 bottom tab bar）+ `AdminLayout`（桌面 sidebar）
- Router guard（未登入自動導 login、員工/管理員互不能跨區）
- Mock API 層（用 Pinia + JSON 替代 MSW）

### ✅ Phase 3 - 共用元件與 utility（已完成）
已建：
- `src/utils/format.ts`：`formatCurrency`（TWD，無小數）、`formatDate`（YYYY-MM-DD）、`formatDateTime`
- `components/StatusBadge.vue`：6 種請款狀態徽章（依 `design.md` status-badge-mapping）
- `components/AmountText.vue`：`tabular-nums` 金額顯示，支援 size / weight / tone
- `components/EmptyState.vue`：icon + title + description + action slot
- `components/PageHeader.vue`：標題 + 副標 + `#actions` slot，支援 `size="front|admin"`
- 現有 views（HomeView / HistoryView / ExpenseFormView / DashboardView / RecordsView / ReviewView / UsersView）全部套用 PageHeader / EmptyState / AmountText
- Button / Input / Select / DatePicker / Table / Modal / Pagination 直接用 PrimeVue，**不再 wrap**

### 🔲 Phase 4 - 頁面實作（尚未開始）
依風險由低到高開發：
1. 登入頁（已 functional，需精修）
2. 前台 - 表單填寫頁（含發票上傳、草稿保存）
3. 前台 - 歷史記錄頁
4. 前台 - 首頁儀表板（目前有 3 個統計卡片雛形）
5. 後台 - 請款記錄列表（PrimeVue DataTable）
6. 後台 - 審核列表 + 詳情（最複雜，多按鈕、駁回意見、發票查看）
7. 後台 - 儀表板（含 ECharts）
8. 後台 - 人員管理（CRUD）

### 🔲 Phase 5 - 串接（未來，接後端時）
Mock 換 `fetch`（可在 `src/api/http.ts` 建薄 wrapper 統一 base URL / 錯誤處理）、全站 Loading/Error 盤點、RWD 檢查

## 目前的檔案樹狀（frontend/src）

```
frontend/src/
├── App.vue                  # 掛 RouterView + Toast + ConfirmDialog
├── main.ts                  # 掛 Pinia + Router + PrimeVue(TrustBlue)
├── styles/                  # index.css（Tailwind v4 + @theme tokens）+ qds.css（設計系統 class）
├── presets/
│   └── trust-blue.ts        # PrimeVue Aura 客製為 Trust Blue
├── router/
│   └── index.ts             # 路由 + 權限守衛
├── layouts/
│   ├── FrontLayout.vue      # 手機 bottom tab
│   └── AdminLayout.vue      # 桌面 sidebar
├── views/
│   ├── front/
│   │   ├── LoginView.vue    # 已 functional
│   │   ├── HomeView.vue     # 3 個統計卡片雛形（讀 store）
│   │   ├── ExpenseFormView.vue  # placeholder
│   │   └── HistoryView.vue      # placeholder
│   └── admin/
│       ├── LoginView.vue    # 已 functional
│       ├── DashboardView.vue    # placeholder
│       ├── RecordsView.vue      # placeholder
│       ├── ReviewView.vue       # placeholder
│       └── UsersView.vue        # placeholder
├── stores/
│   ├── auth.ts              # 假登入（find by email）
│   └── expenses.ts          # 讀 mocks/expenses.json
├── types/
│   └── domain.ts            # Role, ExpenseStatus, ExpenseCategory, User, Department, ApprovalStep, ApprovalProgress, Expense
├── mocks/
│   ├── users.json           # 5 個測試帳號
│   ├── departments.json     # 工程部、財務部
│   └── expenses.json        # 6 筆涵蓋所有狀態
└── components/              # 空（Phase 3 才建 StatusBadge 等）
```

## 假登入帳號（見 `mocks/users.json`）

| Email | 職級 | 部門 | 前台 | 後台 |
|-------|------|------|:---:|:---:|
| ming@example.com | 員工 | 工程部 | ✅ | ❌ |
| hua@example.com | 員工 | 工程部 | ✅ | ❌ |
| lin@example.com | 主管 | 工程部 | ✅ | ✅ |
| zhang@example.com | 財務 | 財務部 | ✅ | ✅ |
| admin@example.com | 管理員 | — | ❌ | ✅ |

## 常用指令

```bash
cd /Users/laipeiying/Desktop/work/quickey/frontend
pnpm dev          # 開發 server (http://localhost:5173/)
pnpm build        # 打包 + 型別檢查
pnpm lint         # ESLint --fix
pnpm format       # Prettier
pnpm type-check   # vue-tsc
```

## Git 狀態

- 已 `git init`（分支 `main`）
- 已有 2 個 commit：
  1. `初始化前端專案骨架 (Prototype 階段)`
  2. `Phase 1-2 補完 (ESLint / Prettier / Router guard)`

## 使用者的協作偏好（觀察到的）

- **喜歡先問清楚再動手**：規格、技術選型都會反覆確認，不喜歡默默做
- **喜歡看到選項比較**：常要求「給我幾個方案」比較優缺點
- **繁體中文回應**
- **簡潔實用**：不喜歡冗長，喜歡表格對照
- **重視「這是什麼、為什麼」**：即使是熟悉的概念（如 MVP、Docker）也會問定義釐清
- **不喜歡過早引入複雜性**：MVP 階段砍功能、Prototype 階段砍後端、Docker 等到需要時再上

## 重啟對話後建議做的第一件事

1. 讀 `CLAUDE.md`（repo 根目錄；專案結構、慣例）
2. 讀 `docs/dev/design.md`（動 UI 前必讀）
3. 問使用者：「要從 Phase 3（共用元件）開始，還是先自己開瀏覽器看看目前狀態？」
