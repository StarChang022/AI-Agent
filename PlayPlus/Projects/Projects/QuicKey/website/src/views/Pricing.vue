<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { staggerDelay } from '../motion/reveal'
import { RouterLink } from 'vue-router'
import { SIGNUP_URL } from '../config'
import { plans, sharedFeatures, subscriptionNotes } from '../data/pricing'

// 手機版方案卡片水平捲動：左右箭頭依捲動位置切換可用狀態
const grid = ref<HTMLElement | null>(null)
const canPrev = ref(false)
const canNext = ref(true)
function updateNav() {
  const el = grid.value
  if (!el) return
  canPrev.value = el.scrollLeft > 4
  canNext.value = el.scrollLeft + el.clientWidth < el.scrollWidth - 4
}
function scrollPlans(dir: 1 | -1) {
  const el = grid.value
  if (!el) return
  const card = el.querySelector<HTMLElement>('.plan-item')
  const step = card ? card.offsetWidth + 16 : el.clientWidth
  el.scrollBy({ left: dir * step, behavior: 'smooth' })
}
onMounted(() => {
  updateNav()
  window.addEventListener('resize', updateNav)
})
onBeforeUnmount(() => {
  window.removeEventListener('resize', updateNav)
})

function priceParts(price: number | null) {
  return price === null ? { amount: '客製方案', unit: '' } : { amount: `NT$ ${price.toLocaleString('en-US')}`, unit: '/ 月' }
}
</script>

<template>
  <div class="pricing-page">
    <section class="pricing-hero">
      <div class="container-page">
        <h1 class="pricing-title" v-reveal="'up'">找到適合你的管理方案</h1>
        <p class="pricing-lead" v-reveal="{ type: 'soft', delay: 100 }">從個人工作室到企業團隊，依照實際需求選擇適合的方案，讓每一筆收支都能輕鬆管理。</p>
      </div>
    </section>

    <section class="section plans-section" aria-label="方案內容">
      <div class="container-page">
        <div class="plans-carousel">
        <button
          type="button"
          class="plan-nav plan-nav-prev"
          aria-label="查看上一個方案"
          :disabled="!canPrev"
          @click="scrollPlans(-1)"
        >
          <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path d="M15 6l-6 6 6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /></svg>
        </button>
        <ul ref="grid" class="plan-grid" @scroll.passive="updateNav">
          <li v-for="(plan, i) in plans" :key="plan.id" class="plan-item" v-reveal="{ type: 'up', delay: staggerDelay(i) }">
            <article :class="['plan-card', { 'is-recommended': plan.recommended }]">
              <header class="plan-head">
                <h2 class="plan-name">{{ plan.name }}</h2>
                <span v-if="plan.recommended" class="plan-tag">推薦方案</span>
              </header>
              <p class="plan-audience">{{ plan.audience }}</p>

              <p class="plan-price">
                <span class="plan-amount">{{ priceParts(plan.price).amount }}</span>
                <span v-if="priceParts(plan.price).unit" class="plan-unit">{{ priceParts(plan.price).unit }}</span>
              </p>

              <div class="plan-cta">
                <a v-if="plan.cta.kind === 'trial'" :href="SIGNUP_URL" :class="[plan.cta.variant === 'ghost' ? 'btn-ghost' : 'btn-primary', 'plan-btn']">{{ plan.cta.label }}</a>
                <RouterLink v-else :to="plan.cta.to" class="btn-ghost plan-btn">{{ plan.cta.label }}</RouterLink>
                <p v-if="plan.cta.kind === 'contact'" class="plan-note">人數、辨識次數與儲存空間可依需求客製</p>
              </div>

              <div class="plan-body">
                <p class="plan-body-title">方案內容</p>
                <ul class="feature-list">
                  <li><span class="tick" aria-hidden="true">✓</span>員工人數 <strong>{{ plan.seats }}</strong></li>
                  <li><span class="tick" aria-hidden="true">✓</span>每月辨識次數 <strong>{{ plan.recognitions }}</strong></li>
                  <li><span class="tick" aria-hidden="true">✓</span>儲存空間 <strong>{{ plan.storage }}</strong></li>
                  <li v-for="f in sharedFeatures" :key="f"><span class="tick" aria-hidden="true">✓</span>{{ f }}</li>
                </ul>
              </div>
            </article>
          </li>
        </ul>
        <button
          type="button"
          class="plan-nav plan-nav-next"
          aria-label="查看下一個方案"
          :disabled="!canNext"
          @click="scrollPlans(1)"
        >
          <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false"><path d="M9 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /></svg>
        </button>
        </div>
      </div>
    </section>

    <section class="section notes-section" aria-labelledby="notes-title">
      <div class="container-page notes-grid" v-reveal="'soft'">
        <h2 id="notes-title" class="notes-title">訂閱與免費試用說明</h2>
        <ol class="notes-list">
          <li v-for="note in subscriptionNotes" :key="note.text">{{ note.text }}</li>
          <li><RouterLink to="/terms">其餘條款細節，請參閱服務條款</RouterLink></li>
        </ol>
      </div>
    </section>
  </div>
</template>

