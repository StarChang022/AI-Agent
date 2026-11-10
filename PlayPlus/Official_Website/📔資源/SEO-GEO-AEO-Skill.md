---
name: seo-geo-aeo
description: >
  PlayPlus 官網與內容行銷專屬之全方位 SEO（搜尋引擎優化）、GEO（生成式 AI 引擎優化 — 針對 ChatGPT Search、Perplexity、Google AI Overviews、Gemini、Claude）與 AEO（問答引擎優化 — 針對精選摘要 Featured Snippets、People Also Ask 與語音搜尋）實戰指南與網站審計技能。適用於：(1) 規劃與撰寫官網頁面、知識筆記（Blog）、作品集案例（Portfolio）時的 SEO/GEO/AEO 結構與寫作規範；(2) 對任何線上網址或本地網站專案（如 playplus2026）進行深度 SEO/GEO/AEO 審計並產出專業 Word (.docx) 與 PDF 報告。
---

# PlayPlus 最新 SEO / GEO / AEO 行銷實戰指南與審計技能

本文件為 PlayPlus（普魯士國際）的核心搜尋與 AI 能見度指南，結合最新 **SEO（傳統搜尋引擎優化）**、**GEO（Generative Engine Optimization，生成式引擎優化）** 與 **AEO（Answer Engine Optimization，問答引擎優化）** 權威研究與演算法標準。

**語言規範：** 除非使用者另有指定，所有對話輸出、文章規劃、內容撰寫與產出的審計報告文件預設均採用**繁體中文（Traditional Chinese，台灣商業與技術習慣用語）**，技術專有名詞可保留英文或中英對照。

---

# 第一部分：內容創作與網頁開發之 SEO / GEO / AEO 實戰準則（Creation Playbook）

當執行「撰寫文章規劃書」、「撰寫知識筆記／作品集內文」或「建置與優化官網頁面」時，必須嚴格落實以下三大維度的優化規範：

## 1. GEO 核心準則：讓 ChatGPT、Perplexity、Gemini 與 Google AI Overviews 主動引用

生成式 AI 搜尋引擎並非單純比對關鍵字密度，而是透過檢索增強生成（RAG）尋找**「高事實密度、高結構化、高可信度（E-E-A-T）且具獨特觀點」**的權威來源進行合成與引用（Citation）：

1. **開門見山與 AI 快速摘要（BLUF — Bottom Line Up Front）**：
   - 在每篇知識筆記或作品集案例的最開頭（第一個 `<h2>` 之前），必須設計 **「AI 快速摘要（Key Takeaways / 3 點核心重點）」**，以「**小標題：核心結論**」格式濃縮全篇痛點、分析方法與關鍵結論，方便 AI 爬蟲與忙碌的企業決策者於第一時間擷取全貌。
2. **提升 30%～40% AI 引用率的三大內容要素（Princeton GEO 實證法則）**：
   - **具體數據與量化指標（Statistics & Quantitative Proof）**：避免使用「大幅提升效率」、「很多客戶」等空泛形容詞；改用具體量化敘述（例如：「服務超過 200+ 家中小企業、維持 100+ 個活躍營運系統」、「將跨部門人工核對時間從每週 8 小時縮短至 15 分鐘」、「降低 80% 人為登打錯誤」）。
   - **真實案例與實務情境驗證（Case Study & Real-World Context）**：所有抽象觀點都必須搭配真實產業場景（如製造業巡檢、連鎖餐飲叫貨、科技總部會議室預約系統等），展現第一手實戰經驗（Experience）。
   - **專業領域語意共現（Domain Fluency & Entities）**：自然融入商業流程與軟體工程專有名詞（如：流程梳理、Figma 互動原型、RESTful API 串接、RBAC 權限控管、資料遷移、分階段 MVP 落地），建立專家語境。
3. **資訊增益（Information Gain — 拒絕 AI 水文）**：
   - 現代搜尋與 AI 引擎會降權「與網路既有文章千篇一律的拼湊內容」。每篇文章必須提供 PlayPlus 獨到的**「顧問決策框架」、「常見盲點拆解」或「評估檢核表」**，給出明確的判斷標準。
4. **品牌與作者實體清晰度（Entity Clarity & E-E-A-T）**：
   - 提及品牌時保持一致名稱（「PlayPlus 普魯士國際」），並透過頁面 JSON-LD（`WebPage`、`Organization`、`BlogPosting`、`FAQPage`）明確連結台北實體地址、電話與社群圖譜（`sameAs`）。

