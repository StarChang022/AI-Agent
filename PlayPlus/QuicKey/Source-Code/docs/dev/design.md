---
version: 1.2
name: Quickey-Design
description: 代墊款管理工具設計系統 — 品牌綠主題。主色 #00B39F（取自 Logo），並加入 6 種請款狀態的語意化色彩對應，狀態色與主色脫鉤避免撞色。前台採 mobile-first 大圓角卡片語言，後台繼承相同 tokens。

colors:
  # === Primary (品牌綠 Teal Green，取自 image/logo/*.svg) ===
  primary: "#00b39f"
  primary-hover: "#019181"
  primary-pressed: "#008072"
  primary-50: "#edfaf8"
  primary-100: "#d1f1ee"
  primary-200: "#8cddd4"
  primary-300: "#58cdc0"
  primary-400: "#2abfaf"
  primary-500: "#00b39f"
  primary-600: "#019181"
  primary-700: "#008072"
  primary-800: "#035a50"
  primary-900: "#053f38"
  primary-950: "#062a25"
  on-primary: "#ffffff"
  # primary-500 本身跟白字對比只有 2.64:1，未達 WCAG AA 的 4.5:1（文字用途一樣不合格）。
  # 疊白字的實心底（按鈕、選中分頁下方色塊以外的填色）跟文字強調，一律走下面兩個語意別名：
  primary-solid: "{colors.primary-700}"   # 按鈕實心底、選中狀態底色 — 對比 4.85:1，過關
  primary-text: "{colors.primary-700}"    # 連結、文字強調、次要按鈕文字 — 同上
  # primary-500 本身保留給不需要疊文字對比的場合：icon、分頁下方指示條、圖表點狀標記等

  # === Semantic ===
  success: "#10b981"
  warning: "#f59e0b"
  info: "#0ea5e9"
  danger: "#dc2626"

  # === Status Badge (6 種請款狀態，刻意跟主色脫鉤) ===
  # 「已核銷」過去等於 primary，主色一旦換成綠色會跟「已發放」的綠撞色，已改成固定紫色，
  # 不論主色未來選什麼，六個狀態互相都不會撞色。
  status-draft: "#6b7280"          # 灰 - 草稿
  status-review: "#d97706"         # 琥珀/橘 - 簽核中
  status-rejected: "#dc2626"       # 紅 - 駁回
  status-approved: "#6d28d9"       # 紫 - 已核銷待發放（不再借用 primary）
  status-paid: "#059669"           # 綠 - 已發放
  status-voided: "#485266"         # 深灰(同 slate) - 已作廢，用深底白字強調「已結束」

  # === Neutrals — 對齊 reference 前台卡片系統 ===
  canvas: "#ffffff"
  surface: "#f4f5f8"               # 頁面背景（reference #F4F5F8）
  surface-soft: "#eef1f5"          # 更淺的灰底（左滑操作條、tag 底色）
  hairline: "#e3e6ec"              # 卡片/分隔線
  hairline-strong: "#c9cedd"       # 較深邊線（虛線上傳區）
  ink: "#1a1f29"                   # 主要文字（reference #1a1f29）
  slate: "#485266"                 # 次要文字（卡片內副資訊）
  steel: "#454b57"                 # 中間灰（次要按鈕文字）
  muted: "#6b7280"                 # 一般 muted 文字
  muted-soft: "#a6acb8"            # 很輕的 hint / placeholder

typography:
  fontFamily: "'Open Sans', 'Noto Sans TC', -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang TC', 'Microsoft JhengHei', sans-serif"
  # 英文字體為 Open Sans，中文字體為 Noto Sans TC。字體堆疊順序即規則：英文與數字先取 Open Sans，中文字元自動 fallback 到 Noto Sans TC。
  # index.html preconnect + link 匯入 Noto Sans TC 與 Open Sans，各自 400/500/600/700 四個字重

  hero:
    fontSize: 32px
    fontWeight: 600
    lineHeight: 1.20
    letterSpacing: -0.5px
    usage: 登入頁品牌區、後台儀表板總標
  heading-1:
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.25
    usage: 後台頁面主標
  heading-2:
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.30
    usage: 前台頁面主標
  heading-3:
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.35
    usage: 卡片內副標、Modal 標題
  body-md:
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.55
    usage: 主要內文
  body-sm:
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.50
    usage: 表格內容、次要文字
  caption:
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.40
    usage: 提示、輔助說明
  currency:
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.20
    fontVariantNumeric: tabular-nums
    usage: 金額卡片、統計數字
  button:
    fontSize: 14px
    fontWeight: 600      # 對齊 reference（.p-button 已全域覆寫）
    lineHeight: 1.30

