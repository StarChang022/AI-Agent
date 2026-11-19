<script setup lang="ts">
/**
 * 首次設定引導的白色說明卡（進度、標題、說明、「結束引導」、可選的上一步／下一步）。
 * 新增頁引導（FirstRecordGuide）與新增帳戶視窗旁的引導（FirstAccountGuide）共用；
 * 卡片放在哪裡（固定在底部、視窗旁邊）由使用端用 class 決定。
 */
import { useId } from 'vue'
import Button from 'primevue/button'

defineProps<{
  /** 卡片名稱，讀屏用 */
  label: string
  /** 例：第 1 步 / 共 6 步 */
  progress: string
  title: string
}>()
const emit = defineEmits<{ end: [] }>()

const titleId = useId()
const descId = useId()
defineExpose({ descId })
</script>

<template>
  <section class="guide-card" tabindex="-1" :aria-label="label" :aria-describedby="`${titleId} ${descId}`">
    <div class="gc-head">
      <span class="gc-progress">{{ progress }}</span>
      <Button label="結束引導" text size="small" severity="secondary" @click="emit('end')" />
    </div>
    <div aria-live="polite" aria-atomic="true">
      <h2 :id="titleId" class="gc-title">{{ title }}</h2>
      <div :id="descId" class="gc-desc"><slot /></div>
      <slot name="status" />
    </div>
    <div v-if="$slots.actions" class="gc-actions"><slot name="actions" /></div>
  </section>
</template>

<style scoped>
.guide-card {
  padding: var(--space-md);
  background: var(--canvas);
  border: 1px solid var(--hairline);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-float);
  display: flex;
  flex-direction: column;
  gap: var(--space-xs);
  text-align: left;
}
.guide-card:focus-visible {
  outline: 2px solid var(--primary-solid);
  outline-offset: 2px;
}
.gc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-xs);
  margin: -6px -6px 0 0;
}
.gc-progress {
  font-size: 13px;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.gc-title {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--ink);
}
.gc-desc {
  margin-top: 4px;
  font-size: 14px;
  line-height: 1.6;
  color: var(--slate);
}
.gc-desc :slotted(p) {
  margin: 0;
}
.gc-desc :slotted(ul) {
  margin: 0;
  padding-left: 1.2em;
  list-style: disc;
}
.gc-desc :slotted(b) {
  font-weight: 600;
  color: var(--ink);
}
.gc-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-xs);
  margin-top: 4px;
}
@media (max-width: 639.98px) {
  .guide-card {
    padding: var(--space-sm) var(--space-md);
  }
  .gc-title {
    font-size: 14px;
  }
  .gc-desc {
    font-size: 13px;
  }
  .gc-actions :slotted(.p-button) {
    flex: 1;
    min-height: 44px;
  }
  .gc-head :deep(.p-button) {
    min-height: 44px;
  }
}
</style>
