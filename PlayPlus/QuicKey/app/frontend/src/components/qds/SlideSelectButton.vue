<script setup lang="ts" generic="T">
/**
 * SelectButton（膠囊式）＋選中底色滑動效果。包一層 PrimeVue SelectButton，其餘 props/事件照傳。
 * 見 design-system/design-select-date.html「SelectButton」。
 */
import { ref } from 'vue'
import SelectButton from 'primevue/selectbutton'
import { useSlideIndicator } from '@/composables/useSlideIndicator'

const model = defineModel<T>()
const wrap = ref<HTMLElement | null>(null)
const { style } = useSlideIndicator(wrap, '.p-togglebutton-checked', model)
</script>

<template>
  <div ref="wrap" class="slide-seg">
    <span class="slide-seg-indicator" :style="style" aria-hidden="true" />
    <SelectButton v-model="model" v-bind="$attrs" />
  </div>
</template>

<script lang="ts">
export default { inheritAttrs: false }
</script>
