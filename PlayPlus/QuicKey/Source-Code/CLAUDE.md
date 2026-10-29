# CLAUDE.md — Quickey

## 專案概述

**Quickey**：中小企業收支帳簿。解決「錢花到哪裡、誰花的、有沒有超預算、審核有沒有卡住」，**不是**取代會計做帳或報稅。

功能雙軌並存：
- **一般支出**：管理員直接登錄（採購、廠商發票、訂閱費），無簽核。
- **代墊款請款**：員工前台提交 → 管理員一層審核 → 撥款 → 併入正式支出。

**現階段：Prototype（前端 + 假資料，尚未接後端）**。品牌先前叫 ExpensePal，2026-09 改名為 Quickey，同時 PRD 範圍從「單純代墊款」擴展成「支出總覽 + 代墊款」。

## 相關文件（**開發前務必依順序閱讀**）

**新版規格（Quickey 起點，優先讀）：**
- **產品規格文件**：`./docs/產品規格文件.md`（PRD @2026/08/19，定義新範圍、3 種角色、一層審核）
- **Sitemap**：`./docs/sitemap.md`（各模組與頁面欄位對照，含「後續擴充不做」清單）
- **分工討論**：`./docs/產品延伸分工討論.md`（Miki/Peggy/阿星 分工、MVP 邊界、超管+員工帳號模型）
- **資料模型**：`./docs/資料模型.md`（Reimbursement + Expense 雙 model 架構決策）
- **技術選型**：`./docs/技術選型.md`（後端/DB/OCR/自架部署 選項比較，**待團隊定案**）

**歷史文件（可選讀，供理解舊決策）：**
- `./docs/dev/CONTEXT.md`：ExpensePal 時期的簽核鏈設計紀錄
- `./docs/代墊款管理工具_PRD.md`：舊版 PRD（已被新 PRD 取代大部分內容）
- `./docs/代墊款管理工具_規格確認_Delta.md`：舊 PRD 補充；駁回重送與作廢邏輯仍適用

**設計 / 風格：**
- `./docs/dev/design.md`（**動 UI 前必讀**：色彩 tokens、元件模式）
- `./docs/dev/dev-style.md`（**動 UI/CSS 前必讀**：樣式三層架構、utility class 使用時機、無障礙屬性清單）

## 技術棧

| 層 | 現況 |
|---|---|
| Frontend framework | Vue 3.5 + Vite 8 + TypeScript |
| CSS | Tailwind CSS v4（CSS-first config，見 `frontend/src/styles/index.css`） |
| UI 元件庫 | PrimeVue 4.5（Aura theme 客製為 Trust Blue） |
| Icon | PrimeIcons |
| State | Pinia |
| Routing | Vue Router |
| PWA | vite-plugin-pwa（已加入 manifest + Service Worker） |
| HTTP | 原生 `fetch`（尚未使用） |
| Package manager | pnpm |
| Backend | **待定**（見技術選型：NestJS/Rails 二選一） |
| DB | **待定**（見技術選型：PostgreSQL 優先） |
| 部署 | **自架雲端伺服器**（見技術選型第四節） |

## Repo 分工

- **本 repo（`quickey`）**：主 App（前端 + 未來後端）
- **`quickey-landing`（尚未建立，獨立 repo）**：一頁式 Landing + 部落格 + 後台管理，Miki 主責

## 專案結構

```
quickey/
├── CLAUDE.md              # 本檔（AI 專案說明；Claude Code 自動載入）
├── README.md
├── docs/
│   ├── dev/               # 開發文件：design.md / dev-style.md / CONTEXT.md
│   ├── 產品規格文件.md     # 新 PRD / sitemap / 資料模型 / 技術選型 等
│   └── QA_list/
├── frontend/              # Vue 前端
│   ├── src/
│   │   ├── App.vue
│   │   ├── main.ts
│   │   ├── styles/        # index.css（Tailwind + @theme tokens）+ qds.css（設計系統 class）
│   │   ├── presets/       # PrimeVue 客製 preset
│   │   ├── router/
│   │   ├── layouts/       # FrontLayout / AdminLayout
│   │   ├── views/
│   │   │   ├── front/     # 員工前台（提交請款）
│   │   │   └── admin/     # 超管後台（審核/發放/支出/預算）
│   │   ├── stores/        # Pinia (auth, expenses, users)
│   │   ├── mocks/         # JSON 種子資料
│   │   ├── types/         # 領域型別（domain.ts）
│   │   ├── components/    # 共用元件
│   │   ├── utils/
│   │   └── api/           # fetch 封裝（待建）
│   └── vite.config.ts
└── backend/               # 未來後端（尚未建立）
```

## 關鍵領域概念

### 角色模型

`types/domain.ts` 的 `Role` 兩種：
- **`admin`（超級管理員）**：一家公司 1 名，Email 註冊時自動產生；可進後台管理所有東西（含審核、發放、人員、類別、預算）
- **`employee`（員工）**：由超管以 Email 邀請連結新增，最多 10 名；只能進前台提交請款、查看自己進度

