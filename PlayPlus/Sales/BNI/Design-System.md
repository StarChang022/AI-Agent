# 參考網站設計系統規範文件 (Reference Visual Design System)

本文件深度拆解所提供之 6 頁參考網站截圖（涵蓋：**首頁繁體中文版**、**企業平台方案頁**、**專案管理／AI 代理頁**、**企業專業服務頁**、**關於我們頁**、**聯絡業務／顧問諮詢頁**），完整彙整其設計哲學、Design Tokens、色彩系統、文字排版、圓角陰影、核心元件庫、版面節奏與 B2B 高轉換視覺模式，作為 `Sales / BNI` 簡報與相關網頁設計之設計系統基準。

---

## 1. 設計哲學與核心原則 (Design Philosophy & Principles)

參考網站採用典型的 **現代 B2B SaaS × 企業級科技顧問（Enterprise Work OS）** 視覺語言，在「極簡白底的清晰商業閱讀」與「高張力深色宇宙／品牌紫藍視覺」之間取得高度平衡：

1. **高對比光影節奏 (Light-to-Dark Narrative Rhythm)**
   - **資訊閱讀與轉換表單區**採用高明度純白（`#FFFFFF`）與冷調薰衣草灰（`#F5F6FA` / `#F1F3FF`），降低表單與文字的閱讀壓力。
   - **產品架構與 AI 核心展示區**切換為深邃極黑（`#000000`）與深靛藍（`#1F0F83`）氛圍光暈，營造科技深度與產品立體層次。
2. **理性結構 × 人性溫度 (Structured UI × Human Warmth)**
   - 大量運用**真實人物肖像搭配浮動 UI 卡片**（Human-in-the-loop），避免純軟體截圖帶來的冰冷感，強化「科技為人服務」的信任感。
3. **精準的視覺焦點標記 (Intentional Focal Highlights)**
   - 運用**暖黃膠囊螢光底色**（Highlight Pill）標註標題關鍵字（如 *services*、*partners*），並以「主要靛藍紫（`#6161FF`）」與「極黑膠囊按鈕（`#000000`）」明確區分全站導覽 CTA 與頁面內情境 CTA。
4. **模組化卡片與視覺框景 (Framed Product Showcases)**
   - 產品 Mockup 不直接裸露貼圖，而是以**柔和粉彩外框（薰衣草紫、薄荷綠、深海松綠、極致黑）**與大圓角容器進行「裝框（Framing）」，建立強烈的視覺秩序與品牌識別度。

---

## 2. 色彩系統 (Color Palette & Tokens)

以下色票由 6 張參考頁面截圖實際採樣並收斂定義為統一 `:root` CSS Variables（Design Tokens）：

### 2.1 品牌核心色 (Brand Core Colors)
| Token 名稱 | Hex 色碼 | 視覺特徵 | 主要使用情境 |
| :--- | :--- | :--- | :--- |
| `--brand-primary` | `#6161FF` | 🟣 品牌電光靛紫 | 全站導覽主 CTA（`Get Started →`）、表單送出鈕（`Submit`）、AI 產品主識別、數據橫幅底色 |
| `--brand-primary-hover` | `#5038FF` | 🟣 深電光紫 | 主按鈕 Hover 狀態、漸層光暈過渡 |
| `--brand-indigo-deep` | `#1F0F83` | 🔵 深邃靛藍 | 企業安全區塊底色、深色科技背景光暈、Impact Banner |
| `--brand-indigo-mid` | `#422AA1` | 🟣 中階皇家紫 | 深色區漸層光暈過渡、卡片微光邊框 |
| `--brand-obsidian` | `#000000` | ⬛ 極致黑 | 頁面內次級主 CTA 膠囊鈕（`Contact sales →`、`Get started →`）、產品展示深色宇宙底色 |
| `--brand-charcoal` | `#181B34` / `#1F1414` | ⬛ 深石板黑 | 主要標題與正文文字（高對比深色）、深色方案卡底色 |

