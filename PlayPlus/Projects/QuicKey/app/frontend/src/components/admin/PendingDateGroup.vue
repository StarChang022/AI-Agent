<script setup lang="ts">
/**
 * 待付款／待收款依應付／應收日期分組的一組卡片（PRD 第 23 條）：
 * 標題列顯示日期、總金額、筆數，可展開收合；逾期組以警示色呈現、標題不顯示日期（各筆日期看組內列表）。
 * 表格由呼叫端放進預設 slot。
 */
import { computed, useId } from 'vue'
import Button from 'primevue/button'
import { formatCurrency, formatDate } from '@/utils/format'

const props = defineProps<{
  kind: 'expense' | 'income'
  date: string | null
  overdue: boolean
  total: number
  count: number
  open: boolean
}>()
const emit = defineEmits<{ toggle: []; action: [] }>()
const bodyId = `pending-group-${useId()}`

const text = computed(() =>
  props.kind === 'expense'
    ? { overdue: '逾期未付款', date: '應付日期', total: '應付金額', action: '標記這批已付款', group: '付款批次' }
    : { overdue: '逾期未收款', date: '應收日期', total: '應收金額', action: '標記這批已收款', group: '收款批次' },
)
/** 多組時讀屏要分得出是哪一組：按鈕名稱帶上組別 */
const groupName = computed(() => (props.overdue ? text.value.overdue : `${text.value.date} ${formatDate(props.date)}`))
</script>

<template>
  <section class="batch-card" :class="{ overdue, open }">
    <div class="batch-card-head" @click="emit('toggle')">
      <span class="batch-primary">
        <!-- 逾期組合併多個日期，只放組名；與金額、筆數的數值同一列對齊 -->
        <span v-if="overdue" class="batch-date">
          <strong class="batch-overdue-title">
            <i class="pi pi-exclamation-circle" aria-hidden="true" />
            {{ text.overdue }}
          </strong>
        </span>
        <span v-else class="batch-date">
          <span class="batch-eyebrow">
            <i class="pi pi-calendar" aria-hidden="true" />
            {{ text.date }}
          </span>
          <strong>{{ formatDate(date) }}</strong>
        </span>
        <span class="batch-total">
          <span>{{ text.total }}</span>
          <strong>{{ formatCurrency(total) }}</strong>
        </span>
        <span class="batch-total">
          <span>筆數</span>
          <strong>{{ count }} 筆</strong>
        </span>
      </span>
      <span class="batch-actions">
        <Button :label="text.action" :aria-label="`${text.action}（${groupName}）`" size="small" text @click.stop="emit('action')" />
        <button type="button" class="batch-toggle" :aria-expanded="open" :aria-controls="bodyId" @click.stop="emit('toggle')">
          <i class="pi pi-chevron-down" aria-hidden="true" />
          <span class="sr-only">{{ open ? `收合${text.group}` : `展開${text.group}` }}（{{ groupName }}）</span>
        </button>
      </span>
    </div>
    <!-- 內容區用高度展開／收合（同篩選列 .filter-collapse） -->
    <div :id="bodyId" class="batch-collapse" :class="{ open }" :inert="!open">
      <div class="batch-card-body">
        <slot />
      </div>
    </div>
  </section>
</template>

<style scoped>
.batch-card {
  overflow: hidden;
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-card-lg);
  background: var(--color-canvas);
}
.batch-card-head {
  display: grid;
  grid-template-columns: minmax(380px, 1fr) auto;
  align-items: center;
  gap: 18px;
  min-height: 92px;
  padding: 18px 20px;
  background: var(--color-canvas);
}
/* 逾期淡紅底：由 --color-danger 調淡（約等於原本的 #fffafa、#fff3f3），不另設 token */
.batch-card.overdue .batch-card-head { background: color-mix(in srgb, var(--color-danger) 2.5%, var(--color-canvas)); }
.batch-card-body {
  background: var(--color-canvas);
}
.batch-card-body :deep(.p-datatable) { margin: 0; }
.batch-card-body :deep(.p-datatable-tbody > tr:last-child > td) { border-bottom: 0; }
.batch-card-body :deep(.p-datatable-thead > tr > th:first-child),
.batch-card-body :deep(.p-datatable-tbody > tr > td:first-child) { padding-left: 20px; }
.batch-card-body :deep(.p-datatable-thead > tr > th:last-child),
.batch-card-body :deep(.p-datatable-tbody > tr > td:last-child) { padding-right: 20px; }
.batch-primary {
  display: inline-flex;
  align-items: flex-end;
  gap: clamp(28px, 5vw, 72px);
  min-width: 0;
}
.batch-date,
.batch-total {
  display: inline-flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
.batch-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  font-weight: 400;
  color: var(--color-muted);
}
.batch-date strong,
.batch-total strong {
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--color-ink);
  font-variant-numeric: tabular-nums;
}
.batch-overdue-title {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
}
.batch-overdue-title .pi { font-size: 0.8em; }
.batch-card.overdue .batch-date strong,
.batch-card.overdue .batch-total strong { color: var(--color-danger); }
.batch-total span { font-size: 14px; color: var(--color-muted); }
.batch-card.overdue .batch-total span { color: var(--color-danger); font-weight: 600; }
.batch-total { align-items: flex-start; text-align: left; }
.batch-actions {
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}
.batch-toggle {
  width: 36px;
  height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: var(--radius-full);
  background: transparent;
  color: var(--color-slate);
  cursor: pointer;
}
.batch-toggle:hover { background: var(--color-surface-soft); color: var(--color-ink); }
/* 整個標題列可點擊展開／收合；動作與箭頭按鈕各自 stop，不會重複觸發 */
.batch-card-head { cursor: pointer; transition: background-color .15s ease; }
.batch-card-head:hover { background: var(--color-surface); }
.batch-card.overdue .batch-card-head:hover { background: color-mix(in srgb, var(--color-danger) 5.5%, var(--color-canvas)); }
.batch-toggle .pi { transition: transform .22s ease; }
.batch-card.open .batch-toggle .pi { transform: rotate(180deg); }
.batch-collapse { display: grid; grid-template-rows: 0fr; transition: grid-template-rows .22s ease; }
.batch-collapse.open { grid-template-rows: 1fr; border-top: 1px solid var(--color-hairline); }
.batch-collapse > .batch-card-body { min-height: 0; overflow: hidden; }
@media (prefers-reduced-motion: reduce) {
  .batch-collapse, .batch-toggle .pi, .batch-card-head { transition: none; }
}
@media (max-width: 960px) {
  .batch-card-head { grid-template-columns: minmax(0, 1fr) auto; }
  .batch-primary { flex-wrap: wrap; gap: 16px 28px; }
  .batch-actions { grid-column: 1 / -1; justify-content: flex-start; }
}
@media (max-width: 639.98px) {
  .batch-date strong,
  .batch-total strong { font-size: 14px; }
}
</style>
