<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import type { Budget, BudgetTemplate, Category, BudgetCycle } from '@/types/domain'
import { listCategories } from '@/api/categories'
import {
  applyBudgetTemplates,
  createBudget,
  deleteBudget,
  getBudgetUtilization,
  listBudgets,
  listBudgetTemplates,
  updateBudget,
  upsertBudgetTemplate,
} from '@/api/budgets'
import { monthPeriod, yearPeriod } from '@/utils/period'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import { formatCurrency } from '@/utils/format'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import DatePicker from 'primevue/datepicker'
import Dialog from 'primevue/dialog'
import InputNumber from 'primevue/inputnumber'
import Menu from 'primevue/menu'
import SlideSelectButton from '@/components/qds/SlideSelectButton.vue'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'

const confirm = useConfirm()
const toast = useToast()

/** 支出類別清單（進頁 fetch 一次）；行列、基本預算 Dialog、摘要都從這份跑。 */
const activeCategories = ref<Category[]>([])

// ─── Cycle + Period state ─────────────────────────────

const cycleOptions = [
  { label: '月預算', value: 'month' as const },
  { label: '年預算', value: 'year' as const },
]
const cycle = ref<BudgetCycle>('month')
const refDate = ref<Date>(new Date())

const period = computed(() =>
  cycle.value === 'month' ? monthPeriod(refDate.value) : yearPeriod(refDate.value),
)

/**
 * 當期 Budget 列表（依 cycle + periodStart 從後端撈）；
 * 以 categoryId → Budget 的 map 給表格列、編輯動作、Template 設定共用。
 */
const budgetsOfPeriod = ref<Budget[]>([])
const budgetByCategory = computed<Record<string, Budget>>(() => {
  const m: Record<string, Budget> = {}
  for (const b of budgetsOfPeriod.value) m[b.categoryId] = b
  return m
})

/**
 * 當前期間各類別的實際支出加總（map：categoryId → actual）；由後端
 * /budgets/utilization 聚合後回傳，沒出現的類別視為 0。
 */
const actualByCategory = ref<Record<string, number>>({})

/** 列表 loading：首次載入與 cycle/period 切換時都顯示。 */
const loading = ref(false)
/** 首次 fetch 完成前讓 DataTable 持續吃 loading mask，不閃 EmptyState。 */
const initialLoaded = ref(false)

async function refreshBudgets() {
  try {
    budgetsOfPeriod.value = await listBudgets({
      cycle: cycle.value,
      periodStart: period.value.periodStart,
    })
  } catch {
    budgetsOfPeriod.value = []
  }
}

async function refreshUtilization() {
  try {
    const list = await getBudgetUtilization({
      periodStart: period.value.periodStart,
      periodEnd: period.value.periodEnd,
    })
    const map: Record<string, number> = {}
    for (const r of list) map[r.categoryId] = r.actual
    actualByCategory.value = map
  } catch {
    actualByCategory.value = {}
  }
}

async function refreshAll() {
  loading.value = true
  try {
    await Promise.all([refreshBudgets(), refreshUtilization()])
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  loading.value = true
  try {
    const [cats] = await Promise.all([
      listCategories({ kind: 'expense' }).catch(() => [] as Category[]),
      refreshBudgets(),
      refreshUtilization(),
    ])
    activeCategories.value = cats
  } finally {
    loading.value = false
    initialLoaded.value = true
  }
})

watch(
  () => [cycle.value, period.value.periodStart, period.value.periodEnd],
  () => {
    if (initialLoaded.value) refreshAll()
  },
)

const periodLabel = computed(() => {
  const y = refDate.value.getFullYear()
  if (cycle.value === 'year') return `${y} 年`
  const m = refDate.value.getMonth() + 1
  return `${y} 年 ${m} 月`
})

const isTodayPeriod = computed(() => {
  const today = new Date()
  if (cycle.value === 'year') return refDate.value.getFullYear() === today.getFullYear()
  return (
    refDate.value.getFullYear() === today.getFullYear() &&
    refDate.value.getMonth() === today.getMonth()
  )
})

