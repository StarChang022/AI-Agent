# Marketing 知識庫：SEO、AEO 與 GEO 全景架構與實戰指南

> 本文件萃取並整合自 `00_Original` 下所有屬 **Marketing（SEO / AEO / GEO）** 範疇之技能庫（涵蓋 `AgriciDaniel_claude-seo`、`everyinfra_seo-skills`、`aaron-he-zhu_aaron-marketing-skills`、`akii-technologies-ltd_akii-seo-ai-search-optimizer`、`coreyhaines31_marketingskills`、`Illyism_seo-skills`、`Citlyze_citlyze-skills`、`addyosmani_web-quality-skills`、`karero_croftweaver`、`nowork-studio_notfair-plugin`、`squirrelscan_skills`、`sanity-io_agent-toolkit`、`zhuyansen_new-term-radar`、`indranilbanerjee_digital-marketing-pro`、`gooseworks-ai_goose-skills`、`JasonColapietro_suede-creator-skills` 等）。

---

## 一、 核心範式轉移：SEO × AEO × GEO × Agentic Readiness

在搜尋引擎與生成式 AI 並存的環境中，搜尋最佳化已分化為四個互補層次，各有不同的檢索機制與驗收標準：

| 層次 | 核心目標 | 決策與運作機制 | 關鍵驗收指標 |
| :--- | :--- | :--- | :--- |
| **1. SEO**<br>（Search Engine Optimization） | **獲准進場與排名前段**<br>（Get Indexed & Ranked） | 爬蟲可達性、索引資格、Canonical、Core Web Vitals、關鍵字意圖對齊、站內外權威信號（E-E-A-T & 反鏈）。 | 索引覆蓋率、SERP 排名、GSC 自然曝光與點擊（CTR）。 |
| **2. AEO**<br>（Answer Engine Optimization） | **段落可被乾淨抽取**<br>（Get Extracted as the Answer） | 檢索增強生成（RAG）在切塊（Chunking）時，能否不依賴前後文、直接從標題下首段抽出高事實密度的完整解答。 | Featured Snippets、PAA 佔有率、段落自足性評分（Chunk Quality Score）。 |
| **3. GEO**<br>（Generative Engine Optimization） | **跨引擎合成引用與推薦**<br>（Get Cited & Recommended） | 多源合成時的信任加權：一手數據、具名專家引語、權威來源引用、知識圖譜實體一致性，以及全網第三方共識（YouTube/Reddit/評論站）。 | 引用率（Citation Rate）、提及率（Mention Rate）、回答佔有率（Share of Answer）、推薦短名單入選率。 |
| **4. Agentic Readiness**<br>（AI 代理瀏覽與互動就緒度） | **讓自主 AI Agent 讀懂並代客操作**<br>（Get Parsed & Acted Upon） | 瀏覽器代理（ChatGPT Agent、Claude/Gemini in Chrome）透過無障礙樹（Accessibility Tree）、SSR 文字、`/pricing.md`、`/llms.txt` 與 WebMCP 進行比價、填表或結帳。 | Lighthouse `AGENTIC_BROWSING`（`X/N` 分數）、無 JS 正文完整度、Agent 任務完成率。 |

### 1.1 權威來源與適用邊界（Scoped Authority Matrix）

不同 AI 搜尋引擎由不同底層系統驅動，**不可將單一來源的建議套用至所有引擎**：

