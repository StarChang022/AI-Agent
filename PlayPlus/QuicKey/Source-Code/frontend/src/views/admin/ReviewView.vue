<script setup lang="ts">
/**
 * 簽核：待管理員簽核的請款單。
 * 待簽核：逐筆「通過/駁回」，或勾選後批次核准/批次駁回；核准時後端會自動建立對應支出。
 * 已處理：approved 可逐筆作廢、voided 可逐筆取消作廢；paid/rejected 僅查看。
 * 走伺服器端分頁；pending / reviewed 的「我該簽 / 我處理過」由後端 pending_for_me /
 * reviewed_by_me filter 判定（Reimbursement.pending_for / reviewed_by_user scope）。
 */
import { computed, onMounted, ref, useTemplateRef, watch } from 'vue'
import {
  listAdminReimbursements,
  type AdminReimbursementListFilters,
  type ReimbursementSummary,
} from '@/api/reimbursements'
import { formatCurrency, formatDate, formatDateTime, toIsoDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import { useReimbursementFilters } from '@/composables/useReimbursementFilters'
import { useReimbursementActions } from '@/composables/useReimbursementActions'
import PageHeader from '@/components/PageHeader.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import TabBar from '@/components/qds/TabBar.vue'
import SearchInput from '@/components/qds/SearchInput.vue'
import SelectionBar from '@/components/qds/SelectionBar.vue'
import ReimbursementToolbar from '@/components/admin/ReimbursementToolbar.vue'
import ReimbursementDrawer from '@/components/admin/ReimbursementDrawer.vue'
import ReimbursementDialogs from '@/components/admin/ReimbursementDialogs.vue'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable, { type DataTablePageEvent, type DataTableRowClickEvent } from 'primevue/datatable'
import { useToast } from 'primevue/usetoast'
import { useOpenQuery } from '@/composables/useOpenQuery'

const toast = useToast()
const { f, isFiltered, reset } = useReimbursementFilters()

type Tab = 'pending' | 'reviewed'
const tab = ref<Tab>('pending')

// ─── 伺服器端分頁 state ─────────────────────────────
const rows = ref<ReimbursementSummary[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const loading = ref(false)
// 待簽核 badge 與列表 filter 連動（與 RecordsView 的 tab 計數規則一致）。
const pendingCount = ref(0)

const selected = ref<ReimbursementSummary[]>([])
const openId = ref<string | null>(null)
const drawerRef = useTemplateRef<InstanceType<typeof ReimbursementDrawer>>('drawerRef')
const actions = useReimbursementActions(async (ids) => {
  selected.value = selected.value.filter((s) => !ids.includes(s.id))
  await refreshAll()
  drawerRef.value?.refetch()
})

const filterOpen = ref(false)
const activeFilterCount = computed(
  () =>
    (f.categories.length ? 1 : 0) +
    (f.dateRange && f.dateRange.some((d) => d instanceof Date) ? 1 : 0) +
    (f.min !== null || f.max !== null ? 1 : 0),
)

const tabs = computed(() => [
  { value: 'pending' as Tab, label: '待簽核', count: pendingCount.value },
  { value: 'reviewed' as Tab, label: '已處理' },
])

// 共用篩選（不含 tab / 分頁），給列表與 pending 計數共用。
function baseFilters(): Partial<AdminReimbursementListFilters> {
  const q: Partial<AdminReimbursementListFilters> = {
    q: f.keyword.trim() || undefined,
    categoryIds: f.categories.length ? f.categories : undefined,
    amountMin: f.min ?? undefined,
    amountMax: f.max ?? undefined,
  }
  if (f.dateRange) {
    const [from, to] = f.dateRange
    if (from instanceof Date) q.dateFrom = toIsoDate(from)
    if (to instanceof Date) q.dateTo = toIsoDate(to)
  }
  return q
}

async function refreshList() {
  loading.value = true
  try {
    const query: AdminReimbursementListFilters = {
      ...baseFilters(),
      page: page.value,
      perPage: pageSize.value,
      ...(tab.value === 'pending' ? { pendingForMe: true } : { reviewedByMe: true }),
    }
    const resp = await listAdminReimbursements(query)
    rows.value = resp.data
    total.value = resp.meta.total
  } catch {
    toast.add({ severity: 'error', summary: '載入簽核清單失敗', life: 3000 })
  } finally {
    loading.value = false
  }
}

async function refreshPendingCount() {
  try {
    const resp = await listAdminReimbursements({
      ...baseFilters(),
      pendingForMe: true,
      page: 1,
      perPage: 1,
    })
    pendingCount.value = resp.meta.total
  } catch {
    pendingCount.value = 0
  }
}

async function refreshAll() {
  await Promise.all([refreshList(), refreshPendingCount()])
}

onMounted(refreshAll)

// tab 切換：清選取、重設第一頁、refetch 列表（badge 跟著 filter 走，不受 tab 影響）
watch(tab, () => {
  selected.value = []
  page.value = 1
  refreshList()
})

let keywordTimer: number | null = null
watch(
  () => f.keyword,
  () => {
    if (keywordTimer !== null) window.clearTimeout(keywordTimer)
    keywordTimer = window.setTimeout(() => {
      page.value = 1
      refreshAll()
    }, 300)
  },
)
watch(
  () => [[...f.categories], f.dateRange, f.min, f.max],
  () => {
    page.value = 1
    refreshAll()
  },
  { deep: true },
)
watch([page, pageSize], refreshList)

function onPage(evt: DataTablePageEvent) {
  pageSize.value = evt.rows
  page.value = evt.page + 1
}

const sum = (list: ReimbursementSummary[]) => list.reduce((s, r) => s + r.amount, 0)

function stageOf(r: ReimbursementSummary) {
  const p = r.approvalProgress
  const step = p?.steps[p.currentStep - 1]
  return step ? step.stageName : '—'
}

function onRowClick(e: DataTableRowClickEvent) {
  openId.value = (e.data as ReimbursementSummary).id
}
useOpenQuery(openId)
</script>

<template>
  <div class="dash-page">
    <PageHeader title="簽核" size="admin" />

    <section class="dash-panel dash-table-panel" aria-label="簽核列表" data-tour="review-queue">
      <div class="list-head">
        <TabBar v-model="tab" :tabs="tabs" label="簽核狀態" variant="segmented" />
        <div class="list-head-tools">
          <SearchInput v-model="f.keyword" placeholder="搜尋申請人、說明、廠商" />
          <Button
            label="篩選"
            :badge="activeFilterCount ? String(activeFilterCount) : undefined"
            icon="pi pi-sliders-h"
            outlined
            size="small"
            :class="{ 'is-open': filterOpen }"
            :aria-expanded="filterOpen"
            aria-controls="review-filters"
            @click="filterOpen = !filterOpen"
          />
        </div>
      </div>
      <div class="filter-collapse" :class="{ open: filterOpen }" :inert="!filterOpen">
        <ReimbursementToolbar id="review-filters" :filters="f" :filtered="isFiltered" :show-search="false" @reset="reset" />
      </div>
      <SelectionBar v-if="selected.length" class="list-selection" :count="selected.length" :summary="`合計 ${formatCurrency(sum(selected))}`" @clear="selected = []">
        <Button label="批次退回" size="small" severity="danger" outlined @click="actions.openReject(selected)" />
        <Button label="批次通過" size="small" @click="actions.batchApprove(selected)" />
      </SelectionBar>
      <DataTable
        v-model:selection="selected"
        :value="rows"
        data-key="id"
        lazy
        paginator
        :first="(page - 1) * pageSize"
        :rows="pageSize"
        :total-records="total"
        :loading="loading"
        :rows-per-page-options="ROWS_OPTIONS"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
        row-hover
        :pt="{ bodyRow: { class: 'q-clickable', tabindex: 0 } }"
        @page="onPage"
        @row-click="onRowClick"
      >
        <template #empty>
          <div class="dash-empty">
            {{ isFiltered ? '沒有符合條件的請款單' : tab === 'pending' ? '目前沒有待簽核的請款單' : '還沒有處理過的請款單' }}
            <Button v-if="isFiltered" label="清除所有篩選" text size="small" @click="reset" />
          </div>
        </template>
        <Column v-if="tab === 'pending'" selection-mode="multiple" header-class="w-[44px]" />
        <Column header="申請人">
          <template #body="{ data }">
            {{ data.employee.name }}
            <div class="cell-sub">{{ data.description }}</div>
          </template>
        </Column>
        <Column header="類別"><template #body="{ data }">{{ data.category.name }}</template></Column>
        <Column header="金額" field="amount" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="費用日" field="incurredAt"><template #body="{ data }">{{ formatDate(data.incurredAt) }}</template></Column>
        <Column v-if="tab === 'reviewed'" header="對應支出">
          <template #body="{ data }">
            <template v-if="['approved', 'paid'].includes(data.status)">
              <span v-if="data.expenseId" class="tag-soft tag-success">已建立</span>
              <span v-else class="tag-soft tag-warn">未建立</span>
            </template>
            <span v-else class="text-[var(--color-muted)]">—</span>
          </template>
        </Column>
        <Column header="更新時間" field="updatedAt"><template #body="{ data }">{{ formatDateTime(data.updatedAt) }}</template></Column>
        <Column v-if="tab === 'pending'" header="目前階段">
          <template #body="{ data }"><span class="tag-soft tag-warn">{{ stageOf(data) }}</span></template>
        </Column>
        <Column v-if="tab === 'reviewed'" header="狀態"><template #body="{ data }"><StatusBadge :status="data.status" /></template></Column>
        <Column header-class="act" body-class="act">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <span class="row-actions">
              <template v-if="tab === 'pending'">
                <Button label="通過" size="small" outlined @click.stop="actions.openApprove(data)" />
                <Button label="退回" size="small" severity="danger" outlined @click.stop="actions.openReject([data])" />
              </template>
              <template v-else>
                <Button v-if="actions.can.void(data)" label="作廢" size="small" severity="danger" outlined @click.stop="actions.openPay('void', [data])" />
                <Button v-else-if="actions.can.revertVoid(data)" label="取消作廢" size="small" outlined @click.stop="actions.openPay('revert-void', [data])" />
                <Button icon="pi pi-eye" outlined size="small" aria-label="查看明細" v-tooltip.top="'查看明細'" @click.stop="openId = data.id" />
              </template>
            </span>
          </template>
        </Column>
      </DataTable>
    </section>

    <ReimbursementDrawer ref="drawerRef" v-model:id="openId" :ctx="actions" />
    <ReimbursementDialogs :ctx="actions" />
  </div>
</template>