rounded:
  none: 0
  xs: 4px
  sm: 6px
  md: 8px
  lg: 12px
  xl: 16px
  full: 9999px
  # === 語意化圓角（前台卡片語言，對應 styles/index.css 的 --radius-* tokens） ===
  tag: 8px                          # 小標籤（類別 chip）→ Tailwind `rounded-tag`
  chip: 14px                        # 中型 chip（非按鈕/分頁用途時）
  control: 16px                     # input、textarea、select（PrimeVue 已全域覆寫）
  card: 18px                        # 內層/次要卡片（詳情頁區塊、歷史記錄列表）
  card-lg: 20px                     # 主要卡片（Home KPI、Form 主容器）
  # 按鈕、分頁 Tab、狀態徽章、類別標籤全部改用 full（全圓角 pill），
  # 不再用 control（16px）這種偏方形的圓角 —— 這是這輪視覺調整的決定之一。

spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 20px
  xl: 24px
  xxl: 32px
  xxxl: 40px
  # === 前台語意間距（Tailwind 對照） ===
  # 卡片內距：16px（p-4）常用、20px（p-5）主要卡片
  # 卡片間距：12px（gap-3 / mb-3）
  # 欄位間距：16px（space-y-4）
  # Input padding：12px 14px（上下 12px、左右 14px，統一規則）
  # Button padding：12px 20px（PrimeVue 預設）

shadow:
  sm: "0 1px 2px rgba(15, 23, 42, 0.04)"
  md: "0 4px 12px rgba(15, 23, 42, 0.06)"
  lg: "0 8px 24px rgba(15, 23, 42, 0.08)"
  # === 前台語意陰影（對應 styles/index.css） ===
  primary: "0 6px 16px rgba(0, 128, 114, 0.22)"    # 主要 CTA 按鈕陰影（跟 primary-solid #008072 對齊）
  card: "0 8px 24px rgba(26, 31, 41, 0.10)"        # 浮動卡片（底部 nav）
  float: "0 20px 60px rgba(26, 31, 41, 0.10)"      # 大型浮層（Dialog、Drawer）