const prevPeriodLabel = computed(() =>
  cycle.value === 'month' ? '上個月' : '上一年',
)
const nextPeriodLabel = computed(() =>
  cycle.value === 'month' ? '下個月' : '下一年',
)
const returnTodayLabel = computed(() => (cycle.value === 'month' ? '本月' : '今年'))

function shiftPeriod(delta: number) {
  const d = new Date(refDate.value)
  if (cycle.value === 'month') d.setMonth(d.getMonth() + delta)
  else d.setFullYear(d.getFullYear() + delta)
  refDate.value = d
  cancelEdit()
}

/** 直接從月份/年份面板選期間（PrimeVue DatePicker view=month|year） */
function onPickPeriod(v: Date | Date[] | (Date | null)[] | null | undefined) {
  if (!(v instanceof Date)) return
  refDate.value = cycle.value === 'month' ? new Date(v.getFullYear(), v.getMonth(), 1) : new Date(v.getFullYear(), 0, 1)
  cancelEdit()
}

function resetToToday() {
  refDate.value = new Date()
  cancelEdit()
}

function onCycleChange(next: BudgetCycle | null | undefined) {
  // 保險：SlideSelectButton（PrimeVue SelectButton）已設 allow-empty=false，仍忽略 null 避免無效狀態
  if (!next) return
  cycle.value = next
  refDate.value = new Date()
  cancelEdit()
}

// ─── Row data ─────────────────────────────────────────

interface Row {
  category: Category
  budgetId: string | null
  budgetAmount: number | null
  actual: number
  utilization: number | null
  remainingRatio: number | null
  remainingAmount: number | null
  isOverBudget: boolean
}

/**
 * 執行率 / 剩餘 / 餘額的純算術：
 * - 未設預算（找不到 Budget）：utilization / remaining 皆 null、isOverBudget=false；
 *   actual 仍照常回，讓 UI 顯示該類別當期支出
 * - 有預算：utilization 不 cap（可 > 1）；remainingRatio 給進度條，超支 = 0
 */
function computeUtilization(record: Budget | undefined, actual: number) {
  if (!record || record.amount <= 0) {
    return {
      budget: null as number | null,
      actual,
      utilization: null as number | null,
      remainingRatio: null as number | null,
      remainingAmount: null as number | null,
      isOverBudget: false,
    }
  }
  const utilization = actual / record.amount
  const remainingAmount = record.amount - actual
  const remainingRatio = Math.max(0, remainingAmount / record.amount)
  return {
    budget: record.amount,
    actual,
    utilization,
    remainingRatio,
    remainingAmount,
    isOverBudget: actual >= record.amount,
  }
}

const rows = computed<Row[]>(() =>
  activeCategories.value.map((c) => {
    const record = budgetByCategory.value[c.id]
    const util = computeUtilization(record, actualByCategory.value[c.id] ?? 0)
    return {
      category: c,
      budgetId: record?.id ?? null,
      budgetAmount: util.budget,
      actual: util.actual,
      utilization: util.utilization,
      remainingRatio: util.remainingRatio,
      remainingAmount: util.remainingAmount,
      isOverBudget: util.isOverBudget,
    }
  }),
)

// ─── 預算行內編輯 ─────────
// 點預算金額 → 就地變成輸入框；Enter 或離開輸入框儲存，Esc 取消

interface EditState {
  categoryId: string | null
  amount: number | null
}
const edit = reactive<EditState>({ categoryId: null, amount: null })
const editInputRef = ref<InstanceType<typeof InputNumber> | null>(null)
/**
 * 阻擋 Enter + blur、連點等觸發的 commitEdit 併發：第二次進 saveBudget
 * 時直接回 false，避免重複 createBudget / 重複 toast。
 */
const savingBudget = ref(false)

async function startEdit(row: Row) {
  if (edit.categoryId === row.category.id) return
  // 正在編輯別列 → 先儲存那一列；存不過（例如負數）就停在原列
  if (edit.categoryId) {
    const current = rows.value.find((r) => r.category.id === edit.categoryId)
    if (current && !(await saveBudget(current, edit.amount))) return
  }
  edit.categoryId = row.category.id
  edit.amount = row.budgetAmount ?? null
  await nextTick()
  const el =
    (editInputRef.value as unknown as { $el?: HTMLElement } | null)?.$el ?? null
  if (el) {
    const input = el.querySelector('input')
    input?.focus()
    input?.select()
  }
}

