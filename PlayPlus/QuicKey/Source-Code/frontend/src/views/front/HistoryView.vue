<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, useTemplateRef, watch } from 'vue'
import { useRouter } from 'vue-router'
import type { ReimbursementStatus } from '@/types/domain'
import {
  deleteReimbursement,
  listReimbursements,
  withdrawReimbursement,
  type MyReimbursementSummary,
  type ReimbursementListFilters,
} from '@/api/reimbursements'
import { listCategories, type Category } from '@/api/categories'
import { formatCurrency, formatDate, toIsoDate } from '@/utils/format'
import PageHeader from '@/components/PageHeader.vue'
import TabBar from '@/components/qds/TabBar.vue'
import { useReimbursementPayout } from '@/composables/useReimbursementPayout'
import EmptyState from '@/components/EmptyState.vue'
import StatusBadge from '@/components/StatusBadge.vue'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import Drawer from 'primevue/drawer'
import IconField from 'primevue/iconfield'
import InputIcon from 'primevue/inputicon'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'
import MultiSelect from 'primevue/multiselect'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'

const router = useRouter()
const confirm = useConfirm()
const toast = useToast()

// ─── 滾動載入 state（server-side 分頁、每頁 10 筆） ──────────
// rows 累積每頁回來的資料；IntersectionObserver 觀察到 sentinel 進入可視範圍
// 就自動抓下一頁 append。filter / tab / 關鍵字變動會重設到第一頁 refetch。
const PAGE_SIZE = 10
const rows = ref<MyReimbursementSummary[]>([])
const page = ref(1)
const total = ref(0)
const hasMore = ref(true)
const isLoading = ref(false)       // 首次 / filter 變動後 full-page loading
const isLoadingMore = ref(false)   // 滾到底後 append 下一頁
const activeCategories = ref<Category[]>([])
// 各 tab 的筆數：filter 條件不變、僅 statuses 不同，獨立 perPage=1 count 請求。
type StatusTab = 'all' | 'pending' | 'review' | 'approved' | 'done'
const tabCounts = ref<Record<StatusTab, number>>({ all: 0, pending: 0, review: 0, approved: 0, done: 0 })

const categoryFilterOptions = computed(() =>
  activeCategories.value.map((c) => ({ value: c.id, label: c.name })),
)

/**
 * 狀態 tab 對應的原始 status：
 * - all      : 全部
 * - pending  : 待處理（駁回 + 草稿）——需要員工立即動作的兩種狀態
 * - review   : 簽核中（in_review，僅等待簽核）
 * - approved : 已核銷（等待管理員發放）
 * - done     : 完成（paid + voided，已終結）
 */
const STATUS_TABS: { value: StatusTab; label: string }[] = [
  { value: 'all', label: '全部' },
  { value: 'pending', label: '待處理' },
  { value: 'review', label: '簽核中' },
  { value: 'approved', label: '已核銷' },
  { value: 'done', label: '完成' },
]

const TAB_STATUSES: Record<StatusTab, ReimbursementStatus[] | 'all'> = {
  all: 'all',
  pending: ['rejected', 'draft'],
  review: ['in_review'],
  approved: ['approved'],
  done: ['paid', 'voided'],
}

const activeTab = ref<StatusTab>('all')
const keyword = ref('')
const committedKeyword = ref('')
/** 桌機關鍵字暫存（跟 draftFilters 一起，按「搜尋」才 commit 到 keyword） */
const draftKeyword = ref('')
const drawerOpen = ref(false)

// 關鍵字綁 keyword；IME 組字期間不觸發 commit，正常輸入 300ms debounce
// 到 committedKeyword，避免每個 keystroke 都打 API。
let isComposing = false
let kwTimer: number | null = null

function scheduleKeywordCommit() {
  if (kwTimer !== null) window.clearTimeout(kwTimer)
  kwTimer = window.setTimeout(() => {
    committedKeyword.value = keyword.value
    kwTimer = null
  }, 300)
}

function onKeywordInput() {
  if (isComposing) return
  scheduleKeywordCommit()
}
function onCompositionStart() {
  isComposing = true
}
function onCompositionEnd() {
  isComposing = false
  scheduleKeywordCommit()
}

function clearKeyword() {
  if (!keyword.value) return
  keyword.value = ''
  if (kwTimer !== null) {
    window.clearTimeout(kwTimer)
    kwTimer = null
  }
  committedKeyword.value = ''
}

function clearDraftKeyword() {
  draftKeyword.value = ''
}