# === 元件規範 ===
# 註：以下 button / input / card / table 等規範**僅供手刻元件時參考**。
# 專案優先使用 PrimeVue 元件（已由 presets/trust-blue.ts 對齊主色，未來改名對齊品牌綠），
# 只有在 PrimeVue 沒有對應元件、或需要自製共用元件時，才依照這裡的 tokens 手刻。
# `status-badge` 例外：狀態徽章屬於領域專屬（6 種請款狀態），一定會做成共用元件，
# 顏色映射見下方 status-badge-mapping。
components:
  button-primary:
    backgroundColor: "{colors.primary-solid}"      # #008072，不是 primary-500，見上方對比說明
    textColor: "{colors.on-primary}"
    typography: "{typography.button}"
    rounded: "{rounded.full}"              # 全圓角 pill（原 16px control，已改）
    padding: "12px 20px"
    shadow: "{shadow.primary}"
    hover: "{colors.primary-hover}"
    pressed: "{colors.primary-pressed}"

  button-secondary:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.primary-text}"
    border: "1.5px solid {colors.primary-solid}"
    rounded: "{rounded.full}"              # 全圓角 pill
    padding: "12px 20px"
    hover-background: "{colors.primary-50}"

  button-danger:
    backgroundColor: "{colors.canvas}"
    textColor: "#c0362c"
    border: "1.5px solid #f1b3ac"
    rounded: "{rounded.full}"
    padding: "12px 20px"
    shadow: none
    usage: 駁回、作廢等破壞性動作（改成外框樣式，不用實心紅底，跟其餘按鈕的克制感一致）

  button-text:
    backgroundColor: transparent
    textColor: "{colors.primary-text}"
    border: none
    padding: "10px 12px"
    usage: 次要、低強調動作，例如「取消選取」（實際頁面：ReviewView.vue `text size="small"`、多處 `p-button-text`）

  button-icon:
    # 按鈕本身仍是 button-primary / button-secondary，這裡只定義圖示的排版規則
    gap: 6px
    iconSize: 16px
    usage: "帶 PrimeIcons 的按鈕（icon+label 如「新增類別」icon=pi-plus；icon-only 如搜尋鍵 icon=pi-search，寬高固定 40x40、置中）"

  card:
    backgroundColor: "{colors.canvas}"
    border: "1px solid {colors.hairline}"
    rounded: "{rounded.card-lg}"          # 20px 主卡（首頁 KPI、Form 主容器）
    padding: "20px"
    shadow: none
    variants:
      nested:
        rounded: "{rounded.card}"         # 18px 內層卡（詳情頁區塊、歷史列表）
        padding: "16px"
    kpi-label:
      fontSize: 15px
      fontWeight: 500
      textColor: "{colors.slate}"
      # 原本 12px + muted-soft，太淡太不明顯，已加大字級、改用較深的 slate（例如「本月已核銷」這種卡片標籤）
    kpi-value:
      typography: "{typography.currency}"
      textColor: "{colors.ink}"

  status-badge:
    padding: "3px 10px"
    rounded: "{rounded.full}"
    typography: "{typography.caption}"
    fontWeight: 600
    # 具體顏色映射見下方 status-badge-mapping，六色固定，不隨主色調整

  category-chip:
    padding: "2px 9px"
    rounded: "{rounded.tag}"              # 8px
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    fontSize: 12px
    fontWeight: 600
    usage: 卡片上「材料/工具/交通/服務費/其他」類別標記（比 status-badge 樸素、非狀態，統一灰底，不做強調變體）

  tag:
    # 對應 PrimeVue <Tag>，跟 category-chip 用途不同：category-chip 是分類本身，
    # tag 是附加在資料上的一般語意標記（例如超支警示）
    padding: "4px 12px"
    rounded: "{rounded.full}"
    fontSize: 14px
    fontWeight: 600
    variants:
      default:
        backgroundColor: "{colors.surface}"
        textColor: "{colors.slate}"
        border: "1px solid {colors.hairline}"
      danger:
        backgroundColor: "#fee2e2"
        textColor: "{colors.danger}"
        usage: "警示性標記，例如 BudgetsView 超支（severity=danger）"

  tab:
    # 後台列表頁的分頁一律用 segmented（膠囊式，TabBar variant="segmented"）；下方底線規格僅適用於非列表的頁內分頁
    # 對應實際 3 處手刻 tab（PayoutView / ReviewView / CategoriesView），統一成同一種樣式
    fontSize: 16px
    activeColor: "{colors.primary-text}"
    inactiveColor: "{colors.muted}"
    indicator:
      height: 2px
      color: "{colors.primary-solid}"
      position: "bottom, 貼齊文字下緣"
    countBadge:
      rounded: "{rounded.full}"
      fontSize: 12px
      activeBackground: "{colors.primary-50}"
      activeColor: "{colors.primary-text}"
      inactiveBackground: "{colors.surface}"
      inactiveColor: "{colors.slate}"
      usage: "數量徽章，如「待發放 12」「已完成 86」（PayoutView / ReviewView 樣式）"

  input:
    backgroundColor: "{colors.canvas}"
    border: "1.5px solid {colors.hairline}"
    rounded: "{rounded.control}"          # 16px
    padding: "12px 14px"                   # 上下 12px、左右 14px（統一規則，先前是 11px 14px）
    focus-border: "{colors.primary-solid}"
    focus-shadow: "0 0 0 3px {colors.primary-100}"

  select:
    # 對應 PrimeVue <Select>（原生單選下拉，不同於 multi-select）
    extends: input
    icon: "pi-chevron-down"
    iconPosition: right
    iconColor: "{colors.muted}"
    panel:
      backgroundColor: "{colors.canvas}"
      border: "1px solid {colors.hairline}"
      rounded: "{rounded.control}"
      shadow: "{shadow.float}"
      optionHighlight:
        backgroundColor: "{colors.primary-50}"
        textColor: "{colors.primary-text}"
    usage: "點擊整個輸入框展開選項清單（不能只換箭頭方向卻沒有實際展開面板），例如 ExpensesView 的費用類別選擇"

  date-picker:
    extends: input
    icon: "pi-calendar"
    iconPosition: right
    iconColor: "{colors.muted}"           # 功能性圖示統一用較淺的灰，不是 slate
    panel:
      backgroundColor: "{colors.canvas}"
      border: "1px solid {colors.hairline}"
      rounded: "{rounded.control}"
      shadow: "{shadow.float}"
      selectedDate:
        backgroundColor: "{colors.primary-solid}"
        textColor: "{colors.on-primary}"
    usage: "點擊整個輸入框展開月曆面板，不是只顯示靜態文字＋圖示"

  icon-field:
    extends: input
    icon: "pi-search"
    iconPosition: left
    iconColor: "{colors.muted}"
    usage: 搜尋框（IconField + InputIcon，例如 PayoutView / ExpensesView / RecordsView / ReviewView 的搜尋鍵）

  multi-select:
    extends: input
    minHeight: 44px
    chip:
      backgroundColor: "{colors.primary-50}"
      textColor: "{colors.primary-text}"
      rounded: "{rounded.full}"
      fontSize: 13px
    dropdownIconColor: "{colors.muted}"

  autocomplete:
    extends: input
    panel:
      backgroundColor: "{colors.canvas}"
      border: "1px solid {colors.hairline}"
      rounded: "{rounded.control}"
      shadow: "{shadow.float}"
      optionHighlight:
        backgroundColor: "{colors.primary-50}"
        textColor: "{colors.primary-text}"

  upload-dropzone:
    border: "2px dashed {colors.hairline}"
    rounded: "{rounded.card}"
    padding: "32px 20px"
    backgroundColor: "{colors.canvas}"
    hover:
      borderColor: "{colors.primary-solid}"
      backgroundColor: "{colors.primary-50}"
    icon:
      size: 40px
      color: "{colors.muted}"
    usage: "憑證（發票/收據）上傳 —— 上傳是核銷流程的關鍵動作，改用比一般 input 更明顯的拖放區樣式，取代原本『邊框按鈕＋小字提示』的樣式"

  dialog:
    header:
      padding: "16px 20px"
      borderBottom: "1px solid {colors.hairline}"
      typography: "{typography.heading-3}"
    body:
      padding: "20px"
    footer:
      padding: "14px 20px"
      borderTop: "1px solid {colors.hairline}"
      align: right
      gap: 8px
      usage: "取消（button-secondary）+ 主要動作（button-primary），順序固定：取消在左、主要動作在右"
    shadow: "{shadow.float}"
    rounded: "{rounded.card-lg}"
    usage: 表單型彈窗（例如 UsersView 新增/編輯人員、重設密碼）

  drawer:
    header:
      padding: "16px 20px"
      borderBottom: "1px solid {colors.hairline}"
    body:
      padding: "16px 20px"
    shadow: "{shadow.float}"
    rounded: "{rounded.card-lg}"
    position: right
    usage: 篩選條件、次要詳情等不需要打斷主要流程的內容
    detail-content:
      # 詳情抽屜（支出詳情 / 請款單）內容結構，class 定義在 frontend/src/styles/qds.css 的 .dt-*
      order: "摘要 .dt-summary（surface 底：狀態 + 大字金額 + 下一步/付款安排）→ 分區卡片 .dt-section（hairline 框）→ 底部 .dt-meta 小字紀錄"
      row: "<dl class=dt-list> + .dt-row：標籤固定寬 88px（手機 76px）、數值緊接靠左，不做左右兩端對齊"
      rules:
        - 沒有資料的欄位不顯示（收據不列發票號碼 / 統編），不要用「—」佔一行
        - 金額不重複：摘要已有總額；營業稅才列 未稅 / 稅額 / 總金額（總金額列加上框線），免稅只顯示稅別
        - 建立者、時間等紀錄放底部 .dt-meta，不和主要欄位同權重
        - 危險動作（刪除、作廢）在 footer 用 text 按鈕，主要動作用實心按鈕

  table-header:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.slate}"
    typography: "{typography.caption}"
    fontWeight: 600
    textTransform: none
    padding: "10px 14px"
    borderBottom: "1px solid {colors.hairline}"
    # 曾評估過表頭整排用 primary 實心底 + 白字（借用其他產品的視覺概念），
    # 最後決定維持淺灰底 + 深灰字：主色收斂到按鈕/選中分頁這類「需要操作」的元件，
    # 表格是資訊呈現，不需要主色搶走注意力。

  table-row:
    backgroundColor: "{colors.canvas}"
    hover-background: "{colors.surface-soft}"
    borderBottom: "1px solid {colors.hairline}"
    padding: "12px 14px"
    # 表格列之間只用一條分隔線（border-bottom），不要用列距 + 上下雙邊框疊出「兩條線」的效果

  empty-state:
    padding: "36px 20px"
    border: "1px dashed {colors.hairline}"
    rounded: "{rounded.control}"
    textColor: "{colors.muted}"
    title:
      typography: "{typography.heading-3}"
      textColor: "{colors.ink}"
    usage: 各列表頁（Expenses / Payout / Categories / Records / Review / History / Home）在無資料時使用

