<script setup lang="ts">
/**
 * 支出管理：公司所有支出（一般支出＋核准後轉入的代墊款）。
 * 版型依 design-system 列表頁（CRUD）：分頁標籤 → 工具列（搜尋/篩選/合計）→ 表格 → 分頁。
 * 點列或眼睛按鈕開右側明細；⋯ 選單放編輯、調整付款日、標記已付款、刪除。
 * 付款批次：待付款依預計付款日分組；可單筆或勾選多筆調整付款日。
 */
import { computed, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { Expense, ExpenseSource, PaymentMethod, PayoutStatus } from '@/types/domain'
import { PAYMENT_METHOD_LABELS } from '@/types/domain'
import { onMounted } from 'vue'
import {
  listExpenses,
  listTrashedExpenses,
  listPendingBatches,
  getExpense,
  payExpense,
  adjustPayoutDate,
  deleteExpense,
  restoreExpense,
  purgeExpense,
  type ExpenseSummary,
  type ListExpensesQuery,
  type PendingBatchGroup,
} from '@/api/expenses'
import { HttpError } from '@/api/service'
import { listCategories, type Category } from '@/api/categories'
import { getPayoutSchedule, updatePayoutSchedule } from '@/api/payoutSchedule'
import { autoPayoutDate, payoutDayLabel, PAYOUT_DAY_OPTIONS, type PayoutDay } from '@/utils/payoutSchedule'
import { formatCurrency, formatDate, toIsoDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import PageHeader from '@/components/PageHeader.vue'
import { DELETE_BLOCKED, userErrorToast } from '@/utils/userFeedback'
import EmptyState from '@/components/EmptyState.vue'
import BatchImportDialog from '@/components/BatchImportDialog.vue'
import ExpenseDetail from '@/components/admin/ExpenseDetail.vue'
import TabBar from '@/components/qds/TabBar.vue'
import SearchInput from '@/components/qds/SearchInput.vue'
import SelectionBar from '@/components/qds/SelectionBar.vue'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable, { type DataTableRowClickEvent, type DataTablePageEvent } from 'primevue/datatable'
import DatePicker from 'primevue/datepicker'
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
const confirm = useConfirm()
const toast = useToast()

// 公司付款日（null = 關閉自動付款批次）；onMounted 從 API 載入，saveSchedule 時 PATCH。
const payoutDay = ref<PayoutDay | null>(null)
const scheduleSaving = ref(false)


const activeCategories = ref<Category[]>([])
const categoryFilterOptions = computed(() => activeCategories.value.map((c) => ({ value: c.id, label: c.name })))

// ─── 伺服器端分頁 state ─────────────────────────────
// rows 是列表精簡版（ExpenseSummary，不含 attachments / items）；drawer / 編輯
// 要用全欄位時走 getExpense 另外抓。
const rows = ref<ExpenseSummary[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const loading = ref(false)
// 首次 fetch 完成前永遠顯示 DataTable（含 loading mask），不閃 EmptyState
const initialLoaded = ref(false)
// 「待付款」tab 的 count，獨立請求維持；全部 / 已付款 tab 的 count 不顯示
const pendingCount = ref(0)
// 用來判斷 EmptyState：曾經載到資料就不再秀「還沒有支出」
const everHadData = ref(false)
// 付款日載入完成前，先別讓 payoutDay 的 watcher 自動 refresh
// 否則會跟 onMounted 內的 initial refreshList 打架。
const scheduleReady = ref(false)

// ─── 篩選 state ─────────────────────────────────────
type StatusTab = 'all' | PayoutStatus
interface Filters {
  keyword: string
  source: ExpenseSource | 'all'
  categories: string[]
  dateRange: (Date | null)[] | null
  status: StatusTab
}
const emptyFilters = (): Filters => ({ keyword: '', source: 'all', categories: [], dateRange: null, status: 'all' })
const f = reactive<Filters>(emptyFilters())
function resetAll() {
  Object.assign(f, emptyFilters())
  page.value = 1
  // watcher 會自動觸發 refreshList
}

const SOURCE_OPTIONS = [
  { value: 'all', label: '全部來源' },
  { value: 'general', label: '一般支出' },
  { value: 'reimbursement', label: '代墊款' },
]

// 待付款 tab + 有付款日設定 → 走 listPendingBatches 伺服器端分組；其他情境走 listExpenses 分頁。
const grouped = computed(() => f.status === 'pending' && payoutDay.value !== null)

function buildListQuery(): ListExpensesQuery {
  const query: ListExpensesQuery = {
    source: f.source === 'all' ? undefined : f.source,
    categoryIds: f.categories.length ? f.categories : undefined,
    payoutStatus: f.status === 'all' ? undefined : f.status,
    q: f.keyword.trim() || undefined,
    page: page.value,
    perPage: pageSize.value,
  }
  if (f.dateRange) {
    const [from, to] = f.dateRange
    if (from instanceof Date) query.dateFrom = toIsoDate(from)
    if (to instanceof Date) query.dateTo = toIsoDate(to)
  }
  return query
}

async function refreshList() {
  loading.value = true
  try {
    if (grouped.value) {
      // 待付款分組：後端一次吐全部 pending 並做分組（避免前端用 perPage 上限自己切）
      const resp = await listPendingBatches()
      pendingBatches.value = resp.groups
      const sum = resp.groups.reduce((s, g) => s + g.rows.length, 0)
      pendingCount.value = sum
      if (sum > 0) everHadData.value = true
      // 切回非分組視圖前先清空 rows / total，避免殘影
      rows.value = []
      total.value = 0
    } else {
      const resp = await listExpenses(buildListQuery())
      rows.value = resp.data
      total.value = resp.meta.total
      if (resp.meta.total > 0) everHadData.value = true
      pendingBatches.value = []
    }
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '載入支出失敗'), life: 3000 })
  } finally {
    loading.value = false
    initialLoaded.value = true
  }
}

async function refreshPendingCount() {
  try {
    const resp = await listExpenses({ payoutStatus: 'pending', perPage: 1 })
    pendingCount.value = resp.meta.total
  } catch {
    // count 失敗不致命；toast 由主 list 顯示
  }
}

