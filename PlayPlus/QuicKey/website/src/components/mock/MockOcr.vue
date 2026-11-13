<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import MockCursor from './MockCursor.vue'
import { useDemoScript, type DemoStep } from './useDemoScript'
import './mock.css'

// 收據辨識示意：上傳 → 辨識 → 欄位自動帶入（沿用後台「新增支出」的上傳區與辨識按鈕）
type Stage = 'empty' | 'attached' | 'loading' | 'done'
const stage = ref<Stage>('empty')
const root = ref<HTMLElement | null>(null)
let timers: number[] = []

function clearTimers() {
  timers.forEach((id) => window.clearTimeout(id))
  timers = []
}
function attach() {
  if (stage.value === 'empty') stage.value = 'attached'
}
function recognize() {
  if (stage.value !== 'attached') return
  stage.value = 'loading'
  timers.push(window.setTimeout(() => (stage.value = 'done'), 900))
}
function reset() {
  clearTimers()
  stage.value = 'empty'
}

const steps: DemoStep[] = [
  { target: 'upload', run: attach, wait: 700 },
  { target: 'ocr', run: recognize, wait: 1900 },
]

const { cursor } = useDemoScript({ root, steps, reset })
onBeforeUnmount(clearTimers)
</script>

<template>
  <div ref="root" class="mk-card" role="group" aria-label="收據辨識示意">
    <div class="mk-head">
      <div>
        <p class="mk-title">新增支出</p>
        <p class="mk-sub">拍照或上傳收據，自動帶入資訊</p>
      </div>
    </div>

    <button
      type="button"
      class="mk-drop"
      data-demo="upload"
      :class="{ 'is-filled': stage !== 'empty' }"
      :aria-label="stage === 'empty' ? '上傳收據' : '已選擇收據檔案'"
      @click="attach"
    >
      <span v-if="stage === 'empty'">點擊或拖曳收據至此上傳</span>
      <span v-else class="mk-file"><i class="mk-file-thumb" aria-hidden="true" />收據_1018.jpg</span>
      <span v-if="stage === 'loading'" class="mk-scan" aria-hidden="true" />
    </button>

    <div style="margin-top: 14px; display: flex; justify-content: flex-end">
      <button
        type="button"
        class="mk-btn"
        data-demo="ocr"
        :disabled="stage !== 'attached'"
        @click="recognize"
      >
        {{ stage === 'loading' ? '辨識中…' : '辨識收據' }}
      </button>
    </div>

    <dl class="mk-fields">
      <div class="mk-field">
        <dt>日期</dt>
        <dd :class="{ 'is-on': stage === 'done' }">{{ stage === 'done' ? '2026/10/18' : '—' }}</dd>
      </div>
      <div class="mk-field">
        <dt>金額</dt>
        <dd :class="{ 'is-on': stage === 'done' }">{{ stage === 'done' ? 'NT$ 128' : '—' }}</dd>
      </div>
      <div class="mk-field">
        <dt>廠商</dt>
        <dd :class="{ 'is-on': stage === 'done' }">{{ stage === 'done' ? '全家便利商店' : '—' }}</dd>
      </div>
      <div class="mk-field">
        <dt>類別</dt>
        <dd :class="{ 'is-on': stage === 'done' }">{{ stage === 'done' ? '餐費' : '—' }}</dd>
      </div>
    </dl>

    <MockCursor :cursor="cursor" />
  </div>
</template>