## 2. AEO 核心準則：奪取精選摘要（Featured Snippets）與問答區塊（PAA）

問答引擎優化旨在讓網頁成為決策者搜尋具體問題時的「唯一標準答案」：

1. **對話式問句標題（Question-Phrased Headings）**：
   - 規劃文章或服務頁的 `<h2>` / `<h3>` 標題時，優先採用目標受眾會直接詢問搜尋引擎或 AI 的自然問句（例如：*「套裝軟體與客製化系統怎麼選？」*、*「沒有 IT 部門的中小企業如何導入管理系統？」*）。
2. **黃金 40～80 字直答塊（Direct Answer Block）**：
   - 在問句型 `<h2>` / `<h3>` 正下方的第一個自然段，必須用 **40～80 個中文字（約 2～3 句話）直接給出最精準的定義或核心答案**，不講廢話鋪陳；直答段之後，再展開詳細的條列分析或案例說明。
3. **結構化比較表格與步驟清單（Tables & Ordered Lists）**：
   - 凡涉及「方案優劣比較（如 Excel vs 套版 ERP vs 客製化系統）」、「費用組成維度」、「適用情境對照」，一律規劃為 **Markdown / HTML 表格（`<table>`）**。
   - 凡涉及「導入步驟」、「驗收流程」、「檢核清單」，一律使用具明確順序的條列（`<ol>` / `<ul>`），且每點開頭使用粗體關鍵詞帶領。
4. **常見問題（FAQ）模組化配置**：
   - 服務頁與深度文章文末配置 3～5 題高搜尋意圖的常見問答（FAQ），並同步埋設 `FAQPage` JSON-LD 結構化資料。

## 3. SEO 核心準則：鞏固傳統搜尋排名與技術體質

1. **搜尋意圖精準對位（Search Intent Alignment）**：
   - 寫作前先確立該頁屬於「商業採購意圖（服務頁）」、「方案比較評估（知識筆記）」或「實績驗證（作品集）」，確保標題、前言與 CTA 完全契合讀者當下的決策階段。
2. **標題、Meta 與語意化階層規範**：
   - 嚴格遵守 `頁面基本元素.md` 與 `網站架構規範.md`：全頁唯一 `<h1>`、不跳階的 `<h2>`～`<h4>`、Title 控制於 25～30 中文字、Meta Description 控制於 70～85 中文字。
3. **主題叢集內部連結（Topic Cluster Internal Linking）**：
   - 每篇內容須規劃連往核心支柱服務頁（如 `services/enterprise-system.html`）與相關知識筆記／作品集的內部連結，並使用包含目標關鍵字的描述性錨點文字（Descriptive Anchor Text）。

---

# 第二部分：全站與單頁 SEO / GEO / AEO 審計流程（Audit Skill Workflow）

當使用者提供網址（URL）、網域或指定本地專案目錄（如 `playplus2026`），並要求進行「網站 SEO 檢查」、「SEO/GEO/AEO 審計」或「搜尋能見度分析」時，請依序執行以下 6 個步驟：

## Step 1: 確認審計範圍（Confirm Scope）

**在開始抓取或分析前，除非使用者已在指令中明確指定審計模式，否則請先詢問：**

> 「您希望進行 **快速審計（Quick Audit）**（聚焦首頁與核心頁面問題與評分，約需 1～2 分鐘）還是 **完整深度審計（Full Audit）**（全站多維度深入檢測與完整建議矩陣，約需 5～10 分鐘）？」

確認使用者選擇後再進入下一步。

---

## Step 2: 資料抓取與全站盤點（Fetch & Collect Data）

- **針對線上網址**：使用網頁讀取工具或 `browser` 子代理抓取完整 HTML、Meta 標籤、Schema 結構化資料、導覽列連結、`robots.txt`、`sitemap.xml` 與 `llms.txt`。
- **針對本地專案（如 `playplus2026`）**：直接掃描並讀取專案目錄下的 HTML 原始碼（`index.html`、`services.html`、`services/*.html`、`portfolio.html`、`portfolio/*.html`、`blog.html`、`blog/*.html`、`about-playplus.html`、`contact.html` 等）。
- **核心原則**：**絕不憑空猜測網站缺漏**。必須先完整盤點導覽列、頁尾與子目錄，確認某個頁面（如關於我們、作品集、FAQ、結構化資料）是否已存在於全站其他路徑。
  - **Quick Audit**：檢測首頁加上最多 6 個核心代表頁面。
  - **Full Audit**：完整檢測所有具備實質內容價值的頁面（包含服務內頁、作品集案例與近期部落格文章；僅略過隱私權政策、服務條款與純轉址頁）。

