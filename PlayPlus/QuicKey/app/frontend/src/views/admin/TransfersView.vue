<script setup lang="ts">
/**
 * 資金移轉（PRD 規則 18、19；docs/dev/transfers-api.md）。
 * 列表走伺服器端分頁；垃圾桶模式共用同一組分頁狀態，只有「還原 / 永久刪除」。
 */
import { computed, onMounted, reactive, ref, watch } from 'vue'
import type { DataTableRowClickEvent } from 'primevue/datatable'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import DatePicker from '@/components/qds/DatePicker'
import Drawer from 'primevue/drawer'
import Menu from 'primevue/menu'
import Select from 'primevue/select'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import NoAccountNotice from '@/components/admin/NoAccountNotice.vue'
import TransferDetail from '@/components/admin/TransferDetail.vue'
import TransferDialog from '@/components/admin/TransferDialog.vue'
import { HttpError } from '@/api/service'
import {
  deleteTransfer,
  getTransfer,
  listTransfers,
  purgeTransfer,
  restoreTransfer,
  type ListTransfersQuery,
  type TransferSummary,
} from '@/api/transfers'
import { useAccountOptions } from '@/composables/useAccountOptions'
import { useOpenQuery } from '@/composables/useOpenQuery'
import { usePagedList } from '@/composables/usePagedList'
import type { Transfer } from '@/types/domain'
import { formatCurrencyExact, formatDate, toIsoDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import { userErrorToast } from '@/utils/userFeedback'

const confirm = useConfirm()
const toast = useToast()

const trashMode = ref(false)
const filters = reactive({
  dateRange: null as (Date | null)[] | null,
  fromAccountId: null as string | null,
  toAccountId: null as string | null,
})
const isFiltered = computed(
  () => !!filters.dateRange?.some((d) => d instanceof Date) || !!filters.fromAccountId || !!filters.toAccountId,
)

function clearFilters() {
  filters.dateRange = null
  filters.fromAccountId = null
  filters.toAccountId = null
}

const { options: accounts, loaded: accountsLoaded, load: loadAccounts } = useAccountOptions()
/**
 * 移轉要選兩個不同帳戶（PRD 第 20 條）：少於兩個時停用新增入口並提示前往帳戶設定，
 * 比照新增支出；載入完成前不判斷，避免入口閃一下停用。
 */
const tooFewAccounts = computed(() => accountsLoaded.value && accounts.value.length < 2)
const noAccountNotice = computed(() =>
  accounts.value.length === 0
    ? { title: '請先建立帳戶', detail: '資金移轉要選擇轉出與轉入兩個帳戶，公司建立帳戶後才能新增。' }
    : { title: '至少需要兩個帳戶', detail: '資金移轉要選擇轉出與轉入兩個不同的帳戶，請再建立一個帳戶。' },
)

function filterQuery(): ListTransfersQuery {
  const [from, to] = filters.dateRange ?? []
  return {
    dateFrom: from instanceof Date ? toIsoDate(from) : undefined,
    dateTo: to instanceof Date ? toIsoDate(to) : undefined,
    fromAccountId: filters.fromAccountId ?? undefined,
    toAccountId: filters.toAccountId ?? undefined,
  }
}

// 第一次載入完成前不顯示空狀態，避免閃一下
const loaded = ref(false)
const {
  rows,
  total,
  page,
  pageSize,
  loading,
  failed: loadFailed,
  refresh,
  reset,
  onPage,
} = usePagedList<TransferSummary>({
  fetcher: (query) => listTransfers({ ...(trashMode.value ? { discarded: true } : filterQuery()), ...query }),
  failTitle: () => (trashMode.value ? '載入垃圾桶失敗' : '載入資金移轉失敗'),
  onLoaded: () => (loaded.value = true),
})

onMounted(() => {
  void refresh()
  void loadAccounts()
})

watch([trashMode, filters], () => {
  reset()
  void refresh()
})

const emptyText = computed(() => {
  if (loadFailed.value) return trashMode.value ? '垃圾桶載入失敗，請重新整理頁面' : '資金移轉載入失敗，請重新整理頁面'
  if (trashMode.value) return '垃圾桶是空的'
  return '沒有符合條件的移轉'
})

const showEmptyGuide = computed(
  () => !trashMode.value && loaded.value && !loading.value && !loadFailed.value && total.value === 0 && !isFiltered.value,
)

// ─── 新增 / 編輯 ─────────────────────────────────
const dialogOpen = ref(false)
const editing = ref<Transfer | null>(null)
const editLoading = ref(false)

function openCreate() {
  editing.value = null
  dialogOpen.value = true
}
function openEdit(t: Transfer) {
  editing.value = t
  dialogOpen.value = true
}
/** 列表沒有憑證，編輯前要取完整資料 */
async function openEditFromRow(id: string) {
  editLoading.value = true
  try {
    openEdit(await getTransfer(id))
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '載入移轉失敗'), life: 3500 })
  } finally {
    editLoading.value = false
  }
}

