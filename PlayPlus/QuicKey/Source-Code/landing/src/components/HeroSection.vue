<script setup lang="ts">
import { SIGNUP_URL } from '../config'
import ProductShot from './ProductShot.vue'
</script>

<template>
  <section class="hero">
    <div class="hero-bg" aria-hidden="true">
      <span class="blob blob-a"></span>
      <span class="blob blob-b"></span>
      <span class="blob blob-c"></span>
    </div>

    <div class="container-page hero-inner">
      <div>
        <h1 class="hero-title" v-reveal="{ type: 'up', delay: 80 }"><span class="hero-title-line">快記每一筆，</span><span class="hero-title-line">帳務更省力。</span></h1>
        <p class="lead" v-reveal="{ type: 'soft', delay: 160 }">AI 智慧辨識收據，整合收支、請款、預算與報表，讓財務管理更簡單、更有效率。</p>
        <div class="hero-actions" v-reveal="{ type: 'up', delay: 240 }">
          <a :href="SIGNUP_URL" class="btn-primary">免費試用30天</a>
        </div>
      </div>

      <div class="hero-visual">
        <ProductShot
          src="/product/expenses.webp"
          alt="QUICKEY 支出管理列表，可依付款狀態篩選並查看廠商、類別與金額"
          eager
        />
      </div>
    </div>
  </section>
</template>

<style scoped>
/* 與下方痛點區塊銜接：底部光暈淡出為白色 */
.hero::after {
  content: '';
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 160px;
  background: linear-gradient(to bottom, transparent, var(--color-canvas));
  pointer-events: none;
}
.hero-inner {
  z-index: 2;
}
.hero-visual {
  min-width: 0;
}
@media (min-width: 900px) {
  .hero-inner {
    grid-template-columns: minmax(0, 0.8fr) minmax(0, 1.4fr);
    gap: 56px;
  }
}
/* 試用說明：置於按鈕下方、保持距離，使用淡色膠囊標籤 */
.hero-actions {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0;
}
.hero-trial {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  width: auto;
  margin: 16px 0 0;
  padding: 6px 14px;
  font-size: 14px;
  line-height: 1.4;
  color: var(--color-primary-700);
  background: var(--color-primary-50);
  border: 1px solid var(--color-primary-100);
  border-radius: 10000px;
}
.hero-trial::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-primary-500);
}
/* 標題不強制換行，字級縮小，由瀏覽器自然斷行 */
.hero-title {
  font-size: clamp(34px, 5.6vw, 64px);
  line-height: 1.22;
}
/* 兩句各自獨立成行 */
.hero-title-line {
  display: block;
}
</style>