/**
 * 收到後端回來的 full Expense 時：更新清單那筆（自動轉成 Summary 的子集）+ 連動詳情抽屜。
 * 待付款分組視圖中，若該筆已轉為 paid 等不屬於 pending 的狀態，就地從批次 rows
 * 移除；pendingBatches 內該組會自動縮短（空組保留，refreshList 下一次會清掉）。
 */
function patchLocal(updated: Expense) {
  const idx = rows.value.findIndex((r) => r.id === updated.id)
  if (idx !== -1) rows.value.splice(idx, 1, updated)
  if (detailExpense.value?.id === updated.id) detailExpense.value = updated
  for (const g of pendingBatches.value) {
    const i = g.rows.findIndex((r) => r.id === updated.id)
    if (i === -1) continue
    if (updated.payoutStatus !== 'pending') {
      g.rows.splice(i, 1)
      g.total -= updated.amount
    } else {
      g.rows.splice(i, 1, updated)
    }
  }
}

onMounted(async () => {
  try {
    activeCategories.value = await listCategories({ kind: 'expense' })
  } catch {
    activeCategories.value = []
  }
  try {
    const resp = await getPayoutSchedule()
    payoutDay.value = resp.day
  } catch (err) {
    toast.add({ severity: 'error', summary: '載入付款日設定失敗', detail: errorMessage(err), life: 3000 })
  }
  scheduleReady.value = true
  await Promise.all([refreshList(), refreshPendingCount()])
})

// 篩選變動 → 重設到第 1 頁、refetch
// keyword debounce 300ms，避免每個字母都打 request
let keywordTimer: number | null = null
watch(() => f.keyword, () => {
  if (keywordTimer !== null) window.clearTimeout(keywordTimer)
  keywordTimer = window.setTimeout(() => {
    page.value = 1
    refreshList()
  }, 300)
})
watch(
  () => [f.source, [...f.categories], f.dateRange, f.status, payoutDay.value],
  () => {
    if (!scheduleReady.value) return
    page.value = 1
    refreshList()
  },
  { deep: true },
)
watch([page, pageSize], () => refreshList())

// ─── 付款批次：待付款依預計付款日分組 ─────────────
// 分組邏輯整個搬到後端：listPendingBatches() 一次吐全部 pending + 分組結果。
// 前端只負責把 PendingBatchGroup 的 sourceMeta 轉成行政人員看得懂的中文。
interface BatchGroup {
  key: string
  /** UI 顯示的預計付款日；'' 表示組內無任何預計日 */
  date: string
  overdue: boolean
  rows: ExpenseSummary[]
  total: number
  sourceMeta: string
}
const pendingBatches = ref<PendingBatchGroup[]>([])

function formatSourceMeta(m: { general: number; reimbursement: number }): string {
  return [m.general ? `${m.general} 筆一般支出` : '', m.reimbursement ? `${m.reimbursement} 筆代墊款` : '']
    .filter(Boolean)
    .join('、')
}

const batchGroups = computed<BatchGroup[]>(() =>
  pendingBatches.value.map((g) => ({
    key: g.key,
    date: g.date ?? '',
    overdue: g.overdue,
    rows: g.rows,
    total: g.total,
    sourceMeta: formatSourceMeta(g.sourceMeta),
  })),
)

const tabs = computed(() => [
  // 分頁數字只顯示待付款（需要處理）；全部、已付款不顯示
  { value: 'all' as StatusTab, label: '全部' },
  { value: 'pending' as StatusTab, label: '待付款', count: pendingCount.value },
  { value: 'paid' as StatusTab, label: '已付款' },
])

function onPage(evt: DataTablePageEvent) {
  pageSize.value = evt.rows
  page.value = evt.page + 1
}
const expandedBatches = ref<string[]>([])
watch(
  batchGroups,
  (groups) => {
    const valid = new Set(groups.map((g) => g.key))
    const kept = expandedBatches.value.filter((key) => valid.has(key))
    if (kept.length) {
      expandedBatches.value = kept
      return
    }
    const overdueKeys = groups.filter((g) => g.overdue).map((g) => g.key)
    const nextKey = groups.find((g) => !g.overdue)?.key
    expandedBatches.value = [...new Set([...overdueKeys, ...(nextKey ? [nextKey] : [])])]
  },
  { immediate: true },
)
function isBatchOpen(key: string) {
  return expandedBatches.value.includes(key)
}
function toggleBatch(key: string) {
  expandedBatches.value = isBatchOpen(key)
    ? expandedBatches.value.filter((k) => k !== key)
    : [...expandedBatches.value, key]
}

// 勾選（只在「待付款」分頁）
const selected = ref<ExpenseSummary[]>([])
watch(() => f.status, () => (selected.value = []))
const selectedTotal = computed(() => selected.value.reduce((s, e) => s + e.amount, 0))

