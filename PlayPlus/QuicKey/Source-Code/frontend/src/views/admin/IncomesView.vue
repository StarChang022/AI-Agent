<script setup lang="ts">
/**
 * 收入管理：公司所有收入列表。
 * 版型對齊 ExpensesView，但簡化：無來源欄、無付款批次。
 * 行動作：編輯 / 標記已收款 / 取消收款 / 刪除。
 * 垃圾桶模式：還原 / 永久刪除。
 * 狀態管理：採 CategoriesView 模式，直接呼叫 api/incomes，不經 Pinia store。
 */
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { CollectionStatus, Income } from '@/types/domain'
import {
  collectIncome,
  deleteIncome,
  listIncomes,
  listTrashedIncomes,
  purgeIncome,
  restoreIncome,
  revertCollectIncome,
} from '@/api/incomes'
import { listCategories, type Category } from '@/api/categories'
import { formatCurrency, formatDate, toIsoDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import PageHeader from '@/components/PageHeader.vue'
import { DELETE_BLOCKED, userErrorToast } from '@/utils/userFeedback'
import EmptyState from '@/components/EmptyState.vue'
import IncomeDetail from '@/components/admin/IncomeDetail.vue'
import TabBar from '@/components/qds/TabBar.vue'
import SearchInput from '@/components/qds/SearchInput.vue'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable, { type DataTableRowClickEvent } from 'primevue/datatable'
import DatePicker from 'primevue/datepicker'
import Dialog from 'primevue/dialog'
import Drawer from 'primevue/drawer'
import Menu from 'primevue/menu'
import MultiSelect from 'primevue/multiselect'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import { useOpenQuery } from '@/composables/useOpenQuery'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

function goNew() {
  router.push({ name: 'admin-income-new' })
}

/** 正常列表。進頁 fetch 一次；之後 CRUD 都走 upsertLocal / removeLocal 就地更新。 */
const incomes = ref<Income[]>([])
/** 垃圾桶列表（已軟刪）；進垃圾桶模式時 fetch，還原後就地移除。 */
const trashedItems = ref<Income[]>([])
const loading = ref(false)
const trashMode = ref(false)

async function refetch() {
  loading.value = true
  try {
    incomes.value = await listIncomes()
  } catch (err) {
    toast.add({
      severity: 'error',
      ...userErrorToast(err, '載入收入失敗'),
      life: 3500,
    })
    incomes.value = []
  } finally {
    loading.value = false
  }
}
async function reloadTrashed() {
  loading.value = true
  try {
    trashedItems.value = await listTrashedIncomes()
  } catch (err) {
    toast.add({
      severity: 'error',
      ...userErrorToast(err, '載入垃圾桶失敗'),
      life: 3500,
    })
    trashedItems.value = []
  } finally {
    loading.value = false
  }
}
function upsertLocal(i: Income) {
  const idx = incomes.value.findIndex((x) => x.id === i.id)
  if (idx === -1) incomes.value.unshift(i)
  else incomes.value.splice(idx, 1, i)
}
function removeLocal(id: string) {
  const idx = incomes.value.findIndex((x) => x.id === id)
  if (idx !== -1) incomes.value.splice(idx, 1)
}
function removeTrashedLocal(id: string) {
  const idx = trashedItems.value.findIndex((x) => x.id === id)
  if (idx !== -1) trashedItems.value.splice(idx, 1)
}

async function enterTrashMode() {
  trashMode.value = true
  detailId.value = null
  await reloadTrashed()
}
function exitTrashMode() {
  trashMode.value = false
  trashedItems.value = []
}

const activeCategories = ref<Category[]>([])
onMounted(async () => {
  await Promise.allSettled([
    refetch(),
    listCategories({ kind: 'income' })
      .then((list) => {
        activeCategories.value = list
      })
      .catch(() => {
        activeCategories.value = []
      }),
  ])
})
const categoryFilterOptions = computed(() =>
  activeCategories.value.map((c) => ({ value: c.id, label: c.name })),
)

// ─── 篩選 ─────────────────────────────────────────
type StatusTab = 'all' | CollectionStatus
interface Filters {
  keyword: string
  categories: string[]
  dateRange: (Date | null)[] | null
  status: StatusTab
}
const emptyFilters = (): Filters => ({ keyword: '', categories: [], dateRange: null, status: 'all' })
const f = reactive<Filters>(emptyFilters())
function resetAll() {
  Object.assign(f, emptyFilters())
}

const baseFilter = computed<Income[]>(() => {
  const kw = f.keyword.trim().toLowerCase()
  return incomes.value.filter((i) => {
    if (f.categories.length && !f.categories.includes(i.category.id)) return false
    if (f.dateRange) {
      const [from, to] = f.dateRange
      if (from instanceof Date && i.date < toIsoDate(from)) return false
      if (to instanceof Date && i.date > toIsoDate(to)) return false
    }
    if (kw && ![i.customer, i.note, i.invoiceNo].join(' ').toLowerCase().includes(kw)) return false
    return true
  })
})
const tabs = computed(() => [
  { value: 'all' as StatusTab, label: '全部' },
  { value: 'uncollected' as StatusTab, label: '待收款', count: baseFilter.value.filter((i) => i.collectionStatus === 'uncollected').length },
  { value: 'collected' as StatusTab, label: '已收款' },
])
const visibleRows = computed(() => baseFilter.value.filter((i) => f.status === 'all' || i.collectionStatus === f.status))
const sortedRows = computed(() =>
  [...visibleRows.value].sort(
    (a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt),
  ),
)

const isFiltered = computed(
  () => !!f.keyword.trim() || f.categories.length > 0 || !!(f.dateRange && f.dateRange.some((d) => d instanceof Date)),
)
const hasAnyData = computed(() => incomes.value.length > 0)

const filterOpen = ref(false)
const activeFilterCount = computed(
  () => (f.categories.length ? 1 : 0) + (f.dateRange && f.dateRange.some((d) => d instanceof Date) ? 1 : 0),
)
function clearPanelFilters() {
  f.categories = []
  f.dateRange = null
}

// ─── 行動作：收款 / 取消收款 / 刪除 ─────────────────
// 標記已收款走 Dialog 選收款日（預設今日，可改）
const collectDialog = reactive({
  visible: false,
  target: null as Income | null,
  date: null as Date | null,
  submitting: false,
})
function openCollectDialog(target: Income) {
  collectDialog.target = target
  collectDialog.date = new Date()
  collectDialog.visible = true
}
async function confirmCollect() {
  if (!collectDialog.target || !collectDialog.date) return
  collectDialog.submitting = true
  try {
    const updated = await collectIncome(collectDialog.target.id, {
      collectedAt: toIsoDate(collectDialog.date),
    })
    upsertLocal(updated)
    toast.add({ severity: 'success', summary: '已標記為已收款', life: 2500 })
    collectDialog.visible = false
    collectDialog.target = null
  } catch (err) {
    toast.add({
      severity: 'error',
      ...userErrorToast(err, '操作失敗'),
      life: 3500,
    })
  } finally {
    collectDialog.submitting = false
  }
}
function confirmRevertCollect(target: Income) {
  confirm.require({
    header: '取消收款',
    message: `確定要把「${target.customer}」${formatCurrency(target.amount)} 改回待收款嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '取消收款',
    rejectLabel: '保留',
    accept: async () => {
      try {
        const updated = await revertCollectIncome(target.id)
        upsertLocal(updated)
        toast.add({ severity: 'success', summary: '已改回待收款', life: 2500 })
      } catch (err) {
        toast.add({
          severity: 'error',
          ...userErrorToast(err, '操作失敗'),
          life: 3500,
        })
      }
    },
  })
}
function confirmDelete(target: Income) {
  if (target.collectionStatus === 'collected') {
    toast.add({
      severity: 'warn',
      ...DELETE_BLOCKED.collected,
      life: 3000,
    })
    return
  }
  confirm.require({
    header: '移至垃圾桶',
    message: `確定要把「${target.customer}」${formatCurrency(target.amount)} 這筆收入移至垃圾桶嗎？可在垃圾桶還原。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '移至垃圾桶',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: () => softDelete(target),
  })
}
async function softDelete(target: Income) {
  try {
    await deleteIncome(target.id)
    removeLocal(target.id)
    if (detailId.value === target.id) detailId.value = null
    toast.add({
      severity: 'success',
      summary: '已移至垃圾桶',
      detail: '可從垃圾桶還原',
      life: 2500,
    })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '刪除失敗'), life: 3500 })
  }
}

