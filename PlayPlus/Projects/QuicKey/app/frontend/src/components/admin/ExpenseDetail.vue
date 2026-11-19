<script setup lang="ts">
import { accountSubjectLabel } from '@/constants/accountSubjects'
import { computed, ref, watch } from 'vue'
import type { Expense, Reimbursement } from '@/types/domain'
import { getReimbursement } from '@/api/reimbursements'
import {
  DOCUMENT_TYPE_OPTIONS,
  TAX_RATE_OPTIONS,
  expenseSourceLabel,
} from '@/constants/expense'
import { formatCurrency, formatDate, formatMonth } from '@/utils/format'
import AttachmentThumbs from '@/components/AttachmentThumbs.vue'
import ItemsTable from '@/components/ItemsTable.vue'
import { getExpense } from '@/api/expenses'
import LinkedRecordRow from '@/components/LinkedRecordRow.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'

const props = defineProps<{
  expense: Expense
  /** 顯示「應付日期」旁的「調整應付日期」連結（支出管理用） */
  canAdjustPayout?: boolean
}>()
defineEmits<{ adjustPayout: [] }>()

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

const sourceLabel = computed(() => expenseSourceLabel(props.expense))
/** 摘要區：待付款顯示應付日期（已付款改顯示實付日期；應付日期仍在基本資訊） */
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
const applicantName = computed(() => linkedReimbursement.value?.employee.name ?? null)

const isInvoice = computed(() => props.expense.documentType === 'invoice')
const isTransferFee = computed(() => props.expense.source === 'transfer_fee')
/** 營業稅且有拆分未稅/稅額時才列金額明細；免稅只顯示稅別 */
const showTaxBreakdown = computed(
  () =>
    props.expense.taxRate === 'business_5' &&
    props.expense.preTaxAmt !== null &&
    props.expense.taxAmt !== null,
)

</script>

<template>
  <div class="dt-body">
    <!-- 摘要：來源、類別、描述；金額與應付／實付日期並排 -->
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
          <span class="dt-stat-label">實付日期</span>
          <span class="dt-stat-value">{{ formatDate(expense.paidAt) }}</span>
        </div>
        <div v-else-if="plannedPayout" class="dt-stat">
          <span class="dt-stat-label">應付日期</span>
          <span class="dt-stat-value">{{ plannedPayout }}</span>
          <button v-if="canAdjustPayout" type="button" class="link-btn dt-stat-action" @click="$emit('adjustPayout')">調整應付日期</button>
        </div>
      </div>
    </section>

    <section class="dt-section" aria-labelledby="exp-basic">
      <h3 id="exp-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div v-if="!isTransferFee" class="dt-row"><dt>賣方</dt><dd>{{ expense.vendor || '未填寫' }}</dd></div>
        <div class="dt-row"><dt>類別</dt><dd>{{ categoryLabel }}<span v-if="accountCode" class="dt-block">會計科目 {{ accountCode }}</span></dd></div>
        <div class="dt-row"><dt>帳戶</dt><dd>{{ expense.account.name }}</dd></div>
        <div class="dt-row"><dt>發生日期</dt><dd>{{ formatDate(expense.date) }}</dd></div>
        <div class="dt-row"><dt>應付日期</dt><dd>{{ formatDate(expense.plannedPayoutDate) }}<span v-if="expense.plannedPayoutManual" class="dt-aside">（已手動調整）</span></dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="exp-doc">
      <h3 id="exp-doc" class="dt-section-title">憑證</h3>
      <dl v-if="!isTransferFee" class="dt-list">
        <div class="dt-row"><dt>憑證類型</dt><dd>{{ documentTypeLabel }}</dd></div>
        <div v-if="isInvoice" class="dt-row"><dt>發票日期</dt><dd>{{ expense.invoiceDate ? formatDate(expense.invoiceDate) : '未填寫' }}</dd></div>
        <div v-if="isInvoice || expense.invoiceNo" class="dt-row"><dt>發票號碼</dt><dd>{{ expense.invoiceNo || '未填寫' }}</dd></div>
        <div v-if="expense.taxId" class="dt-row"><dt>賣方統編</dt><dd>{{ expense.taxId }}</dd></div>
      </dl>
      <AttachmentThumbs
        v-if="expense.attachments.length"
        :attachments="expense.attachments"
        :refetch="() => getExpense(expense.id).then((x) => x.attachments)"
      />
      <p v-else class="dt-empty"><i class="pi pi-paperclip mr-1" aria-hidden="true" />{{ isTransferFee ? '憑證放在資金移轉上' : '尚未上傳憑證檔案' }}</p>
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
      <ItemsTable :items="expense.items" />
    </section>

    <section v-if="expense.payoutStatus === 'paid'" class="dt-section" aria-labelledby="exp-payout">
      <h3 id="exp-payout" class="dt-section-title">付款資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>付款人</dt><dd>{{ expense.paidBy?.name || '—' }}</dd></div>
        <div v-if="expense.paidAt" class="dt-row"><dt>實付日期</dt><dd>{{ formatDate(expense.paidAt) }}</dd></div>
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

    <!-- 範本永久刪除後不再連回，來源仍顯示「固定」 -->
    <section v-if="expense.recurringTemplateId" class="dt-section" aria-labelledby="exp-recurring">
      <h3 id="exp-recurring" class="dt-section-title">固定收支</h3>
      <LinkedRecordRow
        :to="{ name: 'admin-recurring', query: { open: expense.recurringTemplateId } }"
        label="期數"
        action="前往範本"
      >
        {{ formatMonth(expense.recurringPeriod ?? '') }}
      </LinkedRecordRow>
    </section>

    <section v-if="expense.transferId" class="dt-section" aria-labelledby="exp-transfer">
      <h3 id="exp-transfer" class="dt-section-title">資金移轉</h3>
      <LinkedRecordRow
        :to="{ name: 'admin-transfers', query: { open: expense.transferId } }"
        label="手續費"
        action="前往移轉"
      >
        {{ formatCurrency(expense.amount) }}
      </LinkedRecordRow>
      <p class="dlg-note">這筆支出由資金移轉管理，要修改請到移轉。</p>
    </section>

    <AuditLogList target-type="expense" :target-id="expense.id" />
  </div>
</template>