---

## Step 3: 三大維度信號深度分析（Analyze the Signals）

### 1. SEO Signals（傳統搜尋引擎優化）
- **Technical On-Page**：
  - `<html lang="zh-Hant-TW">` 語系宣告是否正確？
  - `<title>` 長度是否適中（25～30 中文字／50～60 字元）？是否包含核心關鍵字且全站無重複？
  - `<meta name="description">` 是否存在、長度適中（70～85 中文字）且具備吸引力與行動呼籲？
  - Heading 階層：是否具備唯一 `<h1>`？`<h2>`～`<h3>` 邏輯是否清晰且涵蓋次要關鍵字？
  - URL 結構與 `<link rel="canonical">` 是否乾淨、自我參照且無相對路徑錯誤？
  - 圖片 `alt` 屬性、`width`/`height` 尺寸宣告、`.webp` 格式與 Open Graph（`og:title`, `og:description`, `og:image`, `og:url`）是否完整（特別留意子目錄內頁的 `og:image` 路徑是否正確）？
  - 內部連結（Internal Links）與錨點文字是否具備語意描述性？
- **Content Quality**：
  - 內容字數與深度是否充足？關鍵字與語意關聯詞是否自然分佈？是否具備發佈或更新日期？
- **Structured Data**：
  - JSON-LD 語法是否正確？是否依頁面性質配置對應 Schema（`WebPage`, `Organization`, `Service`, `BlogPosting`, `FAQPage`, `BreadcrumbList`）？

### 2. GEO Signals（生成式 AI 引擎優化）
- **E-E-A-T（經驗、專業、權威、信任）**：
  - 團隊與作者背景（About 頁面、顧問團隊介紹）、實體聯絡資訊（NAP：名稱、地址、電話）、客戶實證案例与量化數據是否清晰可見？
  - 品牌實體宣告（Organization Schema、Logo、`sameAs` 社群連結）是否一致？
- **AI 合成與引用友善度（Content for AI Synthesis）**：
  - **開門見山（BLUF）**：頁面頂端或文章前言是否清楚陳述核心價值主張與快速摘要？
  - **事實密度（Factual Density）**：是否包含具體統計數據、專案實績數字、流程步驟與明確技術規格供 AI 引述？
  - **資訊增益（Information Gain）**：是否提供原創觀點、實務比較框架或避坑指南？
- **Technical GEO**：
  - AI 爬蟲可檢索性（無不當 `noindex` 或純 JS 渲染阻擋）、是否提供 `llms.txt` 或清晰的語意化 HTML 標籤？

### 3. AEO Signals（問答引擎與精選摘要優化）
- **精選摘要適格性（Featured Snippet Eligibility）**：
  - **直答區塊**：問句標題下方是否具備 40～80 中文字的精準直答段落？
  - **定義與清單／表格結構**：是否善用標準 `<table>` 比較表與 `<ol>`/`<ul>` 步驟清單？
- **結構化問答格式（Structured Answer Formats）**：
  - 標題是否涵蓋自然語言問句（如何、為什麼、多少錢、怎麼選）？
  - 是否埋設 `FAQPage` 或 `HowTo` JSON-LD 結構化資料？

---

## Step 4: 評分標準與對話視窗精簡摘要（Score Rubric & Chat Summary）

每個維度採 1～10 分制評分：
- **1–3 分（急需修正）**：存在嚴重技術阻礙或關鍵元素缺失
- **4–5 分（尚待加強）**：基礎未臻完善，錯失大量搜尋與 AI 引用機會
- **6–7 分（基礎良好）**：架構穩健，可針對特定進階項目優化
- **8–9 分（表現優異）**：符合現代最佳實踐，僅需微調細節
- **10 分（典範等級）**：全維度完美落實

在對話視窗中請先輸出以下**精簡摘要**，並將完整逐項分析寫入可下載的報告文件中：

