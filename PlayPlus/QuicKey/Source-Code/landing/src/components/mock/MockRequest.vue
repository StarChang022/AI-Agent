<script setup lang="ts">
import { computed, ref } from 'vue'
import MockCursor from './MockCursor.vue'
import { useDemoScript, type DemoStep } from './useDemoScript'
import './mock.css'

// 請款進度示意：草稿 → 簽核中 → 已核銷 → 已發放（沿用後台請款狀態與操作按鈕）
const flow = [
  { key: 'draft', label: '草稿' },
  { key: 'in_review', label: '簽核中' },
  { key: 'approved', label: '已核銷' },
  { key: 'paid', label: '已發放' },
] as const

const current = ref(0)
const root = ref<HTMLElement | null>(null)

const status = computed(() => flow[current.value])
const nextLabel = computed(() => ['送出簽核', '核銷', '撥款', '已發放'][current.value])

function next() {
  if (current.value < flow.length - 1) current.value++
}
function reset() {
  current.value = 0
}

const steps: DemoStep[] = [
  { target: 'next', run: next, wait: 1300 },
  { target: 'next', run: next, wait: 1300 },
  { target: 'next', run: next, wait: 1300 },
]

const { cursor } = useDemoScript({ root, steps, reset })
</script>

<template>
  <div ref="root" class="mk-card" role="group" aria-label="請款進度示意">
    <div class="mk-head">
      <div>
        <p class="mk-title">請款單 #R-0148</p>
        <p class="mk-sub">王小明 · 交通費 · NT$ 1,240</p>
      </div>
      <span class="mk-chip" :class="`mk-chip--${status.key}`">{{ status.label }}</span>
    </div>

    <ol class="mk-steps" aria-label="處理進度">
      <li
        v-for="(s, i) in flow"
        :key="s.key"
        :class="{ 'is-done': i <= current, 'is-current': i === current }"
      >
        <span class="mk-dot" aria-hidden="true" />
        {{ s.label }}
      </li>
    </ol>

    <div style="margin-top: 16px; display: flex; justify-content: flex-end">
      <button
        type="button"
        class="mk-btn"
        data-demo="next"
        :disabled="current >= flow.length - 1"
        @click="next"
      >
        {{ nextLabel }}
      </button>
    </div>

    <MockCursor :cursor="cursor" />
  </div>
</template>
