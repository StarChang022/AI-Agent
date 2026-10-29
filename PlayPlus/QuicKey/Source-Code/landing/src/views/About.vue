<script setup lang="ts">
import { staggerDelay } from '../motion/reveal'
import CtaBand from '../components/CtaBand.vue'
import LottieDeco from '../components/LottieDeco.vue'
import heroAnimation from '../assets/lottie/about-01.json'
import practiceAnimation from '../assets/lottie/about-02.json'

// 三大核心理念：每一項使用相同的結構
const principles = [
  {
    title: '清楚透明',
    sub: '每一筆收支，都有跡可循。',
    body: '集中管理收入、支出與請款資訊，讓財務流向更清晰，也讓團隊之間的資訊更透明。',
  },
  {
    title: '簡單直覺',
    sub: '不必熟悉繁瑣流程，也能輕鬆上手。',
    body: '從日常記帳到收據辨識，以直覺的操作流程降低使用門檻，讓財務管理不再複雜。',
  },
  {
    title: '省時高效',
    sub: '少一點重複整理，多一點時間做重要的事。',
    body: '運用 AI 辨識、自動化報表與整合管理，減少日常帳務工作的負擔。',
  },
]
</script>

<template>
  <main>
    <!-- Section 01｜品牌主張 -->
    <section class="about-hero">
      <div class="container-page">
        <div class="about-hero-grid">
          <div>
            <p class="eyebrow" v-reveal="'up'">關於我們</p>
            <h1 class="about-title" v-reveal="{ type: 'up', delay: 80 }">
              讓每一筆收支<em class="hl">更清楚</em>，<br />
              讓每一天的管理<em class="hl">更輕鬆</em>。
            </h1>
            <div class="about-intro" v-reveal="{ type: 'soft', delay: 160 }">
              <p>我們相信，財務管理不該是一件複雜的事。</p>
              <p>
                不論是一人公司、小型企業，還是需要多人協作的團隊，每一筆收入與支出，都值得被簡單記錄、清楚掌握。
              </p>
              <p>QUICKEY 快記，讓繁瑣的帳務工作變得更直覺，幫助你把時間留給更重要的事。</p>
            </div>
          </div>
          <LottieDeco class="about-hero-deco" :animation-data="heroAnimation" v-reveal="{ type: 'soft', delay: 200 }" />
        </div>
      </div>
    </section>

    <!-- Section 02｜品牌起點 -->
    <section class="section-alt about-origin">
      <div class="container-page about-origin-grid">
        <h2 class="about-h2" v-reveal="'up'">管好公司的錢，不該花掉這麼多時間。</h2>
        <div class="about-origin-body" v-reveal="'soft'">
          <p>收據散落各處、收支紀錄分散在不同的 Excel、請款進度需要反覆詢問，月底還得花時間整理報表。</p>
          <p>對許多企業與工作室來說，困難的不是記錄一筆帳，而是如何持續整理、追蹤與掌握每一筆帳。</p>
          <p>我們希望透過更簡單的操作方式與智慧化工具，減少重複輸入、人工核對與資訊整理的負擔，讓日常財務管理不再令人頭痛。</p>
          <p class="about-origin-key">這正是 QUICKEY 想解決的問題。</p>
        </div>
      </div>
    </section>

    <!-- Section 03｜三大核心理念 -->
    <section class="section about-principles-section">
      <div class="container-page">
        <header class="about-head" v-reveal="'up'">
          <p class="eyebrow">我們的理念</p>
          <h2 class="about-h2">我們相信，好的管理工具應該做到三件事。</h2>
        </header>

        <div class="about-principles">
          <article v-for="(p, i) in principles" :key="p.title" class="principle" v-reveal="{ type: 'up', delay: staggerDelay(i) }">
            <h3 class="p-title">{{ p.title }}</h3>
            <p class="p-sub">{{ p.sub }}</p>
            <p class="p-body">{{ p.body }}</p>
          </article>
        </div>
      </div>
    </section>

    <!-- Section 04｜產品理念的實踐 -->
    <section class="about-practice">
      <div class="container-page">
        <div class="about-practice-card">
        <div class="about-practice-grid">
          <div class="about-practice-main">
          <h2 class="about-h2 is-light" v-reveal="'up'">讓科技替你省力，讓管理回歸簡單。</h2>
          <div class="about-practice-body" v-reveal="'soft'">
            <p>QUICKEY 不只是記帳工具，更希望成為企業日常收支管理的好幫手。</p>
            <p>
              從 AI 收據辨識、收支紀錄、請款追蹤，到預算控管與報表分析，將原本分散的工作整合在同一個平台。
            </p>
            <p>讓行政人員減少整理時間、讓員工更容易追蹤請款，也讓經營者能更清楚掌握財務狀況。</p>
          </div>
          </div>
          <div class="practice-stage">
            <LottieDeco class="practice-art" :animation-data="practiceAnimation" />
            <p class="practice-statement" v-reveal="{ type: 'soft', delay: 120 }">記帳可以很簡單，<br />管理也可以很有效率。</p>
          </div>
        </div>
        </div>
      </div>
    </section>

    <!-- Section 05｜結尾 CTA -->
    <CtaBand />
  </main>
</template>

<style scoped>
/* 首屏：文案在左，裝飾動畫在右（手機版動畫置於文案下方） */
.about-hero-grid {
  display: grid;
  gap: 40px;
  align-items: center;
}
@media (min-width: 960px) {
  .about-hero-grid {
    grid-template-columns: minmax(0, 1fr) minmax(0, 380px);
    gap: 56px;
  }
}

/* 理念標題：桌機版不斷行 */
@media (min-width: 768px) {
  .about-head .about-h2 {
    white-space: nowrap;
  }
}

/* 理念小標題：綠色 */
.p-title {
  color: var(--color-primary-700);
}

/* 產品理念實踐：白底頁面中的整張綠色卡片（與解決方案區塊同色系、同圓角） */
.about-practice {
  padding-top: 0;
  background: var(--color-canvas);
}
.about-practice-card {
  position: relative;
  overflow: hidden;
  padding: 88px 56px;
  color: var(--color-canvas);
  background: var(--color-primary-900);
  border-radius: 24px;
}
@media (max-width: 639.98px) {
  .about-practice-card {
    padding: 56px 24px;
    border-radius: 20px;
  }
}

/* 右側欄：文案與背景動畫同一區，垂直水平置中 */
.practice-stage {
  position: relative;
  isolation: isolate;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 240px;
}
.practice-art {
  position: absolute;
  inset: -48px 0;
  z-index: -1;
  max-width: none;
  pointer-events: none;
}
.practice-art :deep(svg) {
  display: block;
  width: 100%;
  height: 100%;
  overflow: visible;
}
.practice-stage .practice-statement {
  margin: 0;
  text-align: center;
}

/* 兩欄各自獨立：左欄為標題與內文，右欄為口號；兩欄以整張卡片為基準垂直置中 */
.about-practice-grid {
  display: grid;
  gap: 40px;
  align-items: center;
}
.about-practice-main .about-practice-body {
  margin-top: 24px;
}
@media (min-width: 768px) {
  .about-practice-grid {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 80px;
  }
}
</style>
