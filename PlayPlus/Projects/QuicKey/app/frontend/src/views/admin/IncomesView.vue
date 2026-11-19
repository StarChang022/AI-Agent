<script setup lang="ts">
/**
 * 收入管理：公司所有收入列表。
 * 版型對齊 ExpensesView，但簡化：無來源欄。待收款依應收日期分組（PRD 第 23 條）。
 * 資料匯出（PRD 第 24 條）：每個分頁都可勾選；選取列「匯出」匯出勾選；頁首「匯出」選已選項目或全部收入（目前分頁標籤＋篩選），兩者都先跳確認視窗；明細與每列選單可單筆匯出，同樣先確認。
 * 行動作：編輯 / 標記已收款 / 刪除。已收款改回待收款比照支出，一律從編輯畫面改收款狀態。
 * 垃圾桶模式：還原 / 永久刪除，可勾選本頁批次處理（TrashBatchActions）。
 * 狀態管理：採 CategoriesView 模式，直接呼叫 api/incomes，不經 Pinia store。
 */
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { CollectionStatus, Income } from '@/types/domain'
import {
  collectIncome,
  deleteIncome,
  getIncome,
  listIncomePendingBatches,
  listIncomes,
  listTrashedIncomes,
  purgeIncome,
  restoreIncome,
  type IncomePendingGroup,
  type IncomeSummary,
} from '@/api/incomes'
import PendingDateGroup from '@/components/admin/PendingDateGroup.vue'
import { listCategories, type Category } from '@/api/categories'
import { formatCurrency, formatDate, toIsoDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import PageHeader from '@/components/PageHeader.vue'
import { DELETE_BLOCKED, userErrorToast } from '@/utils/userFeedback'
import EmptyState from '@/components/EmptyState.vue'
import PayStatusChip from '@/components/PayStatusChip.vue'
import CashFlowExcludedHint from '@/components/admin/CashFlowExcludedHint.vue'
import { useAccountOptions } from '@/composables/useAccountOptions'
import ExcelImportDialog from '@/components/admin/ExcelImportDialog.vue'
import NoAccountNotice from '@/components/admin/NoAccountNotice.vue'
import BatchReceiptImportDialog from '@/components/admin/BatchReceiptImportDialog.vue'
import IncomeDetail from '@/components/admin/IncomeDetail.vue'
import TrashedNotice from '@/components/admin/TrashedNotice.vue'
import DataExportMenu from '@/components/admin/DataExportMenu.vue'
import DataExportConfirmDialog from '@/components/admin/DataExportConfirmDialog.vue'
import { exportCategoryText, exportDateRangeText, type DataExportConfirm } from '@/composables/useDataExport'
import TrashBatchActions from '@/components/admin/TrashBatchActions.vue'
import { usePageSelection } from '@/composables/usePageSelection'
import { HttpError } from '@/api/service'
import TabBar from '@/components/qds/TabBar.vue'
import SearchInput from '@/components/qds/SearchInput.vue'
import SelectionBar from '@/components/qds/SelectionBar.vue'
import Button from 'primevue/button'
import Checkbox from 'primevue/checkbox'
import Column from 'primevue/column'
import DataTable, { type DataTablePageEvent, type DataTableRowClickEvent } from 'primevue/datatable'
import DatePicker from '@/components/qds/DatePicker'
import Dialog from 'primevue/dialog'
import Drawer from 'primevue/drawer'
import Menu from 'primevue/menu'
import MultiSelect from 'primevue/multiselect'
import Select from 'primevue/select'
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
    const [list] = await Promise.all([listIncomes(), grouped.value ? refreshGroups() : undefined])
    incomes.value = list
    // 重新載入後（匯入、刪除等）勾選的列可能已不在列表上
    selected.value = []
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
  if (grouped.value) void refreshGroups()
  // 標記收款、還原等就地更新後，清空勾選（同支出）
  selected.value = []
}
function removeLocal(id: string) {
  const idx = incomes.value.findIndex((x) => x.id === id)
  if (idx !== -1) incomes.value.splice(idx, 1)
  if (grouped.value) void refreshGroups()
  selected.value = []
}
function removeTrashedLocal(id: string) {
  const idx = trashedItems.value.findIndex((x) => x.id === id)
  if (idx !== -1) trashedItems.value.splice(idx, 1)
}

