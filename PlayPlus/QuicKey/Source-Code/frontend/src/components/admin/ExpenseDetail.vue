<script setup lang="ts">
import { accountSubjectLabel } from '@/constants/accountSubjects'
import { computed, ref, watch } from 'vue'
import type { Expense, ExpenseAttachment, Reimbursement } from '@/types/domain'
import { getReimbursement } from '@/api/reimbursements'
import {
  DOCUMENT_TYPE_OPTIONS,
  TAX_RATE_OPTIONS,
} from '@/constants/expense'
import { formatCurrency, formatDate } from '@/utils/format'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import LinkedRecordRow from '@/components/LinkedRecordRow.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'

const props = defineProps<{
  expense: Expense
  /** 顯示「預計付款日」旁的「調整」連結（支出管理用） */
  canAdjustPayout?: boolean
}>()
defineEmits<{ adjustPayout: [] }>()

const previewAtt = ref<ExpenseAttachment | null>(null)
const linkedReimbursement = ref<Reimbursement | null>(null)

watch(
  () => (props.expense.source === 'reimbursement' ? props.expense.sourceRefId : null),
  async (sourceRefId) => {
    if (!sourceRefId) {
      linkedReimbursement.value = null
      return
    }
    try {
      linkedReimbursement.value = await getReimbursement(sourceRefId)
    } catch {
      linkedReimbursement.value = null
    }
  },
  { immediate: true },
)

const sourceLabel = computed(() =>
  props.expense.source === 'general' ? '一般支出' : '代墊款',
)
/** 待付款才顯示預計付款日（snapshot：手動調整或自動 snapshot，不另外標示） */
const plannedPayout = computed(() => {
  if (props.expense.payoutStatus !== 'pending') return null
  const iso = props.expense.plannedPayoutDate
  return iso ? formatDate(iso) : null
})
const accountCode = computed(() =>
  accountSubjectLabel(props.expense.category.accountCode),
)
const categoryLabel = computed(() => props.expense.category.name)
const documentTypeLabel = computed(
  () =>
    DOCUMENT_TYPE_OPTIONS.find((o) => o.value === props.expense.documentType)
      ?.label ?? '—',
)
// 收據沒有營業稅，不顯示「免稅 0%」以免誤會
const taxRateLabel = computed(() =>
  props.expense.documentType === 'receipt'
    ? '無'
    : TAX_RATE_OPTIONS.find((o) => o.value === props.expense.taxRate)?.label ?? '—',
)
const itemsTotal = computed(() =>
  props.expense.items.reduce((acc, it) => acc + it.subtotal, 0),
)
const applicantName = computed(() => linkedReimbursement.value?.employee.name ?? null)

const isInvoice = computed(() => props.expense.documentType === 'invoice')
/** 營業稅且有拆分未稅/稅額時才列金額明細；免稅只顯示稅別 */
const showTaxBreakdown = computed(
  () =>
    props.expense.taxRate === 'business_5' &&
    props.expense.preTaxAmt !== null &&
    props.expense.taxAmt !== null,
)

function isImageAttachment(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}
</script>

<template>
  <div class="dt-body">
    <!-- 摘要：來源、類別、描述；金額與付款日並排 -->
    <section class="dt-summary" aria-label="支出摘要">
      <span class="tag-soft tag-neutral">{{ sourceLabel }}</span>
      <div class="dt-summary-heading">{{ categoryLabel }}</div>
      <p v-if="expense.note" class="dt-summary-desc">{{ expense.note }}</p>
      <div class="dt-stats">
        <div class="dt-stat">
          <span class="dt-stat-label">金額</span>
          <span class="dt-stat-value">{{ formatCurrency(expense.amount) }}</span>
        </div>
        <div v-if="expense.payoutStatus === 'paid' && expense.paidAt" class="dt-stat">
          <span class="dt-stat-label">付款日</span>
          <span class="dt-stat-value">{{ formatDate(expense.paidAt) }}</span>
        </div>
        <div v-else-if="plannedPayout" class="dt-stat">
          <span class="dt-stat-label">預計付款日</span>
          <span class="dt-stat-value">{{ plannedPayout }}</span>
          <button v-if="canAdjustPayout" type="button" class="link-btn dt-stat-action" @click="$emit('adjustPayout')">調整付款日</button>
        </div>
      </div>
    </section>

    <section class="dt-section" aria-labelledby="exp-basic">
      <h3 id="exp-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>賣方</dt><dd>{{ expense.vendor || '未填寫' }}</dd></div>
        <div class="dt-row"><dt>類別</dt><dd>{{ categoryLabel }}<span v-if="accountCode" class="dt-block">會計科目 {{ accountCode }}</span></dd></div>
        <div class="dt-row"><dt>費用日期</dt><dd>{{ formatDate(expense.date) }}</dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="exp-doc">
      <h3 id="exp-doc" class="dt-section-title">憑證</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>憑證類型</dt><dd>{{ documentTypeLabel }}</dd></div>
        <div v-if="isInvoice || expense.invoiceNo" class="dt-row"><dt>發票號碼</dt><dd>{{ expense.invoiceNo || '未填寫' }}</dd></div>
        <div v-if="expense.taxId" class="dt-row"><dt>賣方統編</dt><dd>{{ expense.taxId }}</dd></div>
      </dl>
      <div v-if="expense.attachments.length" class="dt-thumbs">
        <button
          v-for="(att, i) in expense.attachments"
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

    <section class="dt-section" aria-labelledby="exp-amt">
      <h3 id="exp-amt" class="dt-section-title">金額</h3>
      <dl class="dt-list">
        <template v-if="showTaxBreakdown">
          <div class="dt-row"><dt>未稅金額</dt><dd>{{ formatCurrency(expense.preTaxAmt!) }}</dd></div>
          <div class="dt-row"><dt>稅額</dt><dd>{{ formatCurrency(expense.taxAmt!) }}<span class="dt-aside">{{ taxRateLabel }}</span></dd></div>
          <div class="dt-row is-total"><dt>總金額</dt><dd>{{ formatCurrency(expense.amount) }}</dd></div>
        </template>
        <div v-else class="dt-row"><dt>稅別</dt><dd>{{ taxRateLabel }}</dd></div>
      </dl>
      <template v-if="expense.items.length">
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
            <tr v-for="(it, i) in expense.items" :key="i" class="border-t border-[var(--color-hairline)]">
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

    <section v-if="expense.payoutStatus === 'paid'" class="dt-section" aria-labelledby="exp-payout">
      <h3 id="exp-payout" class="dt-section-title">付款資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>付款人</dt><dd>{{ expense.paidBy?.name || '—' }}</dd></div>
        <div v-if="expense.paidAt" class="dt-row"><dt>付款日期</dt><dd>{{ formatDate(expense.paidAt) }}</dd></div>
      </dl>
    </section>

    <!-- 對應請款單：與請款單抽屜的「對應支出」成對；說明與上方相同不重複 -->
    <section v-if="linkedReimbursement" class="dt-section" aria-labelledby="exp-src">
      <h3 id="exp-src" class="dt-section-title">對應請款單</h3>
      <LinkedRecordRow
        :to="{ name: 'admin-records', query: { open: linkedReimbursement.id } }"
        label="申請人"
        action="前往請款單"
      >
        {{ applicantName }}
      </LinkedRecordRow>
    </section>


    <AuditLogList target-type="expense" :target-id="expense.id" />

    <AttachmentPreviewDialog
      :src="previewAtt?.dataUrl ?? null"
      :filename="previewAtt?.filename"
      :mime-type="previewAtt?.mimeType"
      @close="previewAtt = null"
    />
  </div>
</template>
