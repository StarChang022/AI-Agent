<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { faqItems, faqCategories } from '../data/faq'

const query = ref('')
const active = ref<string>('全部')
const categories = ['全部', ...faqCategories]

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  return faqItems.filter((i) => {
    const inCategory = active.value === '全部' || i.category === active.value
    const inText = !q || `${i.q}${i.a}`.toLowerCase().includes(q)
    return inCategory && inText
  })
})

// 膠囊 Tab 的選中底色滑動到新選項（同設計系統 TabBar segmented）
const tabsEl = ref<HTMLElement | null>(null)
const indicator = ref({ left: 0, width: 0 })

function measure() {
  const el = tabsEl.value?.querySelector<HTMLElement>('.faq-tab[aria-pressed="true"]')
  if (el) indicator.value = { left: el.offsetLeft, width: el.offsetWidth }
}

watch(active, () => nextTick(measure))
onMounted(() => {
  measure()
  window.addEventListener('resize', measure)
})
onUnmounted(() => window.removeEventListener('resize', measure))

// 手風琴展開／收合：高度滑動，尊重 prefers-reduced-motion
const DURATION = 250
const EASING = 'cubic-bezier(.4, 0, .2, 1)'
const animations = new WeakMap<HTMLDetailsElement, Animation>()

function onSummaryClick(e: MouseEvent) {
  e.preventDefault()
  const details = (e.currentTarget as HTMLElement).parentElement as HTMLDetailsElement
  toggleDetails(details)
}

function toggleDetails(details: HTMLDetailsElement) {
  const summary = details.querySelector('summary') as HTMLElement
  const opening = !details.open

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    details.open = opening
    return
  }

  // 先量測目前的實際高度（動畫中途點擊時會從當前高度反向）
  const startHeight = details.getBoundingClientRect().height
  animations.get(details)?.cancel()

  if (opening) details.open = true
  const endHeight = opening ? details.getBoundingClientRect().height : summary.getBoundingClientRect().height

  details.style.overflow = 'hidden'
  const anim = details.animate(
    { height: [`${startHeight}px`, `${endHeight}px`] },
    { duration: DURATION, easing: EASING },
  )
  animations.set(details, anim)
  anim.onfinish = () => {
    if (!opening) details.open = false
    details.style.overflow = ''
    animations.delete(details)
  }
}
</script>

<template>
  <section class="section faq-page">
    <div class="container-page faq-narrow">
      <header class="faq-head" v-reveal="'soft'">
        <h1 class="faq-page-title">常見問題</h1>
        <p class="faq-page-sub">快速找到關於 QUICKEY 的使用解答</p>
      </header>

      <div class="faq-search" v-reveal="{ type: 'soft', delay: 80 }">
        <svg class="faq-search-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <path d="M20 20l-3.5-3.5" />
        </svg>
        <label for="faq-search" class="sr-only">搜尋常見問題</label>
        <input id="faq-search" v-model="query" type="search" placeholder="搜尋問題，例如：請款、權限" autocomplete="off" />
      </div>

      <div ref="tabsEl" class="faq-tabs" v-reveal="{ type: 'soft', delay: 160 }" role="group" aria-label="問題分類">
        <span
          class="slide-seg-indicator"
          :style="{ transform: `translateX(${indicator.left}px)`, width: `${indicator.width}px` }"
          aria-hidden="true"
        />
        <button
          v-for="c in categories"
          :key="c"
          type="button"
          class="faq-tab"
          :aria-pressed="active === c"
          @click="active = c"
        >
          {{ c }}
        </button>
      </div>


      <div v-show="filtered.length > 0" class="faq-list" v-reveal="'soft'">
        <details v-for="item in filtered" :key="item.q" class="faq-item">
          <summary @click="onSummaryClick">
            <span class="faq-q">{{ item.q }}</span>
          </summary>
          <p class="faq-a">{{ item.a }}</p>
        </details>
      </div>
      <p v-show="!filtered.length" class="empty-state">
        找不到相關問題，可以試試其他關鍵字，或到<RouterLink to="/contact">聯絡我們</RouterLink>留言。
      </p>

      <p class="faq-more">還有其他問題？<RouterLink to="/contact">聯絡我們</RouterLink></p>
    </div>
  </section>
</template>

<style scoped>
/* 底部「聯絡我們」維持一般文字連結，不使用區塊樣式 */
.faq-more a {
  display: inline;
  padding: 0;
  background: none;
  border: 0;
  border-radius: 0;
  box-shadow: none;
  font-weight: 600;
  color: var(--color-primary-700);
  text-decoration: underline;
  text-underline-offset: 4px;
}
</style>