async function enterTrashMode() {
  trashMode.value = true
  trashFirst.value = 0
  detailId.value = null
  await reloadTrashed()
}
function exitTrashMode() {
  trashMode.value = false
  trashedItems.value = []
}

// 垃圾桶在前端分頁；分頁位置自己管，才知道「本頁」是哪幾筆
const trashFirst = ref(0)
const trashPageSize = ref(10)
const trashPageRows = computed(() => trashedItems.value.slice(trashFirst.value, trashFirst.value + trashPageSize.value))
function onTrashPage(evt: DataTablePageEvent) {
  trashPageSize.value = evt.rows
  trashFirst.value = evt.first
}
/** 本頁之後沒有資料了（全部移出）就回前一頁 */
function clampTrashPage() {
  while (trashFirst.value > 0 && trashFirst.value >= trashedItems.value.length) {
    trashFirst.value = Math.max(0, trashFirst.value - trashPageSize.value)
  }
}

// 批次還原 / 永久刪除：只選本頁，換頁或改每頁筆數就清空（PRD 第 18 條）
const trashSel = usePageSelection(trashPageRows, [trashFirst, trashPageSize])
async function onTrashBatchDone(succeeded: string[]) {
  trashSel.clear()
  await reloadTrashed()
  clampTrashPage()
  // 還原的回到收入列表
  if (succeeded.length) await refetch()
}

const activeCategories = ref<Category[]>([])
onMounted(async () => {
  // 沒有帳戶時停用新增與匯入入口（PRD 第 20 條）
  void loadAccounts()
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
  recurring: boolean
  categories: string[]
  dateRange: (Date | null)[] | null
  missingInvoiceNo: boolean
  status: StatusTab
}
const emptyFilters = (): Filters => ({ keyword: '', recurring: false, categories: [], dateRange: null, missingInvoiceNo: false, status: 'all' })
const f = reactive<Filters>(emptyFilters())
function resetAll() {
  Object.assign(f, emptyFilters())
}

const SOURCE_OPTIONS = [
  { value: false, label: '全部來源' },
  { value: true, label: '固定' },
]

/** 篩選（不含收款狀態分頁）；後端「全部收入」匯出照同樣規則做 */
function filterIncomes(dateFrom?: string, dateTo?: string): Income[] {
  const kw = f.keyword.trim().toLowerCase()
  return incomes.value.filter((i) => {
    if (f.recurring && !i.recurringPeriod) return false
    if (f.missingInvoiceNo && (i.documentType !== 'invoice' || i.invoiceNo?.trim())) return false
    if (f.categories.length && !f.categories.includes(i.category.id)) return false
    if (dateFrom && i.date < dateFrom) return false
    if (dateTo && i.date > dateTo) return false
    if (kw && ![i.customer, i.note, i.invoiceNo].join(' ').toLowerCase().includes(kw)) return false
    return true
  })
}
const baseFilter = computed<Income[]>(() => {
  const [from, to] = f.dateRange ?? []
  return filterIncomes(from instanceof Date ? toIsoDate(from) : undefined, to instanceof Date ? toIsoDate(to) : undefined)
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
  () => !!f.keyword.trim() || f.recurring || f.categories.length > 0 || !!(f.dateRange && f.dateRange.some((d) => d instanceof Date)) || f.missingInvoiceNo,
)
const hasAnyData = computed(() => incomes.value.length > 0)

// ─── 待收款依應收日期分組（逾期在前；分組 API 不吃篩選，有篩選時改回一般列表） ───
const grouped = computed(() => f.status === 'uncollected' && !isFiltered.value)
const pendingGroups = ref<IncomePendingGroup[]>([])
const groupsLoading = ref(false)
async function refreshGroups() {
  groupsLoading.value = true
  try {
    pendingGroups.value = (await listIncomePendingBatches()).groups
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '載入待收款失敗'), life: 3500 })
    pendingGroups.value = []
  } finally {
    groupsLoading.value = false
  }
}
watch(grouped, (v) => {
  if (v) void refreshGroups()
})
// 預設展開逾期組與最近一組；重新載入後保留使用者展開的組
const expandedGroups = ref<string[]>([])
watch(pendingGroups, (groups) => {
  const valid = new Set(groups.map((g) => g.key))
  const kept = expandedGroups.value.filter((key) => valid.has(key))
  if (kept.length) {
    expandedGroups.value = kept
    return
  }
  const overdueKeys = groups.filter((g) => g.overdue).map((g) => g.key)
  const nextKey = groups.find((g) => !g.overdue)?.key
  expandedGroups.value = [...new Set([...overdueKeys, ...(nextKey ? [nextKey] : [])])]
})
function isGroupOpen(key: string) {
  return expandedGroups.value.includes(key)
}
function toggleGroup(key: string) {
  expandedGroups.value = isGroupOpen(key)
    ? expandedGroups.value.filter((k) => k !== key)
    : [...expandedGroups.value, key]
}