### 2.2 中性與版面底色 (Neutrals & Surface Colors)
| Token 名稱 | Hex 色碼 | 視覺特徵 | 主要使用情境 |
| :--- | :--- | :--- | :--- |
| `--surface-white` | `#FFFFFF` | ⬜ 純白畫布 | 全站基礎背景、表單浮動卡片、Accordion 區塊、Footer 底色 |
| `--surface-cool-gray` | `#F5F6FA` / `#F6F7FB` | ⬜ 冷調淺灰藍 | 客戶引言卡片（Testimonial Card）、交替雙欄底色、分析師評比卡底色 |
| `--surface-lavender-tint` | `#F1F3FF` / `#F2F3FF` | 🟪 淡薰衣草底 | Fortune 500 案例大橫幅底色、企業文化價值卡片底色（About Us） |
| `--surface-warm-sand` | `#F7F3EA` | 🟨 暖調燕麥米 | 編輯式敘事區塊底色（專案管理頁流程文字牆），柔和區隔冷灰區段 |
| `--surface-dark-card` | `#080809` / `#161223` | ⬛ 深色玻璃卡片 | 深色模式下的產品功能卡、企業資安 4 欄卡、分析師獎章卡 |
| `--text-primary` | `#181B34` | ⬛ 深藍墨黑 | 主標題（H1–H3）、內文核心文字 |
| `--text-secondary` | `#5C595B` / `#676879` | ◽ 中度中性灰 | 副標題、引言職稱、說明段落、表單提示文字、Footer 連結 |
| `--border-default` | `#D2D2D7` / `#E6E7EA` | ◽ 細灰邊框 | 表單輸入框邊框、FAQ 分隔線、卡片微框線 |
| `--border-dark-subtle` | `rgba(255, 255, 255, 0.14)` | ◽ 深色半透框線 | 深色宇宙背景上的玻璃擬態卡片框線 |

### 2.3 語意色與產品線強調色 (Semantic & Product Accent Colors)
參考系統同時使用一組高飽和度、明快的機能色彩來區分不同產品線、狀態標籤與插畫框景：

| Token 名稱 | Hex 色碼 | 視覺特徵 | 主要使用情境 |
| :--- | :--- | :--- | :--- |
| `--accent-yellow-mark` | `#FFFFC3` / `#FFCC00` | 🟨 螢光暖黃標記 | 標題關鍵字背後之膠囊色塊（如 `services`、`partners`）、進行中狀態 |
| `--accent-periwinkle` | `#97AEFE` | 🟦 柔霧長春花藍 | 專業服務頁圖文框景面板底色、工作流卡片視覺底框 |
| `--accent-teal-deep` | `#125F59` | 🟩 深海松綠 | 專業服務頁維運圖文面板底色、深色光暈點綴 |
| `--accent-emerald` | `#00C875` / `#70D8A8` | 🟩 翡翠綠／薄荷綠 | 達成／完成狀態（Done）、Dev 開發模組識別、Mint 方案卡框景 |
| `--accent-cyan` | `#20C0E8` / `#00A8E8` | 🟦 晴空青藍 | CRM 產品線卡片識別、即時數據圖表亮點 |
| `--accent-coral` | `#FF5870` | 🟥 珊瑚粉紅 | Service／客服產品線卡片識別、警示與重點標記 |
| `--accent-lavender-card` | `#DED4F9` | 🟪 柔薰衣草紫 | 方案級別卡底色、產品 Mockup 外框背景 |
| `--accent-violet-quote` | `#9050FF` | 🟣 亮紫羅蘭 | Bento Grid 大型引言卡底色、AI Agent 圖示強調色 |

---

## 3. 字體與排版規範 (Typography System)

全站字體表現具備強烈的幾何現代感與極佳的閱讀清晰度；於繁體中文版（首頁截圖）與英文版之間保持一致的字重階梯與緊湊標題行距。

### 3.1 字型家族 (Font Stack)
```css
/* 英文與數字優先使用現代幾何無襯線體（如 Poppins / Figtree），中文搭配 Noto Sans TC */
--font-display: "Poppins", "Plus Jakarta Sans", "Noto Sans TC", -apple-system, BlinkMacSystemFont, sans-serif;
--font-sans: "Figtree", "Inter", "Noto Sans TC", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
```

