<script setup lang="ts">
import { ref } from 'vue'
import { staggerDelay } from '../motion/reveal'
import warnIcon from '../assets/home/warn-icon.svg'
import pain1 from '../assets/pain/pain-card-1.png'
import pain2 from '../assets/pain/pain-card-2.png'
import pain3 from '../assets/pain/pain-card-3.png'
import pain4 from '../assets/pain/pain-card-4.png'

// 每個角色只出現一次，對應該角色的主要痛點（文案沿用原內容），由左至右依序排列
const threads = [
  {
    role: '行政人員',
    line: '收據一張張找，月底對帳總是忙不完。',
    note: '紙本收據分散、Excel 資料難以統整',
    img: pain1,
    alt: '行政人員被大量收據與報表包圍、雙手抱頭的插圖',
  },
  {
    role: '一人公司老闆',
    line: '忙著做生意，哪還有時間慢慢記帳？',
    note: '日常收支容易漏記，統計還得自己整理',
    img: pain2,
    alt: '疲憊趴在桌上、電量見底的工作者插圖',
  },
  {
    role: '企業主',
    line: '錢花去哪裡，總要等報表出來才知道。',
    note: '預算與支出缺乏即時掌握',
    img: pain3,
    alt: '兩人一同檢視報表與圖表的插圖',
  },
  {
    role: '員工',
    line: '代墊的費用送出去了，現在審到哪？',
    note: '請款流程不透明，進度只能反覆詢問',
    img: pain4,
    alt: '對著電腦、被金錢與問號包圍的員工插圖',
  },
] as const

// 翻面狀態：點擊（觸控）或鍵盤 Enter / 空白鍵翻面；桌機以滑鼠移入翻面
const flipped = ref(threads.map(() => false))
function toggle(i: number) {
  flipped.value[i] = !flipped.value[i]
}
</script>

<template>
  <section id="pain" class="pain">
    <div class="container-page">
      <header class="pain-head" v-reveal="'up'">
        <p class="eyebrow">你是否也遇過</p>
        <h2 class="pain-title">還在用 Excel、收據和訊息管理每一筆帳？</h2>
        <p class="lead">從日常記帳到月底對帳，繁瑣的流程正在佔用你的時間。</p>
      </header>

      <ul class="pain-grid">
        <li v-for="(t, i) in threads" :key="t.role" class="pain-card" v-reveal="{ type: 'up', delay: staggerDelay(i) }">
          <div
            :class="['pain-flip', { 'is-flipped': flipped[i] }]"
            role="button"
            tabindex="0"
            :aria-pressed="flipped[i]"
            @click="toggle(i)"
            @keydown.enter.prevent="toggle(i)"
            @keydown.space.prevent="toggle(i)"
          >
            <div class="pain-flip-inner">
              <div class="pain-face pain-front">
                <img class="pain-img" :src="t.img" :alt="t.alt" loading="lazy" width="800" height="800" />
                <div class="pain-bubble">
                  <p class="pain-quote">{{ t.line }}</p>
                  <p class="pain-role">{{ t.role }}</p>
                </div>
              </div>
              <div class="pain-face pain-back">
                <p class="pain-note">{{ t.note }}</p>
                <img class="pain-warn" :src="warnIcon" alt="" aria-hidden="true" width="64" height="54" />
              </div>
            </div>
          </div>
        </li>
      </ul>
    </div>
  </section>
</template>

<style scoped>
.pain {
  position: relative;
  padding: clamp(36px, 5vw, 60px) 0 clamp(72px, 10vw, 120px);
  background: var(--color-surface);
}
/* 與上方 Hero 的銜接：頂部由白色漸層淡出 */
.pain::before {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 160px;
  background: linear-gradient(to bottom, var(--color-canvas), transparent);
  pointer-events: none;
}
.pain > .container-page {
  position: relative;
  z-index: 2;
}
.pain-head {
  margin-bottom: var(--section-head-gap);
}
.pain-title {
  margin: var(--section-title-gap-top) 0 var(--section-lead-gap-top);
  font-size: var(--section-title-size);
  font-weight: 600;
  line-height: 1.3;
  color: var(--color-ink);
}
.pain-grid {
  display: grid;
  gap: 24px;
  margin: 0;
  padding: 0;
  list-style: none;
}
.pain-card {
  min-width: 0;
  padding: 0;
  text-align: left;
}
/* 翻牌容器：正背面疊在同一格，卡片高度取兩面較高者，正背面一致 */
.pain-flip {
  position: relative;
  display: block;
  height: 100%;
  perspective: 1200px;
  cursor: pointer;
  border-radius: 20px;
}
.pain-flip:focus-visible {
  outline: 2px solid var(--color-primary-500);
  outline-offset: 4px;
}
.pain-flip-inner {
  display: grid;
  height: 100%;
  transform-style: preserve-3d;
  transition: transform 0.6s cubic-bezier(0.4, 0.2, 0.2, 1);
}
.pain-face {
  grid-area: 1 / 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 16px;
  background: var(--color-canvas);
  border: 1px solid var(--color-hairline);
  border-radius: 20px;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}
.pain-back {
  position: relative;
  justify-content: center;
  padding: 28px 24px;
  overflow: hidden;
  transform: rotateY(180deg);
}
.pain-img {
  display: block;
  width: 100%;
  aspect-ratio: 1 / 1;
  height: auto;
  margin-bottom: 20px;
  object-fit: contain;
  border-radius: 14px;
  background: var(--color-canvas);
}
/* 對話框：文字靠左上，角色名稱靠右下 */
.pain-bubble {
  position: relative;
  flex: 1;
  margin: 12px 0 0;
  padding: 20px 20px 44px;
  background: var(--color-primary-50);
  border-radius: 4px 18px 18px 18px;
}
.pain-quote {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  line-height: 1.6;
  color: var(--color-ink);
  text-align: left;
  text-wrap: pretty;
}
.pain-role {
  position: absolute;
  right: 16px;
  bottom: 12px;
  margin: 0;
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 0.04em;
  color: var(--color-primary-700);
  text-align: right;
}
/* 背面：大字呈現角色的真實痛點 */
.pain-note {
  position: relative;
  z-index: 2;
  align-self: stretch;
  width: 100%;
  margin: 0;
  font-size: clamp(22px, 2.2vw, 26px);
  font-weight: 600;
  line-height: 1.45;
  color: var(--color-ink);
  text-align: left;
  text-wrap: pretty;
}
/* 淡色警示圖示：超出卡片右下角的部分由卡片裁切 */
.pain-warn {
  position: absolute;
  right: -36px;
  bottom: -30px;
  z-index: 0;
  width: 200px;
  height: auto;
  opacity: 0.5;
  pointer-events: none;
}
/* 滑鼠移入即翻面（有滑鼠的裝置） */
@media (hover: hover) and (pointer: fine) {
  .pain-card:hover .pain-flip-inner {
    transform: rotateY(180deg);
  }
}
/* 觸控裝置：點一下翻面 */
@media (hover: none) {
  .pain-flip.is-flipped .pain-flip-inner {
    transform: rotateY(180deg);
  }
}
/* 鍵盤焦點時翻面 */
.pain-flip:focus-visible .pain-flip-inner {
  transform: rotateY(180deg);
}
@media (prefers-reduced-motion: reduce) {
  .pain-flip-inner {
    transition: none;
  }
}

@media (min-width: 900px) {
  .pain-title {
    white-space: nowrap;
  }
}
@media (min-width: 640px) {
  .pain-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
@media (min-width: 1100px) {
  .pain-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 20px;
  }
  .pain-quote {
    font-size: 18px;
  }
}
</style>
