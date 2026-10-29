<script setup lang="ts">
/**
 * 請款記錄：員工送出的代墊款請款單（不含草稿）。
 * 走伺服器端分頁 + 篩選；點列開右側明細（含簽核進度與可做的動作）；可匯出 CSV / XLSX。
 */
import { computed, onMounted, ref, useTemplateRef, watch } from 'vue'
import type { ReimbursementStatus } from '@/types/domain'
import {
  exportReimbursements,
  listAdminReimbursements,
  type AdminReimbursementListFilters,
  type ReimbursementExportFormat,
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

type StatusTab = 'all' | Exclude<ReimbursementStatus, 'draft'>
const tab = ref<StatusTab>('all')
const TAB_DEFS: { value: StatusTab; label: string }[] = [
  { value: 'all', label: '全部' },
  { value: 'in_review', label: '簽核中' },
  { value: 'rejected', label: '退回' },
  { value: 'approved', label: '已核銷' },
  { value: 'paid', label: '已發放' },
  { value: 'voided', label: '已作廢' },
]
// 分頁數字只顯示還需要處理的狀態（簽核中、駁回、已核銷待發放）；全部與終點狀態不顯示
const COUNTED_TABS: Exclude<StatusTab, 'all'>[] = ['in_review', 'rejected', 'approved']

// ─── 伺服器端分頁 state ─────────────────────────────
const rows = ref<ReimbursementSummary[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const loading = ref(false)
// 待處理 tab 計數獨立 fetch；終點 tab 不顯示數字
const tabCounts = ref<Record<string, number>>({})

const filterOpen = ref(false)
const activeFilterCount = computed(() => (f.categories.length ? 1 : 0) + (f.dateRange && f.dateRange.some((d) => d instanceof Date) ? 1 : 0) + (f.min !== null || f.max !== null ? 1 : 0))

const tabs = computed(() =>
  TAB_DEFS.map((t) =>
    COUNTED_TABS.includes(t.value as Exclude<StatusTab, 'all'>)
      ? { ...t, count: tabCounts.value[t.value] ?? 0 }
      : t,
  ),
)

// ─── 把篩選狀態轉成 API query ───────────────────────
function buildQuery(overrides: Partial<AdminReimbursementListFilters> = {}): AdminReimbursementListFilters {
  const query: AdminReimbursementListFilters = {
    status: tab.value === 'all' ? undefined : tab.value,
    q: f.keyword.trim() || undefined,
    categoryIds: f.categories.length ? f.categories : undefined,
    amountMin: f.min ?? undefined,
    amountMax: f.max ?? undefined,
    page: page.value,
    perPage: pageSize.value,
  }
  if (f.dateRange) {
    const [from, to] = f.dateRange
    if (from instanceof Date) query.dateFrom = toIsoDate(from)
    if (to instanceof Date) query.dateTo = toIsoDate(to)
  }
  return { ...query, ...overrides }
}

async function refreshList() {
  loading.value = true
  try {
    const resp = await listAdminReimbursements(buildQuery())
    rows.value = resp.data
    total.value = resp.meta.total
  } catch {
    toast.add({ severity: 'error', summary: '載入請款記錄失敗', life: 3000 })
  } finally {
    loading.value = false
  }
}

async function refreshCounts() {
  const base = buildQuery({ page: 1, perPage: 1 })
  const entries = await Promise.all(
    COUNTED_TABS.map(async (status) => {
      try {
        const resp = await listAdminReimbursements({ ...base, status })
        return [status, resp.meta.total] as const
      } catch {
        return [status, 0] as const
      }
    }),
  )
  tabCounts.value = Object.fromEntries(entries)
}

async function refreshAll() {
  await Promise.all([refreshList(), refreshCounts()])
}

onMounted(refreshAll)

// 篩選 / tab 變動 → 重設到第 1 頁、refetch
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
  () => [tab.value, [...f.categories], f.dateRange, f.min, f.max],
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

// ─── 抽屜開關與動作 ─────────────────────────────────
const openId = ref<string | null>(null)
const drawerRef = useTemplateRef<InstanceType<typeof ReimbursementDrawer>>('drawerRef')
const actions = useReimbursementActions(async () => {
  await refreshAll()
  drawerRef.value?.refetch()
})

function onRowClick(e: DataTableRowClickEvent) {
  openId.value = (e.data as ReimbursementSummary).id
}
// 抽屜開關與網址 ?open 同步（可從其他頁連過來，按上一頁也能回到抽屜）
useOpenQuery(openId)

// ─── 匯出 ──────────────────────────────────────────
// 把當前篩選條件原封不動傳給後端 /reimbursements/export；後端一次吐檔案串流回來。
async function exportAs(format: ReimbursementExportFormat) {
  const q = buildQuery()
  // 匯出一律不分頁；拿掉 page / perPage 避免後端誤判
  delete q.page
  delete q.perPage
  loading.value = true
  try {
    await exportReimbursements(format, q)
    toast.add({ severity: 'success', summary: `已匯出 ${format.toUpperCase()}`, life: 2000 })
  } catch {
    toast.add({ severity: 'error', summary: '匯出失敗', life: 3000 })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="請款記錄" size="admin">
      <template #actions>
        <Button label="匯出 CSV" icon="pi pi-download" outlined :disabled="loading || !total" @click="exportAs('csv')" />
        <Button label="匯出 XLSX" icon="pi pi-file-excel" outlined :disabled="loading || !total" @click="exportAs('xlsx')" />
      </template>
    </PageHeader>

    <section class="dash-panel dash-table-panel" aria-label="請款列表" data-tour="records-table">
      <div class="list-head">
        <TabBar v-model="tab" :tabs="tabs" label="請款狀態" variant="segmented" />
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
            aria-controls="records-filters"
            @click="filterOpen = !filterOpen"
          />
        </div>
      </div>
      <div class="filter-collapse" :class="{ open: filterOpen }" :inert="!filterOpen">
        <ReimbursementToolbar id="records-filters" :filters="f" :filtered="isFiltered" :show-search="false" @reset="reset" />
      </div>
      <DataTable
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '960px' }"
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
            {{ isFiltered ? '沒有符合條件的請款單' : '這個狀態目前沒有請款單' }}
            <Button v-if="isFiltered" label="清除所有篩選" text size="small" @click="reset" />
          </div>
        </template>
        <Column header="申請人">
          <template #body="{ data }">
            <div class="cell-trunc">{{ data.employee.name }}</div>
            <div class="cell-sub" :title="data.description">{{ data.description }}</div>
          </template>
        </Column>
        <Column header="類別"><template #body="{ data }">{{ data.category.name }}</template></Column>
        <Column header="金額" field="amount" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="費用日" field="incurredAt"><template #body="{ data }">{{ formatDate(data.incurredAt) }}</template></Column>
        <Column header="建立時間" field="createdAt"><template #body="{ data }">{{ formatDateTime(data.createdAt) }}</template></Column>
        <Column header="狀態" :style="{ width: '1%' }"><template #body="{ data }"><StatusBadge :status="data.status" /></template></Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <Button icon="pi pi-eye" outlined size="small" aria-label="查看明細" v-tooltip.top="'查看明細'" @click.stop="openId = data.id" />
          </template>
        </Column>
      </DataTable>
    </section>

    <ReimbursementDrawer ref="drawerRef" v-model:id="openId" :ctx="actions" />
    <ReimbursementDialogs :ctx="actions" />
  </div>
</template>