/** 桌機關鍵字 Enter 觸發搜尋（略過 IME composition Enter 的誤觸） */
function onDesktopKeywordKeydown(ev: KeyboardEvent) {
  if (ev.key === 'Enter' && !ev.isComposing) {
    ev.preventDefault()
    applyDraftFilters()
  }
}

function selectTab(t: StatusTab) {
  activeTab.value = t
}

interface Filters {
  dateRange: (Date | null)[] | null
  amountMin: number | null
  amountMax: number | null
  categories: string[]
}

function emptyFilters(): Filters {
  return {
    dateRange: null,
    amountMin: null,
    amountMax: null,
    categories: [],
  }
}

// 已套用的篩選（實際過濾清單用）
const filters = reactive<Filters>(emptyFilters())
// Drawer 內編輯中的暫存（按套用才會覆寫 filters）
const draftFilters = reactive<Filters>(emptyFilters())

function openDrawer() {
  draftFilters.dateRange = filters.dateRange ? [...filters.dateRange] : null
  draftFilters.amountMin = filters.amountMin
  draftFilters.amountMax = filters.amountMax
  draftFilters.categories = [...filters.categories]
  drawerOpen.value = true
}

function toggleCategory(c: string) {
  const idx = draftFilters.categories.indexOf(c)
  if (idx === -1) draftFilters.categories.push(c)
  else draftFilters.categories.splice(idx, 1)
}

function applyDraftFilters() {
  filters.dateRange = draftFilters.dateRange ? [...draftFilters.dateRange] : null
  filters.amountMin = draftFilters.amountMin
  filters.amountMax = draftFilters.amountMax
  filters.categories = [...draftFilters.categories]
  // 桌機關鍵字也一起 commit（手機 keyword input 是即時綁 keyword）
  keyword.value = draftKeyword.value
  committedKeyword.value = draftKeyword.value
  drawerOpen.value = false
}

function resetDraftFilters() {
  draftFilters.dateRange = null
  draftFilters.amountMin = null
  draftFilters.amountMax = null
  draftFilters.categories = []
}

function clearAllFilters() {
  keyword.value = ''
  committedKeyword.value = ''
  filters.dateRange = null
  filters.amountMin = null
  filters.amountMax = null
  filters.categories = []
  // 桌機 inline widgets 綁 draftFilters/draftKeyword；一併清空以免顯示殘留
  draftKeyword.value = ''
  resetDraftFilters()
}

function hasDateRange(range: Filters['dateRange']): boolean {
  return !!range && range.some((d) => d instanceof Date)
}

const activeFilterCount = computed(() => {
  let n = 0
  if (hasDateRange(filters.dateRange)) n++
  if (filters.amountMin !== null || filters.amountMax !== null) n++
  if (filters.categories.length > 0) n++
  return n
})

const { payoutInfo } = useReimbursementPayout()
/** 卡片第一列標籤：「預計 2026/10/05 發放」／「2026/09/10 已發放」 */
function payoutPhrase(r: MyReimbursementSummary): string {
  const p = payoutInfo(r)
  if (!p) return ''
  return p.kind === 'paid' ? `${p.date} 已發放` : `預計 ${p.date} 發放`
}

// ─── 把目前的篩選狀態轉成 API query（不含 page / perPage） ─────────
function buildQuery(overrides: Partial<ReimbursementListFilters> = {}): ReimbursementListFilters {
  const q: ReimbursementListFilters = {
    q: committedKeyword.value.trim() || undefined,
    categoryIds: filters.categories.length ? filters.categories : undefined,
    amountMin: filters.amountMin ?? undefined,
    amountMax: filters.amountMax ?? undefined,
  }
  if (filters.dateRange) {
    const [from, to] = filters.dateRange
    if (from instanceof Date) q.dateFrom = toIsoDate(from)
    if (to instanceof Date) q.dateTo = toIsoDate(to)
  }
  const spec = TAB_STATUSES[activeTab.value]
  if (spec !== 'all') q.statuses = spec
  return { ...q, ...overrides }
}

async function fetchPage(nextPage: number) {
  const resp = await listReimbursements({ ...buildQuery(), page: nextPage, perPage: PAGE_SIZE })
  rows.value = nextPage === 1 ? resp.data : [...rows.value, ...resp.data]
  page.value = nextPage
  total.value = resp.meta.total
  hasMore.value = rows.value.length < resp.meta.total
}