### 3.2 字級層級 (Type Scale Hierarchy)
| 層級 (Level) | 桌面端尺寸 | 字重 (Weight) | 行高 (Line Height) | 字距 (Tracking) | 使用場景範例 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hero Display** | `48px ~ 64px` | `600 ~ 700` | `1.1 ~ 1.15` | `-0.025em` | 頁面首屏大標（如 *Talk with our sales team...*、*您的首選工作平台*） |
| **Section Title (H2)** | `36px ~ 44px` | `600 ~ 700` | `1.18 ~ 1.25` | `-0.02em` | 區塊主標（如 *Trusted by top Fortune 500...*、*FAQs*） |
| **Sub-Heading / Stat** | `24px ~ 32px` | `600 ~ 700` | `1.25 ~ 1.3` | `-0.015em` | KPI 大數字（`8x`、`$351,336`、`186,000+`）、卡片大標 |
| **Card Title (H3)** | `18px ~ 22px` | `600 (SemiBold)` | `1.35` | `-0.01em` | 方案卡標題、表單卡標題（*Contact our sales team*）、手風琴問題 |
| **Lead / Subtitle** | `16px ~ 18px` | `400 (Regular)` | `1.55 ~ 1.6` | `0` | Hero 副標、區塊導讀、引言本文 |
| **Body / UI Control** | `14px ~ 15px` | `400 ~ 500` | `1.5 ~ 1.6` | `0` | 一般內文、表單欄位、按鈕文字、導覽列連結 |
| **Caption / Legal** | `12px ~ 13px` | `400 ~ 500` | `1.45` | `0.01em` | Footer 連結、條款聲明、指標副標（`saved per month`）、Eyebrow Tag |

### 3.3 特殊標題排版技巧
* **關鍵字膠囊螢光底 (Inline Highlight Pill)**：將標題中的單一關鍵詞包裹於帶圓角暖黃底色（`background: #FFFFC3` 或 `#FFEC8B`、`padding: 0 12px`、`border-radius: 9999px`）的 `<span>` 中，在黑白極簡排版中創造立即視覺記憶點。
* **超大背景文字牆 (Oversized Muted Statement)**：於暖米底（`#F7F3EA`）右側以 `32px ~ 40px` 半透明低對比字體縱向列出流程關鍵詞，營造編輯感與呼吸空間。

---

## 4. 圓角、陰影與空間尺寸 (Elevation & Geometry)

### 4.1 邊界圓角 (Border Radii)
參考網站顯著偏好**大圓角（Soft-Rounded Geometry）**，賦予科技產品親和力與現代質感：
- `--radius-xs (6px ~ 8px)`：表單輸入框（Input / Select / Textarea）、小型 UI 標籤。
- `--radius-md (12px ~ 16px)`：一般功能小卡（Values Card、Partner 2×2 浮動卡、FAQ 區塊內框）、表單外框容器。
- `--radius-lg (20px ~ 24px)`：大型圖文展示面板（Periwinkle / Teal 框景容器）、Bento Grid 卡片、Case Study 橫幅容器、深色平台展示框。
- `--radius-xl (28px ~ 32px)`：全寬圓角大區塊（如 `#F1F3FF` 案例包裝盒、全寬產品展示區外框）。
- `--radius-pill (9999px)`：全站所有主要 CTA 按鈕（`Get Started →`、`Contact sales →`、`Submit`）、膠囊徽章、關鍵字螢光標籤。

### 4.2 深度與陰影 (Elevation & Shadows)
整體走**低陰影、靠色塊區分層次**路線，僅在「表單卡片」與「懸浮 UI 元素」使用柔和擴散陰影：
```css
/* 浮動表單卡 / Case Study 疊加卡 */
--shadow-card-float: 0 12px 40px rgba(24, 27, 52, 0.08), 0 2px 8px rgba(24, 27, 52, 0.04);

/* 產品展示內嵌小 UI 視窗 / Partner 浮動方塊 */
--shadow-ui-widget: 0 8px 24px rgba(24, 27, 52, 0.06);

/* 深色宇宙模式發光卡片光暈 */
--shadow-dark-glow: 0 0 48px rgba(97, 97, 255, 0.22);
```

### 4.3 容器與間距節奏 (Container & Vertical Rhythm)
- **頁面最大內容寬度**：`1200px ~ 1280px` 置中對齊（`padding-inline: 24px ~ 32px`）；全寬色帶／深色背景橫跨 `100vw`。
- **區段垂直間距 (Section Spacing)**：桌機版標準為 `80px ~ 120px` 上下留白，確保每個敘事段落各自獨立、不顯擁擠。

---

## 5. 版面結構與全站骨架 (Layout Architecture)

