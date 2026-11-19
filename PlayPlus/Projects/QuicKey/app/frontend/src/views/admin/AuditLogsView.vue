<script setup lang="ts">
/**
 * 稽核日誌（PRD 規則 15、16；docs/資料模型.md §2.7）。
 * 唯讀：列表走伺服器端分頁，明細一律重撈；沒有編輯、刪除的入口。
 */
import { computed, onMounted, reactive, ref, watch } from 'vue'
import type { DataTableRowClickEvent } from 'primevue/datatable'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import DatePicker from '@/components/qds/DatePicker'
import Drawer from 'primevue/drawer'
import Select from 'primevue/select'
import { useToast } from 'primevue/usetoast'
import PageHeader from '@/components/PageHeader.vue'
import AuditDiffList from '@/components/admin/AuditDiffList.vue'
import {
  getAuditLog,
  listAuditLogs,
  type AuditAction,
  type AuditLogDetail,
  type AuditLogSummary,
  type AuditTargetType,
  type ListAuditLogsQuery,
} from '@/api/audit-logs'
import { listUsers } from '@/api/users'
import { useOpenQuery } from '@/composables/useOpenQuery'
import { usePagedList } from '@/composables/usePagedList'
import {
  AUDIT_ACTION_OPTIONS,
  AUDIT_TARGET_OPTIONS,
  auditDiffRows,
  auditTargetText,
  entryActionLabel,
} from '@/constants/auditLog'
import { formatDateTime, toIsoDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import { userErrorToast } from '@/utils/userFeedback'

const toast = useToast()

const filters = reactive({
  targetType: null as AuditTargetType | null,
  action: null as AuditAction | null,
  actorId: null as string | null,
  dateRange: null as (Date | null)[] | null,
})
const isFiltered = computed(
  () =>
    !!filters.targetType ||
    !!filters.action ||
    !!filters.actorId ||
    !!filters.dateRange?.some((d) => d instanceof Date),
)

function clearFilters() {
  filters.targetType = null
  filters.action = null
  filters.actorId = null
  filters.dateRange = null
}

function filterQuery(): ListAuditLogsQuery {
  const [from, to] = filters.dateRange ?? []
  return {
    targetType: filters.targetType ?? undefined,
    action: filters.action ?? undefined,
    actorId: filters.actorId ?? undefined,
    dateFrom: from instanceof Date ? toIsoDate(from) : undefined,
    dateTo: to instanceof Date ? toIsoDate(to) : undefined,
  }
}

const { rows, total, page, pageSize, loading, failed, refresh, reset, onPage } = usePagedList<AuditLogSummary>({
  fetcher: (query) => listAuditLogs({ ...filterQuery(), ...query }),
  failTitle: () => '載入稽核日誌失敗',
})

/** 操作人選項：含已停用的人；邀請中還沒有帳號，不會有操作紀錄。名稱空白時同列表退回 email */
const actors = ref<{ id: string; name: string }[]>([])
async function loadActors() {
  try {
    const users = await listUsers()
    actors.value = users
      .filter((u) => u.status !== 'invited')
      .map((u) => ({ id: u.id, name: u.name.trim() || u.email }))
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '載入操作人失敗'), life: 3500 })
  }
}

onMounted(() => {
  void refresh()
  void loadActors()
})

watch(filters, () => {
  reset()
  void refresh()
})

const emptyText = computed(() => {
  if (failed.value) return '稽核日誌載入失敗，請重新整理頁面'
  return isFiltered.value ? '沒有符合條件的紀錄' : '目前沒有紀錄'
})


// ─── 明細抽屜 ────────────────────────────────────
const detailId = ref<string | null>(null)
const detail = ref<AuditLogDetail | null>(null)
const detailLoading = ref(false)

let detailSeq = 0
watch(detailId, async (id) => {
  const seq = ++detailSeq
  detail.value = null
  if (!id) {
    detailLoading.value = false
    return
  }
  detailLoading.value = true
  try {
    const entry = await getAuditLog(id)
    if (seq !== detailSeq) return
    detail.value = entry
  } catch (err) {
    if (seq !== detailSeq) return
    toast.add({ severity: 'error', ...userErrorToast(err, '載入稽核日誌失敗'), life: 3500 })
    detailId.value = null
  } finally {
    if (seq === detailSeq) detailLoading.value = false
  }
})
useOpenQuery(detailId)

const detailRows = computed(() => (detail.value ? auditDiffRows(detail.value, detail.value.targetType) : []))