```markdown
## 🔍 [網站名稱] — [快速 / 完整] SEO / GEO / AEO 審計摘要

**審核頁面數：** [數量與清單]  **審計日期：** [YYYY-MM-DD]

| 維度 | 分數 | 狀態 |
|---|---|---|
| SEO | X/10 | [需加強 / 良好 / 優良] |
| GEO | X/10 | [需加強 / 良好 / 優良] |
| AEO | X/10 | [需加強 / 良好 / 優良] |

**前 3 大優先改進建議：**
1. [具體指出頁面與首要改進項目]
2. [具體指出頁面與次要改進項目]
3. [具體指出頁面與第三改進項目]

**最大現有優勢：** [一句話點出網站目前表現最亮眼的核心優勢]

*詳細檢測結果、訊號逐項分析與完整改善建議矩陣已整理於下方報告文件中。*
```

---

## Step 5: 自動生成專業可下載報告（Generate Downloadable DOCX / PDF Report）

輸出對話摘要後，立即告知使用者：「正在為您生成可下載的審計報告...」，並使用 Node.js `docx` 套件生成顧問級 `.docx` 報告（若環境支援 `soffice` 則同步轉出 `.pdf`）。

### 1. 環境檢查
```bash
node -e "require('docx')" 2>/dev/null || npm install docx
```

### 2. 報告視覺與版面規範（Agency Deliverable Design）
- **色彩系統**：
  - 深海藍封面與表頭（Navy）：`1B2A4A`
  - 品牌強調藍（Accent Blue）：`2563EB`
  - 高分綠（8–10 分）：`16A34A`
  - 中分橘（5–7 分）：`D97706`
  - 低分紅（1–4 分）：`DC2626`
  - 表格交錯淺灰底：`F8F9FA`、邊框灰：`E2E8F0`、深色內文：`1E293B`、摘要區塊淺藍底：`EFF6FF`
- **字型與尺寸**：Arial / Noto Sans TC，封面主標 36pt Bold、H1 24pt Bold、H2 18pt Bold、H3 14pt Bold、內文 11pt、頁首頁尾 9pt。
- **報告章節順序**：
  1. **封面頁（Cover Page）**：滿版深海藍底（`1B2A4A`），置中呈現網域名稱、「SEO / GEO / AEO 深度審計報告」、審計類型、三維度彩色分數卡，底部標註審計日期與 **「PlayPlus 普魯士國際 SEO / GEO / AEO 審計報告」**。
  2. **執行摘要（Executive Summary）**：淺藍底重點框（3～5 句話具體總結網站現況、最迫切問題與最大機會點）＋ 三維度與總分（X/30）總表。
  3. **審核頁面清單（Pages Audited）**：列出所有檢測頁面的路徑、頁面類型與關鍵發現。
  4. **SEO 深度分析（SEO Analysis）**：分為 Technical On-Page、Content Quality、Structured Data 三張檢測表（欄位：檢測信號｜實際發現｜狀態評級）。
  5. **GEO 深度分析（GEO Analysis）**：分為 E-E-A-T 評估、AI 合成與引用友善度、Technical GEO 三張檢測表。
  6. **AEO 深度分析（AEO Analysis）**：分為 精選摘要適格性、結構化問答格式、語音與對話搜尋準備度 三張檢測表。
  7. **優先改善建議矩陣（Priority Recommendations Matrix）**：5 欄式全寬表格（優先級〔🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Quick Win〕｜問題與具體位置｜所屬維度｜執行難度｜預期影響）。
  8. **現有優勢亮點（What's Working Well）**：淺綠底（`F0FDF4`）表格，具體列出網站目前已落實良好的項目與實證。
  9. **專有名詞說明（Glossary，完整審計專用）**：簡明解釋 SEO、GEO、AEO 對企業商業成長的意義。
- **頁首與頁尾**：
  - 頁首：左側網域名稱，右側「SEO / GEO / AEO Audit Report」。
  - 頁尾：左側「PlayPlus 普魯士國際 SEO / GEO / AEO Audit Report」，右側頁碼。

### 3. 交付報告連結
於對話中提供標準 `file:///` 絕對路徑連結供使用者點擊下載，並在結尾主動詢問：
> 「您希望針對特定區域進一步深入探討或直接由我協助修改對應的網頁原始碼嗎？我也可以為您審計其他子頁面，或在調整完成後重新執行複檢。」