async function onSaved(saved: Transfer) {
  if (detailId.value === saved.id) detail.value = saved
  await refresh()
}

/** 編輯視窗刪了已存圖檔：立即生效，開著的明細與編輯中的資料同步更新（列表不含圖檔，不必重撈） */
function onAttachmentDeleted(t: Transfer) {
  if (detailId.value === t.id) detail.value = t
  if (editing.value?.id === t.id) editing.value = t
}

// ─── 明細抽屜 ────────────────────────────────────
const detailId = ref<string | null>(null)
const detail = ref<Transfer | null>(null)
const detailLoading = ref(false)

let detailSeq = 0
watch(detailId, async (id) => {
  const seq = ++detailSeq
  detail.value = null
  if (!id) return
  detailLoading.value = true
  try {
    const t = await getTransfer(id)
    if (seq !== detailSeq) return
    detail.value = t
    // 從支出詳情連過來時，切到移轉所在的列表
    trashMode.value = !!t.deletedAt
  } catch (err) {
    if (seq !== detailSeq) return
    toast.add({ severity: 'error', ...userErrorToast(err, '載入移轉失敗'), life: 3500 })
    detailId.value = null
  } finally {
    if (seq === detailSeq) detailLoading.value = false
  }
})
useOpenQuery(detailId)

function onRowClick(evt: DataTableRowClickEvent) {
  detailId.value = (evt.data as TransferSummary).id
}

function transferLabel(t: TransferSummary): string {
  return `${t.fromAccount.name} → ${t.toAccount.name}`
}

// ─── 移至垃圾桶 ──────────────────────────────────
function confirmDelete(t: TransferSummary) {
  confirm.require({
    header: '移至垃圾桶',
    message: `確定要把移轉「${transferLabel(t)}」${formatCurrencyExact(t.amount)} 移至垃圾桶嗎？${t.fee > 0 ? '手續費支出會一併移入。' : ''}可在垃圾桶還原。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '移至垃圾桶',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: () => softDelete(t),
  })
}

async function softDelete(t: TransferSummary) {
  try {
    await deleteTransfer(t.id)
    if (detailId.value === t.id) detailId.value = null
    toast.add({ severity: 'success', summary: '已移至垃圾桶', detail: '可從垃圾桶還原', life: 2500 })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '刪除失敗'), life: 3500 })
  }
  await refresh()
}

// ─── 垃圾桶：還原 / 永久刪除 ───────────────────────
/** 移轉進垃圾桶後，帳戶的起始月份才調到移轉日期之後，後端回 409 */
function isDateBlocked(err: unknown): boolean {
  return err instanceof HttpError && (err.body as { error?: string })?.error === 'TRANSFER_DATE_BEFORE_OPENING'
}

async function restoreOne(t: TransferSummary) {
  try {
    await restoreTransfer(t.id)
    toast.add({
      severity: 'success',
      summary: '已還原',
      detail: t.fee > 0 ? '回到資金移轉列表，手續費支出一併還原' : '回到資金移轉列表',
      life: 2500,
    })
    if (detailId.value === t.id) detailId.value = null
  } catch (err) {
    toast.add({ severity: isDateBlocked(err) ? 'warn' : 'error', ...userErrorToast(err, '還原失敗'), life: 3500 })
  }
  await refresh()
}

function confirmPurge(t: TransferSummary) {
  confirm.require({
    header: '永久刪除',
    message: `將永久刪除移轉「${transferLabel(t)}」，相關的手續費支出也會一併永久刪除。刪除後無法還原。確定嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '永久刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    defaultFocus: 'reject',
    accept: () => purgeOne(t),
  })
}