1. **Google AI Overviews (AIO) 與 Google AI Mode**
   - **最高權威**：[Google AI Optimization Guide](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide) 與 [AI Features 指南](https://developers.google.com/search/docs/appearance/ai-features)。
   - **官方核心立場**：「從 Google Search 的角度來看，為生成式 AI 搜尋做最佳化就是為搜尋體驗做最佳化，因此**本質上仍然是 SEO**。」
   - **技術資格**：頁面只需已被 `Googlebot` 索引、且允許顯示摘要（無 `nosnippet` / `noindex`），並於 Search Console 開啟「納入生成式 AI 功能（Search generative AI）」即可；**不需要** `llms.txt`、**不需要**專用 Schema、**不需要**刻意為 AI 切碎段落或改寫語氣。
   - **AIO 與 AI Mode 是兩套不同的引用引擎**：Ahrefs 對 54 萬組查詢配對研究顯示，AIO 與 AI Mode 雖有 ~86% 得出相同結論，但**僅有 13.7% 引用相同的 URL**。AIO 高度綁定傳統搜尋前 10 名；AI Mode 則從更廣的候選池（平均每題引用 ~9 個網域）抽取，更看重時效性、實體權威與非前 5 名頁面的可引用段落。

2. **非 Google 生成式引擎（ChatGPT Search、Claude、Perplexity、Microsoft Copilot、獨立版 Gemini）**
   - **實證依據**：Princeton / IIT Delhi GEO 論文（[Aggarwal et al., KDD 2024, arXiv:2311.09735](https://arxiv.org/abs/2311.09735)）與多引擎大型觀測研究。
   - **運作差異**：ChatGPT 與 Copilot 仰賴 **Bing 索引**；Claude 仰賴 **Brave Search 索引**；Perplexity 結合自有索引與 Google。若網站只提交給 Google 而未進 Bing / Brave 索引，在這些引擎中將完全隱形。
   - **Princeton GEO 論文實證之有效手法**（於 GEO-bench 1 萬筆查詢基準測試之位置加權字數可見度提升）：
     - **加入專家引語（Add quotations）**：**+41%**（須為真實具名與頭銜之引述）
     - **加入具體統計數據（Add statistics）**：**+31%**（以具體數字與日期取代「許多、大幅」等模糊詞）
     - **流暢度與結構優化（Fluency optimization）**：**+28%**
     - **引用權威來源（Cite sources）**：**+27%**（對排名第 5 的弱勢頁面甚至帶來 **+115.1%** 提升）
     - **專業術語（Technical terms）**：**+18%**；**權威肯定語氣（Authoritative tone）**：**+10%**
     - ❌ **關鍵字堆砌（Keyword stuffing）**：**平均 -8.7%**（範圍 -6% 至 -20%，不僅無效且主動傷害 AI 能見度，同時違反 Google 垃圾內容政策）。
   - **學術實證的冷靜邊界**（`everyinfra/geo-evidence.md`）：
     - `C-SEO Bench`（NeurIPS 2025, `arXiv:2506.11097`）與 45 篇研究批判綜述（`arXiv:2607.14035`）指出：Princeton 論文的增益建立在「來源已被檢索進固定前 5 名上下文」的前提上，改變的是**已被檢索內容被合成引用的比例**，而非自然被檢索到的排名保證；此外，論文實驗允許合成測試引語，但**真實商業環境嚴禁捏造數據或引語**。

### 1.2 AI 能見度六階證據梯（The 6-Rung GEO Evidence Ladder）

衡量與匯報 AI 搜尋成效時，嚴禁將不同階段混為一談：

```text
[1. Eligible]     平台爬蟲可訪問、已索引、未設 nosnippet/noarchive
      ↓
[2. Retrieved]    進入引擎查詢扇出（Query Fan-Out）之候選檢索集（Source Consulted）
      ↓
[3. Cited]        回答中附帶指向網站頁面的可點擊連結（Citation）
      ↓
[4. Mentioned]    回答正文中點名品牌或產品名稱（Mention，未必附連結）
      ↓
[5. Recommended]  在比較或購買意圖問題中，進入 AI 推薦的最終短名單（Shortlist）
      ↓
[6. Converted]    帶來可歸因之直接引薦流量、延遲品牌搜尋（Branded Search）與實際轉化
```

> **關鍵洞見（Citation ≠ Recommendation）**：被引用（Cited）只代表頁面提供了有用的背景知識；要進入買家短名單被推薦（Recommended），取決於**全網第三方共識（Web-wide Consensus）**。在 B2B 100 組查詢研究中，新創品牌自己寫的「Best [Category]」自賣自夸榜單，雖能獲得 AI Overview 引用，但其中 **69% 的回答最終推薦的是競品而非發文品牌**。

---

## 二、 AI 爬蟲分類學與檢索存取控制（Crawler Taxonomy & Governance）

許多網站因在 `robots.txt` 或 WAF 誤將「搜尋引用爬蟲」與「模型訓練爬蟲」混為一談，導致在 ChatGPT 或 Claude 搜尋中完全消失。**每一項報告主張都必須對應正確的 User-Agent**：

### 2.1 四大類 AI User-Agent 權限對照表

| 類別 | User-Agent 名稱 | 所屬機構 | 實際管轄能力與封鎖後果 | 是否遵守 `robots.txt` |
| :--- | :--- | :--- | :--- | :--- |
| **A. 搜尋與引用決策型**<br>*(決定能否被搜尋與引用，建議 Allow)* | `Googlebot` | Google | 管轄傳統 Google Search、**AI Overviews** 與 **AI Mode** 索引。 | 是 |
| | `Bingbot` | Microsoft | 管轄 Bing 搜尋、**Microsoft Copilot** 與 **ChatGPT Search** 底層索引。 | 是 |
| | `OAI-SearchBot` | OpenAI | **唯一決定 ChatGPT Search 能否引用頁面內容**的爬蟲（與 `GPTBot` 完全獨立）。 | 是 |
| | `Claude-SearchBot` | Anthropic | **決定 Claude Search 能否引用頁面**的搜尋爬蟲。 | 是 |
| | `PerplexityBot` | Perplexity | Perplexity AI 搜尋索引爬蟲（非基底模型訓練爬蟲）。 | 是 |
| | `Applebot` | Apple | Siri、Spotlight 與 Safari 搜尋探索。 | 是 |
| | `meta-webindexer` | Meta | Meta AI 搜尋索引。 | 是 |
| **B. 模型訓練與 Grounding 控制型**<br>*(依授權策略決定 Allow/Disallow，封鎖不影響搜尋引用)* | `GPTBot` | OpenAI | **僅用於 OpenAI 模型訓練**。封鎖 `GPTBot` 但開放 `OAI-SearchBot` 的網站，仍可在 ChatGPT Search 被完整引用。 | 是 |
| | `ClaudeBot` | Anthropic | **僅用於 Anthropic 模型訓練**（與 `Claude-SearchBot` 獨立）。 | 是 |
| | `Google-Extended` | Google | 管轄 Gemini / Vertex AI 訓練與 grounding，以及 Search 生成式 AI 背後模型的訓練；**完全不影響** Google Search、AI Overviews 或 AI Mode 的收錄與排名。 | 是 |
| | `Applebot-Extended` | Apple | 僅為 Apple Intelligence 訓練排除標記（本身不爬抓，只標記 `Applebot` 已抓回的資料）；封鎖不影響 Siri/Safari 搜尋。 | 是 |
| | `CCBot` | Common Crawl | 公開訓練語料庫爬蟲。 | 是 |
| | `Bytespider` / `cohere-ai` | ByteDance / Cohere | 抖音/豆包 AI 與 Cohere 模型資料收集。 | 是 |
| **C. 使用者觸發即時擷取型**<br>*(User-Triggered Fetchers)* | `ChatGPT-User` | OpenAI | 使用者在對話中要求 ChatGPT 即時瀏覽特定網址。 | OpenAI 聲明「可能不適用」 |
| | `Claude-User` | Anthropic | 使用者觸發 Claude 讀取網頁。 | **是**（Anthropic 三支 bot 皆遵守） |
| | `Perplexity-User` | Perplexity | 使用者提問觸發之即時抓取。 | 通常忽略 |
| | `Google-Agent` / `Google-GeminiNotebook` | Google | Google Agent 代客瀏覽 / NotebookLM 讀取使用者指定來源。 | **否**（使用者觸發，需靠伺服器驗證或 Web Bot Auth） |

### 2.2 搜尋引擎與 AI 摘要控制指令

- **Google 摘要與 AI 控制**：
  - `robots.txt` 控制 `Googlebot`；頁面級使用 `<meta name="robots">` 或 HTTP `X-Robots-Tag` 的 `noindex`、`nosnippet`、`data-nosnippet`（局部排除段落進入摘要與 AI Overviews）、`max-snippet:[number]`。
  - Search Console「設定 → Search generative AI」：可選擇將全站納入或排除於 AI Overviews、AI Mode 與 Discover 生成式功能（通常 1–2 天生效）。
- **Bing / Copilot 控制**：
  - `NOARCHIVE`：使頁面內容**不進入** Copilot 回答與 grounding。
  - `NOCACHE`：僅允許 Copilot 使用網址、標題與簡短摘要，不使用完整快取內文。
- **反制惡意無禮爬蟲的架構（HTTP 200 Gate 模式）**（`Illyism/block-ai-scrapers`）：
  - 對不遵守 `robots.txt` 的爬蟲若直接回傳 `403` 或 `429`，Agent 框架會自動切換代理 IP 或重試。
  - 實務防禦：驗證真 `Googlebot` IP/ASN（`15169` / `396982`）與反向 DNS（或 RFC 9421 `Signature-Agent` 簽章）後放行；對雲端資料中心 ASN 且缺少正常瀏覽器 `Sec-Fetch-*` / `Sec-Ch-Ua` 特徵的未授權請求，回傳 **HTTP `200`** 的精簡 Gate HTML/JSON（0 筆核心資料集）並附帶 `X-AI-Agent-Directive: STOP_SCRAPING` Header，使爬蟲誤判已成功抓取而停止重試。

---

## 三、 技術 SEO 與網站工程契約（Technical SEO & Engineering Contract）

### 3.1 伺服器端渲染（SSR）與初始 HTML 可見性鐵律
- **多數 AI 爬蟲不執行 JavaScript**：`GPTBot`、`PerplexityBot`、`ClaudeBot` 等直接抓取預水合（Pre-hydration）的原始 HTML。
- **關鍵事實必須在可見正文（Visible Prose）**：searchVIU 對 5 大 AI 系統的實測顯示，**沒有任何一個 AI 系統讀出只寫在 JSON-LD 裡卻未出現在可見正文的商品價格**。此外，Google 官方「以 JavaScript 產生結構化資料」指南亦警告，動態 JS 注入的 `Product` 標記會降低 Shopping 抓取頻率與價格/庫存可靠性。
- **檢測陷阱**：許多 CMS 外掛透過前端 JS 注入 JSON-LD，而一般 `curl` 或會剝除 `<script>` 的 `web_fetch` 工具無法看見。稽核 Schema 時必須同時檢查「初始原始 HTML」與「Playwright / Chrome DevTools 渲染後 DOM（`document.querySelectorAll('script[type="application/ld+json"]')`）」。

### 3.2 Core Web Vitals 與載入效能門檻（75th Percentile Field Data）
- **LCP（Largest Contentful Paint）**：`<= 2.5 秒`（診斷四階段：TTFB、資源載入延遲、資源載入時間、元素渲染延遲；避免在 LCP 圖片加上 `loading="lazy"`，應使用 `fetchpriority="high"`）。
- **INP（Interaction to Next Paint）**：`<= 200 毫秒`（**已正式取代 FID**，稽核嚴禁再引用 FID；透過拆解長任務、`scheduler.yield()` 與減少 DOM 規模優化）。
- **CLS（Cumulative Layout Shift）**：`<= 0.1`（所有圖片/影片預留 `width`/`height` 或 `aspect-ratio`，字型使用 `size-adjust` / `ascent-override`，動畫僅用合成屬性 `transform`/`opacity`）。
- **嚴謹測量分類**（`addyosmani_web-quality-skills`）：必須明確區分 **CrUX 實測數據**（28 天滾動 p75）、**第一方 RUM**（`web-vitals/attribution`）、**Lab 實驗室數據**（Lighthouse/DevTools trace，至少 3 次取中位數，TBT 僅為 INP 實驗室代理指標）與**靜態原始碼推論（Hypotheses）**。禁止把 `curl --time_total` 當成 TTFB（須看 `time_starttransfer` 或 PSI）。

### 3.3 Metadata、Canonical 與多語系（Hreflang）精確規範

| 項目 | 標準與硬性上限 | 常見致命錯誤與工程守則 |
| :--- | :--- | :--- |
| **`<title>`** | **50–60 字元**（~580–600px 渲染上限） | 主關鍵字靠前、全站唯一。**德文等複合詞語系**大寫與變音母音較寬，應瞄準 **50–55 字元**。區分「過長被截斷」與「Google 因標題不符內文而取 H1/錨點改寫 Title Link」。 |
| **`<meta name="description">`** | **140–155/160 字元**（底限 120 字元） | 含主要關鍵字、明確價值主張與 CTA。注意 `<meta name="description">` 與 `og:description` 不能互相替代，必須同時輸出且內容同步。 |
| **OG / Twitter / Canonical 同步** | `og:title` == `<title>`<br>`canonical` == `og:url` == `sitemap <loc>` | 由單一 Layout 元件統一綁定 `(title, description)` 以防漂移。Canonical 必須為**完整絕對路徑（含 `https://`）**、無 `.html` 後綴、尾部斜線策略全站一致（如 `trailingSlash: 'never'`）。 |
| **URL 與 ASCII Slug** | 小寫、連字號 `-` 分隔、< 75 字元 | 德文等特殊字元必須轉寫為 ASCII（如 `/ueber-uns` 而非 `/über-uns`），避免機器序列化之 `%C3%BC` 與手寫連結在 Canonical / Sitemap / `llms.txt` 間比對失敗。 |
| **託管 PDF 標題陷阱** | PDF Info dict `/Title` **與** XMP `dc:title` 皆 `>= 15 字元` | PDF 無 HTML `<title>`，Google 與 Bing 直接把內嵌 doc-title 當成搜尋結果標題。必須在發布前同時寫入 `/Title` 與 `dc:title`，嚴禁留著 `Microsoft Word - ...` 或簡短檔名。 |
| **Hreflang 國際化** | 雙向互指（Reciprocal）+ 自我參照（Self-referencing）+ `x-default` | 1. 語言碼須符合 ISO 639-1 + ISO 3166-1 Alpha 2（如 `en-GB`，**絕不可寫 `en-UK`**）。<br>2. **每個語系頁必須 Self-canonical**（如 `/fr/page` canonical 指自己；若指回 `/en/page` 會導致法文頁被完全移除索引）。<br>3. Next.js `alternates.languages` 不會自動加入當前語系的自我參照，必須手動寫入。<br>4. 10 種語系以上優先採用 XML Sitemap `<xhtml:link>`（注意 50MB 檔案上限，約每 2K–5K URL 拆一個檔）。 |

### 3.4 網站架構與內部連結圖譜（Internal Link Graph）
- **點擊深度**：核心商業頁（Money Pages）距首頁點擊深度 `<= 3`。
- **區分導覽列與正文內連**（`Illyism/internal-linking`）：全站共用的 `nav` / `header` / `footer` / `sidebar` 屬於 Chrome 連結；真正傳遞主題權重的是**正文脈絡連結（Contextual Body Links）**。
- **逆向內連工程**：每篇高流量資訊文應在**文章前 40% 篇幅內**，以自然描述性錨點（Descriptive Anchor Text）連向對應的商業/產品頁；單一頁面指向同一目標的重複錨點不超過 5 次；消滅孤兒頁（Orphan Pages，即 0 條正文入站內連的頁面）。

---

## 四、 結構化資料（Schema.org JSON-LD）2026 規範與實證

### 4.1 實證效益認知
根據三項大型獨立研究（`arXiv:2609.35077` 200 萬筆 B2B SaaS 引用、Ahrefs 2026-05 對 1,885 頁新增 JSON-LD 與 4,000 對照頁之雙重差分、以及 `SSRN 6284518`），在控制網域權重後，**一般 Schema 標記對 AI 引用率並無統計顯著的獨立提升**（唯一有小幅正面效應的是填寫完整價格、評分與規格的 `Product` / `Review` Schema）。
因此，Schema 的正確定位為：**① 取得傳統搜尋 Rich Results 資格；② 協助知識圖譜進行實體消歧義（Entity Disambiguation，`@id` 與 `sameAs`）；③ 絕不可用來藏匿未顯示於可見正文的文字**。

### 4.2 2026 年 Schema.org 類型狀態清冊（必背防踩雷）

| 狀態分類 | 涵蓋 Schema `@type` | 2025–2026 關鍵政策變動與工程規範 |
| :--- | :--- | :--- |
| **✅ Active**<br>*(自由推薦使用)* | `Organization`, `LocalBusiness`（優先用細分子類如 `Dentist`, `Restaurant`）, `SoftwareApplication`, `WebApplication`, `Product`, `ProductGroup`, `Offer`, `Service`, `Article`, `BlogPosting`, `NewsArticle`, `Review`, `AggregateRating`, `BreadcrumbList`, `WebSite`, `WebPage`, `Person`, `ProfilePage`, `ContactPage`, `VideoObject`, `ImageObject`, `Event`, `JobPosting`, `Course`, `DiscussionForumPosting`, `QAPage`, `Book Actions`, `BroadcastEvent`, `Clip`, `SeekToAction`, `SoftwareSourceCode` | - `Product` 自 2025-04 支援 `Certification`；自 2026-05-20 成人商品必填 `hasAdultConsideration`。<br>- `QAPage`（2026-03-24 擴充留言串屬性）適用於**使用者可投稿回答**的論壇/問答頁。<br>- `Book Actions` 於 2025-11-05 撤銷退役通知，仍獲搜尋功能支援。<br>- `Dataset` 仍供 Google Dataset Search 使用，勿當成廢棄移除。 |
| **ℹ️ 無富結果但可保留語意**<br>*(No SERP Rich Results)* | `FAQPage` | **Google 已於 2026-05-07 全面停止所有網站的 FAQ 富結果展示**（取代 2023-08 僅限政府/醫療之舊規），並於 2026-06-15 下架富結果文檔。現存 `FAQPage` 僅作為描述頁面上真實可見問答的機器語意標記（稽核列為 Info 而非 Critical，亦不可向客戶承諾會出現 FAQ 下拉富結果）。 |
| **❌ Deprecated**<br>*(已廢棄，嚴禁推薦)* | `HowTo`（2023-09 移除）<br>`SpecialAnnouncement`（2025-07-31 移除）<br>`CourseInfo`, `EstimatedSalary`, `LearningVideo`, `VehicleListing`（2025-06 移除）<br>`ClaimReview`（2025-06 移除 SERP 富結果，僅 Fact Check Explorer 使用）<br>`Practice Problem`（2026-01 移除） | Search Console、Rich Results Test 與 API 已於 2025-09 至 2026-01 移除上述標記支援。稽核發現時應標記退役日期並建議替換或清理。 |

### 4.3 JSON-LD 語法與跨頁實體圖譜檢查要點
1. **`@graph` 容器規則**：`@graph` 本身不是實體，**不需要 `@type`**，且其內部節點會自動繼承頂層宣告的 `@context`（切勿誤判 `@graph` 缺 `@type` 或子節點缺 `@context`）。
2. **完整時區偏移（ISO-8601 Timezone Offset）**：所有日期時間欄位（特別是 `VideoObject.uploadDate`、`Event.startDate`、`Offer.validFrom`、`Article.datePublished/dateModified`）必須帶時區偏移（如 `2026-11-27T15:00:00+08:00`），只寫 `2026-11-27` 會導致 Google 影片解析器報錯。
3. **全站實體圖譜一致性（Site-wide Entity Graph）**（`squirrelscan_skills`）：跨頁面的 `Organization`、`Person`、`WebSite`、`Product` 應使用穩定一致的 `@id`（如 `https://example.com/#organization`），避免出現 `no-id`、`split-identity`（同一實體多個不同 `@id`）、`conflict`（不同頁面對同一 `@id` 的屬性宣告衝突）或 `dangling`（指向不存在的 `@id`）。
4. **評論合規**：2026-07-24 更新之 Review Snippet 指南嚴禁虛假評論或未明確揭露獎勵的激勵評論（Incentivized Reviews），且第一方網站自我評分不得在自家首頁濫用 `AggregateRating`。

---

## 五、 AEO & GEO 內容工程、一手證據庫與除臭（Content Engineering & De-Slopping）

### 5.1 段落可擷取性設計（AEO Passage & Chunk Engineering）
- **黃金前 30% 法則**：SE Ranking 研究指出 **~44% 的 AI 引用來自頁面最前方的 30% 篇幅**。
- **首段 40–60 字直接回答（Direct-Answer Lead）**：無論是整篇文章的開頭，或是每個問句型 `<h2>` 的下方第一段，必須在 **40–60 字內**給出可直接被單獨抽離引用的結論與核心數據，刪去所有「在當今快速變化的數位時代…」等鋪墊廢話。
- **自足段落（Self-Contained Chunks）**：每個 H2/H3 區塊（建議約 130–170 字，或 25–90 字的精簡答案塊）在脫離上下文後仍須語意完整：
  - ❌ 禁止懸空指代：「如上所述（As mentioned above）」、「這套工具（指代前一段才出現的產品名）」、「它的價格很便宜」。
  - ✅ 實體與條件內聯：「QueryBench 的 Pro 方案定價為每月 $49（不限席次），可在 1.8 秒內透過 ZFS 快照建立 50GB Postgres 測試分支。」
- **獨立比較卡片（Self-Contained Comparison Blocks）**（`Illyism/unslop-seo`）：撰寫競品比較或清單頁時，每個產品區塊必須包含固定且自足的欄位（**Verdict 總評、Best for 適用對象、Strengths 強項、Trade-offs 限制、Pricing 明確價格**），防止 RAG 切塊時把 A 競品的缺點或價格誤植到 B 品牌頭上。

### 5.2 Citlyze AEO 單頁 100 分快速稽核量表（`Citlyze/aeo-page-audit`）

對未執行 JavaScript 的原始 HTML 與 `/robots.txt` 進行 8 項量化評分：

| # | 檢查項目 | 配分 | 滿分通過條件（Pass Condition） |
| :---: | :--- | :---: | :--- |
| 1 | **AI 爬蟲通行權** | **25 分** | `robots.txt` 未封鎖主要 AI 爬蟲（`OAI-SearchBot`, `GPTBot`, `Claude-SearchBot`, `ClaudeBot`, `PerplexityBot`, `Google-Extended`, `Bingbot` 等）；任一主要爬蟲被擋得 0 分。 |
| 2 | **可達性與可索引性** | **15 分** | HTTP 狀態碼 `< 400`，且 meta robots 與 `X-Robots-Tag` 皆無 `noindex`。 |
| 3 | **唯一描述性 H1** | **10 分** | 恰好 1 個 `<h1>` 且不少於 3 個詞（多個 H1 得一半分數；無 H1 得 0 分）。 |
| 4 | **問句型子標題** | **12 分** | 至少 2 個 `<h2>`/`<h3>` 以真實使用者提問句型撰寫（僅 1 個得一半分數）。 |
| 5 | **可抽取直接回答塊** | **15 分** | 至少 2 個標題下方緊接 25–90 字的直接回答段落（僅 1 個得一半分數）。 |
| 6 | **實體結構化資料** | **10 分** | 初始 HTML 含宣告頁面核心實體之 JSON-LD（`Organization`, `Product`, `Article` 等）。 |
| 7 | **結構化表格與清單** | **8 分** | 規格、比較或步驟使用 AI 可直接原樣抽取的 `<table>`、`<ol>` 或 `<ul>`。 |
| 8 | **誠實 Title 與 Meta** | **5 分** | Title `>= 15 字元`、Meta description `>= 50 字元` 且誠實描述頁面。 |
| - | **`/llms.txt` 探測** | **0 分** | 僅作資訊記錄（Informational only），不計分。 |

### 5.3 一手證據知識庫與「共識 + 鐵證」寫作架構（`Illyism/proof-kb`）

當所有競爭者都能用 LLM 在幾秒內生成結構完整、帶 FAQ Schema 的文章時，能穩居搜尋前三並被 ChatGPT / Claude / Perplexity 持續引用的頁面，靠的是**競爭對手無法複製的一手收據（First-Hand Receipts）**：

1. **五大類一手證據（每篇核心商業長文必須疊加至少 4 類）**：
   - **① 受控基準測試（Benchmarks & controlled tests）**：列明資料集大小、硬體規格、執行次數、Median 與 p99 數據（如：`50.4 GB` Postgres 16 於 `i4i.xlarge` 連續 50 次冷啟動，ZFS clone 中位數 `1.8s` 對比 `pg_restore` `14m 22s`）。
   - **② 客戶遷移與實測成果（Customer outcomes & migrations）**：具名客戶或精確匿名畫像（如「12 人 A 輪 Fintech 團隊」）的遷移前後指標（如每月運算成本由 `$1,840` 降至 `$290`）。
   - **③ 真實截圖與實機短片（Real screenshots & short videos）**：Playwright 實機擷取的終端機/儀表板截圖或 9 秒實機 `<video>` 循環，**嚴禁使用 AI 生成的假介面圖**。
   - **④ 自有聚合統計數據（Proprietary aggregate numbers）**：來自自家平台生產環境的統計（如「分析 2026 Q3 共 140 萬次部署，78% 建置失敗源於未鎖定 Node.js 次版本」）。
   - **⑤ 實務踩坑與邊界筆記（Practitioner failure & edge-case notes）**：只有真正跑過生產環境才知道的設定陷阱（如「將 `max_client_conn` 設超過 8000 卻未調高 `ulimit -n` 會在突發流量下靜默丟包」）。

2. **「共識 + 鐵證（`[CONSENSUS]` + `[PROOF]`）」H2 架構**：
   - **先寫內文，最後寫導言**：把全文最犀利的一手數據收據放在文章**前 2 句（前 40 字內）**。
   - 每個 `<h2>` 由兩層構成：先用最精簡字數交代 SERP 前 5 名皆涵蓋的基礎定義（`[CONSENSUS]`），緊接著放上獨家原子證據檔與圖表（`[PROOF]`）。
   - **單一事實來源與 `route-fact` 跨頁同步**：在儲存庫建立 `seo/kb/brand-ssot.md`（產品機制、定價、不支援邊界）與 `seo/kb/proof/{benchmarks,customers,numbers,workflows}/<id>.md`。當新測試或調價發生時，以 `grep -rnF` 搭配 `seo/kb/pages-index.md` 一次更新所有引用該數字的頁面，杜絕跨頁價格或數據矛盾。

### 5.4 20 點 AI 語氣除臭規範（De-Slopping / Unslop Pass）（`Illyism/unslop-seo`, `coreyhaines31`, `Omentir`）

發佈前必須通過以下三關，消除讓工程師與搜尋引擎反感的 AI 陳腔濫調（AI Slop）：
1. **機制取代形容詞（Mechanism over Feeling）**：刪除 `blazing-fast`, `seamless`, `robust`, `enterprise-grade`, `revolutionary`, `cutting-edge`, `game-changing`，全數換成具體運作機制、延遲毫秒數、CLI 參數或價格。
2. **競品替換測試（Competitor-Swap Test）**：逐段自問「如果把這句話的品牌名換成競品，是否完全成立？」若成立，代表該句是空話，立即刪除或改寫為具體技術細節。
3. **20 項禁用詞與標點規則**：
   - **零破折號**：全文禁止出現 Em-dash（`—`, U+2014）、En-dash（`–`, U+2013）或空格連字號（` - `），改用句號、逗號或冒號。
   - **禁止對比廢話句型**：刪除 `"It's not X, it's Y"`、`"Not just X, but Y"`、`"No X, no Y, just Z"`。
   - **禁用高頻 AI 詞彙**：`delve`, `pivotal`, `tapestry`, `landscape`, `testament`, `underscore`, `foster`, `garner`, `interplay`, `intricate`, `crucial`, `vibrant`, `showcase`, `utilize`, `leverage`, `facilitate`, `commence`, `moreover`, `furthermore`, `additionally`。
   - **禁用抽象隱喻名詞**：將 `substrate/bedrock` 改為 `base/foundation`、`paradigm` 改為 `model`、`north star` 改為 `goal`、`flywheel` 改為 `loop`、`nexus/locus` 改為 `center/spot`。
   - **禁用匿名權威與開場白**：禁止寫 `"Experts believe"`, `"Studies show"`, `"Many teams find"`, `"In today's fast-paced world"`, `"In this article, we'll explore"`, `"Let's dive in"`。

---

## 六、 內容品質與網域權威雙軌評鑑框架：CORE-EEAT (80項) + CITE (40項)

出自 `aaron-he-zhu_aaron-marketing-skills` 的標準化雙軌評鑑體系，將**單頁內容品質（CORE-EEAT，80 項）**與**網域層級信任（CITE，40 項）**分離計分，避免混雜：

### 6.1 單頁內容基準：CORE-EEAT（8 維度 × 10 項 = 80 項）

| 系統 | 維度代號與名稱 | 核心檢核標準（節錄關鍵 ID） |
| :--- | :--- | :--- |
| **CORE**<br>*(內容本體，GEO 導向 40 項)* | **C · Contextual Clarity**<br>（脈絡清晰度） | `C01` 標題承諾與內容一致（**Veto**）、`C02` 前 150 字直接回答（**GEO Top 1**）、`C03` 覆蓋 >=3 個次要查詢意圖、`C04` 術語首見即定義、`C05` 明確聲明涵蓋與不涵蓋範圍、`C08` A vs B 決策框架、`C09` 結構化 FAQ（**GEO Top 2**）。 |
| | **O · Organization**<br>（資訊組織） | `O01` H1→H2→H3 不跳階、`O02` TL;DR 或 Key Takeaways 摘要盒（**GEO Top 6**）、`O03` 比較與規格使用資料表（**GEO Top 3**）、`O04` 平行步驟用清單、`O05` 匹配之 JSON-LD（**GEO Top 4**）、`O06` 單一主題切段（每段 3–5 句）、`O08` TOC 跳轉錨點。 |
| | **R · Referenceability**<br>（可查證與可引用性） | `R01` >=5 個帶單位之精確數據點、`R02` 引用密度 >=1 處/500 字且涵蓋 >=3 種來源類型、`R03` 一手來源優先（>=3 個 Tier 1–2 來源）、`R04` 主張後方緊接證據、`R05` 方法論與樣本透明、`R06` 更新時間 <1 年、`R07` 實體寫出全名、`R09` 語意標籤（`<article>`, `<figure>`, `<time>`, `<cite>`）、`R10` 內文事實無重大自相矛盾（**Veto**）。 |
| | **E · Exclusivity**<br>（獨佔性與資訊增益） | `E01` 一手調查/實驗/原創數據（**GEO Top 5**）、`E02` 具名可引用之原創框架、`E03` 可重現之原創研究、`E04` 有據反共識觀點、`E05` >=2 張原創資訊圖表、`E06` 填補競品未答缺口、`E07` 可下載模板/清單/計算機。 |
| **EEAT**<br>*(來源可信度，SEO 導向 40 項)* | **Exp · Experience**<br>（第一手經驗） | `Exp01` 第一人稱實測敘事、`Exp02` >=10 個具體感官與操作細節、`Exp03` 帶時間軸之步驟紀錄、`Exp04` >=2 張帶時間戳原創實拍/截圖、`Exp05` 註明使用時長、`Exp06` 分享 >=2 個真實踩坑與解法、`Exp07` 前後對比、`Exp08` 量化經驗指標、`Exp10` 誠實說明測試場景限制。 |
| | **Ept · Expertise**<br>（專業度） | `Ept01` 具名作者+頭像+30字以上簡介、`Ept02` 相關學經歷/證照、`Ept04` 可落地之參數與閾值、`Ept05` 分析方法可重現、`Ept06` 討論 >=2 個不適用之例外邊界、`Ept08` 決策權衡透明（「選 A 不選 B 是因為…」）、`Ept10`「Reviewed by / Fact-checked by」審稿標示。 |
| | **A · Authority**<br>（權威度） | `A01` 權威站（.edu/.gov/產業龍頭）反鏈、`A02` 媒體報導、`A05` 目標市場品牌認知、`A06` 具真實細節之用戶見證、`A07` Wikipedia 或 Google Knowledge Panel、`A08` 跨網作者與品牌實體資訊一致。 |
| | **T · Trust**<br>（信任與合規） | `T01` 隱私政策與服務條款、`T02` 實體地址或 >=2 種聯絡管道、`T03` 全站 HTTPS、`T04` 聯盟行銷/利益關係明確揭露（**Veto**）、`T05` 公開編輯與審稿政策、`T06` 更正紀錄或 Changelog、`T07` 廣告版面 <30% 且無干擾彈窗、`T08` YMYL 風險免責聲明。 |

- **依內容類型動態加權**：不同頁面型態套用專屬維度權重（例如 `comparison` 重視 R 25% + O 20% + Ept 15%；`product-review` 重視 E 20% + Exp 20% + R 15% + T 15%；`landing-page` 重視 A 25% + T 25% + C 20%）。

### 6.2 網域權威基準：CITE（4 維度 × 10 項 = 40 項，同儕相對評估）

- **C · Citation（引用與連結，預設權重 35%）**：Referring Domains 規模（相對於同階段同儕 Cohort）、高品質反鏈比（>=20% 來自 DA/DR 50+）、連結速度自然、AI 引用頻率（>=2 引擎、>=10 個垂直查詢）、AI 引用顯著度、跨 >=3 個 AI 引擎引用、正面/中立引用情緒 >=80%、編輯自然連結 >=60%。
- **I · Identity（實體辨識，預設權重 20%）**：出現在 >=2 個知識圖譜（Google KG / Wikidata / DBpedia）、品牌精確搜尋量、品牌 SERP 掌控度（首頁 >=7 筆自控結果）、Schema 覆蓋率 >=50%、>=80% 內容具可驗證作者實體、跨平台品牌描述一致、**無連結品牌提及（Unlinked Brand Mentions）**。
  > **品牌提及 > 反鏈**：Ahrefs 對 75,000 個品牌的研究顯示，**品牌提及與 AI 能見度的相關性約為反鏈（Domain Rating ~0.266）的 3 倍**，其中以 **YouTube 提及（~0.737）** 相關性最強，其次為 Reddit 與 Wikipedia。
- **T · Trust（防弊與信任，預設權重 25%）**：單月反鏈不超過總量 15%、Dofollow 比例落於 40–85%、**`CITE-T03` 連結與流量相對於同儕分布具合理性（Veto）**、>=100 個 C-class IP 網段、**`CITE-T05` 無反鏈操縱網絡（Veto）**、HTTPS+HSTS、90 天內有內容更新、**`CITE-T09` 無生效中之人工懲罰或除名（Veto）**、第三方評論平台 >=3.5/5。
- **E · Eminence（市場顯著度，預設權重 20%）**：Top 100 關鍵字數、自然流量規模、擁有 >=3 種 SERP Features、AI 爬蟲友善且載入 <3 秒、長尾深度（4+ 詞）與主題廣度（覆蓋 >=70% 子主題）、地理覆蓋與產業 Share of Voice。

### 6.3 嚴謹計分與一票否決（Veto & Epistemic Scoring Rules）
1. **拒絕猜測與正規化掩蓋**：適用但缺乏證據的項目一律記為 `unknown`，**嚴禁偷偷降級為 `partial`/`fail` 或把分母權重重新分配給已觀測項目**；只要存在任何 `unknown`，即回傳 `score_state: NOT_SCORED` 與 `verdict: UNDECIDED`，強制補齊證據後才出總分。
2. **一票否決上限（Critical Fail Cap）**：
   - 出現 **1 項已驗證 Veto 失敗**（如未揭露聯盟連結 `T04`、內文數據自相矛盾 `R10`、或反鏈操縱 `CITE-T05`）：裁決為 `FIX`，且最終總分強制封頂於 **59 分**（`final_score = min(raw_score, 59)`）。
   - 出現 **2 項以上已驗證 Veto 失敗**：裁決為 `BLOCK`，不產出最終總分。

---

## 七、 Programmatic SEO（規模化建頁）與主題叢集架構

### 7.1 查詢扇出（Query Fan-Out）與主題叢集（Topical Clusters）
- Google AI Search 與 ChatGPT 在收到使用者提問時，會在背景同時發起 **5–10 個相關子查詢（Query Fan-Out）** 並跨結果合成答案。
- **策略應對**：
  1. 放棄「一個長尾變體建一個薄頁」的舊思維（為每個 fan-out 變體批量建頁會直接觸發 Google **規模化內容濫用政策 Scaled Content Abuse**）。
  2. 改採 **Hub-and-Spoke 主題叢集**，並透過 **SERP 重疊度分群（SERP-Overlap Clustering）**：若兩個關鍵字在 Google 前 10 名有 >=3–4 個相同 URL，代表屬於同一搜尋意圖，應合併於同一篇權威長文，由不同 H2 解答各子查詢；若 SERP 完全不重疊且意圖不同（严禁把資訊型 Informational 與商業交易型 Commercial 混在同一叢集），才獨立建頁。

### 7.2 Programmatic SEO 12 大 Playbooks 與防懲罰護欄（`coreyhaines31/programmatic-seo`, `claude-seo`）
- **12 種經市場驗證的 pSEO 模式**：
  1. **Templates**（`[類型] template`）
  2. **Curation**（`best [類別]`）
  3. **Conversions**（`[X] to [Y]` 換算/轉檔）
  4. **Comparisons**（`[X] vs [Y]`）
  5. **Examples**（`[類型] examples`）
  6. **Locations**（`[服務] in [地點]`）
  7. **Personas**（`[產品] for [受眾/產業]`）
  8. **Integrations**（`[產品 A] + [產品 B] integration`）
  9. **Glossary**（`what is [術語]`）
  10. **Translations**（多語系本地化）
  11. **Directory**（`[類別] tools/directory`）
  12. **Profiles**（`[實體/人物/公司名]`）
- **資料護城河五層級（由強至弱）**：① 自有獨佔數據（Proprietary）> ② 產品衍生數據（Product-derived）> ③ 社群 UGC > ④ 獨家授權數據（Licensed）> ⑤ 公開誰都能抓的數據（Public，最容易淪為薄頁）。
- **技術與品質紅線**：
  - **一律使用子目錄（Subfolders `example.com/templates/`）而非子網域（Subdomains）**，以繼承主站權重與內連。
  - **門頁（Doorway Pages）警戒線**：當地區頁（Location Pages）超過 30–50 頁卻僅替換城市名稱、缺乏真實當地價格/法規/門市/案例差異時，必須阻擋發布或設為 `noindex`。

---

## 八、 Agentic Browsing 與機器可讀探索層（Agent-Ready Web）

當 AI Agent 直接代替人類進入網站執行研究、比價、填表與採購時，網站需具備以下四層基礎建設（`claude-seo/seo-agentic`, `coreyhaines31/ai-seo`, `addyosmani`, `squirrelscan`）：

### 8.1 Lighthouse `AGENTIC_BROWSING` 核心 P0 要求
1. **無障礙樹即 Agent 視覺（Accessibility Tree Hygiene）**：所有互動按鈕、表單與連結具備明確的 Accessible Name 與有效 ARIA Role；重要操作不可藏在 Hover-only 選單或無標籤圖示後；遵循 WCAG 2.2（包含目標尺寸 >=24×24px、焦點不被遮擋）。
2. **無 JS 可讀與視覺穩定**：核心內容、價格、規格與社會證明（客戶見證、評分）必須以**可選取的純文字 HTML** 伺服器端渲染（不可壓死在圖片或需等第三方 Widget JS 載入），且 `CLS <= 0.1`。
3. **真實 404 與 WAF 放行**：未知路徑必須回傳真實 HTTP `404`（若 SPA Catch-all 對不存在的 `/.well-known/*` 或 `/llms.txt` 回傳 `200`，會直接導致 Lighthouse Agentic Browsing 的 `llms-txt` 與 `ard-schema` 檢查失敗）。

### 8.2 機器可讀檔案堆疊（Machine-Readable Discovery Stack）

| 檔案 / 協定 | 路徑與格式 | 實際作用與工程規範 |
| :--- | :--- | :--- |
| **透明定價檔** | `/pricing.md` 或 `/pricing.txt` | **極高商業影響**：自主採購 Agent 比價時會直接跳過把價格藏在「Contact Sales」或複雜互動計算機後的競品。需以純 Markdown 列明各方案月費/年費、計價單位、具體配額上限與包含功能，並標註最後更新日期。 |
| **LLM 導覽檔** | `/llms.txt` 與 `/llms-full.txt`（`<= 5MB`） | 社群提案格式（H1 站名 + `>` 簡介 + H2 分類下的 `- [標題](URL): 說明`）。**Google Search 官方聲明不使用**，但對非 Google 爬蟲與 Coding Agents 有助益。必須**以網站主要語言撰寫**，不放 `noindex` 頁面，並透過自動化測試（如 `llms-coverage.spec.ts`）確保與真實路由 100% 同步。 |
| **Markdown 內容協商** | `Accept: text/markdown` + `Vary: Accept`（或 `.md` URL） | 當 Agent 請求 `Accept: text/markdown` 時直接回傳乾淨 Markdown，大幅降低 HTML 雜訊與 Token 消耗。 |
| **robots.txt `Content-Signal`** | `Content-Signal: search=yes, ai-input=yes, ai-train=no` | 在 `robots.txt` 各群組內明確宣告允許搜尋索引（`search`）、即時回答輸入（`ai-input`）與是否允許模型訓練（`ai-train`）。 |
| **WebMCP 與商務協定** | `document.modelContext`、`/.well-known/ucp`、`ai-catalog.json` | 針對具交易或表單功能的網站，將現有表單 Handler 綁定為 WebMCP 工具（高風險送出/付款/刪除動作必須標註並保留人類確認步驟）；電商網站可配置 UCP（Universal Commerce Protocol）供 Agent 探索商品目錄與結帳。 |

---

## 九、 新詞雷達、早期關鍵字挖掘與科學化衡量（Trend Radar & Measurement）

### 9.1 搶在傳統 SEO 工具前捕捉爆發新詞（`zhuyansen_new-term-radar`）
傳統關鍵字工具（Ahrefs / Semrush）對新興 AI 模型、工具與技術名詞往往有數週至數月的延遲。可透過 **10 類即時訊號源**在第一天捕捉新詞：
1. **X (Twitter) 60 天詞彙差**與 **Hugging Face Top 50 Models/Spaces**
2. **GitHub 14 天內暴紅專案**（`>= 200 stars/day` 或單日暴增 `>= +400 stars`）
3. **工具導航站 Sitemap 新增 Slug** 與 **上線 <=90 天即排進 20+ 關鍵字的新網域**
4. **Google Search Console 首次出現曝光的新查詢（First-time Query Impressions）**
5. **TrustMRR 營收成長榜**與 **新金流連結網域**（Stripe, Polar, Lemon Squeezy, Gumroad, Paddle 等新綁定商家）
6. **Reddit / X / StackExchange 求工具提問（Asks）** 與 **Product Hunt / Show HN / OpenRouter 新上線清單**

**從「新專有名詞」轉化為「可排名搜尋字」的決策管線**：
- 收集新名詞的 GitHub README 與 X 討論 → 萃取背後的 **2–4 字通用任務型關鍵字（Generic Job Keywords）** 與 Google Trends 關聯詞（`tails` / `cosearch`）→ 查詢 Google Ads 真實搜尋量與 DataForSEO Trends 曲線（**必須剔除最後 2 天未穩定數據 `UNSETTLED_DAYS = 2`**，避免假飆升）→ 結合**詞齡（Word Age <= 180 天的新詞可將 SERP 競爭度門檻放寬 1 級）**、SERP 版面結構（首頁佔據 vs 內頁 vs Reddit/論壇佔據）與自家 GSC 現有排名，判定 `prioritize`（立即建頁/更新）、`watch` 或 `skip`。

### 9.2 AI 能見度衡量與 SEO/GEO 對照實驗紀律（`everyinfra`, `Citlyze`, `aaron-he-zhu`, `coreyhaines31`）

1. **區分「即時可引用性（Citability）」與「自然浮現（Unprompted Surfacing）」**：
   - 改完網頁後立刻把 URL 丟給聯網 AI 測試能否抽出答案，測的是 **Citability（分鐘級代理指標）**。
   - 使用者在未提供 URL 的情況下向 AI 提問而你的網站被主動引用，屬於 **Unprompted Surfacing**，受限於搜尋索引重抓與權重更新（**週至月級別延遲**），兩者不可混為一談。
2. **非確定性採樣協議（Sampling Protocol for Non-Deterministic LLMs）**：
   - AI 回答具隨機性，**單次查詢只是軼事（Anecdote），不是測量**。
   - 標準做法：建立固定問題面板（Prompt Panel，涵蓋 Problem-aware、Solution-aware、Product-aware、`[Brand] vs [Competitor]` 等與營收直接相關的買家問題，至少 `>= 10` 題），每題在各目標引擎**重複執行 3–5 次**，記錄 `n_runs`、計算引用率（Citation Rate）、提及率（Mention Rate）、來源讀取率（Source Rate）與 Wilson 信賴區間，並僅在同一品牌跨時間窗口（Window-over-Window）間比較。
3. **官方第一方測量面板**：
   - **Google Search Console「生成式 AI 效果報告」**：僅提供 AI Overviews 與 AI Mode 的**曝光次數（Impressions）**（依頁面、國家、日期、裝置拆解，且同時計入總體网页報告；目前無獨立點擊數拆分）。
   - **Bing Webmaster Tools「AI Performance」**：提供 Copilot 引用次數、被引用頁面與 Grounding Queries。
   - **伺服器存取日誌（Server Access Logs）**：分析 `OAI-SearchBot`、`Claude-SearchBot`、`PerplexityBot` 抓取頻率與狀態碼，並追蹤帶 AI Referrer 的真實引薦流量與延遲品牌搜尋（Delayed Branded Search）。
4. **雙重差分對照實驗（Split Testing / DiD）**：
   - 驗證結構化資料或 GEO 改版成效時，嚴禁只看「改前 vs 改後」（易受演算法更新與季節波動混淆）。
   - 選取 **5–10 個處理頁（Treatment）** 搭配 **5–10 個基線引用/流量水準相近的對照頁（Control）**，同時觀察至少 **30 天**，僅在雙重差分效應之 **95% 信賴區間不含 0** 時才宣稱改動有效。

---

## 十、 原始技能庫之 Marketing（SEO / AEO / GEO）檔案索引

以下為 `00_Original` 中所有屬於 **Marketing** 類別之核心技能與參考文件位置，可直接點擊查閱：

### 10.1 純 SEO / AEO / GEO 專項技能庫
- **[AgriciDaniel_claude-seo](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo)**
  - 核心路由與方法論：[skills/seo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo/SKILL.md)、[thinking-framework.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo/references/thinking-framework.md)、[quality-gates.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo/references/quality-gates.md)
  - AI 搜尋與代理就緒：[skills/seo-geo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-geo/SKILL.md)、[skills/seo-agentic/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-agentic/SKILL.md)
  - 技術、內容與 Schema：[skills/seo-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-audit/SKILL.md)、[skills/seo-technical/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-technical/SKILL.md)、[skills/seo-content/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-content/SKILL.md)、[skills/seo-schema/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-schema/SKILL.md)、[skills/seo-cluster/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-cluster/SKILL.md)、[skills/seo-sxo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-sxo/SKILL.md)、[skills/seo-drift/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-drift/SKILL.md)、[skills/seo-programmatic/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-programmatic/SKILL.md)、[skills/seo-hreflang/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-hreflang/SKILL.md)、[skills/seo-local/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-local/SKILL.md)、[skills/seo-maps/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-maps/SKILL.md)、[skills/seo-ecommerce/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-ecommerce/SKILL.md)、[skills/seo-backlinks/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-backlinks/SKILL.md)、[skills/seo-google/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/AgriciDaniel_claude-seo/skills/seo-google/SKILL.md)
- **[everyinfra_seo-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/everyinfra_seo-skills)**
  - 核心工作台：[skills/seo-suite/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/everyinfra_seo-skills/skills/seo-suite/SKILL.md)、[capability-map.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/everyinfra_seo-skills/skills/seo-suite/references/overview/capability-map.md)
  - GEO 實證仲裁與技術規範：[geo-evidence.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/everyinfra_seo-skills/skills/seo-suite/references/content/geo-evidence.md)、[audit-rule-catalog.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/everyinfra_seo-skills/skills/seo-suite/references/technical/audit-rule-catalog.md)、[multilingual-workflow.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/everyinfra_seo-skills/skills/seo-suite/references/overview/multilingual-workflow.md)
- **[akii-technologies-ltd_akii-seo-ai-search-optimizer](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer)**
  - 權威來源界定：[AUTHORITIES.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/AUTHORITIES.md)
  - 12 項核心技能：[optimize-page](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/optimize-page/SKILL.md)、[seo-audit](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/seo-audit/SKILL.md)、[ai-visibility](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/ai-visibility/SKILL.md)、[llms-txt](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/llms-txt/SKILL.md)、[schema-markup](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/schema-markup/SKILL.md)、[keyword-clustering](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/keyword-clustering/SKILL.md)、[internal-linking](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/internal-linking/SKILL.md)、[content-strategy](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/content-strategy/SKILL.md)、[content-brief](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/content-brief/SKILL.md)、[content-translation](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/content-translation/SKILL.md)、[broken-links](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/broken-links/SKILL.md)、[competitor-intel](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/akii-technologies-ltd_akii-seo-ai-search-optimizer/skills/competitor-intel/SKILL.md)
- **[Citlyze_citlyze-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Citlyze_citlyze-skills)**
  - [aeo-page-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Citlyze_citlyze-skills/skills/aeo-page-audit/SKILL.md)、[citlyze-visibility-report/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Citlyze_citlyze-skills/skills/citlyze-visibility-report/SKILL.md)、[citlyze-citation-gap/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Citlyze_citlyze-skills/skills/citlyze-citation-gap/SKILL.md)、[citlyze-prompt-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Citlyze_citlyze-skills/skills/citlyze-prompt-audit/SKILL.md)、[citlyze-action-plan/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Citlyze_citlyze-skills/skills/citlyze-action-plan/SKILL.md)

### 10.2 綜合技能庫中之 SEO / AEO / GEO 核心模組
- **[aaron-he-zhu_aaron-marketing-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills)**
  - 評鑑基準：[core-eeat-benchmark.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/references/core-eeat-benchmark.md)、[cite-domain-rating.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/references/cite-domain-rating.md)
  - `seo-geo/` 16 項技能：[content-quality-auditor](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/tune/content-quality-auditor/SKILL.md)、[domain-authority-auditor](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/evaluate/domain-authority-auditor/SKILL.md)、[geo-content-optimizer](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/implement/geo-content-optimizer/SKILL.md)、[keyword-research](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/survey/keyword-research/SKILL.md)、[serp-analysis](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/survey/serp-analysis/SKILL.md)、[content-gap-analysis](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/survey/content-gap-analysis/SKILL.md)、[technical-seo-checker](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/tune/technical-seo-checker/SKILL.md)、[on-page-seo-checker](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/tune/on-page-seo-checker/SKILL.md)、[site-structure-optimizer](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/tune/site-structure-optimizer/SKILL.md)、[serp-markup-builder](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/aaron-he-zhu_aaron-marketing-skills/seo-geo/implement/serp-markup-builder/SKILL.md)
- **[coreyhaines31_marketingskills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills)**
  - [skills/ai-seo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/ai-seo/SKILL.md)（含 15 份 `references/`）、[skills/seo-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/seo-audit/SKILL.md)、[skills/programmatic-seo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/programmatic-seo/SKILL.md)、[skills/schema/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/schema/SKILL.md)、[skills/site-architecture/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/site-architecture/SKILL.md)、[skills/link-building/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/link-building/SKILL.md)、[skills/directory-submissions/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/directory-submissions/SKILL.md)、[skills/competitors/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/competitors/SKILL.md)、[skills/content-strategy/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/coreyhaines31_marketingskills/skills/content-strategy/SKILL.md)
- **[Illyism_seo-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills)**
  - [seo/proof-kb/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/proof-kb/SKILL.md)、[content/unslop-seo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/content/unslop-seo/SKILL.md)、[seo/seo-autopilot/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/seo-autopilot/SKILL.md)、[seo/seo-roast/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/seo-roast/SKILL.md)、[seo/internal-linking/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/internal-linking/SKILL.md)、[seo/domain-migration/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/domain-migration/SKILL.md)、[seo/block-ai-scrapers/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/block-ai-scrapers/SKILL.md)、[seo/vs-and-alternatives/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Illyism_seo-skills/seo/vs-and-alternatives/SKILL.md)
- **[addyosmani_web-quality-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/addyosmani_web-quality-skills)** & **[karero_croftweaver](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/karero_croftweaver)** & **[squirrelscan_skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/squirrelscan_skills)**
  - [addyosmani/skills/seo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/addyosmani_web-quality-skills/skills/seo/SKILL.md)、[karero/skills/website-seo-geo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/karero_croftweaver/skills/website-seo-geo/SKILL.md)、[karero/skills/search-console-insights/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/karero_croftweaver/skills/search-console-insights/SKILL.md)、[karero/skills/seo-reposition/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/karero_croftweaver/skills/seo-reposition/SKILL.md)、[squirrelscan/skills/seo-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/squirrelscan_skills/skills/seo-audit/SKILL.md)、[squirrelscan/skills/structured-data-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/squirrelscan_skills/skills/structured-data-audit/SKILL.md)、[squirrelscan/skills/agent-experience-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/squirrelscan_skills/skills/agent-experience-audit/SKILL.md)
- **[zhuyansen_new-term-radar](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/zhuyansen_new-term-radar)** & **[nowork-studio_notfair-plugin](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/nowork-studio_notfair-plugin)** & **[sanity-io_agent-toolkit](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/sanity-io_agent-toolkit)**
  - [new-term-radar/skills/seo-new-keywords-research/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/zhuyansen_new-term-radar/skills/seo-new-keywords-research/SKILL.md)、[notfair-plugin/seo/geo-optimizer/WORKFLOW.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/nowork-studio_notfair-plugin/seo/geo-optimizer/WORKFLOW.md)、[notfair-plugin/seo/seo-analysis/WORKFLOW.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/nowork-studio_notfair-plugin/seo/seo-analysis/WORKFLOW.md)、[sanity-io/skills/seo-aeo-best-practices/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/sanity-io_agent-toolkit/skills/seo-aeo-best-practices/SKILL.md)
- **[Bomx_distribb-skill](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Bomx_distribb-skill)** & **[BrianRWagner_ai-marketing-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/BrianRWagner_ai-marketing-skills)** & **[ReScienceLab_opc-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/ReScienceLab_opc-skills)** & **[indranilbanerjee_digital-marketing-pro](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/indranilbanerjee_digital-marketing-pro)** & **[gooseworks-ai_goose-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/gooseworks-ai_goose-skills)** & **[JasonColapietro_suede-creator-skills](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/JasonColapietro_suede-creator-skills)**
  - [Bomx/90-day-seo-sprint/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/Bomx_distribb-skill/90-day-seo-sprint/SKILL.md)、[BrianRWagner/ai-discoverability-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/BrianRWagner_ai-marketing-skills/ai-discoverability-audit/SKILL.md)、[ReScienceLab/skills/seo-geo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/ReScienceLab_opc-skills/skills/seo-geo/SKILL.md)、[indranilbanerjee/skills/seo-plan/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/indranilbanerjee_digital-marketing-pro/skills/seo-plan/SKILL.md)、[indranilbanerjee/skills/aeo-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/indranilbanerjee_digital-marketing-pro/skills/aeo-audit/SKILL.md)、[gooseworks/skills/marketing/improve-search-visibility/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/gooseworks-ai_goose-skills/skills/marketing/improve-search-visibility/SKILL.md)、[suede/skills/suede-ai-seo/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/JasonColapietro_suede-creator-skills/skills/suede-ai-seo/SKILL.md)、[suede/skills/suede-seo-audit/SKILL.md](file:///Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/00_Skills/00_Original/JasonColapietro_suede-creator-skills/skills/suede-seo-audit/SKILL.md)