```
+-----------------------------------------------------------------------------------+
| Global Header (height: 68px; Sticky; White #FFFFFF)                               |
| [Logo]  [AI platform v] [Solutions v] [Resources v] [Enterprise]   Pricing Log in [Get Started ->] |
+-----------------------------------------------------------------------------------+
| (Optional) Sub-Navigation Bar (e.g., WorkOS | Services | Partners with underline) |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  1. HERO SECTION (3 類常見變體)                                                   |
|     - Variant A (Conversion Split): 左側價值主張 + 引言卡 | 右側浮動表單卡          |
|     - Variant B (Centered Editorial): 置中大標(含螢光詞) + 副標 + 黑/紫膠囊鈕      |
|     - Variant C (Product Showcase): 左文右人像+UI | 下接信任企業 Logo 橫幅        |
|                                                                                   |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  2. FEATURE & SOLUTION SHOWCASE (交替色帶與雙欄節奏)                               |
|     - 左右交替 50/50 卡片（文字+手風琴 ↔ 色彩框景面板+人物與浮動 UI）              |
|     - 多欄產品矩陣卡（Lavender / Mint / Dark 方案比較，或 4 色產品群組）           |
|     - 深色宇宙轉場區塊（#000000 + 靛藍光暈：Interactive Tabs / AI 展示 / 資安 4 欄）|
|     - Bento Grid 不對稱多格敘事（人像卡 + 箭頭功能卡 + 亮紫引言卡）               |
|                                                                                   |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  3. SOCIAL PROOF & TRUST (案例與第三方背書)                                        |
|     - Rounded Lavender Box (#F1F3FF): 滿版實景暗底圖 + 右側懸浮白底數據案例卡      |
|     - G2 / Gartner 分析師評比雙欄卡 + 徽章橫列                                    |
|                                                                                   |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  4. CONVERSION & FAQ (收斂疑慮與最終轉換)                                          |
|     - 2 欄 FAQ（左欄標題+CTA | 右欄分隔線手風琴清單）                              |
|     - 雙欄或全寬收尾 CTA Banner（人像群組 / 動態光點 + 單一強 CTA）                |
|                                                                                   |
+-----------------------------------------------------------------------------------+
| Global Footer (#FFFFFF, Top border subtle)                                        |
| [6-Column Link Directory: Brand / Use cases / Capabilities / Apps / Company / Resources] |
| [Language Selector + Compliance Badges] [Social Icons + Legal Links] [App Stores] |
+-----------------------------------------------------------------------------------+
```

---

## 6. 核心元件庫 (Component Library)

### 6.1 按鈕系統 (Button System)
所有主要與次要按鈕一律採用 **Pill 全圓角（`border-radius: 9999px`）** 與 `font-weight: 500 ~ 600`，常搭配右向箭頭 `→`：

1. **全站主轉換按鈕 (`.btn-brand-primary`)**
   - 背景色：`#6161FF` ｜ 文字色：`#FFFFFF`
   - 內距：`10px 20px`（Nav Bar）或 `12px 28px`（Hero / Form Submit）
   - 用途：全站頂部 `Get Started →`、聯絡表單 `Submit`、深色背景上最核心行動呼籲。
2. **頁面內黑色主按鈕 (`.btn-dark-pill`)**
   - 背景色：`#000000`（Hover `#26263D`）｜ 文字色：`#FFFFFF`
   - 用途：服務頁、專案管理頁 Hero 與各功能段內部的 `Contact sales →`、`Get started →`、`Learn more`。
3. **深底反白按鈕 (`.btn-inverse-pill`)**
   - 背景色：`#FFFFFF` ｜ 文字色：`#181B34`
   - 用途：深色宇宙區塊、#6161FF 紫色數據橫幅與深靛藍 Impact Banner 內的行動按鈕。
4. **外框幽靈按鈕 (`.btn-outline-pill`)**
   - 背景色：`transparent` ｜ 邊框：`1px solid #181B34`（或 `#D2D2D7`）｜ 文字色：`#181B34`
   - 用途：次要導流動作（如 `Find a partner`、`Watch video`）。

### 6.2 導覽列與多欄頁尾 (Navigation & Footer)
* **頂部導覽列 (Global Navbar)**：
  - 白底固定／吸頂，左側品牌 Logo + 4 項主要選單（含下拉箭頭），右側 `Pricing`、`Log in` 純文字連結 + `#6161FF` 主按鈕。
* **次級子導覽 (Sub-Navbar)**：
  - 出現於特定產品線或企業服務頁（如 `monday.com WorkOS | Services | Partners`），以底部 `2px` 實線標記當前頁面。
* **6 欄式巨型頁尾 (Mega Footer)**：
  - 6 欄等距排列，特色是「產品能力（AI platform capabilities）」與「商業應用（Business applications）」欄位內每個連結左側均附**微型彩色產品 Logo 或單色線框 Icon**，大幅提升可掃描性。
  - 最底部設有「語系切換下拉＋資安認證圓標」、「社群 Icon＋隱私／條款連結」、「Google Play / App Store 下載徽章」與右下角無障礙輔助小圖示。

