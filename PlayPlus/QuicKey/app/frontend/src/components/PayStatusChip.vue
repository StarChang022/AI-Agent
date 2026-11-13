<script setup lang="ts">
/** 支出付款狀態、收入收款狀態的標籤。 */
import { computed } from 'vue'
import type { CollectionStatus, PayoutStatus } from '@/types/domain'

const props = defineProps<{ status: PayoutStatus | CollectionStatus }>()

const LABELS: Record<PayoutStatus | CollectionStatus, string> = {
  pending: '待付款',
  paid: '已付款',
  uncollected: '待收款',
  collected: '已收款',
}
const settled = computed(() => props.status === 'paid' || props.status === 'collected')
</script>

<template>
  <span
    class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]"
    :class="settled ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'"
  >
    {{ LABELS[status] }}
  </span>
</template>
