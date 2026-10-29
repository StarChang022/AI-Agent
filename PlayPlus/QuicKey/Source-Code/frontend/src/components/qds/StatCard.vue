<script setup lang="ts">
/** KPI 卡（stat-card）：白底＋彩色圖示/標籤/數字＋說明列＋實際數據 sparkline。見 design-system/design-stat-chart.html */
import { computed } from 'vue'
import type { RouteLocationRaw } from 'vue-router'

const props = defineProps<{
  tone: 'primary' | 'warning' | 'info' | 'danger'
  icon: string
  label: string
  value: string
  desc?: string
  meta?: string
  alertTag?: string
  sparkline?: number[]
  to?: RouteLocationRaw
}>()

const viewBox = { w: 200, h: 64, padX: 0, padY: 8, baseline: 64, tail: 12 }
const fallback = [0, 0, 0, 0, 0, 0, 0]

const points = computed(() => {
  const values = props.sparkline?.length ? props.sparkline : fallback
  const min = Math.min(...values)
  const max = Math.max(...values)
  const span = max - min || 1
  const drawableW = viewBox.w - viewBox.padX * 2 - viewBox.tail
  const drawableH = viewBox.baseline - viewBox.padY * 2
  const step = values.length > 1 ? drawableW / (values.length - 1) : drawableW
  return values.map((v, i) => {
    const x = viewBox.padX + i * step
    const y = viewBox.baseline - viewBox.padY - ((v - min) / span) * drawableH
    return { x, y }
  })
})

const tailPoint = computed(() => {
  const last = points.value[points.value.length - 1]
  return { x: viewBox.w, y: Math.min(viewBox.baseline - 2, last.y + 8) }
})
const linePath = computed(() => {
  const [first, ...rest] = points.value
  const tail = tailPoint.value
  return `M ${first.x} ${first.y} ${rest.map((p) => `L ${p.x} ${p.y}`).join(' ')} L ${tail.x} ${tail.y}`
})
const areaPath = computed(() => {
  const first = points.value[0]
  const rest = points.value.slice(1)
  const tail = tailPoint.value
  return `M 0 ${viewBox.baseline} L ${first.x} ${first.y} ${rest.map((p) => `L ${p.x} ${p.y}`).join(' ')} L ${tail.x} ${tail.y} L ${viewBox.w} ${viewBox.baseline} Z`
})
const gradId = computed(() => `stat-grad-${props.tone}`)
</script>

<template>
  <component :is="to ? 'RouterLink' : 'div'" :to="to" class="stat-card" :class="`stat-${tone}`" :aria-label="to ? `${label}：${value}，前往查看` : undefined">
    <span v-if="alertTag" class="stat-alert-tag">{{ alertTag }}</span>
    <div class="stat-top"><i :class="['pi', icon, 'stat-icon']" aria-hidden="true" /></div>
    <div class="stat-label">{{ label }}</div>
    <div class="stat-value">{{ value }}</div>
    <div class="stat-desc">
      <span class="stat-desc-main">{{ desc }}</span>
      <span>{{ meta }}</span>
    </div>
    <svg class="stat-wave" viewBox="0 0 200 64" preserveAspectRatio="none" aria-hidden="true">
      <defs>
        <linearGradient :id="gradId" x1="0" x2="1" y1="0" y2="0">
          <stop offset="0%" stop-color="currentColor" stop-opacity=".08" />
          <stop offset="100%" stop-color="currentColor" stop-opacity=".42" />
        </linearGradient>
      </defs>
      <path class="stat-area" :d="areaPath" :fill="`url(#${gradId})`" />
      <path class="stat-line" :d="linePath" />
    </svg>
  </component>
</template>