function cancelEdit() {
  edit.categoryId = null
  edit.amount = null
}

function onEditInput(v: number | string | undefined | null) {
  edit.amount = typeof v === 'number' ? v : v === '' || v == null ? null : Number(v)
}

/** 儲存預算；成功回傳 true，由呼叫方關閉編輯狀態 */
async function saveBudget(row: Row, amount: number | null): Promise<boolean> {
  // 併發守門：第一次呼叫 await 期間若 Enter + blur / 連點再觸發，直接擋下
  if (savingBudget.value) return false

  // 清空輸入框視同 0（取消預算）；原本就沒設定則靜默結束
  if (amount === null || Number.isNaN(amount)) amount = row.budgetAmount === null ? null : 0
  if (amount === null) return true
  if (amount < 0) {
    toast.add({ severity: 'warn', summary: '金額不得為負數', life: 2500 })
    return false
  }
  // 沒有改變 → 視為靜默結束
  if (row.budgetAmount === amount) return true

  savingBudget.value = true
  try {
    if (amount === 0) {
      // 取消預算：有既有記錄才打 DELETE，否則靜默結束
      if (!row.budgetId) return true
      await deleteBudget(row.budgetId)
      toast.add({ severity: 'success', summary: '已取消預算', life: 2500 })
    } else if (row.budgetId) {
      await updateBudget(row.budgetId, { amount })
      toast.add({ severity: 'success', summary: '已更新預算', life: 2500 })
    } else {
      await createBudget({
        categoryId: row.category.id,
        cycle: cycle.value,
        amount,
        periodStart: period.value.periodStart,
        periodEnd: period.value.periodEnd,
      })
      toast.add({ severity: 'success', summary: '已設定預算', life: 2500 })
    }
    await refreshBudgets()
    return true
  } catch {
    toast.add({ severity: 'warn', summary: '儲存失敗', life: 2500 })
    return false
  } finally {
    savingBudget.value = false
  }
}

async function commitEdit(row: Row) {
  // 已被 Enter/Esc 結束（元件卸載時仍會觸發 blur）就不重複處理
  if (edit.categoryId !== row.category.id) return
  if (await saveBudget(row, edit.amount)) cancelEdit()
}

// ─── Apply templates ──────────────────────────────────

function confirmApplyTemplates() {
  confirm.require({
    message: `將以「基本${cycle.value === 'month' ? '月' : '年'}預算」覆寫當前期間（${periodLabel.value}）所有類別的預算金額，是否繼續？`,
    header: '套用基本預算',
    acceptLabel: '確認套用',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' } as unknown as Record<string, unknown>,
    accept: async () => {
      try {
        await applyBudgetTemplates({
          cycle: cycle.value,
          periodStart: period.value.periodStart,
          periodEnd: period.value.periodEnd,
        })
        cancelEdit()
        await refreshAll()
        toast.add({
          severity: 'success',
          summary: `已套用基本預算到 ${periodLabel.value}`,
          life: 3000,
        })
      } catch {
        toast.add({ severity: 'warn', summary: '套用失敗', life: 2500 })
      }
    },
  })
}

// ─── Basic budget Dialog ──────────────────────────────

const templateDialogVisible = ref(false)
const templateDialogLoading = ref(false)
const templateDialogSaving = ref(false)
/**
 * 基本預算：每個類別的月預算、年預算分開設定、互不連動，兩邊都可留空。
 * 每月固定的開銷填月預算；一年一次或不定期的（例如員工旅遊）只填年預算。
 * 「套用基本預算」依目前檢視帶入對應的那一種；個別月份在列表上仍可單獨調整。
 */
// null = 未設定（輸入框顯示 placeholder，不顯示 NT$ 0）
const monthDraft = reactive<Record<string, number | null>>({})
const yearDraft = reactive<Record<string, number | null>>({})
const draftInitial = reactive<Record<string, { month: number; year: number }>>({})