async function reload() {
  isLoading.value = true
  rows.value = []
  hasMore.value = true
  page.value = 1
  try {
    await fetchPage(1)
  } catch {
    toast.add({ severity: 'error', summary: '載入歷史記錄失敗', life: 3000 })
    rows.value = []
    hasMore.value = false
  } finally {
    isLoading.value = false
  }
}

async function loadMore() {
  if (isLoading.value || isLoadingMore.value || !hasMore.value) return
  isLoadingMore.value = true
  try {
    await fetchPage(page.value + 1)
  } catch {
    toast.add({ severity: 'error', summary: '載入更多失敗', life: 3000 })
  } finally {
    isLoadingMore.value = false
  }
}

/** 五個 tab 各自 perPage=1 計數；filter 條件照帶、statuses 覆寫為 tab 自己的。 */
async function refreshCounts() {
  const base = buildQuery({ page: 1, perPage: 1 })
  delete base.statuses
  const results = await Promise.all(
    STATUS_TABS.map(async (t) => {
      const spec = TAB_STATUSES[t.value]
      const q: ReimbursementListFilters = { ...base }
      if (spec !== 'all') q.statuses = spec
      try {
        const resp = await listReimbursements(q)
        return [t.value, resp.meta.total] as const
      } catch {
        return [t.value, 0] as const
      }
    }),
  )
  const next: Record<StatusTab, number> = { all: 0, pending: 0, review: 0, approved: 0, done: 0 }
  for (const [k, v] of results) next[k] = v
  tabCounts.value = next
}

async function refreshAll() {
  await Promise.all([reload(), refreshCounts()])
}

onMounted(() => {
  // 類別清單與請款列表並行載入，彼此錯誤不影響。
  listCategories({ kind: 'expense' })
    .then((cs) => { activeCategories.value = cs })
    .catch(() => { activeCategories.value = [] })
  refreshAll()
})

// tab / filter 變動立即 refetch；關鍵字由 scheduleKeywordCommit 的 300ms debounce 控節奏
watch(activeTab, () => refreshAll())
watch(
  () => [[...filters.categories], filters.dateRange, filters.amountMin, filters.amountMax],
  () => refreshAll(),
  { deep: true },
)
watch(committedKeyword, () => refreshAll())

const statusTabs = computed(() =>
  STATUS_TABS.map((t) => ({ ...t, count: tabCounts.value[t.value] })),
)

const hasFilterOrKeyword = computed(
  () =>
    committedKeyword.value.trim().length > 0 || activeFilterCount.value > 0,
)

function rejectedComment(r: MyReimbursementSummary): string | null {
  if (r.status !== 'rejected' || !r.approvalProgress) return null
  const rejected = r.approvalProgress.steps.find((s) => s.status === 'rejected')
  return rejected?.comment ?? null
}

/**
 * 駁回訊息預設單行截斷；只在真的溢出時才顯示 chevron 並允許展開。
 * commentRefs 追蹤各卡片的文字節點，measureOverflow 依 scrollWidth 判斷是否溢出。
 * 監看 rows 與 window resize 兩個時機重新量測。
 */
const commentRefs = new Map<string, HTMLElement>()
const overflowingComments = ref(new Set<string>())
const expandedComments = ref(new Set<string>())

function bindCommentRef(el: HTMLElement | null, id: string) {
  if (el) commentRefs.set(id, el)
  else commentRefs.delete(id)
}

function measureOverflow() {
  const next = new Set<string>()
  for (const [id, el] of commentRefs) {
    // 已展開的卡片保留先前的溢出判定（此時 truncate 已拆掉，量不到）
    if (expandedComments.value.has(id)) {
      if (overflowingComments.value.has(id)) next.add(id)
      continue
    }
    if (el.scrollWidth > el.clientWidth + 1) next.add(id)
  }
  overflowingComments.value = next
}