// ─── 勾選（匯出用） ─────────────────────────────────
// 列表在前端分頁，DataTable 預設的表頭勾選會選到所有分頁；改成只選本頁（PRD 第 24 條）。
// 本頁的列以 DataTable 目前排序、分頁後實際顯示的資料為準。
const selected = ref<Income[]>([])
const incomeTable = ref<{ dataToRender?: () => Income[] } | null>(null)
const pageRows = computed<Income[]>(() => incomeTable.value?.dataToRender?.() ?? [])
const pageAllSelected = computed(
  () => pageRows.value.length > 0 && pageRows.value.every((r) => selected.value.some((s) => s.id === r.id)),
)
function onSelectAllChange(evt: { checked: boolean }) {
  selected.value = evt.checked ? [...pageRows.value] : []
}
// 換分頁、篩選或關鍵字後，勾選的列可能不在畫面上，不留著看不見的勾選；換頁、改每頁筆數、排序由 DataTable 事件清空
watch(() => [f.status, f.keyword, f.recurring, f.categories, f.dateRange, f.missingInvoiceNo], () => (selected.value = []))

// ─── 資料匯出（PRD 第 24 條）：勾選、全部（目前分頁標籤＋篩選）、單筆，都先跳確認視窗 ─────
const pendingExport = ref<DataExportConfirm | null>(null)
/** 確認視窗列出的篩選條件：只列有設定的 */
function exportFilterTexts(): string[] {
  const out: (string | null)[] = [
    f.status === 'all' ? null : f.status === 'uncollected' ? '待收款' : '已收款',
    f.keyword.trim() ? `關鍵字「${f.keyword.trim()}」` : null,
    exportDateRangeText(f.dateRange),
    exportCategoryText(f.categories, activeCategories.value),
    f.recurring ? '來源：固定' : null,
    f.missingInvoiceNo ? '未填發票號碼' : null,
  ]
  return out.filter((t): t is string => !!t)
}
function exportSelected() {
  if (!selected.value.length) return
  pendingExport.value = {
    req: { kind: 'income', scope: 'selected', ids: selected.value.map((i) => i.id) },
    count: selected.value.length,
  }
}
function onExport(scope: 'selected' | 'filtered') {
  if (scope === 'selected') return exportSelected()
  const [from, to] = f.dateRange ?? []
  pendingExport.value = {
    req: {
      kind: 'income',
      scope: 'filtered',
      filters: {
        dateFrom: from instanceof Date ? toIsoDate(from) : undefined,
        dateTo: to instanceof Date ? toIsoDate(to) : undefined,
        recurring: f.recurring || undefined,
        categoryIds: f.categories.length ? [...f.categories] : undefined,
        collectionStatus: f.status === 'all' ? undefined : f.status,
        q: f.keyword.trim() || undefined,
        missingInvoiceNo: f.missingInvoiceNo || undefined,
      },
    },
    count: visibleRows.value.length,
    filters: exportFilterTexts(),
  }
}
function exportOne(i: Income) {
  pendingExport.value = { req: { kind: 'income', scope: 'single', ids: [i.id] }, count: 1 }
}

const filterOpen = ref(false)
const activeFilterCount = computed(
  () => (f.recurring ? 1 : 0) + (f.categories.length ? 1 : 0) + (f.dateRange && f.dateRange.some((d) => d instanceof Date) ? 1 : 0) + (f.missingInvoiceNo ? 1 : 0),
)
function clearPanelFilters() {
  f.recurring = false
  f.categories = []
  f.dateRange = null
  f.missingInvoiceNo = false
}

// ─── 行動作：收款 / 刪除 ─────────────────
const { options: accountOptions, noAccounts, load: loadAccounts } = useAccountOptions()