const templateDialogTitle = '基本預算設定'

// 頁首：主要動作「套用基本預算」；較少用的「基本預算設定」收進 ⋯ 選單
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = [{ label: '基本預算設定', icon: 'pi pi-cog', command: () => openTemplateDialog() }]

async function openTemplateDialog() {
  templateDialogVisible.value = true
  templateDialogLoading.value = true
  for (const k of Object.keys(monthDraft)) delete monthDraft[k]
  for (const k of Object.keys(yearDraft)) delete yearDraft[k]
  for (const k of Object.keys(draftInitial)) delete draftInitial[k]
  try {
    const list: BudgetTemplate[] = await listBudgetTemplates()
    const key = (categoryId: string, c: BudgetCycle) => `${categoryId}|${c}`
    const map: Record<string, number> = {}
    for (const t of list) map[key(t.categoryId, t.cycle)] = t.amount
    for (const c of activeCategories.value) {
      const m = map[key(c.id, 'month')] ?? 0
      const y = map[key(c.id, 'year')] ?? 0
      monthDraft[c.id] = m || null
      yearDraft[c.id] = y || null
      draftInitial[c.id] = { month: m, year: y }
    }
  } catch {
    for (const c of activeCategories.value) {
      monthDraft[c.id] = null
      yearDraft[c.id] = null
      draftInitial[c.id] = { month: 0, year: 0 }
    }
    toast.add({ severity: 'warn', summary: '載入基本預算失敗', life: 2500 })
  } finally {
    templateDialogLoading.value = false
  }
}

function toAmount(v: number | string | undefined | null): number | null {
  const n = typeof v === 'number' ? v : Number(v)
  return v === '' || v == null || !n ? null : n
}
function onDraftInput(draft: Record<string, number | null>, id: string, v: number | string | undefined | null) {
  draft[id] = toAmount(v)
}

const templateTotal = computed(() =>
  activeCategories.value.reduce(
    (t, c) => ({ month: t.month + (monthDraft[c.id] || 0), year: t.year + (yearDraft[c.id] || 0) }),
    { month: 0, year: 0 },
  ),
)

function closeTemplateDialog() {
  templateDialogVisible.value = false
}

async function submitTemplateDialog() {
  for (const c of activeCategories.value) {
    const m = monthDraft[c.id] ?? 0
    const y = yearDraft[c.id] ?? 0
    if (m < 0 || y < 0) {
      toast.add({ severity: 'warn', summary: `「${c.name}」金額不得為負數`, life: 2500 })
      return
    }
  }

  // amount = 0 由後端轉為刪除；只對改動過的類別打 request，避免 N 筆空操作
  const requests: Promise<unknown>[] = []
  for (const c of activeCategories.value) {
    const init = draftInitial[c.id]
    const m = monthDraft[c.id] ?? 0
    const y = yearDraft[c.id] ?? 0
    if (m !== init?.month) requests.push(upsertBudgetTemplate({ categoryId: c.id, cycle: 'month', amount: m }))
    if (y !== init?.year) requests.push(upsertBudgetTemplate({ categoryId: c.id, cycle: 'year', amount: y }))
  }

  if (requests.length === 0) {
    templateDialogVisible.value = false
    return
  }

  templateDialogSaving.value = true
  try {
    await Promise.all(requests)
    toast.add({ severity: 'success', summary: '已儲存基本預算', detail: '按「套用基本預算」即可帶入目前期間', life: 3000 })
    templateDialogVisible.value = false
  } catch {
    toast.add({ severity: 'warn', summary: '儲存失敗', life: 2500 })
  } finally {
    templateDialogSaving.value = false
  }
}

