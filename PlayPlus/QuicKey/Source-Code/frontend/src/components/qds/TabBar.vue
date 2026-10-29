<script setup lang="ts" generic="T extends string">
import { ref } from 'vue'
import { useSlideIndicator } from '@/composables/useSlideIndicator'

/**
 * 分頁標籤（tabbar）：右側數量膠囊。見 design-system/design-tab.html
 * - variant 'underline'（預設）：底線式，下方要有整條分隔線
 * - variant 'segmented'：膠囊分段式（同 SelectButton 外觀），不依賴分隔線，適合放在卡片標題列
 */
const props = withDefaults(
  defineProps<{
    tabs: { value: T; label: string; count?: number }[]
    label?: string
    variant?: 'underline' | 'segmented'
  }>(),
  { label: undefined, variant: 'underline' },
)
const model = defineModel<T>({ required: true })

// 膠囊式：選中底色滑動到新的選項
const bar = ref<HTMLElement | null>(null)
const { style: indicatorStyle } = useSlideIndicator(bar, '.tab.active', model)

function onKey(e: KeyboardEvent, i: number) {
  const n = props.tabs.length
  let j = -1
  if (e.key === 'ArrowRight') j = (i + 1) % n
  else if (e.key === 'ArrowLeft') j = (i - 1 + n) % n
  else if (e.key === 'Home') j = 0
  else if (e.key === 'End') j = n - 1
  if (j < 0) return
  e.preventDefault()
  model.value = props.tabs[j].value
  const bar = (e.currentTarget as HTMLElement).parentElement
  ;(bar?.children[j] as HTMLElement | undefined)?.focus()
}
</script>

<template>
  <div ref="bar" class="tabbar" :class="{ 'is-segmented': props.variant === 'segmented' }" role="tablist" :aria-label="props.label">
    <span v-if="props.variant === 'segmented'" class="slide-seg-indicator" :style="indicatorStyle" aria-hidden="true" />
    <button
      v-for="(t, i) in props.tabs"
      :key="t.value"
      type="button"
      role="tab"
      class="tab"
      :class="{ active: model === t.value }"
      :aria-selected="model === t.value"
      :tabindex="model === t.value ? 0 : -1"
      @click="model = t.value"
      @keydown="onKey($event, i)"
    >
      {{ t.label }}
      <span v-if="t.count !== undefined" class="tab-count">{{ t.count }}</span>
    </button>
  </div>
</template>