// 設定 Dialog：每月一個付款日
const scheduleVisible = ref(false)
const scheduleDraft = ref<PayoutDay | null>(null)
function openSchedule() {
  scheduleDraft.value = payoutDay.value
  scheduleVisible.value = true
}
/** 設定說明：一句規則＋以儲存後為例（月底另外說明短月份） */
const scheduleHint = computed(() => {
  const d = scheduleDraft.value
  if (d === null) return { rule: '不自動建立付款批次，待付款不依付款日分組', example: '', note: '' }
  const now = new Date()
  const pay = autoPayoutDate(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`, d)
  return {
    rule: d >= 31 ? '每月月底，自動建立一批預計付款' : `每月 ${d} 號，自動建立一批預計付款`,
    example: `例：儲存後新登錄或核准的款項 → ${pay.getMonth() + 1}/${pay.getDate()} 預計付款（既有待付款維持原付款日）`,
    note: d >= 29 && d < 31 ? `沒有 ${d} 號的月份（如 2 月），改在月底付款` : '',
  }
})
async function saveSchedule() {
  if (scheduleDraft.value === payoutDay.value) {
    scheduleVisible.value = false
    return
  }
  scheduleSaving.value = true
  try {
    const resp = await updatePayoutSchedule(scheduleDraft.value)
    payoutDay.value = resp.day
    scheduleVisible.value = false
    toast.add({
      severity: 'success',
      summary: resp.day !== null ? `付款日：${payoutDayLabel(resp.day)}` : '已關閉自動付款批次',
      detail: '新規則只套用到之後新登錄 / 核准的支出；已登錄的款項維持原付款日',
      life: 3000,
    })
    // payoutDay 變動時，上方 watcher 會自動 refreshList；
    // f.status 切 pending 讓使用者看到新的付款批次分組（day !== null 才有意義）
    if (resp.day !== null) f.status = 'pending'
  } catch (err) {
    toast.add({ severity: 'error', summary: '儲存付款日失敗', detail: errorMessage(err), life: 3000 })
  } finally {
    scheduleSaving.value = false
  }
}

// 調整付款日（單筆或多筆）
const adjustTargets = ref<ExpenseSummary[] | null>(null)
const adjustDate = ref<Date | null>(null)
const adjustHasManual = computed(() => (adjustTargets.value ?? []).some((e) => e.plannedPayoutManual))
function openAdjust(list: ExpenseSummary[]) {
  adjustTargets.value = list
  const cur = list.length === 1 ? list[0].plannedPayoutDate : null
  adjustDate.value = cur ? new Date(`${cur}T00:00:00`) : null
}
async function applyAdjust(date: string | null) {
  const list = (adjustTargets.value ?? []).filter((e) => e.payoutStatus === 'pending')
  if (!list.length) {
    adjustTargets.value = null
    return
  }
  const results = await Promise.allSettled(list.map((e) => adjustPayoutDate(e.id, date)))
  let n = 0
  for (const r of results) {
    if (r.status === 'fulfilled') {
      patchLocal(r.value)
      n++
    }
  }
  const failed = results.length - n
  toast.add({
    severity: failed ? 'warn' : 'success',
    summary: date ? `已把 ${n} 筆改到 ${formatDate(date)} 付款` : `已把 ${n} 筆改回自動排程`,
    detail: failed ? `${failed} 筆調整失敗，請重試` : undefined,
    life: 3000,
  })
  adjustTargets.value = null
  selected.value = []
  // 分組視圖下付款日改動 → 批次歸屬要重算，refetch 一次
  if (grouped.value && n > 0) await refreshList()
}
function confirmAdjust() {
  if (!adjustDate.value) return
  void applyAdjust(toIsoDate(adjustDate.value))
}

// 批次標記已付款：一個付款日一組，或勾選的多筆
const batchList = ref<ExpenseSummary[] | null>(null)
const batchTitle = ref('')
const batchReimbs = computed(() => (batchList.value ?? []).filter((r) => r.source === 'reimbursement'))
const batchReimbCount = computed(() => batchReimbs.value.length)
// 單筆代墊款場景：summary 已有廠商 / 金額，不重複顯示提示與每列 head，只留 radio。
const isSingleReimb = computed(() => (batchList.value?.length ?? 0) === 1 && batchReimbCount.value === 1)
// 代墊款逐筆發放方式；一般支出不需（Expense 無此欄）。預設匯款。
const batchPaymentMethods = ref<Record<string, PaymentMethod>>({})
function initBatchPaymentMethods(rows: ExpenseSummary[]) {
  const next: Record<string, PaymentMethod> = {}
  for (const r of rows) {
    if (r.source === 'reimbursement') next[r.id] = 'bank_transfer'
  }
  batchPaymentMethods.value = next
}
function openBatch(batch: BatchGroup) {
  batchList.value = batch.rows
  batchTitle.value = batch.overdue ? '逾期未付款' : batch.date ? `${formatDate(batch.date)} 預計付款` : '待付款'
  initBatchPaymentMethods(batch.rows)
}
function openBatchSelected() {
  batchList.value = [...selected.value]
  batchTitle.value = '已選取的付款項目'
  initBatchPaymentMethods(batchList.value)
}
async function confirmBatch() {
  const list = batchList.value ?? []
  // 代墊款來源的支出由後端 /pay 自動反向同步 Reimbursement 狀態與發放方式
  const results = await Promise.allSettled(
    list.map((r) =>
      payExpense(r.id, {
        paymentMethod: r.source === 'reimbursement' ? batchPaymentMethods.value[r.id] : null,
      }),
    ),
  )
  let ok = 0
  for (const r of results) {
    if (r.status === 'fulfilled') {
      patchLocal(r.value)
      ok++
    }
  }
  const failed = results.length - ok
  toast.add({
    severity: failed ? 'warn' : 'success',
    summary: `已標記 ${ok} 筆為已付款`,
    detail: failed
      ? `${failed} 筆失敗，請重試`
      : batchReimbCount.value
        ? `其中 ${batchReimbCount.value} 筆代墊款同步標記為已發放`
        : undefined,
    life: 3000,
  })
  batchList.value = null
  batchPaymentMethods.value = {}
  selected.value = []
  await refreshPendingCount()
}

const isFiltered = computed(
  () => !!f.keyword.trim() || f.source !== 'all' || f.categories.length > 0 || !!(f.dateRange && f.dateRange.some((d) => d instanceof Date)),
)
// 首次 fetch 完成前 → 一律顯示 DataTable（PrimeVue loading mask 自然蓋上去），
// 避免 EmptyState 閃一下。完成後：有資料 or 有篩選 → DataTable；全空且無篩選 → EmptyState。
const hasAnyData = computed(
  () => !initialLoaded.value || loading.value || everHadData.value || total.value > 0 || isFiltered.value,
)

// ─── 明細抽屜 ─────────────────────────────────────
// detailId 跟 URL ?open 同步；detailExpense 由 syncDetailFromId 用 getExpense
// 取 full 欄位（含 attachments / items，列表精簡版沒有）。loading 期間顯示 skeleton。
const detailId = ref<string | null>(null)
const detailExpense = ref<Expense | null>(null)
const detailLoading = ref(false)
const detail = computed(() => detailExpense.value)

async function syncDetailFromId(id: string | null) {
  if (!id) {
    detailExpense.value = null
    detailLoading.value = false
    return
  }
  // 清掉上一筆避免殘影；開 drawer 時先顯示 loading
  detailExpense.value = null
  detailLoading.value = true
  try {
    detailExpense.value = await getExpense(id)
  } catch (err) {
    if (err instanceof HttpError && err.status === 404) {
      toast.add({ severity: 'warn', summary: '找不到該筆支出', detail: '可能已被刪除', life: 2500 })
    } else {
      toast.add({ severity: 'error', ...userErrorToast(err, '載入明細失敗'), life: 3000 })
    }
    detailId.value = null
  } finally {
    detailLoading.value = false
  }
}
watch(detailId, syncDetailFromId)

function openDetail(e: ExpenseSummary) {
  detailId.value = e.id
}
function onRowClick(evt: DataTableRowClickEvent) {
  openDetail(evt.data as ExpenseSummary)
}
watch(
  () => route.query.status,
  (status) => {
    if (status === 'pending' || status === 'paid' || status === 'all') f.status = status
  },
  { immediate: true },
)
// 抽屜開關與網址 ?open 同步（跨頁 share link 也可開；驗證由 syncDetailFromId 負責）
useOpenQuery(detailId)

function goNew() {
  router.push({ name: 'admin-expense-new' })
}
function goEdit(e: ExpenseSummary) {
  router.push({ name: 'admin-expense-edit', params: { id: e.id } })
}
async function markPaid(e: ExpenseSummary) {
  // 代墊款來源要先問發放方式；走單筆版本的批次 dialog 複用邏輯。
  if (e.source === 'reimbursement') {
    batchList.value = [e]
    batchTitle.value = '標記已付款'
    initBatchPaymentMethods([e])
    return
  }
  try {
    const updated = await payExpense(e.id)
    patchLocal(updated)
    await refreshPendingCount()
    toast.add({ severity: 'success', summary: `已把「${e.vendor || e.category.name}」標記為已付款`, life: 2500 })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '標記已付款失敗'), life: 3000 })
  }
}
function confirmDelete(target: ExpenseSummary) {
  if (target.payoutStatus === 'paid') {
    toast.add({ severity: 'warn', ...DELETE_BLOCKED.paid, life: 3000 })
    return
  }
  confirm.require({
    header: '移至垃圾桶',
    message: `確定要把「${target.vendor || '未填廠商'}」${formatCurrency(target.amount)} 這筆支出移至垃圾桶嗎？之後可在垃圾桶還原。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '移至垃圾桶',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      try {
        await deleteExpense(target.id)
        // 從目前頁面移除；若已空且非第 1 頁 → 往前退一頁，否則 refetch 維持 total 準確
        const idx = rows.value.findIndex((e) => e.id === target.id)
        if (idx !== -1) rows.value.splice(idx, 1)
        if (detailId.value === target.id) detailId.value = null
        total.value = Math.max(0, total.value - 1)
        if (rows.value.length === 0 && page.value > 1) {
          page.value = page.value - 1
        } else {
          await refreshList()
        }
        await refreshPendingCount()
        toast.add({ severity: 'success', summary: '已移至垃圾桶', detail: '可從垃圾桶還原', life: 2500 })
      } catch (err) {
        toast.add({ severity: 'error', ...userErrorToast(err, '刪除失敗'), life: 3000 })
      }
    },
  })
}