// ─── 顯示 ─────────────────────────────────────────
/** 使用率進度條：≥80% 警示、≥100% 超支 */
function usagePct(row: Row): number | null {
  return row.utilization === null ? null : Math.round(row.utilization * 100)
}
function barTone(row: Row): string {
  const u = row.utilization ?? 0
  return u >= 1 ? 'over' : u >= 0.8 ? 'warn' : ''
}
function formatBalance(row: Row): string {
  return row.remainingAmount === null ? '—' : formatCurrency(row.remainingAmount)
}
const summary = computed(() => {
  const withBudget = rows.value.filter((r) => r.budgetAmount !== null)
  const total = withBudget.reduce((s, r) => s + (r.budgetAmount ?? 0), 0)
  const actual = withBudget.reduce((s, r) => s + r.actual, 0)
  return {
    total,
    actual,
    pct: total ? Math.round((actual / total) * 100) : null,
    over: withBudget.filter((r) => (r.utilization ?? 0) >= 1).length,
    warn: withBudget.filter((r) => (r.utilization ?? 0) >= 0.8 && (r.utilization ?? 0) < 1).length,
  }
})
</script>

<template>
  <div class="dash-page" data-tour="budgets-page">
    <PageHeader title="預算管理" size="admin">
      <template #actions>
        <Button label="套用基本預算" icon="pi pi-refresh" @click="confirmApplyTemplates" />
        <Button icon="pi pi-ellipsis-h" outlined aria-label="更多動作" aria-haspopup="true" v-tooltip.bottom="'更多動作'" @click="pageMenu?.toggle($event)" />
        <Menu ref="pageMenu" :model="pageMenuItems" popup />
      </template>
    </PageHeader>

    <div class="dash-list-tools" aria-label="預算列表工具">
      <div class="dash-filter">
        <span class="dash-filter-action">
          <SlideSelectButton
            :model-value="cycle"
            :options="cycleOptions"
            option-label="label"
            option-value="value"
            :allow-empty="false"
            aria-label="預算週期"
            @update:model-value="onCycleChange"
          />
        </span>
        <div class="budget-period-tools">
          <Button v-if="!isTodayPeriod" :label="`回到${returnTodayLabel}`" text size="small" @click="resetToToday" />
          <div class="period-nav">
            <Button icon="pi pi-chevron-left" outlined size="small" :aria-label="prevPeriodLabel" @click="shiftPeriod(-1)" />
            <DatePicker
              :key="cycle"
              :model-value="refDate"
              :view="cycle"
              :date-format="cycle === 'month' ? 'yy 年 m 月' : 'yy 年'"
              :manual-input="false"
              class="period-dp"
              panel-class="period-dp-panel"
              :aria-label="cycle === 'month' ? '選擇月份' : '選擇年份'"
              @update:model-value="onPickPeriod"
            />
            <Button icon="pi pi-chevron-right" outlined size="small" :aria-label="nextPeriodLabel" @click="shiftPeriod(1)" />
          </div>
        </div>
      </div>
    </div>

    <section v-if="activeCategories.length" class="budget-summary" aria-label="預算摘要">
      <div><span>總預算</span><b>{{ formatCurrency(summary.total) }}</b></div>
      <div><span>已設預算類別的支出</span><b>{{ formatCurrency(summary.actual) }}</b></div>
      <div><span>整體使用率</span><b>{{ summary.pct === null ? '—' : `${summary.pct}%` }}</b></div>
      <div><span>超支/接近上限</span><b>{{ summary.over }} / {{ summary.warn }} 個類別</b></div>
    </section>

    <section class="dash-panel dash-table-panel budget-table-panel" aria-label="類別預算">
      <EmptyState v-if="initialLoaded && activeCategories.length === 0" variant="plain" icon="pi pi-tag" title="尚無使用中類別" description="先建立類別後，才能為類別編列預算">
        <template #action>
          <Button as="router-link" to="/admin/categories" label="前往類別管理" icon="pi pi-arrow-right" icon-pos="right" />
        </template>
      </EmptyState>

      <template v-else>
        <!-- 預設依類別管理的自訂順序；點欄位標題可暫時排序（第三次點回預設） -->
        <DataTable :value="rows" :loading="loading" data-key="category.id" row-hover removable-sort :table-style="{ width: '100%', minWidth: '880px' }">
          <Column header="類別"><template #body="{ data }">{{ data.category.name }}</template></Column>
          <Column header="預算" field="budgetAmount" sortable header-class="num" body-class="num">
            <template #body="{ data }">
              <InputNumber
                v-if="edit.categoryId === data.category.id"
                ref="editInputRef"
                :model-value="edit.amount"
                :min="0"
                :max-fraction-digits="0"
                prefix="NT$ "
                class="budget-edit-input"
                :aria-label="`${data.category.name} 預算金額`"
                @input="(e) => onEditInput(e.value)"
                @keydown.enter.prevent="commitEdit(data)"
                @keydown.esc.prevent="cancelEdit"
                @blur="commitEdit(data)"
              />
              <!-- mousedown 先處理：避免正在編輯的輸入框 blur 儲存後重繪，把這次點擊吃掉；click 留給鍵盤操作 -->
              <button
                v-else
                type="button"
                class="ie-trigger budget-edit-trigger"
                :class="{ empty: data.budgetAmount === null }"
                :aria-label="`${data.category.name} 預算：${data.budgetAmount !== null ? formatCurrency(data.budgetAmount) : '未設定'}，點擊修改`"
                @mousedown.prevent="startEdit(data)"
                @click="startEdit(data)"
              >
                <i class="pi pi-pencil" aria-hidden="true" />
                <span>{{ data.budgetAmount !== null ? formatCurrency(data.budgetAmount) : '未設定' }}</span>
              </button>
            </template>
          </Column>
          <Column header="實際支出" field="actual" sortable header-class="num" body-class="num">
            <template #body="{ data }">{{ formatCurrency(data.actual) }}</template>
          </Column>
          <Column header="使用率" field="utilization" sortable header-class="budget-usage-cell" body-class="budget-usage-cell">
            <template #body="{ data }">
              <div v-if="usagePct(data) !== null" class="budget-cell">
                <div class="budget-bar" :class="barTone(data)" role="progressbar" aria-valuemin="0" aria-valuemax="100" :aria-valuenow="Math.min(100, usagePct(data) ?? 0)" :aria-label="`${data.category.name} 使用率`">
                  <span :style="{ width: `${Math.min(100, usagePct(data) ?? 0)}%` }" />
                </div>
                <span class="budget-pct">{{ usagePct(data) }}%</span>
              </div>
              <span v-else class="cell-sub">—</span>
            </template>
          </Column>
          <Column header="餘額" field="remainingAmount" sortable header-class="num" body-class="num">
            <template #body="{ data }">
              <span :class="{ 'warn-text': (data.remainingAmount ?? 0) < 0 }">{{ formatBalance(data) }}</span>
            </template>
          </Column>
        </DataTable>
        <p class="q-help budget-help">點預算金額即可直接修改，按 Enter 或點其他地方儲存、Esc 取消；金額清空或設為 0 會取消這個類別當期的預算。</p>
      </template>
    </section>

    <Dialog v-model:visible="templateDialogVisible" modal :header="templateDialogTitle" :style="{ width: 'min(94vw, 640px)' }" :closable="!templateDialogSaving">
      <EmptyState v-if="activeCategories.length === 0" variant="plain" icon="pi pi-tag" title="尚無使用中類別" description="先建立類別後，才能設定基本預算" />
      <div v-else-if="templateDialogLoading" class="tpl-loading" role="status" aria-live="polite">
        <i class="pi pi-spin pi-spinner" aria-hidden="true" />
        <span>載入基本預算…</span>
      </div>
      <template v-else>
        <p class="dash-dialog-text" style="margin-bottom: 16px">每月固定的開銷填「月預算」，一年一次或不定期的填「年預算」，留空表示不設定。<br />之後仍可在列表上調整個別月份。</p>
        <div class="tpl-table" role="table" aria-label="基本預算">
          <div class="tpl-row tpl-head" role="row">
            <span role="columnheader">類別</span>
            <span role="columnheader">月預算</span>
            <span role="columnheader">年預算</span>
          </div>
          <div v-for="c in activeCategories" :key="c.id" class="tpl-row" role="row">
            <span class="tpl-name" role="rowheader">{{ c.name }}</span>
            <InputNumber
              :model-value="monthDraft[c.id]"
              :input-id="`tpl-m-${c.id}`"
              :min="0"
              :max-fraction-digits="0"
              prefix="NT$ "
              placeholder="未設定"
              fluid
              class="tpl-input"
              :aria-label="`${c.name} 月預算`"
              @input="(e) => onDraftInput(monthDraft, c.id, e.value)"
            />
            <InputNumber
              :model-value="yearDraft[c.id]"
              :input-id="`tpl-y-${c.id}`"
              :min="0"
              :max-fraction-digits="0"
              prefix="NT$ "
              placeholder="未設定"
              fluid
              class="tpl-input"
              :aria-label="`${c.name} 年預算`"
              @input="(e) => onDraftInput(yearDraft, c.id, e.value)"
            />
          </div>
          <div class="tpl-row tpl-total" role="row">
            <span role="rowheader">合計</span>
            <span>{{ formatCurrency(templateTotal.month) }}</span>
            <span>{{ formatCurrency(templateTotal.year) }}</span>
          </div>
        </div>
      </template>
      <template #footer>
        <Button label="取消" outlined :disabled="templateDialogSaving" @click="closeTemplateDialog" />
        <Button
          label="儲存"
          :disabled="activeCategories.length === 0 || templateDialogLoading"
          :loading="templateDialogSaving"
          @click="submitTemplateDialog"
        />
      </template>
    </Dialog>
  </div>