// ─── 垃圾桶：還原 / 永久刪除 ───────────────────────
async function restoreOne(target: Income) {
  try {
    const restored = await restoreIncome(target.id)
    removeTrashedLocal(target.id)
    upsertLocal(restored)
    toast.add({ severity: 'success', summary: '已還原', detail: '回到收入列表', life: 2500 })
  } catch (err) {
    toast.add({
      severity: 'error',
      ...userErrorToast(err, '還原失敗'),
      life: 3500,
    })
  }
}
function confirmPurge(target: Income) {
  confirm.require({
    header: '永久刪除',
    message: `將永久刪除「${target.customer}」${formatCurrency(target.amount)} 這筆收入，刪除後無法還原。確定嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '永久刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: () => purgeOne(target),
  })
}
async function purgeOne(target: Income) {
  try {
    await purgeIncome(target.id)
    removeTrashedLocal(target.id)
    toast.add({ severity: 'success', summary: '已永久刪除', life: 2500 })
  } catch (err) {
    toast.add({
      severity: 'error',
      ...userErrorToast(err, '永久刪除失敗'),
      life: 3500,
    })
  }
}

// ─── 明細抽屜 ─────────────────────────────────────
const detailId = ref<string | null>(null)
const detail = computed<Income | null>(() =>
  detailId.value ? incomes.value.find((i) => i.id === detailId.value) ?? null : null,
)
function openDetail(i: Income) {
  detailId.value = i.id
}
function onRowClick(evt: DataTableRowClickEvent) {
  openDetail(evt.data as Income)
}
function goEdit(i: Income) {
  router.push({ name: 'admin-income-edit', params: { id: i.id } })
}

// ─── 頁首 ⋯ 選單（垃圾桶入口） ─────────────────────
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = [
  { label: '垃圾桶', icon: 'pi pi-trash', command: () => enterTrashMode() },
]

// ─── 每列 ⋯ 選單 ───────────────────────────────────
const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<Income | null>(null)
const rowMenuItems = computed(() => {
  const t = menuTarget.value
  if (!t) return []
  return [
    { label: '查看詳情', icon: 'pi pi-eye', command: () => openDetail(t) },
    { label: '編輯', icon: 'pi pi-pencil', command: () => goEdit(t) },
    ...(t.collectionStatus === 'uncollected'
      ? [{ label: '標記為已收款', icon: 'pi pi-check', command: () => openCollectDialog(t) }]
      : [{ label: '取消收款', icon: 'pi pi-undo', command: () => confirmRevertCollect(t) }]),
    { separator: true },
    { label: '移至垃圾桶', icon: 'pi pi-trash', class: 'menu-danger', command: () => confirmDelete(t) },
  ]
})
function openRowMenu(event: MouseEvent, row: Income) {
  menuTarget.value = row
  rowMenu.value?.toggle(event)
}

watch(
  () => route.query.status,
  (status) => {
    if (status === 'uncollected' || status === 'collected' || status === 'all') f.status = status
  },
  { immediate: true },
)
useOpenQuery(detailId, (id) => incomes.value.some((i) => i.id === id))
</script>

<template>
  <div class="dash-page">
    <PageHeader :title="trashMode ? '收入垃圾桶' : '收入管理'" size="admin">
      <template #actions>
        <template v-if="trashMode">
          <Button label="返回收入列表" icon="pi pi-arrow-left" outlined @click="exitTrashMode" />
        </template>
        <template v-else>
          <Button label="新增收入" icon="pi pi-plus" @click="goNew" />
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

    <!-- 垃圾桶模式：獨立 table，只有「還原 / 永久刪除」 -->
    <section v-if="trashMode" class="dash-panel dash-table-panel trash-table-panel" aria-label="收入垃圾桶">
      <DataTable
        :value="trashedItems"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '860px' }"
        :loading="loading"
        paginator
        :rows="10"
        :rows-per-page-options="ROWS_OPTIONS"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
      >
        <template #empty>
          <div class="dash-empty">垃圾桶是空的</div>
        </template>
        <Column header="開立日" field="date">
          <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.date) }}</span></template>
        </Column>
        <Column header="類別">
          <template #body="{ data }">{{ data.category.name }}</template>
        </Column>
        <Column header="客戶">
          <template #body="{ data }">
            <div class="cell-trunc" :title="data.customer">{{ data.customer }}</div>
            <div v-if="data.note" class="cell-sub" :title="data.note">{{ data.note }}</div>
          </template>
        </Column>
        <Column header="金額" field="amount" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="刪除時間" field="deletedAt" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="tabular-nums">{{ data.deletedAt ? formatDate(data.deletedAt) : '—' }}</span>
          </template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <div class="flex gap-1 justify-end">
              <Button label="還原" icon="pi pi-undo" text size="small" @click="restoreOne(data as Income)" />
              <Button
                label="永久刪除"
                icon="pi pi-trash"
                text
                size="small"
                severity="danger"
                @click="confirmPurge(data as Income)"
              />
            </div>
          </template>
        </Column>
      </DataTable>
    </section>

    <section v-else-if="hasAnyData || loading" class="dash-panel dash-table-panel" aria-label="收入列表">
      <div class="list-head">
        <TabBar v-model="f.status" :tabs="tabs" label="收款狀態" variant="segmented" />
        <div class="list-head-tools">
          <SearchInput v-model="f.keyword" placeholder="搜尋客戶、備註、發票號碼" />
          <Button
            label="篩選"
            :badge="activeFilterCount ? String(activeFilterCount) : undefined"
            icon="pi pi-sliders-h"
            outlined
            size="small"
            :class="{ 'is-open': filterOpen }"
            :aria-expanded="filterOpen"
            aria-controls="income-filters"
            @click="filterOpen = !filterOpen"
          />
        </div>
      </div>
      <div class="filter-collapse" :class="{ open: filterOpen }" :inert="!filterOpen">
        <div id="income-filters" class="filter-row dash-filter">
          <MultiSelect
            v-model="f.categories"
            :show-toggle-all="false"
            :options="categoryFilterOptions"
            option-label="label"
            option-value="value"
            placeholder="全部類別"
            :max-selected-labels="2"
            selected-items-label="已選 {0} 類"
            class="w-[180px]"
            aria-label="類別"
          />
          <DatePicker
            v-model="f.dateRange"
            selection-mode="range"
            date-format="yy/mm/dd"
            placeholder="開立日區間"
            show-icon
            icon-display="input"
            :manual-input="false"
            class="w-[240px]"
            aria-label="開立日區間"
          />
          <Button v-if="activeFilterCount" label="清除篩選" text size="small" @click="clearPanelFilters" />
        </div>
      </div>

      <DataTable
        :value="sortedRows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '880px' }"
        paginator
        :rows="10"
        :rows-per-page-options="ROWS_OPTIONS"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
        removable-sort
        sort-field="date"
        :sort-order="-1"
        row-hover
        :pt="{ bodyRow: { class: 'q-clickable', tabindex: 0 } }"
        @row-click="onRowClick"
      >
        <template #empty>
          <div class="dash-empty">
            {{ isFiltered ? '沒有符合條件的收入' : '目前沒有此狀態的收入' }}
            <Button v-if="isFiltered" label="清除所有篩選" text size="small" @click="resetAll" />
          </div>
        </template>
        <Column header="開立日" field="date" sortable>
          <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.date) }}</span></template>
        </Column>
        <Column header="類別">
          <template #body="{ data }">{{ data.category.name }}</template>
        </Column>
        <Column header="客戶">
          <template #body="{ data }">
            <div class="cell-trunc" :title="data.customer">{{ data.customer }}</div>
            <div v-if="data.note" class="cell-sub" :title="data.note">{{ data.note }}</div>
          </template>
        </Column>
        <Column header="金額" field="amount" sortable header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="收款狀態" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]" :class="data.collectionStatus === 'collected' ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'">
              {{ data.collectionStatus === 'collected' ? '已收款' : '待收款' }}
            </span>
          </template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <Button
              v-tooltip.left="'操作'"
              icon="pi pi-ellipsis-v"
              text
              rounded
              size="small"
              :aria-label="`${data.customer} 操作選單`"
              @click.stop="openRowMenu($event, data as Income)"
            />
          </template>
        </Column>
      </DataTable>
      <Menu ref="rowMenu" :model="rowMenuItems" popup />
    </section>

    <EmptyState
      v-else
      icon="pi pi-inbox"
      title="還沒有收入紀錄"
      description="登錄第一筆收入開始追蹤公司收款"
    >
      <template #action>
        <Button label="新增收入" icon="pi pi-plus" @click="goNew" />
      </template>
    </EmptyState>

    <Drawer
      :visible="detail !== null"
      position="right"
      class="!w-full sm:!w-[560px]"
      @update:visible="(v: boolean) => { if (!v) detailId = null }"
    >
      <template v-if="detail" #header>
        <div class="q-drawer-head">
          <span>收入詳情</span>
          <span class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]" :class="detail.collectionStatus === 'collected' ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'">
            {{ detail.collectionStatus === 'collected' ? '已收款' : '待收款' }}
          </span>
        </div>
      </template>
      <IncomeDetail v-if="detail" :income="detail" />
      <template v-if="detail" #footer>
        <div class="q-drawer-foot">
          <Button label="移至垃圾桶" severity="danger" text @click="confirmDelete(detail)" />
          <span class="q-gap" />
          <Button
            v-if="detail.collectionStatus === 'uncollected'"
            label="標記為已收款"
            outlined
            @click="openCollectDialog(detail)"
          />
          <Button
            v-else
            label="取消收款"
            outlined
            @click="confirmRevertCollect(detail)"
          />
          <Button label="編輯" @click="goEdit(detail)" />
        </div>
      </template>
    </Drawer>

    <Dialog
      v-model:visible="collectDialog.visible"
      modal
      header="標記為已收款"
      :style="{ width: '360px' }"
      :dismissable-mask="!collectDialog.submitting"
      :closable="!collectDialog.submitting"
    >
      <div class="collect-dialog">
        <p class="collect-dialog-sub">
          <template v-if="collectDialog.target">
            {{ collectDialog.target.customer }}（{{ formatCurrency(collectDialog.target.amount) }}）
          </template>
        </p>
        <label for="collectDialogDate" class="field-label">
          收款日 <span class="text-[var(--color-status-rejected)]">*</span>
        </label>
        <DatePicker
          v-model="collectDialog.date"
          input-id="collectDialogDate"
          date-format="yy-mm-dd"
          show-icon
          icon-display="input"
          class="w-full"
        />
      </div>
      <template #footer>
        <Button
          label="取消"
          text
          :disabled="collectDialog.submitting"
          @click="collectDialog.visible = false"
        />
        <Button
          label="確認"
          :loading="collectDialog.submitting"
          :disabled="!collectDialog.date"
          @click="confirmCollect"
        />
      </template>
    </Dialog>
  </div>
</template>

<style scoped>
.list-head { display: flex; align-items: center; justify-content: space-between; gap: 12px 24px; flex-wrap: wrap; min-height: 68px; margin-inline: calc(var(--space-lg) * -1); padding-inline: 20px; }
.list-head-tools :deep(.search-sm) { width: 280px; }
.list-head-tools { display: flex; align-items: center; gap: 8px; padding: 12px 0; margin-left: auto; }
.list-head-tools :deep(.p-button.is-open) { background: var(--color-primary-50); }
.filter-collapse { display: grid; grid-template-rows: 0fr; margin-inline: calc(var(--space-lg) * -1); transition: grid-template-rows .22s ease; }
.filter-collapse.open { grid-template-rows: 1fr; }
.filter-collapse > .filter-row { min-height: 0; overflow: hidden; }
.filter-row { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; padding: 0 20px; margin-bottom: 0; background: var(--color-canvas, #fff); transition: padding .22s ease; }
.filter-collapse.open > .filter-row { padding-block: 4px 16px; }
@media (prefers-reduced-motion: reduce) { .filter-collapse, .filter-row { transition: none; } }
.collect-dialog { display: flex; flex-direction: column; gap: 8px; }
.collect-dialog-sub { color: var(--color-muted); font-size: 13px; margin: 0 0 4px; }
</style>