// ─── 匯入 ─────────────────────────────────────────
const showImport = ref(false)

// ─── 垃圾桶模式 ─────────────────────────────────────
// 整頁切成單一「已刪除支出」列表；不走 tabs / filter / batch。
// 走伺服器端分頁（跟主清單同一套 ROWS_OPTIONS）；還原/永久刪除就地從 trashRows
// 移除，並讓主清單總數 refetch 一次（refreshList），確保返回時 badge/count 正確。
const trashMode = ref(false)
const trashRows = ref<ExpenseSummary[]>([])
const trashLoading = ref(false)
const trashInitialLoaded = ref(false)
const trashPage = ref(1)
const trashPageSize = ref(10)
const trashTotal = ref(0)

async function refreshTrashList() {
  trashLoading.value = true
  try {
    const resp = await listTrashedExpenses({
      page: trashPage.value,
      perPage: trashPageSize.value,
    })
    trashRows.value = resp.data
    trashTotal.value = resp.meta.total
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '載入垃圾桶失敗'), life: 3000 })
    trashRows.value = []
    trashTotal.value = 0
  } finally {
    trashLoading.value = false
    trashInitialLoaded.value = true
  }
}

async function enterTrashMode() {
  trashMode.value = true
  trashInitialLoaded.value = false
  trashPage.value = 1
  await refreshTrashList()
}

function exitTrashMode() {
  trashMode.value = false
  trashRows.value = []
  trashTotal.value = 0
}

function onTrashPage(evt: DataTablePageEvent) {
  trashPageSize.value = evt.rows
  trashPage.value = evt.page + 1
}
// 只有在 trashMode 開著時才聽分頁變化，避免進頁前就 fetch 一次
watch([trashPage, trashPageSize], () => {
  if (trashMode.value) refreshTrashList()
})

/** 從 trashRows 就地移除；若該頁被清空且非第 1 頁 → 退一頁，否則 refetch 讓 total 準確。 */
async function removeFromTrashLocal(id: string) {
  const idx = trashRows.value.findIndex((x) => x.id === id)
  if (idx !== -1) trashRows.value.splice(idx, 1)
  trashTotal.value = Math.max(0, trashTotal.value - 1)
  if (trashRows.value.length === 0 && trashPage.value > 1) {
    trashPage.value = trashPage.value - 1
  } else {
    await refreshTrashList()
  }
}

async function restoreOne(target: ExpenseSummary) {
  try {
    await restoreExpense(target.id)
    toast.add({ severity: 'success', summary: `已還原「${target.vendor || target.category.name}」`, life: 2500 })
    await removeFromTrashLocal(target.id)
    // 主清單 total 可能受影響；返回後要正確顯示
    refreshList()
    refreshPendingCount()
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '還原失敗'), life: 3000 })
  }
}