Router 已在 `beforeEach` 做區域隔離：employee 進 `/admin/*` 會被導回前台，admin 進 `/app/*` 會被導回後台。個別 admin 導覽項若標了 `allowedRoles`，是為未來付費階段「後台權限細分」預留（自訂哪些員工能進哪些後台功能）。

### 請款記錄狀態（6 種，見 `ExpenseStatus`）

| Key | 中文 | 顏色 token |
|---|---|---|
| `draft` | 草稿 | `--color-status-draft` |
| `in_review` | 簽核中 | `--color-status-review` |
| `rejected` | 駁回 | `--color-status-rejected` |
| `approved` | 已核銷（待發放） | `--color-status-approved` |
| `paid` | 已發放 | `--color-status-paid` |
| `voided` | 已作廢 | `--color-status-voided` |

狀態流轉、駁回重送、作廢限制詳見 `docs/代墊款管理工具_規格確認_Delta.md` 第 C / D / F 節。

### 一般支出（新增功能，尚未實作）

一般支出與代墊款共用 UI，但**不走簽核**：登錄後直接寫入。輸入方式四種並存：拍照 OCR、文件上傳、Excel 匯入、手動建立。詳見 `docs/資料模型.md` §5.1 與 §5.2。

### 費用類別

現有前端：5 種寫死（material / tool / travel / service / other）。
新 PRD 目標：改為公司可自訂 + 3 個預設種子（交通費、餐費、辦公用品）。詳見 `docs/資料模型.md` §3.4。

## 開發原則

- **不建構後端相關功能**（現階段 Prototype）。所有資料互動只操作 Pinia store 中的 mock 資料。
- 新增/審核/駁回等動作要在 Pinia store 內以「就地改狀態」實作。之後接 API 時只需要在 store 內把 mutation 換成 `fetch` 呼叫，component 不用動。
- **不要新增測試**。MVP 階段跳過。
- **QA checklist 是每個模組/階段的必產文件**：
  - **時機**：開發前先產一份 `docs/QA_list/QA_<模組名>.md`；開發完成後由團隊依此清單人工核對通過與否
  - **視角**：撰寫對象是實際使用者（管理員 / 員工），**不用技術用語、不出現欄位 key、store 名、component 名**
    - ✗「`categoryId` fallback 為 id 字串」→ ✓「查不到類別時顯示原本記錄的類別名稱，不會整列消失」
    - ✗「Pinia store 的 `active` computed」→ ✓「新增支出時類別下拉選單」
  - **範圍**：只驗證**功能流程與業務規則**（可做什麼、擋什麼、資料流向何處），**不寫 UI 細節**（顏色、字級、hover、Tag severity、Toast 停留秒數等交由 `docs/dev/design.md` / `docs/dev/dev-style.md` 統一把關）
  - **格式**：以使用者情境分節（例如「新增類別」「停用類別」），每點寫成一條可勾選的動作 + 預期結果（`- [ ] 做 X → 看到 Y`）
  - **範例**：`docs/QA_list/QA_類別管理.md`
- 頁面 UI 一律套用 `docs/dev/design.md` 的 tokens 與元件模式，避免各頁自定顏色/間距。
- 狀態徽章、金額格式、日期格式應抽成共用元件或 utility，避免各頁重寫。
- **手機版文字大小以不超過 14px 為原則**（含 modal / dialog、表單 label、按鈕、input、卡片內容）。頁面主標題（PageHeader）可例外。若 PrimeVue 元件預設超過 14px，用 `@media (max-width: 639.98px)` 在 `styles/index.css` 覆寫。
- **後台管理頁面必須支援手機瀏覽**（行政人員可能在外面用手機處理審核）。
- **實作或修改元件時必須顧及無障礙（a11y）**：icon-only 按鈕加 `aria-label`、裝飾 icon 加 `aria-hidden="true"`、表單欄位綁 `<label for>`、Modal/Drawer 支援 Esc 關閉且 focus 進入時 trap、以語意元素（`<button>` / `<a>` / `<nav>`）承載互動而非 `<div @click>`。詳細清單見 `docs/dev/dev-style.md > 無障礙（Accessibility）`。

## 常用指令

```bash
cd frontend
pnpm dev              # 開發 server
pnpm build            # 打包
pnpm preview          # 預覽打包結果
```

## 測試帳號（後端 seed）

來源：`backend/db/seeds.rb`，掛在 seed 公司「Quickey Demo Co.」底下。
執行 `cd backend && bin/rails db:seed`（development 環境自動跑；測試站需帶 `SEED_DEMO_DATA=1`）。

| Email | 姓名 | 職級 |
|---|---|---|
| admin@example.com | 王管理 | 管理員 |
| ming@example.com | 陳小明 | 員工 |
| zhang@example.com | 張大同 | 員工 |

密碼一律 `password123`。