# === 狀態徽章顏色對應（六色固定，不隨主色調整） ===
status-badge-mapping:
  draft:
    background: "#eef1f5"
    text: "{colors.status-draft}"
    label: 草稿
  in_review:
    background: "#fef3c7"
    text: "{colors.status-review}"
    label: 簽核中
  rejected:
    background: "#fee2e2"
    text: "{colors.status-rejected}"
    label: 駁回
  approved:
    background: "#ede9fe"
    text: "{colors.status-approved}"
    label: 已核銷
    # 過去 background/text 借用 primary-50/primary，主色換成綠色後會跟「已發放」的綠撞色，
    # 已改成固定紫色（不再是 {colors.primary-*}），見上方 colors.status-approved 說明。
  paid:
    background: "#d1fae5"
    text: "{colors.status-paid}"
    label: 已發放
  voided:
    background: "{colors.status-voided}"
    text: "#ffffff"
    label: 已作廢
    # 深灰底 + 白字，跟其他 5 個「淺底 + 深字」的徽章做出區別，強調這是已結束、不可逆的狀態
---

# 使用指引

## 設計理念

本設計系統以「**財務工具需要克制、專業、資訊清晰**」為出發點：

- **主色克制**：品牌綠 `#00B39F`（取自 Logo）只用在主要動作按鈕、選中分頁、Logo 這類「需要注意/操作」的地方。頁面主體以中性灰階為主，大面積(表頭、卡片、頁面背景)維持灰白，不用主色鋪滿。
- **狀態語意化，且與主色脫鉤**：6 種請款狀態各有專屬顏色，一眼可辨，**不可**用主色當狀態色 —— 這條規則比過去更嚴格：舊版「已核銷」直接借用 primary，導致主色一換就可能跟其他狀態撞色（例如換成綠色後跟「已發放」撞色），現在 6 色全部獨立、固定。
- **數字第一**：金額使用 `tabular-nums`，等寬對齊，讓表格內數字可垂直比對。
- **視覺清晰優先**：資訊層級一眼可辨（標題 → 數字 → 說明），任何裝飾都不能干擾閱讀。
- **間距有邏輯**：只用間距 tokens（4／8／12／16／20／24／32／40），關係越近間距越小；同層級元素間距一致，不為單一畫面微調。
- **對齊**：同一區塊的文字、圖示、欄位共用對齊線；文字靠左、金額數字靠右。
- **一致**：同一種元件在每一頁長得一樣，同一種狀態永遠用同一組顏色與圖示。
- **同列等高**：並排在同一列的元件高度一致（按鈕與輸入框、KPI 卡、內容卡片），內容長短不同時由容器撐齊，不讓卡片高低不一。
- **重要動作要有存在感**：多數元件走克制路線，但像憑證上傳這種流程關鍵動作，改用比一般 input 更明顯的拖放區樣式（虛線邊框、大圖示、明確文案），避免「重要但長得不明顯」。
- **互動一定要有回饋**：任何可點擊 / 可輸入的元件（按鈕、Tab、Input、AutoComplete 選項、上傳拖放區、表格列、Dialog/Drawer 的關閉鍵…）都要有 hover（滑入變色/變底）與 focus（邊框 + 光暈）樣式，不能只有靜態外觀；顏色轉場統一用 `transition: 0.15s ease`，避免生硬跳動。