</template>

<style scoped>
.dash-filter-action { margin-left: 0; }
/* 卡片外框已是表格上緣，表頭不再疊一條線 */
.dash-table-panel.budget-table-panel :deep(.p-datatable-thead > tr:first-child > th) { border-top: 0; }
.budget-period-tools { display: flex; align-items: center; gap: 8px; margin-left: auto; }
.budget-col-label { display: inline-block; width: 128px; box-sizing: border-box; padding-right: 14px; text-align: right; }
.budget-edit-input { width: 128px; }
.budget-edit-input :deep(input) { width: 100%; height: 44px; text-align: right; }
.budget-edit-trigger { position: relative; margin-left: auto; padding-right: 14px; } /* 左右內距一致，hover 出現框線時金額不貼邊 */
.budget-edit-trigger .pi { position: absolute; left: 12px; }
/* 使用率：進度條固定寬度作為欄寬依據，百分比緊貼進度條 */
.budget-cell .budget-bar { flex: none; width: 160px; }
.budget-cell .budget-pct { width: auto; min-width: 40px; text-align: left; }
/* 使用率欄與前一欄（實際支出）保持距離 */
.budget-table-panel :deep(.budget-usage-cell) { padding-left: 48px; }

.tpl-loading { display: flex; align-items: center; justify-content: center; gap: 8px; padding: 32px 0; color: var(--slate); }
.tpl-table { max-height: 55vh; overflow: auto; border: 1px solid var(--hairline); border-radius: var(--radius-control); }
.tpl-row { display: grid; grid-template-columns: minmax(0, 1fr) 168px 168px; gap: 12px; align-items: center; padding: 8px 16px; border-top: 1px solid var(--hairline); }
.tpl-row:first-child { border-top: 0; }
.tpl-head { position: sticky; top: 0; z-index: 1; padding-block: 10px; background: var(--surface); font-size: 14px; font-weight: 600; color: var(--slate); }
.tpl-head > span:not(:first-child), .tpl-total > span:not(:first-child) { text-align: right; padding-right: 16px; }
.tpl-name { font-size: 16px; color: var(--ink); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tpl-input :deep(input) { text-align: right; }
.tpl-total { position: sticky; bottom: 0; background: var(--surface); padding-block: 12px; font-weight: 600; color: var(--ink); font-variant-numeric: tabular-nums; }
@media (max-width: 560px) {
  .tpl-row { grid-template-columns: 1fr 1fr; padding: 10px 12px; }
  .tpl-name, .tpl-row > span[role="rowheader"] { grid-column: 1 / -1; }
  .tpl-head > span:first-child { display: none; }
}
</style>