// 標記已收款走 Dialog 確認實收日期（PRD 第 10 條）：單筆預設今天，曾收款後改回待收款的帶回原本的實收日期；
// 整組一起標記時共用同一個日期，預設今天。
const collectDialog = reactive({
  visible: false,
  targets: [] as IncomeSummary[],
  title: '',
  date: null as Date | null,
  submitting: false,
})
function openCollectDialog(target: Income) {
  openCollectFor([target], target.customer)
}
function openCollectGroup(g: IncomePendingGroup) {
  openCollectFor(g.rows, g.overdue ? '逾期未收款' : `應收日期 ${formatDate(g.date)}`)
}
function openCollectFor(targets: IncomeSummary[], title: string) {
  if (!targets.length) return
  collectDialog.targets = targets
  collectDialog.title = title
  const kept = targets.length === 1 ? targets[0].collectedAt : null
  collectDialog.date = kept ? new Date(`${kept}T00:00:00`) : new Date()
  collectDialog.visible = true
  void loadAccounts()
}
function accountOptionOf(i: IncomeSummary) {
  return accountOptions.value.find((a) => a.id === i.account.id)
}
const collectTotal = computed(() => collectDialog.targets.reduce((s, i) => s + i.amount, 0))
async function confirmCollect() {
  const list = collectDialog.targets
  if (!list.length || !collectDialog.date) return
  const collectedAt = toIsoDate(collectDialog.date)
  collectDialog.submitting = true
  const results = await Promise.allSettled(list.map((i) => collectIncome(i.id, { collectedAt })))
  collectDialog.submitting = false
  let ok = 0
  for (const r of results) {
    if (r.status === 'fulfilled') {
      upsertLocal(r.value)
      ok++
    }
  }
  const single = list.length === 1 ? results[0] : null
  if (single?.status === 'rejected') {
    toast.add({ severity: 'error', ...userErrorToast(single.reason, '標記已收款失敗'), life: 3500 })
    return
  }
  const failed = results.length - ok
  toast.add({
    severity: failed ? 'warn' : 'success',
    summary: single ? '已標記為已收款' : `已標記 ${ok} 筆為已收款`,
    detail: failed ? `${failed} 筆失敗，請重試` : undefined,
    life: 3000,
  })
  collectDialog.visible = false
  collectDialog.targets = []
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
    clampTrashPage()
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
    defaultFocus: 'reject',
    accept: () => purgeOne(target),
  })
}
async function purgeOne(target: Income) {
  try {
    await purgeIncome(target.id)
    removeTrashedLocal(target.id)
    clampTrashPage()
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
// 列表裡有的直接用列表資料（標記收款等動作就地更新後跟著變）；列表沒有的（例如用網址開啟
// 垃圾桶內的紀錄，或列表還沒載入）用 getIncome 單筆查詢，查不到再提示並關閉。
const detailId = ref<string | null>(null)
const fetchedDetail = ref<Income | null>(null)
const detailLoading = ref(false)
const detail = computed<Income | null>(() => {
  const id = detailId.value
  if (!id) return null
  return incomes.value.find((i) => i.id === id) ?? (fetchedDetail.value?.id === id ? fetchedDetail.value : null)
})
let detailSeq = 0
watch(detailId, async (id) => {
  const seq = ++detailSeq
  fetchedDetail.value = null
  detailLoading.value = false
  if (!id || incomes.value.some((i) => i.id === id)) return
  detailLoading.value = true
  try {
    const found = await getIncome(id)
    if (seq === detailSeq) fetchedDetail.value = found
  } catch (err) {
    if (seq !== detailSeq) return
    if (err instanceof HttpError && err.status === 404) {
      toast.add({ severity: 'warn', summary: '找不到該筆收入', detail: '可能已被刪除', life: 2500 })
    } else {
      toast.add({ severity: 'error', ...userErrorToast(err, '載入明細失敗'), life: 3000 })
    }
    detailId.value = null
  } finally {
    if (seq === detailSeq) detailLoading.value = false
  }
})
function openDetail(i: Income) {
  detailId.value = i.id
}
function onRowClick(evt: DataTableRowClickEvent) {
  openDetail(evt.data as Income)
}
/** 垃圾桶列表點列也開抽屜（唯讀）；點勾選欄（含勾選框周圍）只勾選，不開抽屜；還原、永久刪除按鈕 PrimeVue 本身就不觸發列點擊 */
function onTrashRowClick(evt: DataTableRowClickEvent) {
  if ((evt.originalEvent.target as HTMLElement | null)?.closest('.sel-col')) return
  openDetail(evt.data as Income)
}
/** 垃圾桶表格沒有 selection-mode，PrimeVue 不會把 Enter 轉成列點擊，自己接：focus 在列上按 Enter 開抽屜 */
function onTrashRowKeydown(evt: KeyboardEvent) {
  const tr = evt.target as HTMLElement
  if (evt.key !== 'Enter' || tr.tagName !== 'TR' || !tr.parentElement) return
  const row = trashPageRows.value[Array.prototype.indexOf.call(tr.parentElement.children, tr)]
  if (!row) return
  evt.preventDefault()
  openDetail(row)
}
function goEdit(i: Income) {
  router.push({ name: 'admin-income-edit', params: { id: i.id } })
}

// ─── 匯入 ─────────────────────────────────────────
const showImport = ref(false)
const showReceiptImport = ref(false)

// ─── 頁首 ⋯ 選單（匯入、垃圾桶入口） ─────────────────
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = computed(() => [
  { label: '匯入 Excel', icon: 'pi pi-upload', disabled: noAccounts.value, command: () => (showImport.value = true) },
  { label: '批次匯入憑證', icon: 'pi pi-images', disabled: noAccounts.value, command: () => (showReceiptImport.value = true) },
  { label: '垃圾桶', icon: 'pi pi-trash', command: () => enterTrashMode() },
])

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
      : []),
    { label: '匯出', icon: 'pi pi-download', command: () => exportOne(t) },
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
// 抽屜開關與網址 ?open 同步；查不到的由上方 watch 提示並清掉
useOpenQuery(detailId)
</script>

<template>
  <div class="dash-page">
    <PageHeader :title="trashMode ? '收入垃圾桶' : '收入管理'" size="admin">
      <template #actions>
        <template v-if="trashMode">
          <Button label="返回收入列表" icon="pi pi-arrow-left" outlined @click="exitTrashMode" />
        </template>
        <template v-else>
          <Button label="新增收入" icon="pi pi-plus" :disabled="noAccounts" @click="goNew" />
          <DataExportMenu all-label="全部收入" :selected-count="selected.length" :total="visibleRows.length" @export="onExport" />
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

    <NoAccountNotice v-if="!trashMode && noAccounts" />

    <ExcelImportDialog v-if="!trashMode" v-model:visible="showImport" kind="income" @imported="refetch" />
    <BatchReceiptImportDialog v-if="!trashMode" v-model:visible="showReceiptImport" kind="income" />

    <!-- 垃圾桶模式：獨立 table，點列開唯讀抽屜；動作只有「還原 / 永久刪除」 -->
    <section v-if="trashMode" class="dash-panel dash-table-panel trash-table-panel" aria-label="收入垃圾桶">
      <TrashBatchActions kind="income" :rows="trashSel.selectedRows.value" @clear="trashSel.clear()" @done="onTrashBatchDone" />
      <DataTable
        :value="trashedItems"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '860px' }"
        :loading="loading"
        paginator
        :first="trashFirst"
        :rows="trashPageSize"
        :rows-per-page-options="ROWS_OPTIONS"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
        row-hover
        :pt="{ bodyRow: { class: 'q-clickable', tabindex: 0, onKeydown: onTrashRowKeydown } }"
        @page="onTrashPage"
        @row-click="onTrashRowClick"
      >
        <template #empty>
          <div class="dash-empty">垃圾桶是空的</div>
        </template>
        <Column header-class="sel-col" body-class="sel-col" :style="{ width: '48px' }">
          <template #header>
            <Checkbox
              :model-value="trashSel.allSelected.value"
              :indeterminate="trashSel.partiallySelected.value"
              binary
              :disabled="!trashPageRows.length"
              aria-label="全選本頁"
              @update:model-value="(v: boolean) => trashSel.toggleAll(v)"
            />
          </template>
          <template #body="{ data }">
            <Checkbox
              :model-value="trashSel.isSelected(data)"
              binary
              :aria-label="`選取「${data.customer}」${formatCurrency(data.amount)}`"
              @update:model-value="(v: boolean) => trashSel.toggle(data, v)"
            />
          </template>
        </Column>
        <Column header="發生日期" field="date">
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
          <Select v-model="f.recurring" :options="SOURCE_OPTIONS" option-label="label" option-value="value" class="w-[140px]" aria-label="來源" />
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
            placeholder="發生日期區間"
            show-icon
            icon-display="input"
            :manual-input="false"
            class="w-[240px]"
            aria-label="發生日期區間"
          />
          <div class="filter-check check-row">
            <Checkbox v-model="f.missingInvoiceNo" input-id="income-filter-missing-invoice" binary />
            <label for="income-filter-missing-invoice">未填發票號碼</label>
          </div>
          <Button v-if="activeFilterCount" label="清除篩選" text size="small" @click="clearPanelFilters" />
        </div>
      </div>

      <SelectionBar v-if="selected.length" class="list-selection" :count="selected.length" @clear="selected = []">
        <Button label="匯出" icon="pi pi-download" size="small" outlined @click="exportSelected" />
      </SelectionBar>
      <div v-if="grouped" class="batch-list">
        <div v-if="groupsLoading && !pendingGroups.length" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
        <div v-else-if="!pendingGroups.length" class="dash-empty">目前沒有待收款的收入</div>
        <PendingDateGroup
          v-for="g in pendingGroups"
          :key="g.key"
          kind="income"
          :date="g.date"
          :overdue="g.overdue"
          :total="g.total"
          :count="g.count"
          :open="isGroupOpen(g.key)"
          @toggle="toggleGroup(g.key)"
          @action="openCollectGroup(g)"
        >
          <DataTable
            v-model:selection="selected"
            :value="g.rows"
            data-key="id"
            :table-style="{ width: '100%', minWidth: '1020px' }"
            row-hover
            :pt="{ bodyRow: { class: 'q-clickable', tabindex: 0 } }"
            @row-click="onRowClick"
          >
          <Column selection-mode="multiple" header-class="w-[44px]" :style="{ width: '48px' }" />
          <Column header="發生日期">
            <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.date) }}</span></template>
          </Column>
          <Column header="應收日期">
            <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.plannedCollectionDate) }}</span></template>
          </Column>
          <Column header="類別">
            <template #body="{ data }">{{ data.category.name }}</template>
          </Column>
          <Column header="帳戶">
            <template #body="{ data }">{{ data.account.name }}</template>
          </Column>
          <Column header="客戶">
            <template #body="{ data }">
              <div class="flex items-center gap-2 min-w-0">
                <div class="cell-trunc" :title="data.customer">{{ data.customer }}</div>
                <span v-if="data.recurringPeriod" class="tag-soft tag-neutral">固定</span>
              </div>
              <div v-if="data.note" class="cell-sub" :title="data.note">{{ data.note }}</div>
            </template>
          </Column>
          <Column header="金額" field="amount" header-class="num" body-class="num">
            <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
          </Column>
          <Column header="收款狀態" :style="{ width: '1%' }">
            <template #body="{ data }">
              <PayStatusChip :status="data.collectionStatus" />
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
        </PendingDateGroup>
      </div>
      <DataTable
        v-else
        ref="incomeTable"
        v-model:selection="selected"
        :select-all="pageAllSelected"
        :value="sortedRows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '1020px' }"
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
        @select-all-change="onSelectAllChange"
        @page="selected = []"
        @sort="selected = []"
      >
        <template #empty>
          <div class="dash-empty">
            {{ isFiltered ? '沒有符合條件的收入' : '目前沒有此狀態的收入' }}
            <Button v-if="isFiltered" label="清除所有篩選" text size="small" @click="resetAll" />
          </div>
        </template>
        <Column selection-mode="multiple" header-class="w-[44px]" :style="{ width: '48px' }" />
        <Column header="發生日期" field="date" sortable>
          <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.date) }}</span></template>
        </Column>
        <Column header="應收日期">
          <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.plannedCollectionDate) }}</span></template>
        </Column>
        <Column header="類別">
          <template #body="{ data }">{{ data.category.name }}</template>
        </Column>
        <Column header="帳戶">
          <template #body="{ data }">{{ data.account.name }}</template>
        </Column>
        <Column header="客戶">
          <template #body="{ data }">
            <div class="flex items-center gap-2 min-w-0">
              <div class="cell-trunc" :title="data.customer">{{ data.customer }}</div>
              <span v-if="data.recurringPeriod" class="tag-soft tag-neutral">固定</span>
            </div>
            <div v-if="data.note" class="cell-sub" :title="data.note">{{ data.note }}</div>
          </template>
        </Column>
        <Column header="金額" field="amount" sortable header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="收款狀態" :style="{ width: '1%' }">
          <template #body="{ data }">
            <PayStatusChip :status="data.collectionStatus" />
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
      description="登錄第一筆收入，或從 Excel、憑證檔案批次匯入"
    >
      <template #action>
        <div class="flex flex-wrap justify-center gap-2">
          <Button label="新增收入" icon="pi pi-plus" :disabled="noAccounts" @click="goNew" />
          <Button label="匯入 Excel" icon="pi pi-upload" outlined :disabled="noAccounts" @click="showImport = true" />
          <Button label="批次匯入憑證" icon="pi pi-images" outlined :disabled="noAccounts" @click="showReceiptImport = true" />
        </div>
      </template>
    </EmptyState>

    <Drawer
      :visible="detailId !== null"
      position="right"
      class="!w-full sm:!w-[560px]"
      @update:visible="(v: boolean) => { if (!v) detailId = null }"
    >
      <template #header>
        <div class="q-drawer-head">
          <span>收入詳情</span>
          <PayStatusChip v-if="detail" :status="detail.collectionStatus" />
          <span v-if="detail?.deletedAt" class="tag-soft tag-neutral">垃圾桶</span>
        </div>
      </template>
      <div v-if="detailLoading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
      <template v-else-if="detail">
        <!-- 垃圾桶內（從垃圾桶列表或網址開啟）唯讀：不顯示底部動作（PRD 第 18 條）；附件照樣可預覽、下載 -->
        <TrashedNotice v-if="detail.deletedAt" />
        <IncomeDetail :income="detail" />
      </template>
      <template v-if="detail && !detail.deletedAt" #footer>
        <div class="q-drawer-foot">
          <Button label="移至垃圾桶" severity="danger" text @click="confirmDelete(detail)" />
          <span class="q-gap" />
          <Button label="匯出" icon="pi pi-download" outlined @click="exportOne(detail)" />
          <Button
            v-if="detail.collectionStatus === 'uncollected'"
            label="標記為已收款"
            outlined
            @click="openCollectDialog(detail)"
          />
          <Button label="編輯" @click="goEdit(detail)" />
        </div>
      </template>
    </Drawer>

    <Dialog
      v-model:visible="collectDialog.visible"
      modal
      header="標記為已收款"
      :style="{ width: 'min(92vw, 400px)' }"
      :dismissable-mask="!collectDialog.submitting"
      :closable="!collectDialog.submitting"
    >
      <div class="collect-dialog">
        <p class="collect-dialog-sub">
          {{ collectDialog.title }}
          <template v-if="collectDialog.targets.length > 1">・{{ collectDialog.targets.length }} 筆</template>
          （{{ formatCurrency(collectTotal) }}）
        </p>
        <label for="collectDialogDate" class="field-label">
          實收日期 <span class="text-[var(--color-status-rejected)]">*</span>
        </label>
        <!-- 日期與提示包在同一層：提示每筆都有一個（空的也在，保留 role="status" 才念得出來），
             間距只加在有內容的提示上；沒有提示時不會多出彈窗本身的欄位間距 -->
        <div class="cf-hint-list">
          <DatePicker
            v-model="collectDialog.date"
            input-id="collectDialogDate"
            date-format="yy-mm-dd"
            show-icon
            icon-display="input"
            class="w-full"
          />
          <CashFlowExcludedHint
            v-for="i in collectDialog.targets"
            :key="i.id"
            date-label="實收日期"
            :date="collectDialog.date"
            :account="accountOptionOf(i)"
            :record-label="collectDialog.targets.length > 1 ? i.customer : undefined"
          />
        </div>
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

    <DataExportConfirmDialog v-model:pending="pendingExport" noun="收入" />
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
.list-selection { margin: 12px 0; }
.collect-dialog { display: flex; flex-direction: column; gap: 8px; }
/* 不用 gap：沒有內容的提示高度為 0，只有出現的提示才加上方間距；flex 讓日期欄位不留行高空白 */
.cf-hint-list { display: flex; flex-direction: column; }
.cf-hint-list > div:not(:empty) { margin-top: 8px; }
.batch-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin: 14px calc(var(--space-lg) * -1) 0;
  padding: 0 20px 20px;
}
.collect-dialog-sub { color: var(--color-muted); font-size: 13px; margin: 0 0 4px; }
</style>
