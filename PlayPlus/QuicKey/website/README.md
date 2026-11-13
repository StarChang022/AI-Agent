# QUICKEY 官網（Landing）

從 `quickey` repo 的 `landing/` 拆出的獨立 repo（保留原 commit 歷史）。部署到 Cloudflare Pages，規格見 `docs/上線前規格.md`。

Node 版本：22（見 `.nvmrc`，先執行 `nvm use`）。

## 指令

```bash
pnpm install
pnpm dev          # 開發伺服器（前端）
pnpm build        # 打包：vite-ssg 在 Node 端預渲染每一頁，再產生 sitemap.xml / robots.txt（不需要瀏覽器）
pnpm build:pages  # Cloudflare Pages 的建置命令，等同 pnpm build
pnpm preview      # 預覽打包結果
pnpm type-check   # 型別檢查（前端 + functions/）
pnpm pages:dev    # 用 wrangler 在本機跑 Pages Functions（聯絡表單 API）
```

## 目錄

| 路徑 | 內容 |
|---|---|
| `src/` | 官網前端（Vue 3 + Vite + Tailwind v4） |
| `functions/api/contact.ts` | 聯絡表單 API（Cloudflare Pages Functions，`POST /api/contact`） |
| `apps-script/` | 備份試算表用的 Google Apps Script 程式碼與建立步驟 |
| `scripts/sitemap.mjs` | 建置後產生 sitemap.xml / robots.txt |
| `docs/` | 上線前規格、隱私權條文、Cloudflare Pages 設定步驟 |

## 本地測試聯絡表單

表單送出流程：驗證 Turnstile → 檢查欄位 → 用 Resend 寄信 → 背景備份到 Google 試算表（失敗時寄通知到 `ALERT_TO`）。本地要同時開兩個伺服器：

```bash
nvm use
pnpm install
cp .dev.vars.example .dev.vars   # 填入伺服器端金鑰（.dev.vars 不進 git）
pnpm build                       # wrangler 需要 dist/ 資料夾

# 終端機 1：Pages Functions，跑在 http://localhost:8788
pnpm pages:dev

# 終端機 2：前端，/api 會轉給 8788（見 vite.config.ts）
pnpm dev
```

打開 `http://localhost:5173/contact` 填表送出。

- **Turnstile**：本地用官方測試金鑰，前端的 site key 在 `.env.development`，伺服器端的 secret 在 `.dev.vars`。
  - secret `1x0000000000000000000000000000000AA`：一律通過
  - secret `2x0000000000000000000000000000000AA`：一律失敗（可以測「機器人驗證沒有通過」）
- **Resend**：網域還沒驗證前，寄件人只能用 `onboarding@resend.dev`，收件人只能是 Resend 帳號本人的 Email。`RESEND_API_KEY` 填假的值時，送出會失敗，送出按鈕上方會顯示「寄送失敗」，可以用來測失敗流程。
- **試算表**：`SHEET_WEBHOOK_URL`、`SHEET_TOKEN` 留空就略過備份。要測的話另建一份測試用試算表（步驟見 `apps-script/README.md`）。
- **試算表失敗通知**：備份失敗時寄「[官網] 試算表備份失敗」到 `ALERT_TO`（留空不寄）。要測的話把 `SHEET_TOKEN` 故意填錯，送出後應收到通知。
- 改了 `.dev.vars` 要重開 `pnpm pages:dev`。
- 伺服器紀錄只會印出錯誤原因，不會印出表單內容。

### 用 curl 直接測 API

測試 secret 只接受官方的假 token `XXXX.DUMMY.TOKEN.XXXX`：

```bash
# 欄位不合法 → 400 和 { errors }
curl -X POST http://localhost:8788/api/contact -H 'Content-Type: application/json' \
  -d '{"turnstileToken":"XXXX.DUMMY.TOKEN.XXXX","name":"","email":"abc","topic":"亂填","message":"","agree":false}'

# 沒有 token → 400
curl -X POST http://localhost:8788/api/contact -H 'Content-Type: application/json' \
  -d '{"name":"王小明","email":"ming@example.com","topic":"產品諮詢","message":"想了解方案","agree":true}'

# 合法資料 → 寄信成功 200；寄信失敗 502
curl -X POST http://localhost:8788/api/contact -H 'Content-Type: application/json' \
  -d '{"turnstileToken":"XXXX.DUMMY.TOKEN.XXXX","name":"王小明","email":"ming@example.com","topic":"產品諮詢","message":"想了解方案","agree":true}'
```

## 預渲染（vite-ssg）

`pnpm build` 用 [vite-ssg](https://github.com/antfu-collective/vite-ssg) 在 Node 端把每一頁渲染成靜態 HTML，爬蟲和社群預覽不用執行 JavaScript 就拿得到完整內容與 meta。

- 要輸出的頁面：`src/main.ts` 的 `includedRoutes`（靜態路由、每篇文章、404）。新增路由不用改；新增動態路由要加在這裡
- `<head>`（title、description、canonical、OG、JSON-LD）：`src/seo/seo.ts` 用 `@unhead/vue` 的 `useHead` 設定
- 元件的 setup 會在 Node 端執行：`window`、`document` 等瀏覽器 API 只能寫在 `onMounted` 或事件處理函式裡；載入時就會用到 `document` 的套件（例如 `lottie-web`）要在 `onMounted` 裡動態 `import()`，否則建置會失敗
- 新增 noindex 頁面或開放頁面時，`src/seo/pages.ts` 和 `scripts/sitemap.mjs` 的 `SITEMAP_ROUTES` 要一起改

## 部署

部署在 Cloudflare Pages：建置指令 `pnpm build:pages`，輸出目錄 `dist`，環境變數清單見 [`docs/上線前規格.md`](docs/上線前規格.md) 一-7。

## 設計 tokens

`src/styles/index.css` 的 `@theme` 區塊複製自主 App（`quickey` repo）的設計系統 `frontend/src/styles/index.css`，修改時兩邊要同步。

## 假資料

`src/config.ts` 內的註冊網址、LINE 官方帳號與 Email 目前皆為示範值，正式上線前要替換。