## 前台 vs 後台的密度差異

| 面向 | 前台（員工） | 後台（財務／管理員） |
|------|-------------|--------------------|
| 響應式優先 | 手機（375px+） | 桌面（1280px+） |
| Layout 寬度 | max-w-3xl 置中 | 側邊 sidebar + flex-1 內容區 |
| 資訊密度 | 低（一次一件事） | 高（表格、篩選、批次操作） |
| 字級基準 | 較大（16-20px） | 較小（14px 為主） |
| 導覽 | 底部 tab bar | 側邊 sidebar |

## 元件套用順位

1. **首選** `frontend/src/components/` 內既有的共用元件（如 `StatusBadge`、`AmountText`）
2. **次選** PrimeVue 元件 + 自訂 class 對齊 tokens
3. **最後** 純 Tailwind + CSS var 手刻

## 元件 utility classes（Tailwind v4 `@utility`）

以下 class 定義在 `frontend/src/styles/index.css`，覆蓋前台重複 3 次以上的 pattern。
**優先使用這些 class**；只有找不到對應的組合時才回退到原生 Tailwind utility。

| Class | 樣式內容 | 使用場景 |
|-------|---------|---------|
| `card-lg` | 白底 + 1px hairline + `rounded-card-lg`（20px） | 首頁 KPI、Form 主容器 |
| `card` | 白底 + 1px hairline + `rounded-card`（18px） | 詳情頁區塊、歷史列表卡 |
| `category-chip` | 灰底 8px 圓角 + 12px 600 | 材料/工具/交通/服務費/其他 分類 |
| `field-label` | 14px 600 ink + `mb-2` block | Form 欄位主標（金額 / 費用類別 …） |
| `field-caption` | 12px muted-soft + `mb-0.5` | 詳情頁 `<dt>` 灰標 |
| `section-title` | 14px 600 ink + `mb-3` | 卡片內 subsection 標題（發票或收據 / 簽核進度） |
| `upload-dropzone` | 虛線邊框 + 大圖示 + 置中文案，hover 邊框轉主色 | 憑證（發票/收據）上傳 |

