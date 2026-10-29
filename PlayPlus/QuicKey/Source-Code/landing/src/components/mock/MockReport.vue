<script setup lang="ts">
import { computed, ref } from 'vue'
import MockCursor from './MockCursor.vue'
import { useDemoScript, type DemoStep } from './useDemoScript'
import './mock.css'

// 報表自動整理示意：切換月份即自動彙整，按下匯出（沿用後台分段控制與按鈕）
type Period = 'cur' | 'prev'

const data: Record<Period, { label: string; income: number; expense: number; pending: number }> = {
  cur: { label: '2026 年 10 月', income: 86000, expense: 48200, pending: 3600 },
  prev: { label: '2026 年 9 月', income: 72400, expense: 51300, pending: 2100 },
}

const period = ref<Period>('cur')
const exported = ref(false)
const root = ref<HTMLElement | null>(null)

const current = computed(() => data[period.value])
const fmt = (n: number) => n.toLocaleString('en-US')

function exportReport() {
  if (!exported.value) exported.value = true
}
function reset() {
  period.value = 'cur'
  exported.value = false
}

const steps: DemoStep[] = [
  { target: 'prev', run: () => (period.value = 'prev'), wait: 1400 },
  { target: 'cur', run: () => (period.value = 'cur'), wait: 1200 },
  { target: 'export', run: exportReport, wait: 1600 },
]

const { cursor } = useDemoScript({ root, steps, reset })
</script>

<template>
  <div ref="root" class="mk-card" role="group" aria-label="自動彙整報表示意">
    <div class="mk-head">
      <div>
        <p class="mk-title">月報彙整</p>
        <p class="mk-sub">{{ current.label }}・依收支紀錄自動計算</p>
      </div>
      <div class="mk-seg" role="group" aria-label="月份切換">
        <button
          type="button"
          data-demo="cur"
          :class="{ 'is-on': period === 'cur' }"
          :aria-pressed="period === 'cur'"
          @click="period = 'cur'"
        >
          本月
        </button>
        <button
          type="button"
          data-demo="prev"
          :class="{ 'is-on': period === 'prev' }"
          :aria-pressed="period === 'prev'"
          @click="period = 'prev'"
        >
          上月
        </button>
      </div>
    </div>

    <ul :key="period" class="mk-sum">
      <li>
        <span class="mk-dot" style="background: #00b39f" aria-hidden="true" />
        <span class="mk-name">收入合計</span>
        <b class="is-pos">+{{ fmt(current.income) }}</b>
      </li>
      <li>
        <span class="mk-dot" style="background: #9ee6dc" aria-hidden="true" />
        <span class="mk-name">支出合計</span>
        <b>-{{ fmt(current.expense) }}</b>
      </li>
      <li>
        <span class="mk-dot" style="background: #d97706" aria-hidden="true" />
        <span class="mk-name">待撥款</span>
        <b>-{{ fmt(current.pending) }}</b>
      </li>
    </ul>

    <div style="margin-top: 16px; display: flex; justify-content: space-between; align-items: center; gap: 12px">
      <span v-if="exported" class="mk-toast">已匯出 {{ current.label }}</span>
      <span v-else />
      <button type="button" class="mk-btn" data-demo="export" :disabled="exported" @click="exportReport">
        匯出報表
      </button>
    </div>

    <MockCursor :cursor="cursor" />
  </div>
</template>