### 6.3 表單控制元件與浮動轉換卡 (Contact Form Card)
參考聯絡頁（`Contact our sales team`）標準結構：
* **容器樣式**：純白底 `#FFFFFF`、`border-radius: 16px`、`padding: 32px ~ 40px`、`box-shadow: var(--shadow-card-float)`。
* **欄位格線**：採用 `2 欄`（如 `First name*` / `Last name*`、`Company name*` / `Company size*`）與 `全寬 1 欄`（`Work email*`、`Job title`、國碼電話、探索主題、Textarea）混排，縮短表單視覺高度。
* **輸入框規格**：高度 `42px ~ 44px`、圓角 `6px`、邊框 `1px solid #D2D2D7`、淺灰 Placeholder；電話欄位左側整合國旗與國碼前綴選擇器。
* **送出區**：置中 `#6161FF` 寬版膠囊按鈕 `Submit`，下方緊接 `11px ~ 12px` 隱私政策小字說明（含底線連結）。

### 6.4 手風琴元件 (Accordion Variants)
系統依場景區分為兩種手風琴樣式：
1. **功能卡片內手風琴 (Feature Row Accordion)**：用於 `Set up for success`、`Ongoing maintenance` 等雙欄面板，右側為極簡 **`+` / `-`** 符號，標題較緊湊（`15px ~ 16px`），僅以極淡水平分隔線區隔。
2. **頁面級常見問題 (FAQ Accordion)**：採雙欄佈局（左 35% 標題與按鈕、右 65% 清單），每題上下間距充裕，右側附向下 **Chevron (`v`)** 箭頭。

### 6.5 證言與量化案例卡 (Testimonials & Case Study Cards)
1. **輕量引言卡 (Compact Quote Card)**：用於聯絡頁左側與 Bento Grid，淺灰底（`#F5F6FA`）、圓角 `12px`，上為量化引文，下為「圓形頭像 + 粗體姓名 + 職稱與公司」。
2. **滿版案例疊加卡 (Overlay Hero Case Study)**：外層為 `#F1F3FF` 大圓角淺紫藍底區塊，內部放一張 `border-radius: 20px` 的滿版暗調實景攝影圖，右側懸浮一張純白卡片（`border-radius: 16px`），依序呈現：
   - 頂部：客戶品牌字標（如 `ZIPPO`）＋ 右上角圓形左右切換箭頭（`←` `→`）。
   - 中上：雙欄超大 KPI 數據（如 `8x ROI` ｜ `$351,336 saved per month`），以垂直細線分隔。
   - 中下：決策者引言＋圓形頭像署名。
   - 底部：動作連結（`Watch Zippo's case story →`）。

### 6.6 信任徽章與 Logo 帶 (Trust & Recognition)
* **企業 Logo 橫幅**：單排置中顯示 6~8 個知名客戶 Logo，統一採**單色灰階或低飽和度處理**（深色背景時反白），避免搶走主視覺焦點。
* **第三方評比徽章 (G2 / Gartner Badges)**：於淺灰卡或深色卡中整齊橫列多枚季度的紅/白/藍 G2 Leader 盾牌徽章，建立客觀可信度。

---

## 7. 特殊版面模式 (Specialized Layout Patterns)

### 7.1 交替框景圖文卡 (Alternating Framed Split Cards)
常見於「企業服務頁」與「企業方案頁」：
* **結構**：雙欄 50/50 卡片，文字端放置「標題＋簡述＋4 項 `+` 手風琴（或檢核清單）」，視覺端則是一個高飽和或柔和粉彩的大圓角矩形色塊（如 `#97AEFE` 長春花藍、`#125F59` 深海松綠、`#DED4F9` 薰衣草紫、`#70D8A8` 薄荷綠）。
* **多層景深技法**：色塊內放入「圓形/圓角人物工作實景照」，再於邊緣疊加 1~2 張**帶陰影的小型產品 UI 浮動視窗與頭像泡泡**，突破平面單調感。

### 7.2 混合內容 Bento Grid (Asymmetric Bento Layout)
見於專案管理頁（`Why project leaders choose...`）：
* 透過 `2 欄 / 3 欄` 不等寬矩形拼貼出多樣化資訊節奏：
  * **人像＋浮動氣泡卡**：真實微笑人像搭配橫跨畫面邊緣的狀態標籤。
  * **淺灰功能卡**：左上方文字說明，右下角固定配置圓形右向箭頭按鈕（`→`）。
  * **亮紫引言卡（`#6161FF` / `#9050FF`）**：全塊高飽和紫底配白色巨大雙引號 `“` 與白色引言，作為整個 Bento 網格的視覺錨點。
  * **整合生態卡**：文字下排列一排方形彩色 App Icon（Slack、Teams、Jira 等），視覺化表達連結性。