function toggleCommentExpand(id: string) {
  const next = new Set(expandedComments.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  expandedComments.value = next
}

function handleCommentClick(ev: MouseEvent, id: string) {
  if (!overflowingComments.value.has(id)) return
  ev.stopPropagation()
  toggleCommentExpand(id)
}

watch(
  rows,
  async () => {
    await nextTick()
    measureOverflow()
  },
  { immediate: true },
)

// ─── 無限捲動：sentinel 進入可視範圍就抓下一頁 ────────────────
const sentinel = useTemplateRef<HTMLElement>('sentinel')
let io: IntersectionObserver | null = null

onMounted(() => {
  window.addEventListener('resize', measureOverflow)
  if (typeof IntersectionObserver === 'undefined') return
  io = new IntersectionObserver(
    (entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore()
    },
    { rootMargin: '200px' },
  )
  watch(
    sentinel,
    (el, _old, onCleanup) => {
      if (!io || !el) return
      io.observe(el)
      onCleanup(() => io?.unobserve(el))
    },
    { immediate: true },
  )
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', measureOverflow)
  io?.disconnect()
})

function isImageDataUrl(url: string) {
  return url.startsWith('data:image/')
}

function goNew() {
  router.push({ name: 'front-new' })
}

function openDetail(id: string) {
  router.push({ name: 'front-expense-detail', params: { id } })
}

function confirmDelete(r: MyReimbursementSummary) {
  const isDraft = r.status === 'draft'
  confirm.require({
    header: isDraft ? '刪除草稿' : '刪除退回記錄',
    message: isDraft
      ? '確定要刪除這筆草稿嗎？此動作無法復原。'
      : '確定要刪除這筆已退回的請款嗎？此動作無法復原。',
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      try {
        await deleteReimbursement(r.id)
        toast.add({
          severity: 'success',
          summary: isDraft ? '草稿已刪除' : '記錄已刪除',
          life: 2500,
        })
        await reload()
      } catch {
        toast.add({ severity: 'error', summary: '刪除失敗', life: 3000 })
      }
    },
  })
}

function goEdit(r: MyReimbursementSummary) {
  router.push({ name: 'front-expense-edit', params: { id: r.id } })
}

function confirmWithdraw(r: MyReimbursementSummary) {
  confirm.require({
    header: '取消簽核',
    message: '取消後這筆請款會退回草稿，你可以繼續編輯或刪除。確定要繼續嗎？',
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '取消簽核',
    rejectLabel: '返回',
    accept: async () => {
      try {
        await withdrawReimbursement(r.id)
        toast.add({ severity: 'success', summary: '已退回草稿', life: 2500 })
        await reload()
      } catch {
        toast.add({ severity: 'error', summary: '取消失敗', life: 3000 })
      }
    },
  })
}

/**
 * 卡片右上角「更多」按鈕 → bottom sheet 的 action 定義。
 * 依 status 決定可用操作；沒有可用操作的狀態不會顯示更多按鈕。
 */
interface ReimbursementAction {
  key: string
  label: string
  icon: string
  colorClass: string
  handler: () => void
}

function actionsForReimbursement(r: MyReimbursementSummary): ReimbursementAction[] {
  if (r.status === 'draft') {
    return [
      {
        key: 'edit',
        label: '編輯草稿',
        icon: 'pi pi-pencil',
        colorClass: 'text-primary-700',
        handler: () => goEdit(r),
      },
      {
        key: 'delete',
        label: '刪除草稿',
        icon: 'pi pi-trash',
        colorClass: 'text-[var(--color-status-rejected)]',
        handler: () => confirmDelete(r),
      },
    ]
  }
  if (r.status === 'rejected') {
    return [
      {
        key: 'edit',
        label: '重新編輯',
        icon: 'pi pi-pencil',
        colorClass: 'text-primary-700',
        handler: () => goEdit(r),
      },
      {
        key: 'delete',
        label: '刪除記錄',
        icon: 'pi pi-trash',
        colorClass: 'text-[var(--color-status-rejected)]',
        handler: () => confirmDelete(r),
      },
    ]
  }
  if (r.status === 'in_review') {
    return [
      {
        key: 'withdraw',
        label: '取消簽核',
        icon: 'pi pi-undo',
        colorClass: 'text-[var(--color-status-review)]',
        handler: () => confirmWithdraw(r),
      },
    ]
  }
  return []
}

function hasActions(r: MyReimbursementSummary): boolean {
  return actionsForReimbursement(r).length > 0
}

const actionSheetReimbursement = ref<MyReimbursementSummary | null>(null)
const currentActions = computed<ReimbursementAction[]>(() =>
  actionSheetReimbursement.value
    ? actionsForReimbursement(actionSheetReimbursement.value)
    : [],
)

function openActionSheet(r: MyReimbursementSummary) {
  actionSheetReimbursement.value = r
}
function closeActionSheet() {
  actionSheetReimbursement.value = null
}
function runAction(action: ReimbursementAction) {
  closeActionSheet()
  action.handler()
}

</script>

