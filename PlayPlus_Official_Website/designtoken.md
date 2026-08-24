# Kintsugi (trykintsugi.com) 設計系統配色與 Design Tokens 規範

> 本文件依據 **[trykintsugi.com](https://trykintsugi.com/)** 官方網站的完整前端架構、Framer Token 系統、CSS 變數及組件視覺規範深入整理。
> 提供完整的配色系統（Color Palette）、語意化代碼（Semantic Design Tokens）、組件應用規範、漸層與光效系統，以及可用於 Vanilla CSS / Tailwind CSS 的標準變數代碼。

---

## 🎨 1. 設計哲學與色彩特徵 (Design Philosophy)

Kintsugi 的視覺風格屬於 **現代極簡科技與有機溫潤感結合（Organic Warm Tech / High-End AI Fintech）**：
1. **溫潤暖白基調 (Warm Ecru Base)**：捨棄傳統 SaaS 常用的刺眼冷白，主背景採用溫暖的奶油米灰灰調（`#F2F2E8`），營造溫潤、高端、具實體印刷質感的氛圍。
2. **深森松綠高對比 (Deep Forest Charcoal)**：使用帶有些微綠意與石板灰的極深松綠（`#213331`）作為主要文字、深色卡片與 Hero / Footer 容器的主色，取代生硬純黑。
3. **標誌性霓虹薄荷綠 (Signature Neon Mint)**：採用高明度、高飽和度的電光薄荷綠（`#B0ED9C`）作為核心行動按鈕（CTA）、動態光暈、即時連線燈號與核心亮點，形成鮮明且具科技感的點睛效果。
4. **柔和薰衣草紫輔助 (Soft Lavender Accent)**：輔以柔和的粉紫/薰衣草色（`#E5D1FA`、`#C69CF4`），用於 AI 功能標籤、次要模組背景及輔助徽章。
5. **精確的合規狀態警示系統 (Tax Compliance Status Colors)**：
   - 🛡️ **已註冊 / 安全 (Registered)**：`#B0ED9C`（薄荷綠）
   - ⚠️ **曝險 / 風險 (Exposed / High Risk)**：`#FF5E5E` / `#FF2C2C`（珊瑚警示紅）
   - ⏳ **即將超標 / 警戒 (Threshold Warning)**：`#FF9800` / `#ED8936`（暖橘）

---

## 🌈 2. 核心調色盤總覽 (Core Color Palette)

### 2.1 品牌主色 (Brand Primary & Accents)

| Token 名稱 | 角色與用途 | HEX | RGB | HSL | 視覺預覽 / 說明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `--k-neon` | **主要品牌亮色 / 核心 CTA** | `#B0ED9C` | `rgb(176, 237, 156)` | `hsl(105, 71%, 77%)` | 電光薄荷綠，按鈕、進度條、脈衝光 |
| `--k-neon-glow` | **霓虹漸層 / 亮光** | `#D7F781` | `rgb(215, 247, 129)` | `hsl(76, 88%, 74%)` | 螢光黃綠，用於徑向光暈與高光 |
| `--k-green-900` | **主要深色基底 / 標題文字** | `#213331` | `rgb(33, 51, 49)` | `hsl(173, 21%, 16%)` | 深森松墨綠，核心文字與深色卡片 |
| `--k-green-950` | **極深黑色背景** | `#0E1716` | `rgb(14, 23, 22)` | `hsl(173, 24%, 7%)` | 超深暗色調，深色容器陰影與邊界 |
| `--k-lavender` | **AI 輔助主色 / 標籤** | `#E5D1FA` | `rgb(229, 209, 250)` | `hsl(270, 77%, 90%)` | 柔和粉紫，AI 特性與次要亮點 |
| `--k-purple-vibrant` | **活躍紫色 / 邊框** | `#C69CF4` | `rgb(198, 156, 244)` | `hsl(269, 81%, 78%)` | 亮紫，用於紫色標籤邊框與圖標 |
| `--k-purple-deep` | **深紫文字 / 背景** | `#5B3FA0` | `rgb(91, 63, 160)` | `hsl(257, 44%, 44%)` | 薰衣草標籤上的文字色彩 |

---

### 2.2 背景與表面層次色 (Backgrounds & Surfaces)

| Token 名稱 | 角色與用途 | HEX | RGB | 備註說明 |
| :--- | :--- | :--- | :--- | :--- |
| `--bg-main` | **全站主要頁面底色** | `#F2F2E8` | `rgb(242, 242, 232)` | 溫暖奶油米灰（Warm Ecru） |
| `--bg-card-light` | **淺色卡片頂層底色** | `#FFFFF9` | `rgb(255, 255, 249)` | 溫潤珍珠白，輕微暖調 |
| `--bg-surface-white`| **巢狀元件純白底色** | `#FFFFFF` | `rgb(255, 255, 255)` | 純白色，用於卡片內子模組、輸入框 |
| `--bg-surface-peach`| **暖調米杏色卡片** | `#FDF5EB` | `rgb(253, 245, 235)` | 應用於特定促銷、重點引導區塊 |
| `--bg-surface-sage` | **淺灰綠色卡片** | `#E8F0D9` | `rgb(232, 240, 217)` | 應用於稅務計算、合規成功狀態卡片 |
| `--bg-surface-lilac`| **淺粉紫色卡片** | `#EDE4FB` | `rgb(237, 228, 251)` | 應用於 AI 助手、智慧對話預覽區塊 |
| `--bg-dark-frame`   | **深色互動區塊主背景** | `#213331` | `rgb(33, 51, 49)` | 模擬終端機/地圖面板的深綠色背景 |

---

### 2.3 文字與排版色彩 (Typography Colors)

| Token 名稱 | 角色與用途 | 色碼 / 數值 | 適用場景 |
| :--- | :--- | :--- | :--- |
| `--text-primary` | **淺色背景主標題 / 內文** | `#213331` (`rgb(33, 51, 49)`) | H1~H4 標題、正文、重點段落 |
| `--text-secondary` | **次要說明 / 副標題** | `#6B7160` / `rgba(0, 0, 0, 0.6)` | 輔助說明、卡片描述、元數據 |
| `--text-muted` | **次微弱文字 / 註腳** | `#8D8A7B` / `#ACABB8` | 版權宣告、停用狀態、時間戳記 |
| `--text-inverse-primary` | **深色背景主文字** | `#FFFFFF` / `#FFFFF9` | 深色 Hero 區塊、深色卡片主標題 |
| `--text-inverse-secondary`| **深色背景副標題** | `rgba(255, 255, 255, 0.75)` | 深色容器內的說明內文 |
| `--text-inverse-muted` | **深色背景輔助文字** | `rgba(255, 255, 255, 0.55)` | SKU 編號、表格小字、次微標籤 |
| `--text-accent-neon` | **高亮強調文字** | `#B0ED9C` | 深色背景中的數值、總計金額、關鍵數據 |

---

### 2.4 狀態與警示色彩 (Status & Feedback Colors)

| 狀態類型 | 代表意義 | 主色 HEX | 輔助 / 背景 HEX | 典型應用組件 |
| :--- | :--- | :--- | :--- | :--- |
| **Exposed (曝險 / 警報)** | 稅務門檻超標、未註冊 | `#FF5E5E` / `#FF2C2C` | `#FBD9D9` / `rgba(255,94,94,0.15)` | 州別曝險標籤（Chip）、警告警示卡 |
| **Registered (合規 / 成功)**| 已註冊、稅務合規、正常 | `#B0ED9C` / `#4CAF50` | `#E8F0D9` / `rgba(176,237,156,0.16)` | 註冊完成徽章、申報成功 Check 標記 |
| **Warning (警戒 / 逼近)** | 接近稅務門檻（80%+） | `#ED8936` / `#FF9800` | `#FEF3C7` / `rgba(237,137,54,0.15)` | 門檻進度條警戒段、提醒提示條 |
| **Exempt (免稅 / 中性)** | 稅率 0% 或免稅商品 | `rgba(255, 255, 255, 0.16)` | `#FFFFFF` 文字 | 購物車稅率標籤（Tax Exempt Badge） |

---

### 2.5 邊框、分隔線與微透明通道 (Borders & Dividers)

| 應用層次 | 色碼 / 數值 | 典型用途 |
| :--- | :--- | :--- |
| **淺色表面邊框 (Light Border)** | `rgba(0, 0, 0, 0.08)` / `#DEE6D6` | 淺色卡片外框、導航欄底部邊界 |
| **淺色微弱分隔 (Subtle Divider)** | `rgba(0, 0, 0, 0.05)` / `#E8E8DE` | 列表項目分隔線、下拉選單邊框 |
| **深色卡片外框 (Dark Border)** | `rgba(255, 255, 255, 0.07)` | 深色 Frame 外框（帶微發光感） |
| **深色表格分隔線 (Dark Table Line)**| `rgba(255, 255, 255, 0.09)` | 深色容器內商品行（Row）分隔線 |
| **霓虹強化邊框 (Neon Accent Border)**| `rgba(176, 237, 156, 0.30)` ~ `0.40` | 地圖節點、總計合計頂部高亮分隔線 |

---

## 🧩 3. 元件色彩應用規範 (Component Specifications)

### 3.1 導航欄 (Navigation Bar)
- **容器背景**：半透明毛玻璃 `rgba(242, 242, 232, 0.85)` 搭配 `backdrop-filter: blur(12px)`
- **文字連結**：`#213331`（正常），Hover 時微透明 `rgba(33, 51, 49, 0.7)`
- **主要 CTA 按鈕 (Book a demo)**：
  - 背景：`#B0ED9C`（薄荷綠）
  - 文字：`#213331`（深松綠，`font-weight: 700`）
  - 圓角：`9999px`（全圓角膠囊型）
- **次要按鈕 (Log in)**：
  - 背景：`#213331` 或透明無底色
  - 文字：`#FFFFFF` 或 `#213331`

---

### 3.2 Hero 互動動態展示區 (Hero Interactive Stage)
- **外框外殼 (hx-frame)**：
  - 背景：`#213331`
  - 邊框：`1px solid rgba(255, 255, 255, 0.07)`
  - 圓角：`22px`
  - 陰影：`0 18px 50px rgba(33, 51, 49, 0.16)`
- **即時脈衝燈 (live-dot)**：
  - 圓點：`#B0ED9C`（7px × 7px）
  - 動畫光暈：`0 0 0 8px rgba(176, 237, 156, 0)`（`liveDot` 動畫）
- **頂部進度條 (hx-prog)**：
  - 背景：`#B0ED9C`
  - 光暈效果：`box-shadow: 0 0 10px rgba(176, 237, 156, 0.6)`
- **動態掃描光 (hx-scan)**：
  - 漸層：`linear-gradient(90deg, transparent, rgba(176, 237, 156, 0.22), transparent)`
- **合計總額區 (hx-total)**：
  - 頂部分隔線：`1.5px solid rgba(176, 237, 156, 0.4)`
  - 數字金額：`#B0ED9C`（`font-size: 24px`，`font-weight: 800`）

---

### 3.3 狀態標籤與徽章 (Badges & Chips)
- **已註冊狀態標籤 (Registered Chip)**：
  - 背景：`#B0ED9C`
  - 文字：`#213331`（字重 800，字級 10.5px）
  - 左側原點：`#213331`
- **曝險狀態標籤 (Exposed Chip)**：
  - 背景：`#FF5E5E`
  - 文字：`#FFFFFF`
- **AI 助手 / 智慧標籤 (AI Lavender Pill)**：
  - 背景：`rgba(229, 209, 250, 0.8)` / `#E5D1FA`
  - 邊框：`1px solid rgba(198, 156, 244, 0.4)`
  - 文字：`#5B3FA0`
- **中性數據標籤 (Neutral Pill)**：
  - 背景：`rgba(255, 255, 255, 0.07)`
  - 邊框：`1px solid rgba(176, 237, 156, 0.25)`
  - 文字：`#FFFFFF`

---

### 3.4 頁尾區域 (Footer)
- **背景色**：`#213331`（深松綠滿版延伸）
- **欄目標題**：`#B0ED9C`（綠色小標，大寫 `letter-spacing: 0.06em`）
- **導航連結**：`#FFFFFF`（Hover 時轉為 `#B0ED9C`）
- **版權與地址次文字**：`rgba(255, 255, 255, 0.65)`

---

## ✨ 4. 陰影、光暈與漸層系統 (Shadows, Glows & Gradients)

```css
/* 陰影 Tokens */
--shadow-1: 0 4px 12px rgba(0, 0, 0, 0.06);
--shadow-2: 0 8px 24px rgba(33, 51, 49, 0.10);
--shadow-3: 0 18px 50px rgba(33, 51, 49, 0.16);
--shadow-neon: 0 0 14px rgba(176, 237, 156, 0.50);

/* 核心漸層 Tokens */
--gradient-mesh-glow: radial-gradient(
  38% 51% at 65% 47%,
  rgb(215, 247, 129) 0%,
  rgba(176, 237, 156, 0.4) 50%,
  transparent 100%
);

--gradient-scanline: linear-gradient(
  90deg,
  transparent 0%,
  rgba(176, 237, 156, 0.22) 50%,
  transparent 100%
);

--gradient-card-dark: linear-gradient(
  180deg,
  rgba(33, 51, 49, 1) 0%,
  rgba(14, 23, 22, 1) 100%
);
```

---

## 🔤 5. 字型排版規範 (Typography System)

| 用途分類 | 字型名稱 (Font Family) | 字重 (Font Weight) | 特徵與應用場合 |
| :--- | :--- | :--- | :--- |
| **主要字型 (Primary UI & Body)** | `'DM Sans', -apple-system, sans-serif` | `300`, `400`, `500`, `600`, `700`, `800` | 全站標題、按鈕、導航、內文、描述 |
| **科技與數字展示 (Display & Data)** | `'Aldrich', monospace, sans-serif` | `400` | 即時數據、百分比、代碼標識、科技亮點 |
| **輔助系統字型 (Secondary UI)** | `'Inter', sans-serif` | `400`, `500`, `600` | 數據表格內部微小標籤、表單輸入 |
| **圖標字型 (Icons)** | `'Material Symbols Outlined'` | `400` | 介面圖標、箭頭、勾選符號 |

---

## 💻 6. 可直接引用的 CSS 變數清單 (CSS Variables / Design Tokens)

可以直接複製以下代碼至專案的 `index.css` 或全域樣式表：

```css
:root {
  /* ===== 品牌核心色彩 (Brand Core) ===== */
  --k-neon: #B0ED9C;                /* 核心霓虹薄荷綠 */
  --k-neon-glow: #D7F781;           /* 螢光黃綠（光暈） */
  --k-neon-rgb: 176, 237, 156;
  
  --k-green-900: #213331;           /* 深森松墨綠（主文字/深色卡片） */
  --k-green-950: #0E1716;           /* 極深墨綠（背景陰影） */
  --k-green-900-rgb: 33, 51, 49;
  
  --k-lavender: #E5D1FA;            /* 柔和薰衣草紫（AI 輔助色） */
  --k-lavender-vibrant: #C69CF4;    /* 亮紫（邊框與高光） */
  --k-purple-deep: #5B3FA0;         /* 深紫（薰衣草標籤文字） */

  /* ===== 背景與表面色彩 (Surfaces & Backgrounds) ===== */
  --bg-main: #F2F2E8;               /* 全站底色：溫潤米灰 */
  --bg-card: #FFFFF9;               /* 淺色卡片：暖白 */
  --bg-white: #FFFFFF;              /* 純白表面 */
  --bg-peach: #FDF5EB;              /* 暖杏米色表面 */
  --bg-sage: #E8F0D9;               /* 淺鼠尾草綠表面 */
  --bg-lilac: #EDE4FB;              /* 淺粉紫表面 */
  --bg-dark-frame: #213331;         /* 深色互動面板底色 */

  /* ===== 文字顏色 (Typography) ===== */
  --text-primary: #213331;          /* 淺色底主文字 */
  --text-secondary: #6B7160;        /* 淺色底次要文字 */
  --text-muted: #8D8A7B;            /* 淺色底輔助文字 */
  
  --text-inverse-primary: #FFFFFF;  /* 深色底主文字 */
  --text-inverse-secondary: rgba(255, 255, 255, 0.75); /* 深色底次要文字 */
  --text-inverse-muted: rgba(255, 255, 255, 0.55);     /* 深色底輔助文字 */
  --text-accent: #B0ED9C;           /* 深色底高亮綠字 */

  /* ===== 狀態色彩 (Status & Alerts) ===== */
  --status-exposed: #FF5E5E;        /* 曝險紅 */
  --status-exposed-bg: #FBD9D9;     /* 曝險紅淺底 */
  --status-registered: #B0ED9C;     /* 合規綠 */
  --status-registered-bg: #E8F0D9;  /* 合規綠淺底 */
  --status-warning: #ED8936;        /* 警戒橘 */
  --status-warning-bg: #FEF3C7;     /* 警戒橘淺底 */

  /* ===== 邊框與分隔線 (Borders & Dividers) ===== */
  --border-light: rgba(0, 0, 0, 0.08);
  --border-light-subtle: #DEE6D6;
  --border-dark: rgba(255, 255, 255, 0.07);
  --border-dark-strong: rgba(255, 255, 255, 0.16);
  --border-neon: rgba(176, 237, 156, 0.30);

  /* ===== 圓角規範 (Border Radii) ===== */
  --radius-sm: 8px;
  --radius-md: 14px;
  --radius-lg: 20px;
  --radius-card: 22px;
  --radius-pill: 9999px;

  /* ===== 陰影規範 (Elevation & Shadows) ===== */
  --shadow-sm: 0 4px 12px rgba(0, 0, 0, 0.06);
  --shadow-2: 0 8px 24px rgba(33, 51, 49, 0.10);
  --shadow-3: 0 18px 50px rgba(33, 51, 49, 0.16);
  --shadow-pulse: 0 0 10px rgba(176, 237, 156, 0.60);

  /* ===== 字型家族 (Font Stacks) ===== */
  --font-sans: 'DM Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --font-display: 'Aldrich', monospace, sans-serif;
}
```

---

## 🛠️ 7. Tailwind CSS 配置對照 (tailwind.config.js)

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: {
        kintsugi: {
          neon: '#B0ED9C',
          'neon-glow': '#D7F781',
          'green-900': '#213331',
          'green-950': '#0E1716',
          lavender: '#E5D1FA',
          'purple-vibrant': '#C69CF4',
          'purple-deep': '#5B3FA0',
          base: '#F2F2E8',
          card: '#FFFFF9',
          peach: '#FDF5EB',
          sage: '#E8F0D9',
          lilac: '#EDE4FB',
          exposed: '#FF5E5E',
          registered: '#B0ED9C',
          warning: '#ED8936',
        }
      },
      fontFamily: {
        sans: ['"DM Sans"', 'sans-serif'],
        display: ['"Aldrich"', 'monospace'],
      },
      borderRadius: {
        'card': '22px',
      },
      boxShadow: {
        'card-soft': '0 8px 24px rgba(33, 51, 49, 0.10)',
        'card-deep': '0 18px 50px rgba(33, 51, 49, 0.16)',
        'neon-glow': '0 0 12px rgba(176, 237, 156, 0.60)',
      }
    }
  }
}
```
