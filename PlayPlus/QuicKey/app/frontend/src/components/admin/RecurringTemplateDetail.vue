<script setup lang="ts">
/**
 * 固定收支範本明細（抽屜內容）：範本內容、它產生的紀錄、歷程。
 * 紀錄點開走支出、收入列表的 ?open=，上一頁能回到這個抽屜。
 */
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { DataTablePageEvent, DataTableRowClickEvent } from 'primevue/datatable'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import { useToast } from 'primevue/usetoast'
import PayStatusChip from '@/components/PayStatusChip.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'
import { listRecurringRecords, type RecurringRecord } from '@/api/recurring'
import { DOCUMENT_TYPE_OPTIONS, TAX_RATE_OPTIONS } from '@/constants/expense'
import { RECURRING_DIRECTION_LABELS, type RecurringTemplate } from '@/types/domain'
import { formatCurrency, formatCurrencyExact, formatDate, formatMonth } from '@/utils/format'
import { categoryBlockedHint, scheduleLabel } from '@/utils/recurring'
import { PAGE_REPORT, PAGINATOR_TEMPLATE } from '@/utils/table'
import { userErrorToast } from '@/utils/userFeedback'

const props = defineProps<{ template: RecurringTemplate }>()

const router = useRouter()
const toast = useToast()

const isExpense = computed(() => props.template.direction === 'expense')
const blockedHint = computed(() => categoryBlockedHint(props.template.category))
const documentTypeLabel = computed(
  () => DOCUMENT_TYPE_OPTIONS.find((o) => o.value === props.template.documentType)?.label,
)
const taxRateLabel = computed(() => TAX_RATE_OPTIONS.find((o) => o.value === props.template.taxRate)?.label)

const records = ref<RecurringRecord[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const loading = ref(true)
const loadFailed = ref(false)

let fetchSeq = 0
async function refresh() {
  const seq = ++fetchSeq
  loading.value = true
  try {
    const res = await listRecurringRecords(props.template.id, { page: page.value, perPage: pageSize.value })
    if (seq !== fetchSeq) return
    records.value = res.data
    total.value = res.meta.total
    loadFailed.value = false
  } catch (err) {
    if (seq !== fetchSeq) return
    loadFailed.value = true
    records.value = []
    total.value = 0
    toast.add({ severity: 'error', ...userErrorToast(err, '載入產生的紀錄失敗'), life: 3500 })
  } finally {
    if (seq === fetchSeq) loading.value = false
  }
}
onMounted(refresh)

function onPage(evt: DataTablePageEvent) {
  page.value = evt.page + 1
  pageSize.value = evt.rows
  void refresh()
}

function onRowClick(evt: DataTableRowClickEvent) {
  const r = evt.data as RecurringRecord
  router.push({ name: r.kind === 'expense' ? 'admin-expenses' : 'admin-incomes', query: { open: r.id } })
}

/** 待付款、待收款的 settledAt 可能是舊值，不顯示 */
function isSettled(r: RecurringRecord): boolean {
  return r.status === 'paid' || r.status === 'collected'
}
</script>

<template>
  <div class="dt-body">
    <section class="dt-summary" aria-label="範本摘要">
      <span class="tag-soft tag-neutral">{{ RECURRING_DIRECTION_LABELS[template.direction] }}</span>
      <div class="dt-summary-heading">{{ template.name }}</div>
      <div class="dt-stats">
        <div class="dt-stat">
          <span class="dt-stat-label">每期金額（含稅）</span>
          <span class="dt-stat-value">{{ formatCurrencyExact(template.amount) }}</span>
        </div>
        <div v-if="template.nextDate" class="dt-stat">
          <span class="dt-stat-label">下一期</span>
          <span class="dt-stat-value">{{ formatDate(template.nextDate) }}</span>
        </div>
      </div>
    </section>

    <p v-if="blockedHint" class="dlg-note">{{ blockedHint }}</p>

    <section class="dt-section" aria-labelledby="rec-basic">
      <h3 id="rec-basic" class="dt-section-title">基本資訊</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>{{ isExpense ? '廠商' : '客戶' }}</dt><dd>{{ template.counterparty }}</dd></div>
        <div class="dt-row"><dt>類別</dt><dd>{{ template.category.name }}</dd></div>
        <div class="dt-row"><dt>帳戶</dt><dd>{{ template.account.name }}</dd></div>
        <div class="dt-row"><dt>文件類型</dt><dd>{{ documentTypeLabel }}</dd></div>
        <div class="dt-row"><dt>稅別</dt><dd>{{ taxRateLabel }}</dd></div>
        <div v-if="template.taxId" class="dt-row"><dt>統一編號</dt><dd>{{ template.taxId }}</dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="rec-schedule">
      <h3 id="rec-schedule" class="dt-section-title">週期</h3>
      <dl class="dt-list">
        <div class="dt-row"><dt>週期</dt><dd>{{ scheduleLabel(template) }}</dd></div>
        <div class="dt-row"><dt>開始月份</dt><dd>{{ formatMonth(template.startMonth) }}</dd></div>
        <div class="dt-row"><dt>結束月份</dt><dd>{{ template.endMonth ? formatMonth(template.endMonth) : '持續' }}</dd></div>
        <div class="dt-row">
          <dt>已產生到</dt>
          <dd>{{ template.lastGeneratedPeriod ? formatMonth(template.lastGeneratedPeriod) : '尚未產生' }}</dd>
        </div>
        <div class="dt-row"><dt>建立者</dt><dd>{{ template.createdBy.name }}</dd></div>
      </dl>
    </section>

    <section class="dt-section" aria-labelledby="rec-records">
      <h3 id="rec-records" class="dt-section-title">產生的紀錄</h3>
      <DataTable
        :value="records"
        data-key="id"
        lazy
        :paginator="total > pageSize"
        :first="(page - 1) * pageSize"
        :rows="pageSize"
        :total-records="total"
        :loading="loading"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
        row-hover
        :pt="{ bodyRow: { class: 'q-clickable', tabindex: 0 } }"
        @page="onPage"
        @row-click="onRowClick"
      >
        <template #empty>
          <div class="dash-empty">{{ loadFailed ? '紀錄載入失敗，請重新開啟' : loading ? '' : '尚未產生紀錄' }}</div>
        </template>
        <Column header="發生日期">
          <template #body="{ data }">
            <span class="tabular-nums whitespace-nowrap">{{ formatDate(data.date) }}</span>
          </template>
        </Column>
        <Column header="金額" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="狀態" :style="{ width: '1%' }">
          <template #body="{ data }">
            <PayStatusChip :status="data.status" />
            <div v-if="isSettled(data) && data.settledAt" class="cell-sub tabular-nums whitespace-nowrap">{{ formatDate(data.settledAt) }}</div>
          </template>
        </Column>
      </DataTable>
    </section>

    <AuditLogList target-type="recurring_template" :target-id="template.id" />
  </div>
</template>