<template>
  <div>
    <PageHeader title="歷史記錄" />

    <!--
      Search + filter：
      - 手機：關鍵字即時搜尋、篩選走 icon → bottom sheet drawer（draft → 套用）
      - 桌機：keyword + 篩選都綁 draft state，按「搜尋」才 commit；Enter 也可以送出。
        兩邊 UX 一致：filter 需要按按鈕才生效
    -->
    <div class="mb-3 flex items-end gap-2 flex-wrap">
      <!-- 手機：關鍵字 input（即時搜尋） -->
      <IconField class="flex-1 relative min-w-[180px] lg:hidden">
        <InputIcon
          :class="[
            isLoading ? 'pi pi-spin pi-spinner' : 'pi pi-search',
            'text-[var(--color-muted)]',
          ]"
        />
        <InputText
          v-model="keyword"
          placeholder="搜尋描述"
          class="w-full !pl-10"
          :class="keyword ? '!pr-10' : ''"
          @input="onKeywordInput"
          @compositionstart="onCompositionStart"
          @compositionend="onCompositionEnd"
        />
        <button
          v-if="keyword"
          type="button"
          aria-label="清除關鍵字"
          class="absolute right-2 top-1/2 -translate-y-1/2 w-7 h-7 rounded-full flex items-center justify-center text-[var(--color-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-ink)] transition-colors"
          @click="clearKeyword"
        >
          <i class="pi pi-times text-xs" />
        </button>
      </IconField>

      <!-- 手機：篩選 icon → bottom sheet -->
      <button
        type="button"
        class="lg:hidden relative inline-flex items-center justify-center w-11 h-11 rounded-chip border-[1.5px] transition-colors flex-shrink-0"
        :class="
          activeFilterCount > 0
            ? 'border-primary-700 bg-primary-50 text-primary-700'
            : 'border-[var(--color-hairline)] bg-white text-[var(--color-slate)] hover:bg-[var(--color-surface)]'
        "
        aria-label="開啟篩選"
        @click="openDrawer"
      >
        <i class="pi pi-sliders-h" />
        <span
          v-if="activeFilterCount > 0"
          class="absolute -top-1.5 -right-1.5 min-w-[1.1rem] h-[1.1rem] px-1 rounded-full bg-primary-700 text-white text-[10px] font-medium flex items-center justify-center tabular-nums"
        >
          {{ activeFilterCount }}
        </span>
      </button>

      <!-- 桌機：關鍵字（綁 draftKeyword；Enter or 搜尋按鈕才 commit） -->
      <div class="hidden lg:block lg:w-72">
        <label class="text-xs text-[var(--color-muted)] mb-1 block">關鍵字</label>
        <IconField class="relative">
          <InputIcon class="pi pi-search text-[var(--color-muted)]" />
          <InputText
            v-model="draftKeyword"
            placeholder="搜尋描述"
            class="w-full !pl-10"
            :class="draftKeyword ? '!pr-10' : ''"
            @keydown="onDesktopKeywordKeydown"
          />
          <button
            v-if="draftKeyword"
            type="button"
            aria-label="清除關鍵字"
            class="absolute right-2 top-1/2 -translate-y-1/2 w-7 h-7 rounded-full flex items-center justify-center text-[var(--color-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-ink)] transition-colors"
            @click="clearDraftKeyword"
          >
            <i class="pi pi-times text-xs" />
          </button>
        </IconField>
      </div>

      <!-- 桌機：日期 -->
      <div class="hidden lg:block lg:w-48">
        <label class="text-xs text-[var(--color-muted)] mb-1 block">
          費用日期
        </label>
        <DatePicker
          v-model="draftFilters.dateRange"
          selection-mode="range"
          :manual-input="false"
          date-format="yy-mm-dd"
          placeholder="日期區間"
          show-icon
          icon-display="input"
          class="w-full"
          fluid
        />
      </div>

      <!-- 桌機：金額 -->
      <div class="hidden lg:block">
        <label class="text-xs text-[var(--color-muted)] mb-1 block">
          金額區間
        </label>
        <div class="flex items-center gap-1">
          <InputNumber
            v-model="draftFilters.amountMin"
            mode="currency"
            currency="TWD"
            locale="zh-TW"
            :min-fraction-digits="0"
            :max-fraction-digits="0"
            :min="0"
            placeholder="下限"
            class="w-32"
            input-class="w-full"
          />
          <span class="text-[var(--color-muted)] text-sm">—</span>
          <InputNumber
            v-model="draftFilters.amountMax"
            mode="currency"
            currency="TWD"
            locale="zh-TW"
            :min-fraction-digits="0"
            :max-fraction-digits="0"
            :min="0"
            placeholder="上限"
            class="w-32"
            input-class="w-full"
          />
        </div>
      </div>

      <!-- 桌機：類別（MultiSelect） -->
      <div class="hidden lg:block lg:w-52">
        <label class="text-xs text-[var(--color-muted)] mb-1 block">
          費用類別
        </label>
        <MultiSelect
          :show-toggle-all="false"
          v-model="draftFilters.categories"
          :options="categoryFilterOptions"
          option-label="label"
          option-value="value"
          placeholder="全部類別"
          class="w-full"
          :max-selected-labels="3"
        />
      </div>

      <!-- 桌機：搜尋/清除按鈕（跟著 filter 走，不置右） -->
      <!-- !py-3 把 button paddingY 從 preset 的 10px 拉到 12px，跟 form field 齊高 -->
      <div class="hidden lg:flex items-center gap-2">
        <Button
          type="button"
          label="搜尋"
          icon="pi pi-search"
          class="!py-3"
          @click="applyDraftFilters"
        />
        <Button
          v-if="activeFilterCount > 0"
          type="button"
          severity="secondary"
          text
          label="清除"
          icon="pi pi-times"
          class="!py-3"
          @click="clearAllFilters"
        />
      </div>
    </div>

    <!-- Status tabs（設計系統 TabBar，膠囊式＋筆數） -->
    <div class="history-tabs">
      <TabBar
        :model-value="activeTab"
        :tabs="statusTabs"
        label="請款狀態"
        variant="segmented"
        @update:model-value="selectTab"
      />
    </div>

    <!-- Loading skeleton -->
    <div
      v-if="isLoading"
      class="py-12 flex flex-col items-center justify-center gap-2 text-[var(--color-muted)]"
    >
      <i class="pi pi-spin pi-spinner text-2xl" />
      <span class="text-[13px]">載入中…</span>
    </div>

    <!-- List -->
    <template v-else-if="rows.length > 0">
      <div class="mb-2.5 text-xs text-[var(--color-muted-soft)]">
        共有 {{ total }} 筆
      </div>
      <div data-tour="history-table" class="space-y-3">
      <article
        v-for="r in rows"
        :key="r.id"
        role="button"
        tabindex="0"
        class="card p-4 cursor-pointer transition-colors hover:border-primary-300 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-400"
        @click="openDetail(r.id)"
        @keydown.enter.prevent="openDetail(r.id)"
        @keydown.space.prevent="openDetail(r.id)"
      >
        <!-- Top row: status badge + more actions -->
        <div class="flex items-center justify-between gap-2 min-h-8 mb-2">
          <StatusBadge :status="r.status" />
          <!-- 已核銷／已發放沒有操作按鈕，發放日標籤靠右 -->
          <span v-if="payoutInfo(r)" class="payout-tag">
            <i class="pi pi-calendar" aria-hidden="true" />{{ payoutPhrase(r) }}
          </span>
          <!-- 手機：more icon → bottom sheet -->
          <button
            v-if="hasActions(r)"
            type="button"
            aria-label="更多操作"
            class="lg:hidden w-8 h-8 -mr-1 rounded-full flex items-center justify-center text-[var(--color-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-ink)] transition-colors"
            @click.stop="openActionSheet(r)"
          >
            <i class="pi pi-ellipsis-v text-sm" />
          </button>
          <!-- 桌機：直接把操作按鈕顯示在卡片上 -->
          <div
            v-if="hasActions(r)"
            class="hidden lg:flex items-center gap-1"
          >
            <button
              v-for="action in actionsForReimbursement(r)"
              :key="action.key"
              type="button"
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-chip text-sm hover:bg-[var(--color-surface)] transition-colors"
              :class="action.colorClass"
              @click.stop="action.handler()"
            >
              <i :class="[action.icon, 'text-sm']" />
              <span>{{ action.label }}</span>
            </button>
          </div>
        </div>

        <!-- Rejected comment box (single-line by default, tap to expand if overflowing) -->
        <div
          v-if="rejectedComment(r)"
          class="mb-2.5 bg-[#fee2e2] text-[var(--color-status-rejected)] rounded-xl px-3 py-2 text-xs leading-snug flex items-start gap-2"
          :class="overflowingComments.has(r.id) ? 'cursor-pointer' : ''"
          @click="handleCommentClick($event, r.id)"
        >
          <span
            :ref="(el) => bindCommentRef(el as HTMLElement | null, r.id)"
            class="flex-1 min-w-0"
            :class="{ truncate: !expandedComments.has(r.id) }"
          >
            <span class="font-semibold">退回：</span>{{ rejectedComment(r) }}
          </span>
          <i
            v-if="overflowingComments.has(r.id)"
            :class="[
              expandedComments.has(r.id) ? 'pi pi-chevron-up' : 'pi pi-chevron-down',
              'text-[10px] flex-shrink-0 mt-1',
            ]"
          />
        </div>

        <!-- 費用日｜類別　金額 -->
        <div class="flex items-center justify-between gap-3">
          <span class="min-w-0 truncate text-sm font-medium text-[var(--color-slate)] tabular-nums">
            {{ formatDate(r.incurredAt) }}<span class="sep" aria-hidden="true" />{{ r.category.name }}
          </span>
          <span class="text-xl font-bold text-[var(--color-ink)] tabular-nums tracking-tight flex-shrink-0">
            {{ formatCurrency(r.amount) }}
          </span>
        </div>

        <!-- 描述（沒填就不顯示） -->
        <p v-if="r.description" class="mt-1 text-sm text-[var(--color-muted)] leading-snug line-clamp-2">
          {{ r.description }}
        </p>

        <div v-if="r.receiptUrls.length > 0" class="h-3" />

        <!-- Receipts -->
        <div v-if="r.receiptUrls.length > 0" class="flex gap-1.5">
          <template v-for="(url, i) in r.receiptUrls.slice(0, 3)" :key="i">
            <img
              v-if="isImageDataUrl(url)"
              :src="url"
              alt="發票縮圖"
              class="w-11 h-11 rounded-[10px] object-cover border border-[var(--color-hairline)]"
            />
            <div
              v-else
              class="w-11 h-11 rounded-[10px] border border-[var(--color-hairline)] bg-[var(--color-surface)] flex items-center justify-center"
            >
              <i class="pi pi-file text-sm text-[var(--color-muted)]" />
            </div>
          </template>
          <div
            v-if="r.receiptUrls.length > 3"
            class="w-11 h-11 rounded-[10px] border border-[var(--color-hairline)] bg-[var(--color-surface)] flex items-center justify-center text-xs text-[var(--color-muted-soft)]"
          >
            +{{ r.receiptUrls.length - 3 }}
          </div>
        </div>

      </article>
      </div>
      <!-- 進入可視範圍即觸發 loadMore；下一頁 append 中顯示 spinner；
           全部載入完畢後顯示提示。 -->
      <div v-if="hasMore" ref="sentinel" aria-hidden="true" class="h-4 mt-2" />
      <div
        v-if="isLoadingMore"
        class="py-4 flex items-center justify-center gap-2 text-[var(--color-muted)]"
      >
        <i class="pi pi-spin pi-spinner" aria-hidden="true" />
        <span class="text-[13px]">載入中…</span>
      </div>
      <div
        v-else-if="!hasMore"
        class="py-4 text-center text-xs text-[var(--color-muted-soft)]"
      >
        已顯示全部 {{ total }} 筆
      </div>
    </template>

    <EmptyState
      v-else-if="activeTab === 'all' && !hasFilterOrKeyword && total === 0"
      icon="pi pi-inbox"
      title="還沒有任何請款記錄"
      description="點下方按鈕新增你的第一筆代墊款"
    >
      <template #action>
        <Button
          label="新增請款"
          @click="goNew"
        />
      </template>
    </EmptyState>

    <EmptyState
      v-else
      icon="pi pi-filter"
      title="沒有符合條件的記錄"
      :description="hasFilterOrKeyword ? '調整篩選條件或關鍵字看看' : '切換其他分頁試試'"
    >
      <template v-if="hasFilterOrKeyword" #action>
        <Button
          label="清除所有篩選"
          severity="secondary"
          outlined
          @click="clearAllFilters"
        />
      </template>
    </EmptyState>

    <!-- Bottom sheet: per-card actions -->
    <Drawer
      :visible="actionSheetReimbursement !== null"
      position="bottom"
      :style="{ height: 'auto' }"
      :pt="{
        root: { class: 'rounded-t-2xl overflow-hidden' },
        header: { class: '!hidden' },
        content: { class: '!p-0' },
      }"
      @hide="closeActionSheet"
    >
      <div class="flex flex-col">
        <div
          class="mx-auto mt-3 mb-2 w-10 h-1 rounded-full bg-[var(--color-hairline)]"
        />
        <div class="px-4 py-2 space-y-1">
          <button
            v-for="action in currentActions"
            :key="action.key"
            type="button"
            class="w-full flex items-center gap-3 px-3 py-3 rounded-chip hover:bg-[var(--color-surface)] transition-colors"
            :class="action.colorClass"
            @click="runAction(action)"
          >
            <i :class="[action.icon, 'text-base']" />
            <span class="text-sm font-semibold">{{ action.label }}</span>
          </button>
        </div>
        <div class="px-4 pb-4 pt-2">
          <Button
            label="取消"
            outlined
            class="w-full"
            @click="closeActionSheet"
          />
        </div>
      </div>
    </Drawer>

    <!-- Bottom sheet filter drawer -->
    <Drawer
      v-model:visible="drawerOpen"
      position="bottom"
      :style="{ height: 'auto', maxHeight: '85vh' }"
      :pt="{
        root: { class: 'rounded-t-2xl overflow-hidden' },
        header: { class: '!hidden' },
      }"
    >
      <div class="flex flex-col max-h-[80vh]">
        <!-- Grab handle + header -->
        <div class="px-5 pt-3 pb-2">
          <div
            class="mx-auto mb-3 w-10 h-1 rounded-full bg-[var(--color-hairline)]"
          />
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-[var(--color-ink)]">篩選</h2>
            <button
              type="button"
              class="text-[13px] text-[var(--color-muted)] hover:text-[var(--color-ink)]"
              @click="resetDraftFilters"
            >
              重設
            </button>
          </div>
        </div>

        <div class="flex-1 overflow-y-auto px-5 py-4 space-y-6">
          <!-- Date range -->
          <div>
            <div class="text-[13px] font-semibold text-[var(--color-ink)] mb-2">
              費用日期區間
            </div>
            <DatePicker
              v-model="draftFilters.dateRange"
              selection-mode="range"
              :manual-input="false"
              date-format="yy-mm-dd"
              placeholder="選擇日期區間"
              show-icon
              icon-display="input"
              class="w-full"
              fluid
            />
          </div>

          <!-- Amount range -->
          <div>
            <div class="text-[13px] font-semibold text-[var(--color-ink)] mb-2">
              金額區間
            </div>
            <div class="grid grid-cols-[1fr_auto_1fr] gap-2 items-center">
              <InputNumber
                v-model="draftFilters.amountMin"
                mode="currency"
                currency="TWD"
                locale="zh-TW"
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                :min="0"
                placeholder="下限"
                class="w-full"
                input-class="w-full"
              />
              <span class="text-[var(--color-muted)] text-[13px]">—</span>
              <InputNumber
                v-model="draftFilters.amountMax"
                mode="currency"
                currency="TWD"
                locale="zh-TW"
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                :min="0"
                placeholder="上限"
                class="w-full"
                input-class="w-full"
              />
            </div>
          </div>

          <!-- Category multi-select -->
          <div>
            <div class="text-[13px] font-semibold text-[var(--color-ink)] mb-2">
              費用類別
              <span
                v-if="draftFilters.categories.length > 0"
                class="text-xs text-[var(--color-muted)] font-normal ml-1"
              >
                （{{ draftFilters.categories.length }}）
              </span>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="opt in categoryFilterOptions"
                :key="opt.value"
                type="button"
                class="px-3 py-1.5 rounded-full text-[13px] border transition-colors"
                :class="
                  draftFilters.categories.includes(opt.value)
                    ? 'bg-primary-700 text-white border-primary-700'
                    : 'bg-white text-[var(--color-ink)] border-[var(--color-hairline)] hover:bg-[var(--color-surface)]'
                "
                @click="toggleCategory(opt.value)"
              >
                {{ opt.label }}
              </button>
            </div>
          </div>
        </div>

        <!-- Footer actions -->
        <div
          class="px-5 py-3 border-t border-[var(--color-hairline)] flex gap-2"
        >
          <Button
            label="取消"
            outlined
            class="flex-1"
            @click="drawerOpen = false"
          />
          <Button
            label="套用篩選"
            class="flex-1"
            @click="applyDraftFilters"
          />
        </div>
      </div>
    </Drawer>
  </div>
</template>

<style scoped>
.payout-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-slate);
  font-size: 13px;
  font-weight: 500;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
.payout-tag { line-height: 1.4; }
.payout-tag .pi { display: block; font-size: 12px; line-height: 1; color: var(--color-muted); }
.scrollbar-none {
  scrollbar-width: none;
}
.scrollbar-none::-webkit-scrollbar {
  display: none;
}
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
