<script setup lang="ts">
import { computed, ref } from 'vue'
import MockCursor from './MockCursor.vue'
import { useDemoScript, type DemoStep } from './useDemoScript'
import './mock.css'

// 預算執行示意：進度條進場後增長，可切換本月 / 本季（沿用後台預算頁的進度條與分段控制）
type Period = 'month' | 'quarter'

const data: Record<Period, { name: string; used: number; total: number }[]> = {
  month: [
    { name: '交通費', used: 6200, total: 10000 },
    { name: '餐費', used: 4100, total: 10000 },
    { name: '辦公用品', used: 4700, total: 5000 },
  ],
  quarter: [
    { name: '交通費', used: 18600, total: 30000 },
    { name: '餐費', used: 12300, total: 30000 },
    { name: '辦公用品', used: 13100, total: 15000 },
  ],
}

const period = ref<Period>('month')
const root = ref<HTMLElement | null>(null)

const items = computed(() =>
  data[period.value].map((i) => ({ ...i, pct: Math.round((i.used / i.total) * 100) })),
)
const fmt = (n: number) => n.toLocaleString('en-US')

function reset() {
  period.value = 'month'
}

const steps: DemoStep[] = [
  { target: 'quarter', run: () => (period.value = 'quarter'), wait: 1600 },
  { target: 'month', run: () => (period.value = 'month'), wait: 1000 },
]

const { cursor, inView } = useDemoScript({ root, steps, reset })
</script>

<template>
  <div ref="root" class="mk-card" role="group" aria-label="預算執行示意">
    <div class="mk-head">
      <div>
        <p class="mk-title">預算執行</p>
        <p class="mk-sub">{{ period === 'month' ? '2026 年 10 月' : '2026 年 第 4 季' }}</p>
      </div>
      <div class="mk-seg" role="group" aria-label="期間切換">
        <button
          type="button"
          data-demo="month"
          :class="{ 'is-on': period === 'month' }"
          :aria-pressed="period === 'month'"
          @click="period = 'month'"
        >
          本月
        </button>
        <button
          type="button"
          data-demo="quarter"
          :class="{ 'is-on': period === 'quarter' }"
          :aria-pressed="period === 'quarter'"
          @click="period = 'quarter'"
        >
          本季
        </button>
      </div>
    </div>

    <div v-for="item in items" :key="item.name" class="mk-budget">
      <div class="mk-budget-top">
        <span>{{ item.name }}</span>
        <b>{{ item.pct }}%</b>
      </div>
      <div class="mk-bar" :class="{ 'is-warn': item.pct >= 90 }">
        <span class="mk-bar-fill" :style="{ width: inView ? `${item.pct}%` : '0%' }" />
      </div>
      <p class="mk-amt">NT$ {{ fmt(item.used) }} / {{ fmt(item.total) }}</p>
    </div>

    <MockCursor :cursor="cursor" />
  </div>
</template>
