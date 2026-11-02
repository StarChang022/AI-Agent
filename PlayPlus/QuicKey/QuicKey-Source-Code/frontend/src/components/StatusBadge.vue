<script setup lang="ts">
import { computed } from 'vue'
import type { ReimbursementStatus } from '@/types/domain'

const props = defineProps<{
  status: ReimbursementStatus
}>()

type Style = { bg: string; text: string; label: string }

// 對齊設計系統 Status Badge：6 種狀態各自獨立的顏色，不借用主色
const STYLES: Record<ReimbursementStatus, Style> = {
  draft: {
    bg: 'bg-[var(--color-status-draft-bg)]',
    text: 'text-[var(--color-status-draft)]',
    label: '草稿',
  },
  in_review: {
    bg: 'bg-[var(--color-status-review-bg)]',
    text: 'text-[var(--color-status-review)]',
    label: '簽核中',
  },
  rejected: {
    bg: 'bg-[var(--color-status-rejected-bg)]',
    text: 'text-[var(--color-status-rejected)]',
    label: '退回',
  },
  approved: {
    bg: 'bg-[var(--color-status-approved-bg)]',
    text: 'text-[var(--color-status-approved)]',
    label: '已核銷',
  },
  paid: {
    bg: 'bg-[var(--color-status-paid-bg)]',
    text: 'text-[var(--color-status-paid)]',
    label: '已發放',
  },
  voided: {
    bg: 'bg-[var(--color-status-voided)]',
    text: 'text-white',
    label: '已作廢',
  },
}

const style = computed(() => STYLES[props.status])
</script>

<template>
  <span
    class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px] leading-[1.4] whitespace-nowrap"
    :class="[style.bg, style.text]"
  >
    {{ style.label }}
  </span>
</template>
