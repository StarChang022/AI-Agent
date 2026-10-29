# Quickey

**中小企業收支帳簿**：幫企業主與行政人員快速掌握「錢花到哪、誰花的、有沒有超預算、審核有沒有卡住」。

- 一般支出登錄（拍照 OCR / 文件上傳 / Excel 匯入 / 手動）
- 員工代墊款請款與一層審核
- 類別預算執行率
- 儀表板統計、Excel 匯出

**不**做正規會計科目全套與正式財報（外帳／報稅），現階段聚焦內部管理。

## 現階段

**Prototype**：前端 + 假資料，後端尚未開發。

## 技術棧

- **Frontend**：Vue 3.5 + Vite 8 + TypeScript + Tailwind CSS v4 + PrimeVue 4.5（Aura theme）+ Pinia
- **PWA**：vite-plugin-pwa
- **Backend / DB / 部署**：待定（見 `docs/技術選型.md`），部署預設自架雲端伺服器

## 專案結構

```
quickey/
├── frontend/     # Vue 3 前端
├── backend/      # 後端（尚未建立）
├── docs/         # 產品規格、資料模型、技術選型；開發文件在 docs/dev/
├── CLAUDE.md     # 給 Claude Code 讀的專案說明
└── README.md
```

Landing site（含部落格與後台管理）另外開一個 repo `quickey-landing`。

## 本地開發

### 前置條件（第一次）

- 安裝並啟動 [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- 安裝套件：
  ```bash
  cd backend && bundle install
  cd frontend && pnpm install
  ```
- 灌測試帳號（Postgres 需先起，或先跑一次 `./dev.sh` 之後再跑）：
  ```bash
  cd backend && bin/rails db:seed
  ```
  會建一家 seed 公司 + 3 個帳號（`admin@example.com` / `ming@example.com` / `zhang@example.com`，密碼皆 `password123`）。只在 `development` 環境跑，`find_or_create_by` 語意可重複執行。

### 一鍵啟動（推薦）

在專案根目錄執行：

```bash
./dev.sh
```

會依序：
1. 啟動 Docker Postgres（背景）
2. 跑 `rails db:migrate`
3. 前景並行啟動 Rails API（<http://localhost:3000>）與 Vite 前端（<http://localhost:5173>）

`Ctrl+C` 會停掉 Rails / Vite，Postgres 保留在背景（下次啟動更快、資料還在）。

### 常用指令

```bash
# 完全關掉 Postgres（資料仍保留）
docker compose -f backend/compose.yml down

# 清空資料庫重來（volume 一起刪）
docker compose -f backend/compose.yml down -v

# 只開前端（不需要後端時）
cd frontend && pnpm dev

# 只開後端（Postgres 需先起）
docker compose -f backend/compose.yml up -d db
cd backend && bin/rails s
```

## 相關文件

- 產品規格：`./docs/產品規格文件.md`（新版 PRD @2026/08/19）
- Sitemap：`./docs/sitemap.md`
- 資料模型：`./docs/資料模型.md`
- 技術選型（待團隊定案）：`./docs/技術選型.md`
- 分工討論：`./docs/產品延伸分工討論.md`
- 設計系統：`./docs/dev/design.md`
- 開發風格：`./docs/dev/dev-style.md`
- Claude 協作說明：`./CLAUDE.md`
