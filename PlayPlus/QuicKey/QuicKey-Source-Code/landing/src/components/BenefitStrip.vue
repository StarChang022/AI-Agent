<script setup lang="ts">
import LottieDeco from './LottieDeco.vue'
import homeAnimation from '../assets/lottie/home-05.json'
import homeIcon from '../assets/home/home-icon.svg'
</script>

<template>
  <section class="benefit">
    <div class="container-page benefit-inner">
      <!-- 左側圖片區塊（白底） -->
      <div class="benefit-visual" v-reveal="{ type: 'image' }">
        <LottieDeco :animation-data="homeAnimation" />
      </div>

      <div class="benefit-main">
        <header class="benefit-head" v-reveal="'up'">
          <p class="eyebrow">為什麼用 QUICKEY</p>
          <h2 class="benefit-heading">不只是記帳，更讓管理事半功倍。</h2>
        </header>

        <ol class="benefit-list">
          <li class="benefit-item" v-reveal="{ type: 'up', delay: 0 }">
            <h3 class="benefit-title">
              <img :src="homeIcon" alt="" aria-hidden="true" class="benefit-icon" width="28" height="28" />
              省下整理時間
            </h3>
            <p>減少重複輸入與手動彙整，把時間留給更重要的事。</p>
          </li>
          <li class="benefit-item" v-reveal="{ type: 'up', delay: 100 }">
            <h3 class="benefit-title">
              <img :src="homeIcon" alt="" aria-hidden="true" class="benefit-icon" width="28" height="28" />
              讓協作更順暢
            </h3>
            <p>收支與請款資訊集中管理，減少反覆確認與溝通。</p>
          </li>
          <li class="benefit-item" v-reveal="{ type: 'up', delay: 200 }">
            <h3 class="benefit-title">
              <img :src="homeIcon" alt="" aria-hidden="true" class="benefit-icon" width="28" height="28" />
              讓決策更有依據
            </h3>
            <p>掌握預算與財務概況，不必等到月底才發現問題。</p>
          </li>
        </ol>
      </div>
    </div>
  </section>
</template>

<style scoped>
.benefit {
  padding: clamp(72px, 10vw, 120px) 0 36px;
  background: var(--color-canvas);
}
@media (min-width: 768px) {
  .benefit {
    padding-bottom: 32px;
  }
}
.benefit-inner {
  display: grid;
  gap: 48px;
  align-items: center;
}
.benefit-visual {
  display: grid;
  place-items: center;
  min-width: 0;
  padding: 32px;
  /* 背景透明，陰影沿著插圖的線條輪廓產生 */
  filter: drop-shadow(0 14px 22px rgba(26, 31, 41, 0.14));
}
.benefit-heading {
  margin: var(--section-title-gap-top) 0 0;
  font-size: var(--section-title-size);
  font-weight: 600;
  line-height: 1.3;
  color: var(--color-ink);
}
.benefit-list {
  display: grid;
  gap: 32px;
  margin: clamp(32px, 4vw, 48px) 0 0;
  padding: 0;
  list-style: none;
}
.benefit-item {
  min-width: 0;
  padding-top: 0;
}
.benefit-title {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 0 0 12px;
  font-size: 22px;
  font-weight: 600;
  color: var(--color-ink);
}
.benefit-icon {
  flex: none;
  width: 28px;
  height: 28px;
}
.benefit-item p {
  font-size: 16px;
  line-height: 1.8;
  color: var(--color-muted);
}
@media (min-width: 640px) {
  /* 標題不換行 */
  .benefit-heading {
    white-space: nowrap;
  }
}
@media (min-width: 900px) {
  .benefit-inner {
    grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr);
    gap: 72px;
  }
}
</style>
