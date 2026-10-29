# 開發風格指南

本檔記錄專案在開發過程中反覆確認的**寫程式風格與慣例**，讓下一位開發者（或下一輪對話）可以直接依循，而不用重覆討論。

新的風格決策請往下追加章節，同時更新 `CLAUDE.md` 的相關指引段落。

---

## 樣式管理（Styling）

### 三層架構

樣式一律走這三層，**由下往上**選擇：

```
┌──────────────────────────────────────────────────────┐
│ 3. Vue 元件（.vue）                                  │
│    有邏輯 / props / slot 才做，如 StatusBadge、      │
│    AmountText、PageHeader、EmptyState                │
├──────────────────────────────────────────────────────┤
│ 2. Utility class（styles/index.css @utility）               │
│    重複 3 次以上、有明確語意的視覺骨架組合，          │
│    如 .card / .card-lg / .category-chip /            │
│    .field-label / .field-caption / .section-title    │
├──────────────────────────────────────────────────────┤
│ 1. Design tokens（styles/index.css @theme + CSS vars）      │
│    顏色、圓角、陰影、字體 — 一切「值」的單一來源      │
│    如 --color-primary-500、--radius-card-lg、        │
│    --shadow-primary                                  │
└──────────────────────────────────────────────────────┘
```

### 決策流程（該用哪一層？）

問自己這三個問題，第一個 yes 就用該層：

1. **需要 props / slot / v-model / 條件邏輯嗎？** → **Vue 元件**
2. **這個「視覺組合」在 3 個以上地方重複，且有明確語意（"卡片"、"標籤"…）嗎？** → **Utility class**
3. **只是一次性排版嗎？** → **Tailwind 原生 utility** 直接寫在 template

### Design tokens 位置

- **顏色 / 圓角 / 陰影**：`frontend/src/styles/index.css` 的 `@theme` 區塊
- **對應同步文件**：`design.md`（設計系統 spec，任何 token 變更要同步）
- **PrimeVue 主色**：`frontend/src/presets/trust-blue.ts`（跟 @theme 同色）

命名遵循 Tailwind v4 慣例：
- `--color-*` → 產生 `bg-*` / `text-*` / `border-*` utility
- `--radius-*` → 產生 `rounded-*` utility
- `--shadow-*` → `shadow-[var(--shadow-*)]`（暫未走 utility）

### Utility class 寫法

**只承載視覺骨架**（背景、邊框、圓角、字級、主要間距）。修飾（hover、寬度、額外間距）用 Tailwind 原生 utility 疊加：

```html
<!-- ✅ 好 -->
<section class="card p-4 mb-3">...</section>
<article class="card p-4 hover:border-primary-300">...</article>

<!-- ❌ 別把 padding、hover 這種變動需求鎖進 utility -->
<section class="card-with-p4-and-mb3">...</section>
```

**`@utility` 內部一律用原生 CSS + `var(--token-*)`，不要 `@apply` Tailwind class**：

```css
/* ✅ 好：原生 CSS，直接引用 token */
@utility card-lg {
  background-color: #fff;
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-card-lg);
}

/* ❌ 避免：@apply 在 v4 需額外 @reference，且多一層編譯 */
@utility card-lg {
  @apply bg-white border border-[var(--color-hairline)] rounded-card-lg;
}
```

理由：Tailwind v4 `@utility` 原本就設計給原生 CSS；token 已透過 `@theme` 統一管理，`bg-white` / `bg-primary-500` 底層產生的 CSS 就是 `#fff` / `var(--color-primary-500)`，直接寫原生 CSS 不會失去 token 同步能力。

現有 utility 清單見 `design.md > 元件 utility classes`。

### PrimeVue 覆寫

PrimeVue 元件（Button / InputText / DatePicker …）的**全域樣式**（圓角、字重、邊框寬度、預設陰影）也集中在 `styles/index.css`，用 `.p-button` / `.p-inputtext` 等原生 class 選擇器覆寫，**不做每個元件個別 `:pt` pass-through**。

例：
```css
.p-button {
  border-radius: var(--radius-control);
  font-weight: 600;
}
```

### 手機版字級

手機版（`max-width: 639.98px`）文字**上限 14px**（含 modal、button、input、卡片內文）。頁面主標 `PageHeader` 可例外。

在 PrimeVue 元件超過 14px 時，於 `styles/index.css` 的手機版 media query 內覆寫（已建立範例）。

### 檢查清單（新增 UI 前）

- [ ] 需要的顏色 / 圓角 / 陰影是否已在 `@theme`？沒有 → 先加 token
- [ ] 有沒有現成的 utility class（`.card`、`.category-chip` …）可以用？
- [ ] 這段 pattern 之後會重複嗎？重複 3 次以上 → 抽 utility
- [ ] 有邏輯或狀態嗎？有 → 抽 Vue 元件
- [ ] 手機版字級都 ≤ 14px？

