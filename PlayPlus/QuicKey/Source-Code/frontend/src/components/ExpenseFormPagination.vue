<script setup lang="ts">
/**
 * 新增支出頁多筆分頁元件。單一表單 = 一項支出；當使用者上傳多張憑證圖片
 * （或由批次匯入 Dialog 帶入 N 筆預覽）時，於「建立」按鈕上方顯示此元件。
 *
 * 對應 openspec/changes/add-general-expense-module/design.md Decision 16
 * 與 tasks.md §6。
 */
const props = defineProps<{
  /** 總頁數（≥ 1；父層在 `total > 1` 時才 render 此元件） */
  total: number
  /** 目前頁 index（0-based） */
  current: number
}>()

const emit = defineEmits<{
  (e: 'change', index: number): void
}>()

function prev() {
  if (props.current > 0) emit('change', props.current - 1)
}
function next() {
  if (props.current < props.total - 1) emit('change', props.current + 1)
}
function jump(index: number) {
  if (index !== props.current && index >= 0 && index < props.total) {
    emit('change', index)
  }
}
</script>

<template>
  <nav
    class="inline-flex items-center gap-2 rounded-full bg-white border border-[var(--color-hairline)] px-3 py-1.5"
    aria-label="表單分頁"
  >
    <span
      class="text-[11px] sm:text-xs text-[var(--color-muted)] tabular-nums pr-1 select-none"
    >
      第 {{ current + 1 }} 筆 / 共 {{ total }} 筆
    </span>
    <button
      type="button"
      class="w-7 h-7 rounded-full flex items-center justify-center hover:bg-[var(--color-surface)] disabled:opacity-40 disabled:cursor-not-allowed"
      :disabled="current <= 0"
      aria-label="上一頁"
      @click="prev"
    >
      <i class="pi pi-chevron-left text-xs" aria-hidden="true" />
    </button>
    <div
      :class="[
        'items-center gap-1.5',
        total > 5 ? 'hidden sm:flex' : 'flex',
      ]"
    >
      <button
        v-for="i in total"
        :key="i - 1"
        type="button"
        :class="[
          'transition-all',
          i - 1 === current
            ? 'w-6 h-2.5 rounded-full bg-[var(--color-primary)]'
            : 'w-2.5 h-2.5 rounded-full bg-[var(--color-hairline)] hover:bg-[var(--color-muted)]',
        ]"
        :aria-label="`第 ${i} 頁`"
        :aria-current="i - 1 === current ? 'page' : undefined"
        @click="jump(i - 1)"
      />
    </div>
    <button
      type="button"
      class="w-7 h-7 rounded-full flex items-center justify-center hover:bg-[var(--color-surface)] disabled:opacity-40 disabled:cursor-not-allowed"
      :disabled="current >= total - 1"
      aria-label="下一頁"
      @click="next"
    >
      <i class="pi pi-chevron-right text-xs" aria-hidden="true" />
    </button>
  </nav>
</template>