<style scoped>
.pricing-hero {
  padding-top: 56px;
}
@media (min-width: 768px) {
  .pricing-hero {
    padding-top: 72px;
  }
}
.pricing-title {
  font-size: var(--section-title-size);
  font-weight: 600;
  line-height: 1.3;
  color: var(--color-ink);
  text-align: center;
}
.pricing-lead {
  margin: var(--section-lead-gap-top) auto 0;
  max-width: 600px;
  font-size: var(--section-lead-size);
  line-height: 1.85;
  color: var(--color-slate);
  text-align: center;
}

.plans-section {
  padding-top: 40px;
}
.plan-grid {
  display: grid;
  gap: 20px;
  list-style: none;
  margin: 0;
  padding: 0;
}
/* 手機：水平捲動 + 吸附，左右箭頭置於卡片區兩側垂直置中 */
.plans-carousel {
  position: relative;
}
.plan-nav {
  display: none;
}
@media (max-width: 767.98px) {
  .plans-carousel {
    margin-inline: -16px;
  }
  .plan-grid {
    display: flex;
    gap: 16px;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    scroll-padding-inline: 16px;
    padding: 8px 16px 20px;
    scrollbar-width: none;
    overscroll-behavior-x: contain;
  }
  .plan-grid::-webkit-scrollbar {
    display: none;
  }
  .plan-item {
    flex: 0 0 min(82%, 340px);
    scroll-snap-align: start;
  }
  .plan-nav {
    position: absolute;
    top: 50%;
    z-index: 2;
    display: grid;
    place-items: center;
    width: 40px;
    height: 40px;
    transform: translateY(-50%);
    border: 1px solid var(--color-hairline-strong);
    border-radius: 50%;
    background: var(--color-canvas);
    color: var(--color-ink);
    box-shadow: var(--shadow-card);
    cursor: pointer;
  }
  .plan-nav:disabled {
    opacity: 0.35;
    cursor: default;
  }
  .plan-nav-prev {
    left: 8px;
  }
  .plan-nav-next {
    right: 8px;
  }
}
@media (min-width: 960px) {
  .plan-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 24px;
    align-items: stretch;
  }
}
.plan-item {
  display: flex;
}
.plan-card {
  display: flex;
  flex: 1;
  flex-direction: column;
  padding: 28px 24px;
  background: var(--color-canvas);
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-card-lg);
}
/* 推薦方案：較明亮的綠色邊框 + 柔和光暈，避免畫面死板 */
.plan-card.is-recommended {
  border: 1.5px solid var(--color-primary-300);
  padding: 27.5px 23.5px;
  box-shadow: 0 0 24px color-mix(in srgb, var(--color-primary-300) 45%, transparent);
}
.plan-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  min-height: 28px;
}
.plan-name {
  font-size: 20px;
  font-weight: 600;
  line-height: 1.35;
  color: var(--color-ink);
}
.plan-tag {
  padding: 4px 10px;
  font-size: 12px;
  font-weight: 600;
  color: var(--color-canvas);
  background: var(--color-primary-700);
  border-radius: 10000px;
}
.plan-audience {
  margin-top: 8px;
  font-size: 14px;
  line-height: 1.7;
  color: var(--color-slate);
  min-height: 3.4em;
}
.plan-price {
  display: flex;
  align-items: baseline;
  gap: 6px;
  margin-top: 16px;
}
.plan-amount {
  font-size: 32px;
  font-weight: 600;
  line-height: 1.2;
  color: var(--color-ink);
}
.plan-unit {
  font-size: 14px;
  color: var(--color-muted);
}
.plan-cta {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 20px;
}
.plan-btn {
  width: 100%;
}
.plan-note {
  font-size: 14px;
  text-align: center;
  color: var(--color-muted);
}

.plan-body {
  margin-top: 28px;
  padding-top: 24px;
  border-top: 1px solid var(--color-hairline);
}
.plan-body-title {
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: var(--color-muted);
}
.feature-list {
  display: grid;
  gap: 12px;
  margin-top: 16px;
  list-style: none;
  padding: 0;
  font-size: 14px;
  line-height: 1.6;
  color: var(--color-slate);
}
.feature-list strong {
  font-weight: 600;
  color: var(--color-ink);
}
.feature-list li {
  display: flex;
  gap: 10px;
}
.tick {
  flex: none;
  font-weight: 600;
  color: var(--color-primary-700);
}

.notes-section {
  padding-top: 72px;
  padding-bottom: 96px;
}
.notes-grid {
  display: grid;
  gap: 32px;
}
@media (min-width: 900px) {
  .notes-grid {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1.6fr);
    gap: 64px;
    align-items: start;
  }
}
.notes-title {
  font-size: var(--section-title-size);
  font-weight: 600;
  line-height: 1.35;
  color: var(--color-ink);
}
.notes-list {
  display: grid;
  gap: 24px;
  margin: 0;
  padding: 0;
  list-style: none;
  counter-reset: none;
}
.notes-list li {
  position: relative;
  padding-left: 20px;
  font-size: 16px;
  line-height: 1.8;
  color: var(--color-slate);
}
/* 綠色直線高度 = 一行文字高度 */
.notes-list li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.4em;
  height: 1em;
  width: 4px;
  border-radius: 10000px;
  background: var(--color-primary-500);
}
.notes-list a {
  color: var(--color-primary-700);
  font-weight: 600;
  text-decoration: underline;
  text-underline-offset: 4px;
}
@media (min-width: 768px) {
  .notes-list li {
    font-size: 18px;
  }
}
</style>
