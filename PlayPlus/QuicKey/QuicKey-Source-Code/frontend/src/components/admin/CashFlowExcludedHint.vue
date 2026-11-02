<script setup lang="ts">
/**
 * 收付款日早於帳戶起始月份時的提示（PRD 規則 20）：可以儲存，但不計入現金流與帳戶餘額。
 * date 傳已收付時的收付款日；待收付傳 null，不受影響也不顯示。
 */
import { computed } from 'vue'
import type { AccountOption } from '@/api/accounts'
import { formatMonth, toIsoDate } from '@/utils/format'

const props = defineProps<{
  /** 例：付款日、收款日 */
  dateLabel: string
  date: Date | null
  account?: AccountOption
  /** 一次處理多筆時標出是哪一筆 */
  recordLabel?: string
}>()

const openingMonth = computed(() => props.account?.openingMonth)
const show = computed(
  () => !!props.date && !!openingMonth.value && toIsoDate(props.date) < openingMonth.value,
)
</script>

<template>
  <div role="status">
    <p v-if="show" class="cf-hint">
      <i class="pi pi-exclamation-triangle" aria-hidden="true" />
      <span><template v-if="recordLabel">{{ recordLabel }}：</template>{{ dateLabel }}早於帳戶「{{ account?.name }}」的起始月份（{{ formatMonth(openingMonth!) }}），這筆不計入現金流。</span>
    </p>
  </div>
</template>

<style scoped>
.cf-hint {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  margin: 0;
  font-size: 14px;
  color: var(--warning-text);
}
.cf-hint .pi { margin-top: 3px; font-size: 14px; }
</style>