### 7.3 深色宇宙互動展示區 (Dark Cosmic Interactive Hub)
見於首頁與企業方案頁中段：
* **背景處理**：極黑 `#000000` 底色結合徑向漸層光暈（`radial-gradient` 揉合 `#1F0F83` 深靛藍與 `#086878` 深青色）。
* **互動元件**：
  1. 橫向 10 顆線條小圖示標籤列（Icon Tabs），選中項以亮紫底框高亮。
  2. 中央超寬產品介面預覽，邊緣帶微弱發光邊框（`rgba(255,255,255,0.12)`）與外溢的白色摘要浮動卡，形成強烈景深。
  3. 2×2 產品家族矩陣卡，每張卡片頂部以各自產品代表色（藍紫 / 青藍 / 翠綠 / 珊瑚紅）做微弱頂部光暈，明確區分四大產品線。

---

## 8. 響應式斷點與無障礙原則 (Responsive & Accessibility)

### 8.1 斷點規範 (Breakpoints)
- **Desktop (寬屏)**：`>= 1200px`（雙欄／三欄／6 欄 Footer 完整展開，容器上限 `1280px`）
- **Tablet Landscape / Small Laptop**：`992px ~ 1199px`（維持雙欄分割，內距與圖文面板比例微幅收窄）
- **Tablet Portrait**：`768px ~ 991px`（導覽列收合為漢堡選單；Bento Grid 改為 2 欄；50/50 圖文卡片轉為上下堆疊；Footer 轉為 3 欄×2 列）
- **Mobile (行動裝置)**：`< 768px`（頁面左右邊距縮減為 `16px ~ 20px`；Hero 與 Form 單欄上下堆疊；橫向產品卡片列轉為可左右滑動 Carousel；表單 2 欄欄位合併為全寬 1 欄）

### 8.2 無障礙與交互體驗 (A11y Standards)
- **高對比文字標準**：淺底使用 `#181B34`（對比度 > 14:1）、深底使用 `#FFFFFF`（對比度 > 18:1），並在 Footer 右下角配置獨立無障礙工具入口（Accessibility Statement / Widget）。
- **表單必填與即時引導**：必填欄位均清楚標示星號 `*`，輸入框與按鈕具備明確焦點環（`box-shadow: 0 0 0 3px rgba(97, 97, 255, 0.25)`）。
- **動態節制**：橫幅切換與手風琴展開採用平滑 CSS Transition，同時確保深色光暈區文字底下維持足夠深度的遮罩對比，避免光暈干擾閱讀。

---

## 9. 應用於 PlayPlus × BNI 專案之轉化建議 (Adaptation Notes)

若將此參考設計系統應用於 PlayPlus BNI 簡報頁面或企業服務著陸頁：
1. **主色對齊與微調**：可保留此系統的「極簡白底 `#FFFFFF` + 冷調薰衣草 `#F1F3FF` + 深藍墨黑 `#181B34`」版面結構與圖文框景手法；主強調色則可視需求採用參考系統的 `#6161FF` 或替換為 PlayPlus 品牌識別色（如 `#33CC33` 品牌綠搭配 `#15161A` 深石板黑），即可完整繼承其高轉換視覺骨架。
2. **最值得借鏡的三個轉換模組**：
   - **「聯絡表單＋左側客戶引文卡」雙欄首屏**（截圖 1）：大幅降低 BNI 引薦對象預約諮詢的心理阻力。
   - **「人像照片＋浮動系統 UI」雙欄色塊框景**（截圖 2）：非常適合呈現 PlayPlus「深入第一線現場訪談 × 客製化系統介面」的顧問價值。
   - **「滿版深底圖＋右側雙 KPI 數據懸浮白卡」案例區**（截圖 1 / 3）：用來展示神達、大管家或中保等指標案例時，能在 3 秒內讓決策者看懂量化成效。

---

*文件版本：v1.0.0*  
*整理日期：2026-11-20*  
*參考來源：6 張參考網站全頁截圖（首頁繁中版、企業平台頁、專案管理頁、專業服務頁、關於我們頁、聯絡業務頁）*