搭配 padding / margin / hover 等仍用原生 Tailwind 疊加，例如：
```html
<section class="card p-4 mb-3">…</section>
<section class="card-lg p-5 space-y-4">…</section>
<article class="card p-4 cursor-pointer hover:border-primary-300">…</article>
<span class="category-chip">材料</span>
```

## 常用 Tailwind class 對照

| 用途 | Class |
|------|-------|
| 主色文字 | `text-primary-700`（不是 500，見上方對比說明） |
| 主色背景（icon、指示條等不疊文字場合） | `bg-primary-500` |
| 主色實心底（按鈕、疊白字場合） | `bg-primary-700` |
| 頁面背景 | `bg-[var(--color-surface)]` |
| 主要文字 | `text-[var(--color-ink)]` |
| 次要文字 | `text-[var(--color-slate)]` / `text-[var(--color-muted)]` |
| 更淡的 hint | `text-[var(--color-muted-soft)]` |
| **按鈕/分頁/徽章圓角**（手刻時） | `rounded-full`（原本是 `rounded-control`，已改為全圓角 pill） |
| **Input/Select/Textarea 圓角** | `rounded-control`（16px，維持不變） |
| 狀態徽章底色 | `bg-status-review` / `bg-status-paid` … |
| **主 CTA 陰影**（手刻按鈕） | `shadow-[var(--shadow-primary)]` |

## 表格欄寬規則

所有資料表（PrimeVue DataTable）共用同一套規則，新表格也照此設定：