---

## 無障礙（Accessibility）

無障礙不是「上線前再補」——**實作或修改元件時就要順手加上**。目標是讓讀屏軟體（VoiceOver / TalkBack / NVDA）與純鍵盤使用者能正常操作，避免上線後才回頭大改。

### 必做屬性清單

**Icon-only 互動元素（按鈕、連結）**
必加 `aria-label`，否則讀屏會念不出來。
```html
<!-- ✅ -->
<button aria-label="開啟選單" @click="isOpen = true">
  <i class="pi pi-bars" aria-hidden="true" />
</button>

<!-- ❌ 沒 aria-label，讀屏只念到「按鈕」 -->
<button @click="isOpen = true"><i class="pi pi-bars" /></button>
```

**裝飾性 icon**
純視覺點綴的 `<i class="pi ...">` 一律加 `aria-hidden="true"`，避免讀屏念出 icon 名稱。有語意的 icon（例如「已完成 ✓」單獨代表狀態時）反而要保留可讀性，用 `<span class="sr-only">已完成</span>` 提供文字。

**表單欄位**
- `<label>` 綁 `for="input-id"`（或用 wrapping label），不要只用視覺上的標題文字
- 必填欄位：`aria-required="true"`（或 native `required`）
- 驗證錯誤：`aria-invalid="true"` + `aria-describedby="error-id"` 指到錯誤訊息元素
- PrimeVue `InputText` / `Dropdown` 等元件已內建 aria，但外層 `<label>` 綁定仍要自己做

**Modal / Dialog / Drawer**
- 可用 `Esc` 關閉
- 開啟時 focus 移入 modal 內（PrimeVue Dialog 預設會做）
- Focus trap：Tab 不會跳到 modal 外面（PrimeVue Dialog 預設會做；自製 drawer 要自己實作或用 `<Dialog>`）
- 關閉按鈕加 `aria-label="關閉"` 或類似文字
- 遮罩點擊關閉時不能是唯一關閉方式（要有可見的關閉按鈕）

**語意元素**
互動一律用 `<button>` / `<a>` / `<RouterLink>`，**不要 `<div @click>`**——後者無法用 Enter/Space 觸發、focus 不會停、讀屏也認不出來。頁面骨架用 `<header>` / `<nav>` / `<main>` / `<aside>`，讀屏可跳段瀏覽。

**顏色不獨當一面**
狀態、錯誤、必填**不能只靠顏色分辨**。狀態徽章要有文字（已建立 StatusBadge 元件），錯誤訊息要有 `!` icon 或明確文字，必填欄位要有 `*` 或「必填」字樣。

**Focus 可見**
不要在 CSS 移除 `:focus` outline。若要客製，用 `:focus-visible` 加自訂樣式（例如 `box-shadow: 0 0 0 2px var(--color-primary-500)`）。

**動態訊息**
Toast、成功／錯誤 flash：讀屏要能感知。PrimeVue Toast 已內建 `role="alert"`；若自製，一般訊息用 `aria-live="polite"`，緊急錯誤用 `aria-live="assertive"`。

**手勢／觸控目標**
可點區域 ≥ 44 × 44 px（手機版尤其重要，行政人員可能戴手套或在晃動的通勤環境操作）。

### 檢查清單（元件實作 / 修改完成前）

- [ ] 所有 icon-only 按鈕都有 `aria-label`？
- [ ] 所有裝飾 icon 都有 `aria-hidden="true"`？
- [ ] 表單欄位都有正確綁定的 `<label>`？錯誤狀態有 `aria-invalid`？
- [ ] Modal / Drawer 可用 Esc 關閉、close button 有 `aria-label`？
- [ ] 沒有 `<div @click>`（除非該元素完全無互動）？
- [ ] 狀態 / 錯誤 / 必填不是只靠顏色表達？
- [ ] Focus outline 沒被 CSS 蓋掉？
- [ ] 手機可點區域 ≥ 44 × 44 px？

---

## 純函數（Utils）

**格式化、轉型、驗證這類跟 UI 無關的純函數一律放 `frontend/src/utils/`**，同一個 helper 不要在多個 `.vue` 各自複製。

現有：
- `utils/format.ts` — 金額、日期、日期時間、日期↔ISO、短日期（`MM/DD`）
- `utils/approval.ts` — 簽核流程 helper

規則：
- **重複 2 次**就抽出去（比 UI utility 的門檻更嚴，因為函數比 class 更難察覺重複）。
- 檔名依領域分（`format.ts` / `approval.ts` / `validate.ts` …），不要 `helpers.ts` 大雜燴。
- 匯出用具名 export，方便 tree-shake：`export function formatCurrency(n) {…}`。
- 有副作用（`localStorage`、`console` 等）→ 不放 utils，放 store 或 composable。
