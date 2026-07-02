# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

PlayPlus 普魯士國際（playplus.com.tw）的企業官網，基於 Canvas 7.3.1 主題模板。靜態 HTML 網站，使用 Gulp 建置流程產出最佳化的 `dist/` 資料夾部署至伺服器。

## 常用指令

```bash
npm run dev          # 啟動 BrowserSync 開發伺服器（watch 模式）
npm run build        # 完整建置流程（清理 → 複製資源 → minify → critical CSS → purge → 指紋化）
npm run scss         # 編譯 SCSS
npm run critical     # 僅產生 Critical CSS
npm run minify       # 僅執行 PurgeCSS + 壓縮 CSS/JS
```

## 建置流程（gulp build）

1. `cleanDist` — 清除 `dist/`
2. 平行複製資源（圖片、CSS、JS、其他檔案）
3. `minifyHTML` — 壓縮所有 HTML
4. `generateCritical` — 用 Puppeteer 產生 Critical CSS 並 inline
5. `purgeStyleCSS` → 平行 `minifyCSS` + `minifyJS` → 平行修正路徑
6. `revisionAssets` + `rewriteHTML` — CSS 檔案指紋化並更新 HTML 引用

## 架構

### 頁面結構
- 根目錄 `*.html` — 主要頁面（首頁、關於、聯絡、FAQ、服務總覽等）
- `services/` — 各服務詳細頁（web-design、app-development、chatbot、internal-systems）
- `blog/` — 文章頁，檔名格式 `YYYYMMDD-slug.html`
- `portfolio/` — 作品集個案頁

### 樣式
- `style.scss` — 主進入點，匯入所有 SASS 模組
- `sass/` — SASS 來源（基於 Canvas 主題：variables、mixins、bootstrap、layouts、shortcodes 等）
- `css/custom.css` — 專案自訂樣式
- `css/font-icons.css` — 圖示字型
- CSS 載入順序：`style.css` → `font-icons.css` → `custom.css`

### JavaScript
- `js/functions.js` / `js/functions.bundle.js` — Canvas 主題核心功能
- `js/plugins.*.js` — 各種插件（carousel、swiper、lightbox、isotope 等）
- `js/components/` — 自訂元件
- `js/modules/` — 自訂模組

### 圖片
- `images/` — 所有圖片資源，使用 WebP 格式
- `resize-services.mjs` — 用 sharp 批次產生服務圖片的不同尺寸

## 部署

- 推送至 `main` 分支觸發 GitHub Actions 自動部署
- CI 流程：checkout → npm install → npm run build → rsync `dist/` 到伺服器
- 網域：playplus.com.tw

## 注意事項

- HTML 中 CSS 使用 `?v=6` 版本參數（開發時），建置後由 `rev` 替換為 hash 指紋
- `generateCritical` 需要 Puppeteer，CI 環境需確保 Chrome 可用
- PurgeCSS safelist 包含動態 class（`show`、`active`、`owl-*`、`swiper-*` 等），新增動態 class 時需更新 safelist
- 修改 HTML 頁面後需確認 `gulpfile.js` 的 glob pattern 有涵蓋到
