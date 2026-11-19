<script setup lang="ts">
/**
 * 收入詳情抽屜內容（read-only）。
 * 鏡像 ExpenseDetail，差異：
 * - 無 source / plannedPayoutDate / linkedReimbursement
 * - 「賣方」→「客戶」；付款相關改收款（collectedAt、無 paidBy）
 */
import { computed } from 'vue'
import type { Income } from '@/types/domain'
import { accountSubjectLabel } from '@/constants/accountSubjects'
import { DOCUMENT_TYPE_OPTIONS, TAX_RATE_OPTIONS } from '@/constants/expense'
import { formatCurrency, formatDate, formatMonth } from '@/utils/format'
import AttachmentThumbs from '@/components/AttachmentThumbs.vue'
import ItemsTable from '@/components/ItemsTable.vue'
import { getIncome } from '@/api/incomes'
import LinkedRecordRow from '@/components/LinkedRecordRow.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'

const props = defineProps<{ income: Income }>()


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

const isInvoice = computed(() => props.income.documentType === 'invoice')
const showTaxBreakdown = computed(
  () =>
    props.income.taxRate === 'business_5' &&
    props.income.preTaxAmt !== null &&
    props.income.taxAmt !== null,
)

</script>

<template>
  <div class="dt-body">
    <section class="dt-summary" aria-label="收入摘要">
      <span v-if="income.recurringPeriod" class="tag-soft tag-neutral">固定</span>
      <div class="dt-summary-heading">{{ categoryLabel }}</div>
      <p v-if="income.note" class="dt-summary-desc">{{ income.note }}</p>
      <div class="dt-stats">
        <div class="dt-stat">
          <span class="dt-stat-label">金額</span>
          <span class="dt-stat-value">{{ formatCurrency(income.amount) }}</span>
        </div>
        <div v-if="income.collectionStatus === 'collected' && income.collectedAt" class="dt-stat">
          <span class="dt-stat-label">實收日期</span>
          <span class="dt-stat-value">{{ formatDate(income.collectedAt) }}</span>
        </div>
        <div v-else-if="income.collectionStatus === 'uncollected'" class="dt-stat">
          <span class="dt-stat-label">應收日期</span>
          <span class="dt-stat-value">{{ formatDate(income.plannedCollectionDate) }}</span>
        </div>
      </div>
    </section>

    <section class="dt-section" aria-labelledby="inc-basic">
      <h3 id="inc-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>客戶</dt><dd>{{ income.customer }}</dd></div>
        <div class="dt-row"><dt>類別</dt><dd>{{ categoryLabel }}<span v-if="accountCode" class="dt-block">會計科目 {{ accountCode }}</span></dd></div>
        <div class="dt-row"><dt>帳戶</dt><dd>{{ income.account.name }}</dd></div>
        <div class="dt-row"><dt>發生日期</dt><dd>{{ formatDate(income.date) }}</dd></div>
        <div class="dt-row"><dt>應收日期</dt><dd>{{ formatDate(income.plannedCollectionDate) }}</dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="inc-doc">
      <h3 id="inc-doc" class="dt-section-title">憑證</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>憑證類型</dt><dd>{{ documentTypeLabel }}</dd></div>
        <div v-if="isInvoice" class="dt-row"><dt>發票日期</dt><dd>{{ income.invoiceDate ? formatDate(income.invoiceDate) : '未填寫' }}</dd></div>
        <div v-if="isInvoice || income.invoiceNo" class="dt-row"><dt>發票號碼</dt><dd>{{ income.invoiceNo || '未填寫' }}</dd></div>
        <div v-if="income.taxId" class="dt-row"><dt>買方統編</dt><dd>{{ income.taxId }}</dd></div>
      </dl>
      <AttachmentThumbs
        v-if="income.attachments.length"
        :attachments="income.attachments"
        :refetch="() => getIncome(income.id).then((x) => x.attachments)"
      />
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
      <ItemsTable :items="income.items" />
    </section>

    <section v-if="income.collectionStatus === 'collected' && income.collectedAt" class="dt-section" aria-labelledby="inc-collect">
      <h3 id="inc-collect" class="dt-section-title">收款資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>實收日期</dt><dd>{{ formatDate(income.collectedAt) }}</dd></div>
      </dl>
    </section>

    <!-- 範本永久刪除後不再連回，「固定」標示仍在 -->
    <section v-if="income.recurringTemplateId" class="dt-section" aria-labelledby="inc-recurring">
      <h3 id="inc-recurring" class="dt-section-title">固定收支</h3>
      <LinkedRecordRow
        :to="{ name: 'admin-recurring', query: { open: income.recurringTemplateId } }"
        label="期數"
        action="前往範本"
      >
        {{ formatMonth(income.recurringPeriod ?? '') }}
      </LinkedRecordRow>
    </section>

    <AuditLogList target-type="income" :target-id="income.id" />
  </div>
</template>