function confirmPurge(target: ExpenseSummary) {
  confirm.require({
    header: '永久刪除支出',
    message: `確定要永久刪除「${target.vendor || '未填廠商'}」${formatCurrency(target.amount)} 這筆支出嗎？刪除後無法還原。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '永久刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      try {
        await purgeExpense(target.id)
        toast.add({ severity: 'success', summary: '已永久刪除', life: 2500 })
        await removeFromTrashLocal(target.id)
      } catch (err) {
        toast.add({ severity: 'error', ...userErrorToast(err, '永久刪除失敗'), life: 3000 })
      }
    },
  })
}

// 頁首：主要動作只有「新增支出」，匯入與付款日設定收進 ⋯
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = [
  { label: '匯入 Excel', icon: 'pi pi-upload', command: () => (showImport.value = true) },
  { label: '付款日設定', icon: 'pi pi-calendar-clock', command: () => openSchedule() },
  { label: '垃圾桶', icon: 'pi pi-trash', command: () => enterTrashMode() },
]

// 篩選：來源、類別、費用日收在「篩選」底下，點了在標題列下方展開一行；按鈕上顯示套用中的數量
const filterOpen = ref(false)
const activeFilterCount = computed(
  () => (f.source !== 'all' ? 1 : 0) + (f.categories.length ? 1 : 0) + (f.dateRange && f.dateRange.some((d) => d instanceof Date) ? 1 : 0),
)
function clearPanelFilters() {
  f.source = 'all'
  f.categories = []
  f.dateRange = null
}

// ─── 每列 ⋯ 選單 ─────────────────────────────────
const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<ExpenseSummary | null>(null)
const rowMenuItems = computed(() => {
  const t = menuTarget.value
  if (!t) return []
  return [
    { label: '查看詳情', icon: 'pi pi-eye', command: () => openDetail(t) },
    { label: '編輯', icon: 'pi pi-pencil', command: () => goEdit(t) },
    ...(t.payoutStatus === 'pending'
      ? [
          { label: '調整付款日', icon: 'pi pi-calendar', command: () => openAdjust([t]) },
          { label: '標記為已付款', icon: 'pi pi-check', command: () => markPaid(t) },
        ]
      : []),
    { separator: true },
    { label: '移至垃圾桶', icon: 'pi pi-trash', class: 'menu-danger', command: () => confirmDelete(t) },
  ]
})
function openRowMenu(event: MouseEvent, row: ExpenseSummary) {
  menuTarget.value = row
  rowMenu.value?.toggle(event)
}

function errorMessage(err: unknown): string {
  if (err instanceof HttpError) return (err.body as { error?: string })?.error ?? err.message
  if (err instanceof Error) return err.message
  return String(err)
}
</script>

<template>
  <div class="dash-page">
    <PageHeader :title="trashMode ? '支出垃圾桶' : '支出管理'" size="admin">
      <template #actions>
        <template v-if="trashMode">
          <Button label="返回支出" icon="pi pi-arrow-left" outlined @click="exitTrashMode" />
        </template>
        <template v-else>
          <Button label="新增支出" icon="pi pi-plus" data-tour="expenses-new-button" @click="goNew" />
          <Button v-tooltip.bottom="'更多動作'" icon="pi pi-ellipsis-h" outlined aria-label="更多動作" aria-haspopup="true" @click="pageMenu?.toggle($event)" />
          <Menu ref="pageMenu" :model="pageMenuItems" popup />
        </template>
      </template>
    </PageHeader>

    <BatchImportDialog v-if="!trashMode" v-model:visible="showImport" />

    <!-- 垃圾桶模式：獨立 table，只有「還原」動作；不走 tabs / filter / batch -->
    <section v-if="trashMode" class="dash-panel dash-table-panel trash-table-panel" aria-label="支出垃圾桶">
      <DataTable
        :value="trashRows"
        :loading="trashLoading"
        data-key="id"
        responsive-layout="scroll"
        lazy
        paginator
        :first="(trashPage - 1) * trashPageSize"
        :rows="trashPageSize"
        :total-records="trashTotal"
        :rows-per-page-options="ROWS_OPTIONS"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
        @page="onTrashPage"
      >
        <template #empty>
          <div v-if="!trashInitialLoaded || trashLoading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
          <div v-else class="dash-empty">垃圾桶是空的</div>
        </template>
        <Column header="刪除時間" :style="{ minWidth: '160px' }">
          <template #body="{ data }">{{ data.deletedAt ? formatDate(data.deletedAt) : '—' }}</template>
        </Column>
        <Column header="廠商 / 類別" :style="{ minWidth: '200px' }">
          <template #body="{ data }">
            <div class="font-medium">{{ data.vendor || '（未填廠商）' }}</div>
            <div class="text-xs text-[var(--color-muted)]">{{ data.category.name }}</div>
          </template>
        </Column>
        <Column header="費用日期" :style="{ minWidth: '120px' }">
          <template #body="{ data }">{{ formatDate(data.date) }}</template>
        </Column>
        <Column header="金額" :style="{ minWidth: '120px', textAlign: 'right' }">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="動作" :style="{ width: '200px', textAlign: 'right' }">
          <template #body="{ data }">
            <Button label="還原" icon="pi pi-undo" text size="small" @click="restoreOne(data as ExpenseSummary)" />
            <Button label="永久刪除" icon="pi pi-trash" text severity="danger" size="small" @click="confirmPurge(data as ExpenseSummary)" />
          </template>
        </Column>
      </DataTable>
    </section>

    <section v-else-if="hasAnyData" class="dash-panel dash-table-panel" aria-label="支出列表" data-tour="expenses-table">
      <!-- 卡片標題列：左分頁、右搜尋＋篩選（參考簡約列表：只留最常用的控制項） -->
      <div class="list-head">
        <TabBar v-model="f.status" :tabs="tabs" label="付款狀態" variant="segmented" />
        <div class="list-head-tools">
          <SearchInput v-model="f.keyword" placeholder="搜尋廠商、描述、發票號碼" />
          <Button
            label="篩選"
            :badge="activeFilterCount ? String(activeFilterCount) : undefined"
            icon="pi pi-sliders-h"
            outlined
            size="small"
            :class="{ 'is-open': filterOpen }"
            :aria-expanded="filterOpen"
            aria-controls="expense-filters"
            @click="filterOpen = !filterOpen"
          />
        </div>
      </div>
      <!-- 滑動展開：grid-template-rows 0fr ↔ 1fr；收起時 inert，Tab 不會跳進去 -->
      <div class="filter-collapse" :class="{ open: filterOpen }" :inert="!filterOpen">
      <div id="expense-filters" class="filter-row dash-filter">
        <Select v-model="f.source" :options="SOURCE_OPTIONS" option-label="label" option-value="value" class="w-[140px]" aria-label="來源" />
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
        <DatePicker v-model="f.dateRange" selection-mode="range" date-format="yy/mm/dd" placeholder="費用日區間" show-icon icon-display="input" :manual-input="false" class="w-[240px]" aria-label="費用日區間" />
        <Button v-if="activeFilterCount" label="清除篩選" text size="small" @click="clearPanelFilters" />
      </div>
      </div>

      <SelectionBar v-if="selected.length" class="list-selection" :count="selected.length" :summary="`合計 ${formatCurrency(selectedTotal)}`" @clear="selected = []">
        <Button label="調整付款日" icon="pi pi-calendar" size="small" outlined @click="openAdjust(selected)" />
        <Button label="標記已付款" size="small" @click="openBatchSelected" />
      </SelectionBar>
      <p v-if="f.status === 'pending' && payoutDay === null" class="dash-dialog-text px-5 pt-4">
        設定<button type="button" class="link-btn text-[13px]" @click="openSchedule">付款日</button>後，待付款會自動整理成付款批次，方便一次處理同一批款項。
      </p>
      <div v-if="grouped" class="batch-list">
        <div v-if="loading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
        <section v-for="batch in batchGroups" :key="batch.key" class="batch-card" :class="{ overdue: batch.overdue, open: isBatchOpen(batch.key) }">
          <div class="batch-card-head" @click="toggleBatch(batch.key)">
            <span class="batch-primary">
              <span class="batch-date">
                <span class="batch-eyebrow">
                  <i :class="batch.overdue ? 'pi pi-exclamation-circle' : 'pi pi-calendar'" aria-hidden="true" />
                  {{ batch.overdue ? '逾期未付款' : '預計付款日' }}
                </span>
                <strong>{{ formatDate(batch.date) }}</strong>
              </span>
              <span class="batch-total">
                <span>應付金額</span>
                <strong>{{ formatCurrency(batch.total) }}</strong>
              </span>
            </span>
            <span class="batch-actions">
              <Button label="標記這批已付款" size="small" text @click.stop="openBatch(batch)" />
              <button type="button" class="batch-toggle" :aria-expanded="isBatchOpen(batch.key)" @click.stop="toggleBatch(batch.key)">
                <i class="pi pi-chevron-down" aria-hidden="true" />
                <span class="sr-only">{{ isBatchOpen(batch.key) ? '收合付款批次' : '展開付款批次' }}</span>
              </button>
            </span>
          </div>
          <!-- 內容區用高度展開／收合（同篩選列 .filter-collapse） -->
          <div class="batch-collapse" :class="{ open: isBatchOpen(batch.key) }" :inert="!isBatchOpen(batch.key)">
          <div class="batch-card-body">
            <DataTable
              v-model:selection="selected"
              :value="batch.rows"
              data-key="id"
              :table-style="{ width: '100%', minWidth: '940px' }"
              row-hover
              :pt="{ bodyRow: { class: 'q-clickable', tabindex: 0 } }"
              @row-click="onRowClick"
            >
              <Column selection-mode="multiple" header-class="w-[44px]" :style="{ width: '48px' }" />
              <Column header="費用日" field="date">
                <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.date) }}</span></template>
              </Column>
              <Column header="類別">
                <template #body="{ data }">{{ data.category.name }}</template>
              </Column>
              <Column header="廠商/對象">
                <template #body="{ data }">
                  <div class="cell-trunc" :title="data.vendor || undefined">{{ data.vendor || '—' }}</div>
                  <div v-if="data.note" class="cell-sub" :title="data.note">{{ data.note }}</div>
                </template>
              </Column>
              <Column header="金額" field="amount" header-class="num" body-class="num">
                <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
              </Column>
              <Column header="來源" :style="{ width: '1%' }">
                <template #body="{ data }">
                  <span class="text-[var(--color-slate)]">{{ data.source === 'general' ? '一般支出' : '代墊款' }}</span>
                </template>
              </Column>
              <Column header="付款狀態" :style="{ width: '1%' }">
                <template #body="{ data }">
                  <span class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]" :class="data.payoutStatus === 'paid' ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'">
                    {{ data.payoutStatus === 'paid' ? '已付款' : '待付款' }}
                  </span>
                </template>
              </Column>
              <Column header-class="act" body-class="act" :style="{ width: '1%' }">
                <template #header><span class="sr-only">操作</span></template>
                <template #body="{ data }">
                  <Button icon="pi pi-ellipsis-h" text rounded severity="secondary" class="row-more" aria-label="更多動作" aria-haspopup="true" @click.stop="openRowMenu($event, data as ExpenseSummary)" />
                </template>
              </Column>
            </DataTable>
          </div>
          </div>
        </section>
      </div>
      <DataTable
        v-else
        v-model:selection="selected"
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '940px' }"
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
            {{ isFiltered ? '沒有符合條件的支出' : '目前沒有此狀態的支出' }}
            <Button v-if="isFiltered" label="清除所有篩選" text size="small" @click="resetAll" />
          </div>
        </template>
        <Column v-if="f.status === 'pending'" selection-mode="multiple" header-class="w-[44px]" :style="{ width: '48px' }" />
        <Column header="費用日" field="date">
          <template #body="{ data }"><span class="tabular-nums">{{ formatDate(data.date) }}</span></template>
        </Column>
        <Column header="類別">
          <template #body="{ data }">{{ data.category.name }}</template>
        </Column>
        <Column header="廠商/對象">
          <template #body="{ data }">
            <div class="cell-trunc" :title="data.vendor || undefined">{{ data.vendor || '—' }}</div>
            <div v-if="data.note" class="cell-sub" :title="data.note">{{ data.note }}</div>
          </template>
        </Column>
        <Column header="金額" field="amount" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrency(data.amount) }}</template>
        </Column>
        <Column header="來源" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="text-[var(--color-slate)]">{{ data.source === 'general' ? '一般支出' : '代墊款' }}</span>
          </template>
        </Column>
        <Column header="付款狀態" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]" :class="data.payoutStatus === 'paid' ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'">
              {{ data.payoutStatus === 'paid' ? '已付款' : '待付款' }}
            </span>
          </template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <Button icon="pi pi-ellipsis-h" text rounded severity="secondary" class="row-more" aria-label="更多動作" aria-haspopup="true" @click.stop="openRowMenu($event, data as ExpenseSummary)" />
          </template>
        </Column>
      </DataTable>
    </section>

    <EmptyState v-else-if="!trashMode" icon="pi pi-inbox" title="還沒有支出紀錄" description="新增第一筆，或從 Excel 匯入">
      <template #action>
        <Button label="新增支出" icon="pi pi-plus" @click="goNew" />
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
          <span>支出詳情</span>
          <span
            v-if="detail"
            class="status-chip inline-flex items-center rounded-full text-xs font-semibold px-2.5 py-[3px]"
            :class="detail.payoutStatus === 'paid' ? 'bg-[var(--color-status-paid-bg)] text-[var(--color-status-paid)]' : 'bg-[var(--color-status-review-bg)] text-[var(--color-status-review)]'"
          >
            {{ detail.payoutStatus === 'paid' ? '已付款' : '待付款' }}
          </span>
        </div>
      </template>
      <div v-if="detailLoading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
      <ExpenseDetail v-else-if="detail" :expense="detail" can-adjust-payout @adjust-payout="openAdjust([detail!])" />
      <template v-if="detail" #footer>
        <div class="q-drawer-foot">
          <Button label="移至垃圾桶" severity="danger" text @click="confirmDelete(detail)" />
          <span class="q-gap" />
          <Button v-if="detail.payoutStatus === 'pending'" label="標記為已付款" outlined @click="markPaid(detail)" />
          <Button label="編輯" @click="goEdit(detail)" />
        </div>
      </template>
    </Drawer>

    <Dialog v-model:visible="scheduleVisible" modal header="付款日設定" :style="{ width: 'min(92vw, 440px)' }">
      <div class="flex flex-col gap-4">
        <div class="q-field">
          <label for="payout-day">每月付款日</label>
          <Select
            v-model="scheduleDraft"
            input-id="payout-day"
            :options="PAYOUT_DAY_OPTIONS"
            option-label="label"
            option-value="value"
            filter
            auto-filter-focus
            filter-placeholder="輸入日期，例如 15 或 月底"
            reset-filter-on-hide
            empty-filter-message="找不到這個日期"
            placeholder="不自動建立付款批次"
            show-clear
            fluid
            aria-describedby="payout-day-help"
          />
          <span id="payout-day-help" class="q-help">{{ scheduleHint.rule }}<template v-if="scheduleHint.example"><br />{{ scheduleHint.example }}</template><template v-if="scheduleHint.note"><br />{{ scheduleHint.note }}</template></span>
        </div>
      </div>
      <template #footer>
        <Button label="取消" outlined :disabled="scheduleSaving" @click="scheduleVisible = false" />
        <Button label="儲存" :loading="scheduleSaving" @click="saveSchedule" />
      </template>
    </Dialog>

    <Dialog :visible="adjustTargets !== null" modal header="調整付款日" :style="{ width: 'min(92vw, 400px)' }" @update:visible="adjustTargets = null">
      <div class="flex flex-col gap-4">
        <div v-if="adjustTargets?.length === 1" class="dlg-summary">
          <b>{{ adjustTargets[0].category.name }}</b>
          <span><template v-if="adjustTargets[0].vendor">{{ adjustTargets[0].vendor }}<span class="sep" aria-hidden="true" /></template>費用日 {{ formatDate(adjustTargets[0].date) }}</span>
          <strong>{{ formatCurrency(adjustTargets[0].amount) }}</strong>
        </div>
        <div v-else class="dlg-summary">
          <b>已選 {{ adjustTargets?.length }} 筆</b>
          <span>預計付款日將一起改為所選日期</span>
          <strong>{{ formatCurrency((adjustTargets ?? []).reduce((s, e) => s + e.amount, 0)) }}</strong>
        </div>
        <div class="q-field">
          <label for="adjust-date">預計付款日</label>
          <DatePicker v-model="adjustDate" input-id="adjust-date" date-format="yy/mm/dd" show-icon icon-display="input" :manual-input="false" fluid />
        </div>
      </div>
      <template #footer>
        <button v-if="adjustHasManual" type="button" class="link-btn is-md mr-auto" @click="applyAdjust(null)">改回自動排程</button>
        <Button label="取消" outlined @click="adjustTargets = null" />
        <Button label="儲存" :disabled="!adjustDate" @click="confirmAdjust" />
      </template>
    </Dialog>

    <Dialog :visible="batchList !== null" modal :header="batchList && batchList.length === 1 ? '標記已付款' : '批次標記已付款'" :style="{ width: 'min(92vw, 520px)' }" @update:visible="batchList = null">
      <div class="flex flex-col gap-4">
        <div class="dlg-summary">
          <b>{{ batchTitle }}</b>
          <span>{{ batchList?.length }} 筆待付款</span>
          <strong>{{ formatCurrency((batchList ?? []).reduce((s, r) => s + r.amount, 0)) }}</strong>
        </div>
        <p v-if="batchReimbCount && !isSingleReimb" class="dash-dialog-text">其中 {{ batchReimbCount }} 筆是員工代墊款，請選擇發放方式；確認後會同時把請款單標記為「已發放」。</p>
        <ul v-if="batchReimbCount" class="pay-method-list" :class="{ 'is-single': isSingleReimb }">
          <li v-for="r in batchReimbs" :key="r.id">
            <div v-if="!isSingleReimb" class="pay-method-head">
              <span class="pay-method-who">{{ r.vendor || r.category.name }}</span>
              <strong>{{ formatCurrency(r.amount) }}</strong>
            </div>
            <div class="choice-cards" role="radiogroup" :aria-label="`${r.vendor || r.category.name} 的發放方式`">
              <label>
                <input :id="`pm-bank-${r.id}`" type="radio" :name="`pay-method-${r.id}`" value="bank_transfer" :checked="batchPaymentMethods[r.id] === 'bank_transfer'" @change="batchPaymentMethods[r.id] = 'bank_transfer'" />
                <span>{{ PAYMENT_METHOD_LABELS.bank_transfer }}</span>
              </label>
              <label>
                <input :id="`pm-cash-${r.id}`" type="radio" :name="`pay-method-${r.id}`" value="cash" :checked="batchPaymentMethods[r.id] === 'cash'" @change="batchPaymentMethods[r.id] = 'cash'" />
                <span>{{ PAYMENT_METHOD_LABELS.cash }}</span>
              </label>
            </div>
          </li>
        </ul>
      </div>
      <template #footer>
        <Button label="取消" outlined @click="batchList = null" />
        <Button :label="`標記 ${batchList?.length ?? 0} 筆已付款`" @click="confirmBatch" />
      </template>
    </Dialog>

    <Menu ref="rowMenu" :model="rowMenuItems" popup />
  </div>
</template>

<style scoped>
.batch-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin: 14px calc(var(--space-lg) * -1) 0;
  padding: 0 20px 20px;
}
.batch-card {
  overflow: hidden;
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-card-lg);
  background: var(--color-canvas);
}
.batch-card-head {
  display: grid;
  grid-template-columns: minmax(380px, 1fr) auto;
  align-items: center;
  gap: 18px;
  min-height: 92px;
  padding: 18px 20px;
  background: #fbfcfd;
}
.batch-card.overdue .batch-card-head { background: #fffafa; }
.batch-card-body {
  background: var(--color-canvas);
}
.batch-card-body :deep(.p-datatable) { margin: 0; }
.batch-card-body :deep(.p-datatable-tbody > tr:last-child > td) { border-bottom: 0; }
.batch-card-body :deep(.p-datatable-thead > tr > th:first-child),
.batch-card-body :deep(.p-datatable-tbody > tr > td:first-child) { padding-left: 20px; }
.batch-card-body :deep(.p-datatable-thead > tr > th:last-child),
.batch-card-body :deep(.p-datatable-tbody > tr > td:last-child) { padding-right: 20px; }
.batch-primary {
  display: inline-flex;
  align-items: flex-end;
  gap: clamp(28px, 5vw, 72px);
  min-width: 0;
}
.batch-date,
.batch-total {
  display: inline-flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}
.batch-eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  font-weight: 400;
  color: var(--color-muted);
}
.batch-card.overdue .batch-eyebrow { color: var(--color-danger); font-weight: 600; }
.batch-date strong,
.batch-total strong {
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--color-ink);
  font-variant-numeric: tabular-nums;
}
.batch-card.overdue .batch-date strong,
.batch-card.overdue .batch-total strong { color: var(--color-danger); }
.batch-total span { font-size: 14px; color: var(--color-muted); }
.batch-card.overdue .batch-total span { color: var(--color-danger); font-weight: 600; }
.batch-total { align-items: flex-start; text-align: left; }
.batch-actions {
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}
.batch-toggle {
  width: 36px;
  height: 36px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 0;
  border-radius: var(--radius-full);
  background: transparent;
  color: var(--color-slate);
  cursor: pointer;
}
.batch-toggle:hover { background: var(--color-surface-soft); color: var(--color-ink); }
/* 整個標題列可點擊展開／收合；「標記這批已付款」與箭頭按鈕各自 stop，不會重複觸發 */
.batch-card-head { cursor: pointer; transition: background-color .15s ease; }
.batch-card-head:hover { background: var(--color-surface); }
.batch-card.overdue .batch-card-head:hover { background: #fff3f3; }
.batch-toggle .pi { transition: transform .22s ease; }
.batch-card.open .batch-toggle .pi { transform: rotate(180deg); }
.batch-collapse { display: grid; grid-template-rows: 0fr; transition: grid-template-rows .22s ease; }
.batch-collapse.open { grid-template-rows: 1fr; border-top: 1px solid var(--color-hairline); }
.batch-collapse > .batch-card-body { min-height: 0; overflow: hidden; }
@media (prefers-reduced-motion: reduce) {
  .batch-collapse, .batch-toggle .pi, .batch-card-head { transition: none; }
}
.list-head { display: flex; align-items: center; justify-content: space-between; gap: 12px 24px; flex-wrap: wrap; min-height: 68px; margin-inline: calc(var(--space-lg) * -1); padding-inline: 20px; }
/* 分頁（膠囊分段式）與右側工具垂直置中；不加整條分隔線，下方灰色表頭已足以分隔 */
.list-head-tools :deep(.search-sm) { width: 280px; }
.list-head-tools { display: flex; align-items: center; gap: 8px; padding: 12px 0; margin-left: auto; }
.list-head-tools :deep(.p-button.is-open) { background: var(--color-primary-50); }
.filter-collapse { display: grid; grid-template-rows: 0fr; margin-inline: calc(var(--space-lg) * -1); transition: grid-template-rows .22s ease; }
.filter-collapse.open { grid-template-rows: 1fr; }
.filter-collapse > .filter-row { min-height: 0; overflow: hidden; }
/* 篩選列白底，視為標題列往下延伸；灰色只留給表頭 */
.filter-row { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; padding: 0 20px; margin-bottom: 0; background: var(--color-canvas, #fff); transition: padding .22s ease; }
.filter-collapse.open > .filter-row { padding-block: 4px 16px; }
@media (prefers-reduced-motion: reduce) { .filter-collapse, .filter-row { transition: none; } }
.list-selection { margin: 12px 0; }
:deep(.row-more.p-button) { width: 40px; min-width: 40px; height: 40px; min-height: 40px; color: var(--color-slate); }
@media (max-width: 960px) {
  .batch-card-head { grid-template-columns: minmax(0, 1fr) auto; }
  .batch-primary { flex-wrap: wrap; gap: 16px 28px; }
  .batch-actions { grid-column: 1 / -1; justify-content: flex-start; }
}
/* 批次標記已付款 dialog 內的代墊款發放方式逐筆選擇區 */
.pay-method-list { display: flex; flex-direction: column; gap: 12px; margin: 0; padding: 0; list-style: none; }
.pay-method-list > li { display: flex; flex-direction: column; gap: 8px; padding: 12px 14px; border: 1px solid var(--color-hairline); border-radius: var(--radius-card); background: var(--color-canvas); }
/* 單筆代墊款場景：summary 已承載廠商／金額，列表外框與內距都去掉，只留 radio */
.pay-method-list.is-single > li { padding: 0; border: 0; background: transparent; }
.pay-method-head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; font-size: 14px; }
.pay-method-who { color: var(--color-ink); font-weight: 600; }
.choice-cards { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.choice-cards > label { display: flex; align-items: center; gap: 8px; padding: 10px 12px; border: 1.5px solid var(--color-hairline); border-radius: var(--radius-card); font-size: 14px; cursor: pointer; transition: border-color .15s ease, background .15s ease; }
.choice-cards > label:hover { border-color: var(--color-primary); }
.choice-cards > label:has(input:checked) { border-color: var(--color-primary); background: var(--color-primary-50); }
.choice-cards > label > input { accent-color: var(--color-primary); }
</style>
