<script setup lang="ts">
/** 金額區間篩選：NT$ 下限 – 上限（小尺寸） */
import { ref, watch } from 'vue'

const min = defineModel<number | null>('min', { default: null })
const max = defineModel<number | null>('max', { default: null })

const minText = ref(min.value == null ? '' : String(min.value))
const maxText = ref(max.value == null ? '' : String(max.value))
watch(min, (v) => { if (v == null) minText.value = '' })
watch(max, (v) => { if (v == null) maxText.value = '' })

function parse(s: string): number | null {
  const n = Number(s.replace(/[^\d.]/g, ''))
  return s.trim() === '' || Number.isNaN(n) ? null : n
}
function onMin(e: Event) {
  minText.value = (e.target as HTMLInputElement).value
  min.value = parse(minText.value)
}
function onMax(e: Event) {
  maxText.value = (e.target as HTMLInputElement).value
  max.value = parse(maxText.value)
}
</script>

<template>
  <div class="amt-range" role="group" aria-label="金額區間">
    <label class="search-sm amt-in">
      <span>NT$</span>
      <input :value="minText" inputmode="numeric" placeholder="金額下限" aria-label="金額下限" @input="onMin" />
    </label>
    <span class="amt-sep">–</span>
    <label class="search-sm amt-in">
      <span>NT$</span>
      <input :value="maxText" inputmode="numeric" placeholder="金額上限" aria-label="金額上限" @input="onMax" />
    </label>
  </div>
</template>