function onRowClick(evt: DataTableRowClickEvent) {
  detailId.value = (evt.data as AuditLogSummary).id
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="稽核日誌" size="admin" />

    <section class="dash-panel dash-table-panel audit-table" aria-label="稽核日誌列表">
      <div class="list-head">
        <div class="dash-filter audit-filters">
          <Select
            v-model="filters.targetType"
            :options="AUDIT_TARGET_OPTIONS"
            option-label="label"
            option-value="value"
            placeholder="全部對象"
            show-clear
            class="w-[180px]"
            aria-label="對象"
          />
          <Select
            v-model="filters.action"
            :options="AUDIT_ACTION_OPTIONS"
            option-label="label"
            option-value="value"
            placeholder="全部動作"
            show-clear
            class="w-[160px]"
            aria-label="動作"
          />
          <Select
            v-model="filters.actorId"
            :options="actors"
            option-label="name"
            option-value="id"
            placeholder="全部操作人"
            show-clear
            class="w-[160px]"
            aria-label="操作人"
          />
          <DatePicker
            v-model="filters.dateRange"
            selection-mode="range"
            date-format="yy/mm/dd"
            placeholder="操作日期區間"
            show-icon
            icon-display="input"
            show-button-bar
            :manual-input="false"
            class="w-[240px]"
            aria-label="操作日期區間"
          />
          <Button v-if="isFiltered" label="清除篩選" text size="small" @click="clearFilters" />
        </div>
      </div>
      <DataTable
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '680px' }"
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
        :pt="{ bodyRow: { class: 'q-clickable' } }"
        @page="onPage"
        @row-click="onRowClick"
      >
        <template #empty>
          <div class="dash-empty">
            {{ loading ? '' : emptyText }}
            <Button v-if="!loading && isFiltered" label="清除篩選" text size="small" @click="clearFilters" />
          </div>
        </template>
        <Column header="時間" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="tabular-nums whitespace-nowrap">{{ formatDateTime(data.createdAt) }}</span>
          </template>
        </Column>
        <Column header="操作人" :style="{ width: '1%' }">
          <template #body="{ data }"><span class="whitespace-nowrap">{{ data.actorName || '系統' }}</span></template>
        </Column>
        <Column header="對象">
          <template #body="{ data }">
            <div class="cell-trunc audit-target" :title="auditTargetText(data)">{{ auditTargetText(data) }}</div>
          </template>
        </Column>
        <Column header="動作">
          <template #body="{ data }"><span class="whitespace-nowrap">{{ entryActionLabel(data) }}</span></template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">變更前後內容</span></template>
          <template #body="{ data }">
            <!-- 整列可點只有滑鼠用得到，鍵盤從這顆按鈕開明細 -->
            <Button
              v-tooltip.top="'查看變更內容'"
              outlined
              size="small"
              :aria-label="`查看 ${formatDateTime(data.createdAt)} 的變更內容`"
              @click.stop="detailId = data.id"
            >
              <template #icon><i class="pi pi-eye" aria-hidden="true" /></template>
            </Button>
          </template>
        </Column>
      </DataTable>
    </section>

    <Drawer
      :visible="detailId !== null"
      position="right"
      class="!w-full sm:!w-[560px]"
      @update:visible="(v: boolean) => { if (!v) detailId = null }"
    >
      <template #header>
        <div class="q-drawer-head audit-drawer-head"><span>稽核日誌明細</span></div>
      </template>
      <div v-if="detailLoading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
      <div v-else-if="detail" class="dt-body">
        <div class="dt-summary">
          <div class="dt-summary-title">{{ entryActionLabel(detail) }}</div>
          <div class="dt-summary-sub">{{ auditTargetText(detail) }}</div>
          <div class="dt-summary-sub">
            {{ detail.actorName || '系統' }} ·
            <span class="tabular-nums">{{ formatDateTime(detail.createdAt) }}</span>
          </div>
        </div>
        <section class="dt-section audit-detail">
          <h3 class="dt-section-title">變更前後內容</h3>
          <AuditDiffList v-if="detailRows.length" :rows="detailRows" class="audit-diff" />
          <p v-else class="dt-empty">這筆紀錄沒有欄位內容</p>
        </section>
      </div>
    </Drawer>
  </div>
</template>

<style scoped>
.audit-filters { margin-bottom: 0; padding-block: 12px; }
.audit-target { max-width: 260px; }
.audit-diff { font-size: 14px; }
/* 表格、分頁與抽屜標題的共用樣式是 16px 以上，手機版要壓到 14px */
@media (max-width: 639.98px) {
  .audit-table :deep(.p-datatable-thead > tr > th),
  .audit-table :deep(.p-datatable-tbody > tr > td),
  .audit-table :deep(.p-paginator),
  .audit-table :deep(.p-paginator-current),
  .audit-table :deep(.p-paginator-content .p-select-label),
  .audit-drawer-head,
  .audit-detail .dt-section-title { font-size: 14px; }
}
</style>
