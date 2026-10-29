<script setup lang="ts">
/**
 * 請款單的發票資訊列：賣方、憑證類型、發票號碼、賣方統編、稅別。
 * 後台請款明細與員工端詳情共用；只負責顯示，外層 <dl> 由呼叫端提供。
 */
import { computed } from 'vue'
import type { Reimbursement } from '@/types/domain'
import { DOCUMENT_TYPE_OPTIONS, TAX_RATE_OPTIONS } from '@/constants/expense'
import { formatCurrency } from '@/utils/format'

const props = defineProps<{ reimbursement: Reimbursement }>()

const r = computed(() => props.reimbursement)
const docLabel = computed(() => DOCUMENT_TYPE_OPTIONS.find((o) => o.value === r.value.documentType)?.label ?? '—')
const taxLabel = computed(() => (r.value.documentType === 'receipt' ? '無' : TAX_RATE_OPTIONS.find((o) => o.value === r.value.taxRate)?.label ?? '—'))
const isInvoice = computed(() => r.value.documentType === 'invoice')
const taxText = computed(() =>
  r.value.taxRate === 'business_5' && r.value.taxAmt !== null
    ? `${taxLabel.value}，稅額 ${formatCurrency(r.value.taxAmt)}`
    : taxLabel.value,
)
</script>

<template>
  <div class="dt-row"><dt>賣方</dt><dd>{{ r.vendor || '未填寫' }}</dd></div>
  <div class="dt-row"><dt>憑證類型</dt><dd>{{ docLabel }}</dd></div>
  <div v-if="isInvoice || r.invoiceNo" class="dt-row"><dt>發票號碼</dt><dd>{{ r.invoiceNo || '未填寫' }}</dd></div>
  <div v-if="r.taxId" class="dt-row"><dt>賣方統編</dt><dd>{{ r.taxId }}</dd></div>
  <div class="dt-row"><dt>稅別</dt><dd>{{ taxText }}</dd></div>
</template>
