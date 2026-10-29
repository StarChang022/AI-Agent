<script setup lang="ts">
/**
 * 收入詳情抽屜內容（read-only）。
 * 鏡像 ExpenseDetail，差異：
 * - 無 source / plannedPayoutDate / linkedReimbursement
 * - 「賣方」→「客戶」；付款相關改收款（collectedAt、無 paidBy）
 */
import { computed, ref } from 'vue'
import type { Income, IncomeAttachment } from '@/types/domain'
import { accountSubjectLabel } from '@/constants/accountSubjects'
import { DOCUMENT_TYPE_OPTIONS, TAX_RATE_OPTIONS } from '@/constants/expense'
import { formatCurrency, formatDate } from '@/utils/format'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'

const props = defineProps<{ income: Income }>()

const previewAtt = ref<IncomeAttachment | null>(null)

const accountCode = computed(() => accountSubjectLabel(props.income.category.accountCode))
const categoryLabel = computed(() => props.income.category.name)
const documentTypeLabel = computed(
  () =>
    DOCUMENT_TYPE_OPTIONS.find((o) => o.value === props.income.documentType)?.label ?? '—',
)
const taxRateLabel = computed(() =>
  props.income.documentType === 'receipt'
    ? '無'
    : TAX_RATE_OPTIONS.find((o) => o.value === props.income.taxRate)?.label ?? '—',
)
const itemsTotal = computed(() =>
  props.income.items.reduce((acc, it) => acc + it.subtotal, 0),
)

const isInvoice = computed(() => props.income.documentType === 'invoice')
const showTaxBreakdown = computed(
  () =>
    props.income.taxRate === 'business_5' &&
    props.income.preTaxAmt !== null &&
    props.income.taxAmt !== null,
)

function isImageAttachment(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}
</script>

<template>
  <div class="dt-body">
    <section class="dt-summary" aria-label="收入摘要">
      <div class="dt-summary-heading">{{ categoryLabel }}</div>
      <p v-if="income.note" class="dt-summary-desc">{{ income.note }}</p>
      <div class="dt-stats">
        <div class="dt-stat">
          <span class="dt-stat-label">金額</span>
          <span class="dt-stat-value">{{ formatCurrency(income.amount) }}</span>
        </div>
        <div v-if="income.collectionStatus === 'collected' && income.collectedAt" class="dt-stat">
          <span class="dt-stat-label">收款日</span>
          <span class="dt-stat-value">{{ formatDate(income.collectedAt) }}</span>
        </div>
      </div>
    </section>

    <section class="dt-section" aria-labelledby="inc-basic">
      <h3 id="inc-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>客戶</dt><dd>{{ income.customer }}</dd></div>
        <div class="dt-row"><dt>類別</dt><dd>{{ categoryLabel }}<span v-if="accountCode" class="dt-block">會計科目 {{ accountCode }}</span></dd></div>
        <div class="dt-row"><dt>開立日期</dt><dd>{{ formatDate(income.date) }}</dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="inc-doc">
      <h3 id="inc-doc" class="dt-section-title">憑證</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>憑證類型</dt><dd>{{ documentTypeLabel }}</dd></div>
        <div v-if="isInvoice || income.invoiceNo" class="dt-row"><dt>發票號碼</dt><dd>{{ income.invoiceNo || '未填寫' }}</dd></div>
        <div v-if="income.taxId" class="dt-row"><dt>買方統編</dt><dd>{{ income.taxId }}</dd></div>
      </dl>
      <div v-if="income.attachments.length" class="dt-thumbs">
        <button
          v-for="(att, i) in income.attachments"
          :key="i"
          type="button"
          class="aspect-square rounded-md border border-[var(--color-hairline)] overflow-hidden bg-[var(--color-surface)] flex items-center justify-center hover:border-[var(--color-primary-700)] transition-colors"
          :aria-label="`預覽 ${att.filename}`"
          @click="previewAtt = att"
        >
          <img v-if="isImageAttachment(att.mimeType)" :src="att.dataUrl" :alt="att.filename" class="w-full h-full object-cover" />
          <span v-else class="w-full h-full flex flex-col items-center justify-center gap-1 p-1.5"><i class="pi pi-file-pdf text-2xl text-[var(--color-danger)]" aria-hidden="true" /><span class="w-full truncate text-center text-xs text-[var(--color-muted)]">{{ att.filename }}</span></span>
        </button>
      </div>
      <p v-else class="dt-empty"><i class="pi pi-paperclip mr-1" aria-hidden="true" />尚未上傳憑證檔案</p>
    </section>

    <section class="dt-section" aria-labelledby="inc-amt">
      <h3 id="inc-amt" class="dt-section-title">金額</h3>
      <dl class="dt-list">
        <template v-if="showTaxBreakdown">
          <div class="dt-row"><dt>未稅金額</dt><dd>{{ formatCurrency(income.preTaxAmt!) }}</dd></div>
          <div class="dt-row"><dt>稅額</dt><dd>{{ formatCurrency(income.taxAmt!) }}<span class="dt-aside">{{ taxRateLabel }}</span></dd></div>
          <div class="dt-row is-total"><dt>總金額</dt><dd>{{ formatCurrency(income.amount) }}</dd></div>
        </template>
        <div v-else class="dt-row"><dt>稅別</dt><dd>{{ taxRateLabel }}</dd></div>
      </dl>
      <template v-if="income.items.length">
        <table class="w-full text-sm">
          <caption class="sr-only">品項明細</caption>
          <thead>
            <tr class="bg-[var(--color-surface)] text-[var(--color-slate)]">
              <th scope="col" class="text-left font-semibold py-2 px-2">品項</th>
              <th scope="col" class="text-right font-semibold py-2 px-2">數量</th>
              <th scope="col" class="text-right font-semibold py-2 px-2">單價</th>
              <th scope="col" class="text-right font-semibold py-2 px-2">小計</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(it, i) in income.items" :key="i" class="border-t border-[var(--color-hairline)]">
              <td class="py-2 px-2">{{ it.name }}</td>
              <td class="py-2 px-2 text-right tabular-nums">{{ it.quantity }}</td>
              <td class="py-2 px-2 text-right tabular-nums">{{ formatCurrency(it.unitPrice) }}</td>
              <td class="py-2 px-2 text-right tabular-nums">{{ formatCurrency(it.subtotal) }}</td>
            </tr>
            <tr class="border-t border-[var(--color-hairline)]">
              <td colspan="3" class="py-2 px-2 text-right text-[var(--color-muted)]">品項合計</td>
              <td class="py-2 px-2 text-right tabular-nums font-semibold">{{ formatCurrency(itemsTotal) }}</td>
            </tr>
          </tbody>
        </table>
      </template>
    </section>

    <section v-if="income.collectionStatus === 'collected' && income.collectedAt" class="dt-section" aria-labelledby="inc-collect">
      <h3 id="inc-collect" class="dt-section-title">收款資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>收款日期</dt><dd>{{ formatDate(income.collectedAt) }}</dd></div>
      </dl>
    </section>

    <AuditLogList target-type="income" :target-id="income.id" />

    <AttachmentPreviewDialog
      :src="previewAtt?.dataUrl ?? null"
      :filename="previewAtt?.filename"
      :mime-type="previewAtt?.mimeType"
      @close="previewAtt = null"
    />
  </div>
</template>
