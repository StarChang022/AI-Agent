# Anthropic 官方視覺配色規範與設計系統色彩指南

> 本文檔完整提取並整理自 [Anthropic 官方網站 (anthropic.com)](https://www.anthropic.com/)、Claude 品牌頁面與其官方前端設計系統（包含 Webflow Shared Stylesheet 及 Next.js Design Tokens）。

---

## 🎨 設計哲學與美學風格 (Design Philosophy)

Anthropic 的視覺風格深受**人文出版品、紙質媒介與自然礦物泥彩（Earth & Mineral Tones）**啟發，呈現出克制、溫潤、知性且具備學術研究嚴謹感的現代美學：

1. **溫潤暖白紙質底色（Warm Ivory & Parchment）**：捨棄冷硬死白（#FFFFFF），採用米白／象牙白作為主畫布底色，營造如閱讀書籍般的舒適感。
2. **經典赤陶黏土主色（Claude Clay / Terracotta）**：以溫暖沈穩的陶土橙褐色（#D97757）作為 Claude 標誌性亮點與互動焦點。
3. **黑曜石深冷灰階（Obsidian Slate & Ivory Neutral Scale）**：捨棄純黑，採用帶有極微暖調的黑曜石深色（#141413 / #0F0F0E），搭配 21 階精細漸進暖灰度。
4. **自然低飽和礦物副色（Mineral & Editorial Accents）**：如橄欖綠（Olive）、仙人掌綠（Cactus）、天青藍（Sky）、無花果紅（Fig）等，提供柔和的多樣性層次。

---

## 1. 品牌核心主色與亮點 (Brand Core & Accent Colors)

用於品牌識別、核心 CTA 按鈕、重點高亮徽章及關鍵互動元件。

| 顏色名稱 | 色樣預覽 | HEX | RGB | HSL | CSS 變數名稱 | 設計角色與使用情境 |
| :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **Claude Clay** | `●` | `#D97757` | `rgb(217, 119, 87)` | `hsl(15, 63%, 60%)` | `--swatch--clay`<br>`--color-clay` | **Claude 核心品牌色**。重點標籤、高亮 CTA、重要公告 |
| **Clay Interactive** | `●` | `#C96442` | `rgb(201, 100, 66)` | `hsl(15, 56%, 52%)` | `--swatch--clay-interactive` | 黏土色元件 Hover / Active 懸停點擊態 |
| **Anthropic Accent** | `●` | `#C6613F` | `rgb(198, 97, 63)` | `hsl(15, 54%, 51%)` | `--swatch--accent` | 官方赤陶副主色、研究文獻特徵色 |
| **Brand Text** | `●` | `#141413` | `rgb(20, 20, 19)` | `hsl(60, 3%, 8%)` | `--swatch--brand-text` | 品牌 Logo、純黑替代文本基礎色 |

### 🌿 輔助與特刊亮點色彩 (Editorial & Accent Swatches)

用於分類標籤 (Tags)、主題卡片背景、圖表數據視覺化及活動橫幅：

| 標籤色彩 | 色樣 | HEX | RGB | HSL | CSS 變數 | 典型用途 |
| :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **Peach (蜜桃粉)** | `●` | `#EBC9B7` | `rgb(235, 201, 183)` | `hsl(21, 57%, 82%)` | `--swatch--peach` | 柔和插圖、輕量卡片背景 |
| **Coral (珊瑚粉白)** | `●` | `#EBCECE` | `rgb(235, 206, 206)` | `hsl(0, 42%, 86%)` | `--swatch--coral` | 柔和強調標籤、警告補充區塊 |
| **Fig (無花果紫紅)** | `●` | `#C46686` | `rgb(196, 102, 134)` | `hsl(340, 44%, 58%)` | `--swatch--fig` | 特殊研究專題、女性科技與人文板塊 |
| **Plum (洋李紫)** | `●` | `#827DBD` | `rgb(130, 125, 189)` | `hsl(245, 33%, 62%)` | `--swatch--plum` | 深度學習 / 架構展示 / 標籤 |
| **Sky (天青藍)** | `●` | `#6A9BCC` | `rgb(106, 155, 204)` | `hsl(210, 49%, 61%)` | `--swatch--sky` | 開發者生態、技術文檔、資訊提示 |
| **Mineral (礦物藍綠)** | `●` | `#629987` | `rgb(98, 153, 135)` | `hsl(160, 22%, 49%)` | `--swatch--mineral` | 數據視覺化、模型效能分析指標 |
| **Cactus (仙人掌綠)** | `●` | `#BCD1CA` | `rgb(188, 209, 202)` | `hsl(160, 19%, 78%)` | `--swatch--cactus` | 成功狀態、安全報告標籤、柔和背景 |
| **Olive (橄欖綠)** | `●` | `#788C5D` | `rgb(120, 140, 93)` | `hsl(86, 20%, 46%)` | `--swatch--olive` | 品牌特色主題區塊、次級主視覺底色 |
| **Manilla (馬尼拉米黃)** | `●` | `#EBDBBC` | `rgb(235, 219, 188)` | `hsl(40, 54%, 83%)` | `--swatch--manilla` | 備忘錄標籤、公告焦點卡片 |
| **Kraft (牛皮紙褐)** | `●` | `#D4A27F` | `rgb(212, 162, 127)` | `hsl(25, 50%, 66%)` | `--swatch--kraft` | 歷史沿革、存檔分類標籤 |
| **Oat (燕麥暖灰)** | `●` | `#E3DACC` | `rgb(227, 218, 204)` | `hsl(37, 29%, 85%)` | `--swatch--oat` | 替代淺色底色、章節分割區塊 |

---

## 2. 背景與表面層次色 (Background & Surface Layer Colors)

Anthropic 採用嚴格的「畫布（Canvas）— 表面（Surface）— 浮層（Elevated）」三級層次架構，並分為淺色（Light Mode）與深色（Dark / Slate Mode）兩套系統。

### ☀️ 淺色系 (Light Theme)

| 層級名稱 | 色樣 | HEX | RGB | CSS 變數 | 使用說明 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Primary Canvas (主畫布)** | `●` | `#FAF9F5` | `rgb(250, 249, 245)` | `--swatch--ivory-light`<br>`--background-primary` | 網頁全站預設底色（象牙白），極度護眼 |
| **Secondary Surface (次級表面)** | `●` | `#F0EEE6` | `rgb(240, 238, 230)` | `--swatch--ivory-medium`<br>`--background-secondary` | 卡片容器、次要區塊背景、表單輸入框 |
| **Tertiary Surface (三級表面)** | `●` | `#E8E6DC` | `rgb(232, 230, 220)` | `--swatch--ivory-dark`<br>`--background-tertiary` | 滾動背景、卡片懸停態、強調邊框區塊 |
| **Pure White Card (純白卡片)** | `●` | `#FFFFFF` | `rgb(255, 255, 255)` | `--swatch--white`<br>`--swatch--gray-000` | 浮出式卡片 (Modals)、對比度最高的內容容器 |
| **Oat Canvas (燕麥主題底色)** | `●` | `#E3DACC` | `rgb(227, 218, 204)` | `--swatch--oat`<br>`--background-oat` | 特殊專題、訪談（Interviews）區段專用底色 |

### 🌙 深色系 (Dark Theme / Slate Theme)

| 層級名稱 | 色樣 | HEX | RGB | CSS 變數 | 使用說明 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Primary Canvas (深色主畫布)** | `●` | `#141413` | `rgb(20, 20, 19)` | `--swatch--slate-dark`<br>`--background-primary` | 深色主題全站底色（Slate-950 黑曜灰） |
| **Deep Dark Base (極致深底)** | `●` | `#0F0F0E` | `rgb(15, 15, 14)` | `--swatch--gray-1000`<br>`--color-dark` | 代碼區塊底色、終端機黑底 |
| **Secondary Surface (次級表面)** | `●` | `#1F1E1D` | `rgb(31, 30, 29)` | `--swatch--gray-850`<br>`--background-secondary` | 深色模式內容卡片、側邊欄 |
| **Tertiary Surface (三級表面)** | `●` | `#30302E` | `rgb(48, 48, 46)` | `--swatch--gray-750`<br>`--background-tertiary` | 深色模式浮層、下拉選單背景 |
| **Slate Elevated / Card (浮層卡片)** | `●` | `#3D3D3A` | `rgb(61, 61, 58)` | `--swatch--slate-medium`<br>`--swatch--gray-700` | 深色按鈕懸停、高亮卡片 |
| **Slate Hover (懸停亮態)** | `●` | `#5E5D59` | `rgb(94, 93, 89)` | `--swatch--slate-light`<br>`--swatch--gray-600` | 次級按鈕懸停邊框、圖示懸停高亮 |

---

## 3. 文字與排版色彩 (Text & Typography Colors)

Anthropic 重視極高閱讀性與層次分明的版面，嚴格規範標題、正文、附註與連結色彩：

### 淺色模式排版 (Light Theme Typography)

| 排版階層 | 色樣 | HEX | RGB | CSS 變數 | 對比度與使用情境 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Primary Text (主要文本)** | `●` | `#141413` | `rgb(20, 20, 19)` | `--_color-theme---text`<br>`--swatch--slate-dark` | 頁面大標題 (H1-H6)、文章主要內文（WCAG AAA 14.5:1） |
| **Secondary Text (次要說明)** | `●` | `#30302E` | `rgb(48, 48, 46)` | `--foreground-secondary`<br>`--swatch--gray-750` | 副標題、作者署名、引言摘要 |
| **Tertiary / Muted (弱化文字)** | `●` | `#5E5D59` | `rgb(94, 93, 89)` | `--foreground-tertiary`<br>`--swatch--slate-light` | 圖表標註、麵包屑、頁腳版權宣告 |
| **Agate / Metadata (元數據)** | `●` | `#B0AEA5` | `rgb(176, 174, 165)` | `--_color-theme---text-agate`<br>`--swatch--cloud-medium` | 發布日期、閱讀時長標籤、輸入框佔位符 (Placeholder) |

### 深色模式排版 (Dark Theme Typography)

| 排版階層 | 色樣 | HEX | RGB | CSS 變數 | 對比度與使用情境 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Primary Text (主要文本)** | `●` | `#FAF9F5` | `rgb(250, 249, 245)` | `--_color-theme---text`<br>`--swatch--ivory-light` | 深色主標題、主要閱讀文字 |
| **Secondary Text (次要說明)** | `●` | `#F0EEE6` | `rgb(240, 238, 230)` | `--foreground-secondary`<br>`--swatch--ivory-medium` | 深色副標題、次級卡片文字 |
| **Tertiary / Agate (輔助文本)** | `●` | `#B0AEA5` | `rgb(176, 174, 165)` | `--swatch--cloud-medium`<br>`--foreground-tertiary` | 深色模式日期、版本號、次要註釋 |

### 🔗 超連結與互動文字狀態 (Interactive Link States)

```css
/* 淺色模式超連結規範 */
a.link {
  color: var(--swatch--slate-dark);       /* #141413 預設常態 */
  text-decoration: underline;
  text-underline-offset: 3px;
  transition: color 0.2s ease;
}
a.link:hover {
  color: var(--swatch--slate-light);      /* #5E5D59 懸停淺黑曜色 */
}
a.link:active {
  color: var(--swatch--slate-dark);       /* #141413 點擊啟動 */
}

/* 深色模式超連結規範 */
.theme-dark a.link {
  color: var(--swatch--ivory-light);      /* #FAF9F5 預設象牙白 */
}
.theme-dark a.link:hover {
  color: var(--swatch--ivory-medium);     /* #F0EEE6 懸停微弱灰白 */
}
```

---

## 4. 狀態與合規警示色彩 (Status & Alert Colors)

Anthropic 在介面狀態反饋中，維持低刺激度且清晰可辨的語義化色彩：

| 狀態類型 | 色樣 | HEX | RGB | 變數名稱 | 應用規範與場景 |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Error (錯誤 / 警示)** | `●` | `#BF4D43` | `rgb(191, 77, 67)` | `--color-error` | 系統嚴重錯誤、API 連線中斷提示 |
| **Form Error (表單驗證錯誤)** | `●` | `#D97757` | `rgb(217, 119, 87)` | `--swatch--clay` | 表單欄位校驗提示（`.form_main_error_wrap`） |
| **Focus Ring (鍵盤焦點框)** | `●` | `#2C84DB` | `rgb(44, 132, 219)` | `--color-focus` | 無障礙（a11y）鍵盤導航外光暈與焦點輪廓 |
| **Success (成功狀態)** | `●` | `#BCD1CA` | `rgb(188, 209, 202)` | `--swatch--cactus` | 訂閱成功、複製成功、操作完成標籤 |
| **Info / Notice (提示資訊)** | `●` | `#6A9BCC` | `rgb(106, 155, 204)` | `--swatch--sky` | 新功能發布、說明文件提示區塊 |
| **Warning / Attention (警告)** | `●` | `#EBDBBC` | `rgb(235, 219, 188)` | `--swatch--manilla` | 實驗性功能提示、額度使用預警 |

---

## 5. 邊框、分隔線與微透明通道 (Borders, Dividers & Opacity Channels)

Anthropic 廣泛使用**帶有微透明通道（Alpha Channel）的色值**來適應多變的淺色與深色背景，確保邊框與卡片分割自然融合：

### 🪟 微透明通道色票 (Alpha Channels)

| 變數名稱 | 8位 HEX | RGBA 等效值 | 不透明度 | 應用場景 |
| :--- | :---: | :---: | :---: | :--- |
| `--swatch--slate-faded-10` | `#1414131A` | `rgba(20, 20, 19, 0.10)` | 10% | **淺色預設細邊框**（卡片邊框、橫幅分隔線） |
| `--swatch--slate-faded-20` | `#14141333` | `rgba(20, 20, 19, 0.20)` | 20% | **淺色懸停邊框**、按鈕邊界、活動標籤輪廓 |
| `--color-tint-10` | `#1919191A` | `rgba(25, 25, 25, 0.10)` | 10% | 次要背景微弱填充、輸入框背景底色 |
| `--color-tint-20` | `#19191933` | `rgba(25, 25, 25, 0.20)` | 20% | 次要背景懸停填充、下拉項目選中態 |
| `--swatch--ivory-faded-10` | `#FAF9F51A` | `rgba(250, 249, 245, 0.10)` | 10% | **深色預設細邊框**（卡片邊框、網格分隔線） |
| `--swatch--ivory-faded-20` | `#FAF9F533` | `rgba(250, 249, 245, 0.20)` | 20% | **深色懸停邊框**、深色模式互動按鈕外框 |

### 📏 邊框與分隔線標準設定

```css
/* 標準邊框預設 */
:root {
  --border-width--main: 0.0625rem; /* 1px */
  --border-radius--small: 0.25rem;  /* 4px */
  --border-radius--main: 0.5rem;    /* 8px */
  --border-radius--large: 1rem;     /* 16px */
  --border-radius--round: 100vw;    /* 膠囊按鈕 / 標籤圓角 */
}

/* 淺色卡片邊框 */
.card-light {
  border: var(--border-width--main) solid var(--swatch--slate-faded-10);
  background-color: var(--swatch--white);
  border-radius: var(--border-radius--main);
  transition: border-color 0.2s ease, background-color 0.2s ease;
}
.card-light:hover {
  border-color: var(--swatch--slate-faded-20);
}

/* 深色卡片邊框 */
.card-dark {
  border: var(--border-width--main) solid var(--swatch--ivory-faded-10);
  background-color: var(--swatch--slate-medium);
  border-radius: var(--border-radius--main);
}
.card-dark:hover {
  border-color: var(--swatch--ivory-faded-20);
}
```

---

## 6. Anthropic 官方完整 21 階暖灰階色梯 (Gray / Slate Ramp)

Anthropic 內部建構了由純白到極致深黑的 21 階連續色標（從 `gray-000` 至 `gray-1000`）：

| 階級 Token | 色樣 | HEX 代碼 | RGB 數值 | HSL 數值 | 系統標準用途 |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`gray-000` / `slate-000`** | `●` | `#FFFFFF` | `rgb(255, 255, 255)` | `hsl(0, 0%, 100%)` | 純白表面、光學強調 |
| **`gray-050` / `slate-050`** | `●` | `#FAF9F5` | `rgb(250, 249, 245)` | `hsl(48, 33%, 97%)` | **Ivory Light**（淺色預設主畫布） |
| **`gray-100` / `slate-100`** | `●` | `#F5F4ED` | `rgb(245, 244, 237)` | `hsl(53, 29%, 95%)` | 淺色微妙漸層表面 |
| **`gray-150` / `slate-150`** | `●` | `#F0EEE6` | `rgb(240, 238, 230)` | `hsl(48, 25%, 92%)` | **Ivory Medium**（次要卡片與區塊） |
| **`gray-200` / `slate-200`** | `●` | `#E8E6DC` | `rgb(232, 230, 220)` | `hsl(50, 21%, 89%)` | **Ivory Dark**（區塊分隔底色） |
| **`gray-250` / `slate-250`** | `●` | `#DEDCD1` | `rgb(222, 220, 209)` | `hsl(51, 16%, 85%)` | 淺色實體描邊分隔線 |
| **`gray-300` / `slate-300`** | `●` | `#D1CFC5` | `rgb(209, 207, 197)` | `hsl(50, 12%, 80%)` | **Cloud Light**（禁用狀態元件） |
| **`gray-350` / `slate-350`** | `●` | `#C2C0B6` | `rgb(194, 192, 182)` | `hsl(50, 9%, 74%)` | 輔助圖示色、淺色微弱線條 |
| **`gray-400` / `slate-400`** | `●` | `#B0AEA5` | `rgb(176, 174, 165)` | `hsl(49, 7%, 67%)` | **Cloud Medium**（時間戳、元數據） |
| **`gray-450` / `slate-450`** | `●` | `#9C9A92` | `rgb(156, 154, 146)` | `hsl(48, 5%, 59%)` | 中階過渡文字與圖示 |
| **`gray-500` / `slate-500`** | `●` | `#87867F` | `rgb(135, 134, 127)` | `hsl(53, 3%, 51%)` | **Cloud Dark**（次要備註文字） |
| **`gray-550` / `slate-550`** | `●` | `#73726C` | `rgb(115, 114, 108)` | `hsl(51, 3%, 44%)` | 中性輔助文字 |
| **`gray-600` / `slate-600`** | `●` | `#5E5D59` | `rgb(94, 93, 89)` | `hsl(48, 3%, 36%)` | **Slate Light**（弱化內文、圖示） |
| **`gray-650` / `slate-650`** | `●` | `#4D4C48` | `rgb(77, 76, 72)` | `hsl(48, 3%, 29%)` | 深色懸停文字高亮 |
| **`gray-700` / `slate-700`** | `●` | `#3D3D3A` | `rgb(61, 61, 58)` | `hsl(60, 3%, 23%)` | **Slate Medium**（深色卡片容器） |
| **`gray-750` / `slate-750`** | `●` | `#30302E` | `rgb(48, 48, 46)` | `hsl(60, 2%, 18%)` | 深色模式次級表面與輸入框 |
| **`gray-800` / `slate-800`** | `●` | `#262624` | `rgb(38, 38, 36)` | `hsl(60, 3%, 15%)` | 深色側邊欄、彈窗面板 |
| **`gray-850` / `slate-850`** | `●` | `#1F1E1D` | `rgb(31, 30, 29)` | `hsl(30, 3%, 12%)` | 深色二級畫布底色 |
| **`gray-900` / `slate-900`** | `●` | `#1A1918` | `rgb(26, 25, 24)` | `hsl(30, 4%, 10%)` | 深色主體過渡底色 |
| **`gray-950` / `slate-950`** | `●` | `#141413` | `rgb(20, 20, 19)` | `hsl(60, 3%, 8%)` | **Slate Dark**（深色主底色 / 淺色主字體） |
| **`gray-1000` / `slate-1000`** | `●` | `#0F0F0E` | `rgb(15, 15, 14)` | `hsl(60, 3%, 6%)` | **Pure Black Base**（代碼終端底色） |

---

## 7. 快速引入代碼片段 (Code Snippets)

### 📌 1. 原生 CSS 自定義屬性 (CSS Variables)

可直接複製並貼入專案的 `tokens.css` 或 `globals.css`：

```css
:root {
  /* 品牌核心主色 */
  --ant-clay: #D97757;
  --ant-clay-hover: #C96442;
  --ant-accent: #C6613F;
  --ant-brand-text: #141413;

  /* 輔助與特刊亮點色彩 */
  --ant-peach: #EBC9B7;
  --ant-coral: #EBCECE;
  --ant-fig: #C46686;
  --ant-plum: #827DBD;
  --ant-sky: #6A9BCC;
  --ant-mineral: #629987;
  --ant-cactus: #BCD1CA;
  --ant-olive: #788C5D;
  --ant-manilla: #EBDBBC;
  --ant-kraft: #D4A27F;
  --ant-oat: #E3DACC;

  /* 狀態反饋 */
  --ant-error: #BF4D43;
  --ant-focus: #2C84DB;

  /* 淺色體系表面與文字 */
  --ant-canvas-light: #FAF9F5;
  --ant-surface-secondary-light: #F0EEE6;
  --ant-surface-tertiary-light: #E8E6DC;
  --ant-card-light: #FFFFFF;
  --ant-text-primary-light: #141413;
  --ant-text-secondary-light: #30302E;
  --ant-text-muted-light: #5E5D59;
  --ant-text-agate-light: #B0AEA5;

  /* 深色體系表面與文字 */
  --ant-canvas-dark: #141413;
  --ant-surface-secondary-dark: #1F1E1D;
  --ant-surface-tertiary-dark: #30302E;
  --ant-card-dark: #3D3D3A;
  --ant-text-primary-dark: #FAF9F5;
  --ant-text-secondary-dark: #F0EEE6;
  --ant-text-muted-dark: #B0AEA5;

  /* 微透明通道邊框 */
  --ant-border-light: rgba(20, 20, 19, 0.10);       /* #1414131A */
  --ant-border-hover-light: rgba(20, 20, 19, 0.20); /* #14141333 */
  --ant-border-dark: rgba(250, 249, 245, 0.10);     /* #FAF9F51A */
  --ant-border-hover-dark: rgba(250, 249, 245, 0.20);/* #FAF9F533 */
}
```

### 📌 2. Tailwind CSS 配置擴展 (tailwind.config.js)

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: {
        anthropic: {
          clay: {
            DEFAULT: '#D97757',
            hover: '#C96442',
          },
          accent: '#C6613F',
          ivory: {
            light: '#FAF9F5',
            medium: '#F0EEE6',
            dark: '#E8E6DC',
          },
          slate: {
            0: '#FFFFFF',
            50: '#FAF9F5',
            100: '#F5F4ED',
            150: '#F0EEE6',
            200: '#E8E6DC',
            250: '#DEDCD1',
            300: '#D1CFC5',
            350: '#C2C0B6',
            400: '#B0AEA5',
            450: '#9C9A92',
            500: '#87867F',
            550: '#73726C',
            600: '#5E5D59',
            650: '#4D4C48',
            700: '#3D3D3A',
            750: '#30302E',
            800: '#262624',
            850: '#1F1E1D',
            900: '#1A1918',
            950: '#141413',
            1000: '#0F0F0E',
          },
          editorial: {
            peach: '#EBC9B7',
            coral: '#EBCECE',
            fig: '#C46686',
            plum: '#827DBD',
            sky: '#6A9BCC',
            mineral: '#629987',
            cactus: '#BCD1CA',
            olive: '#788C5D',
            manilla: '#EBDBBC',
            kraft: '#D4A27F',
            oat: '#E3DACC',
          },
          status: {
            error: '#BF4D43',
            focus: '#2C84DB',
          }
        }
      }
    }
  }
}
```
