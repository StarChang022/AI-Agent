<script setup lang="ts">
// 手風琴 FAQ：與常見問題頁相同的展開／收合動畫，尊重 prefers-reduced-motion
const props = defineProps<{ items: { q: string; a: string }[] }>()

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

  const startHeight = details.getBoundingClientRect().height
  animations.get(details)?.cancel()

  if (opening) details.open = true
  const endHeight = opening ? details.getBoundingClientRect().height : summary.getBoundingClientRect().height

  details.style.overflow = 'hidden'
  const anim = details.animate({ height: [`${startHeight}px`, `${endHeight}px`] }, { duration: DURATION, easing: EASING })
  animations.set(details, anim)
  anim.onfinish = () => {
    if (!opening) details.open = false
    details.style.overflow = ''
    animations.delete(details)
  }
}
</script>

<template>
  <div class="faq-list">
    <details v-for="item in props.items" :key="item.q" class="faq-item">
      <summary @click="onSummaryClick">
        <span class="faq-q">{{ item.q }}</span>
      </summary>
      <p class="faq-a">{{ item.a }}</p>
    </details>
  </div>
</template>