async function purgeOne(t: TransferSummary) {
  try {
    await purgeTransfer(t.id)
    if (detailId.value === t.id) detailId.value = null
    toast.add({ severity: 'success', summary: '已永久刪除', life: 2500 })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '永久刪除失敗'), life: 3500 })
  }
  await refresh()
}

// ─── 選單 ────────────────────────────────────────
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = [{ label: '垃圾桶', icon: 'pi pi-trash', command: () => (trashMode.value = true) }]

const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<TransferSummary | null>(null)
const rowMenuItems = computed(() => {
  const t = menuTarget.value
  if (!t) return []
  return [
    { label: '查看明細', icon: 'pi pi-eye', command: () => (detailId.value = t.id) },
    { label: '編輯', icon: 'pi pi-pencil', command: () => openEditFromRow(t.id) },
    { separator: true },
    { label: '移至垃圾桶', icon: 'pi pi-trash', class: 'menu-danger', command: () => confirmDelete(t) },
  ]
})
function openRowMenu(e: MouseEvent, t: TransferSummary) {
  menuTarget.value = t
  rowMenu.value?.toggle(e)
}
</script>

<template>
  <div class="dash-page">
    <PageHeader :title="trashMode ? '資金移轉垃圾桶' : '資金移轉'" size="admin">
      <template #actions>
        <Button v-if="trashMode" label="返回資金移轉" icon="pi pi-arrow-left" outlined @click="trashMode = false" />
        <template v-else>
          <Button label="新增資金移轉" icon="pi pi-plus" :disabled="tooFewAccounts" @click="openCreate" />
          <Button
            v-tooltip.bottom="'更多動作'"
            icon="pi pi-ellipsis-h"
            outlined
            aria-label="更多動作"
            aria-haspopup="true"
            @click="pageMenu?.toggle($event)"
          />
          <Menu ref="pageMenu" :model="pageMenuItems" popup />
        </template>
      </template>
    </PageHeader>

    <NoAccountNotice
      v-if="!trashMode && tooFewAccounts"
      :title="noAccountNotice.title"
      :detail="noAccountNotice.detail"
    />

    <EmptyState
      v-if="showEmptyGuide"
      icon="pi pi-arrow-right-arrow-left"
      title="還沒有資金移轉"
      description="帳戶之間搬移資金時在這裡記錄，例如從銀行提領到零用金。不計入收入與支出，只影響帳戶餘額。"
    >
      <template #action>
        <Button label="新增資金移轉" icon="pi pi-plus" :disabled="tooFewAccounts" @click="openCreate" />
      </template>
    </EmptyState>

    <section
      v-else
      class="dash-panel dash-table-panel"
      :class="{ 'trash-table-panel': trashMode }"
      :aria-label="trashMode ? '資金移轉垃圾桶' : '資金移轉列表'"
    >
      <div v-if="!trashMode" class="list-head">
        <div class="dash-filter transfer-filters">
          <DatePicker
            v-model="filters.dateRange"
            selection-mode="range"
            date-format="yy/mm/dd"
            placeholder="移轉日期區間"
            show-icon
            icon-display="input"
            show-button-bar
            :manual-input="false"
            class="w-[240px]"
            aria-label="移轉日期區間"
          />
          <Select
            v-model="filters.fromAccountId"
            :options="accounts"
            option-label="name"
            option-value="id"
            placeholder="全部轉出帳戶"
            show-clear
            class="w-[200px]"
            aria-label="轉出帳戶"
          />
          <Select
            v-model="filters.toAccountId"
            :options="accounts"
            option-label="name"
            option-value="id"
            placeholder="全部轉入帳戶"
            show-clear
            class="w-[200px]"
            aria-label="轉入帳戶"
          />
          <Button v-if="isFiltered" label="清除篩選" text size="small" @click="clearFilters" />
        </div>
      </div>
      <DataTable
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '860px' }"
        lazy
        paginator
        :first="(page - 1) * pageSize"
        :rows="pageSize"
        :total-records="total"
        :loading="loading || editLoading"
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
            {{ loading ? '' : emptyText }}
            <Button v-if="!loading && !trashMode && isFiltered" label="清除篩選" text size="small" @click="clearFilters" />
          </div>
        </template>
        <Column header="移轉日期">
          <template #body="{ data }"><span class="tabular-nums whitespace-nowrap">{{ formatDate(data.transferDate) }}</span></template>
        </Column>
        <Column header="轉出帳戶">
          <template #body="{ data }">{{ data.fromAccount.name }}</template>
        </Column>
        <Column header="轉入帳戶">
          <template #body="{ data }">{{ data.toAccount.name }}</template>
        </Column>
        <Column header="金額" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrencyExact(data.amount) }}</template>
        </Column>
        <Column header="手續費" header-class="num" body-class="num">
          <template #body="{ data }">{{ data.fee > 0 ? formatCurrencyExact(data.fee) : '—' }}</template>
        </Column>
        <Column v-if="!trashMode" header="備註">
          <template #body="{ data }">
            <div class="cell-trunc transfer-note" :title="data.note || undefined">{{ data.note || '—' }}</div>
          </template>
        </Column>
        <Column v-if="trashMode" header="刪除時間" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="tabular-nums whitespace-nowrap">{{ data.deletedAt ? formatDate(data.deletedAt) : '—' }}</span>
          </template>
        </Column>
        <Column v-if="trashMode" header="操作人" :style="{ width: '1%' }">
          <template #body="{ data }"><span class="whitespace-nowrap">{{ data.deletedBy?.name ?? '—' }}</span></template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <div v-if="trashMode" class="flex gap-1 justify-end">
              <Button label="還原" icon="pi pi-undo" text size="small" @click.stop="restoreOne(data as TransferSummary)" />
              <Button
                label="永久刪除"
                icon="pi pi-trash"
                text
                size="small"
                severity="danger"
                @click.stop="confirmPurge(data as TransferSummary)"
              />
            </div>
            <Button v-else icon="pi pi-ellipsis-h" text rounded severity="secondary" class="row-more" :aria-label="`${data.fromAccount.name} 轉到 ${data.toAccount.name} 更多動作`" aria-haspopup="true" @click.stop="openRowMenu($event, data as TransferSummary)" />
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
        <div class="q-drawer-head">
          <span>移轉明細</span>
          <span v-if="detail?.deletedAt" class="tag-soft tag-neutral">垃圾桶</span>
        </div>
      </template>
      <div v-if="detailLoading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
      <TransferDetail v-else-if="detail" :key="detail.updatedAt" :transfer="detail" />
      <template v-if="detail" #footer>
        <div class="q-drawer-foot">
          <template v-if="detail.deletedAt">
            <Button label="永久刪除" severity="danger" text @click="confirmPurge(detail)" />
            <span class="q-gap" />
            <Button label="還原" @click="restoreOne(detail)" />
          </template>
          <template v-else>
            <Button label="移至垃圾桶" severity="danger" text @click="confirmDelete(detail)" />
            <span class="q-gap" />
            <Button label="編輯" @click="openEdit(detail)" />
          </template>
        </div>
      </template>
    </Drawer>

    <TransferDialog
      v-model:visible="dialogOpen"
      :transfer="editing"
      @saved="onSaved"
      @attachment-deleted="onAttachmentDeleted"
    />

    <Menu ref="rowMenu" :model="rowMenuItems" popup />
  </div>
</template>

<style scoped>
.transfer-filters { margin-bottom: 0; padding-block: 12px; }
.transfer-note { max-width: 240px; }
</style>