- **版面**：寬度 100%，不設 `tableLayout: fixed`，欄寬交給瀏覽器依內容自動分配，讓表格填滿卡片、欄與欄之間的空白平均。
- **只有兩類欄位指定寬度**：
  - **勾選框**：固定 48px（觸控範圍）。
  - **狀態、來源、操作等只佔內容寬度的欄位**：`width: 1%`，瀏覽器會讓它剛好容納內容與內距，不會溢出。操作欄的按鈕與內距都包含在內。
- **其他欄位不指定寬度**（名稱、類別、金額、日期、說明等），由瀏覽器自動分配。
- **數字右對齊**；文字內容過長時截斷或換行。
- **表格最小寬度**：設定 `minWidth`，螢幕較窄時在表格區域內橫向捲動。
- **固定寬度的元件**（例如進度條、金額輸入框）要設定明確寬度，讓自動分配時能依它們的寬度計算欄寬。

## 欄位順序規則

表格欄位依使用者掃視時的決策順序排列，越靠前越先被看到：

1. **識別**：這是什麼（申請人、廠商、名稱）
2. **分類**：屬於哪一類（類別）
3. **數字**：多少錢（金額，或預算與實際）
4. **時間**：什麼時候（費用日）
5. **狀態**：需不需要處理（狀態、付款狀態、目前階段）
6. **次要資訊**：來源、對應支出、建立時間、更新時間
7. **操作**：永遠放最右邊

同一頁若有多種狀態欄，只顯示當前分頁用到的欄位，並放在資料欄的最後（操作欄之前）。

## 圓角語意

| Token | 值 | 用途 |
|-------|-----|-----|
| `rounded-tag` | 8px | 類別標籤（材料/工具…） |
| `rounded-chip` | 14px | 一般 chip（非按鈕/分頁/徽章） |
| `rounded-control` | 16px | input、textarea、select（PrimeVue 全域已套） |
| `rounded-card` | 18px | 詳情頁內層卡片、歷史列表卡、Dialog/Drawer |
| `rounded-card-lg` | 20px | 首頁主 KPI 卡、Form 主容器 |
| `rounded-full` | 999px | **按鈕、分頁 Tab、狀態徽章、Tag**（這輪改成全部走 pill，原本按鈕是 16px） |

## 圖示規範

- 一律使用 **PrimeIcons**（已內建）。範例：`<i class="pi pi-check" />`。
- 前台底部 tab、後台側邊 nav 的圖示尺寸為 20px（`text-lg`）。
- 輸入框內的功能性圖示（日期、搜尋、下拉箭頭）統一用 `muted` 灰階、不用 `slate`，線條粗細統一（避免深淺、粗細不一致）。
- 按鈕內的圖示（icon+label 或 icon-only）跟隨按鈕文字顏色（`currentColor`），不額外指定顏色。
- 空狀態插圖用大尺寸 icon（`text-4xl`）+ 灰色 (`text-[var(--color-muted)]`)。

## Toast（全站提示訊息）

完整示意見 `design-system/design-toast.html`。

- **位置與寬度**：畫面右上角（`App.vue` 統一設定）；寬度 25rem，窄螢幕不超出視窗（`styles/index.css`）。
- **結構**：標題必填，說明結果或原因；內文選填，只寫處理方式或補充。
- **語意**：`success` 操作完成；`warn` 操作被前置條件擋下，需使用者處理；`error` 操作失敗（後端或網路）；`info` 一般提示，不影響資料。
- **停留時間**：success 2.5 秒、warn／info 3 秒、error 3.5 秒。
- **圖示與對齊**：圖示 18px，所在區塊高度等於標題行高（24px），與標題第一行垂直置中。
- **字級**：標題 16px（行高 24px）、內文 14px；手機版標題也不超過 14px。
- **文案**：不顯示英文或錯誤代碼；無法辨識的錯誤用「請稍後再試。」；標題不重複列表上下文（不寫「這筆」）。
- **不用 Toast 的情況**：需要使用者決定或確認 → Dialog；表單欄位錯誤 → 欄位下方的錯誤文字；需要持續顯示的狀態 → Alert。
- **現況待統一**：部分既有提示的停留時間仍為 2–4 秒，少數錯誤使用 `danger` 而非 `error`。

## 待補（將於後續 UI 開發時補上）

- 具體元件 API（`<StatusBadge :status="...">` 等）
