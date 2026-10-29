<script setup lang="ts">
/**
 * 儀表板。對應 docs/收入管理規格.md §5：
 * - KPI 6 張：本月收入 / 本月支出 / 淨額 / 待收款 / 待付款 / 待簽核（API-driven）
 * - 收支趨勢 bar chart：收入 / 支出並列，右上角期間切換（預設近 12 個月）
 * - 費用類別分佈 donut（API-driven，期間切換）
 * - 待簽核清單（API-driven；最近請款已移除，由待簽核涵蓋）
 */
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  getDashboardSummary,
  getDashboardTrend,
  getDashboardCategoryBreakdown,
  type DashboardSummary,
  type DashboardTrend,
  type DashboardTrendBucket,
  type DashboardCategoryBreakdown,
} from '@/api/dashboard'
import { listCategories, type Category } from '@/api/categories'
import { listAdminReimbursements, type ReimbursementSummary } from '@/api/reimbursements'
import { useAuthStore } from '@/stores/auth'
import { useOnboardingStore } from '@/stores/onboarding'
import { useOnboardingTour } from '@/composables/useOnboardingTour'
import { formatCurrency, formatDate, toIsoDate } from '@/utils/format'
import { resolvePeriod, type Period } from '@/utils/period'
import { categoryColor } from '@/utils/chart'
import PageHeader from '@/components/PageHeader.vue'
import StatCard from '@/components/qds/StatCard.vue'
import PeriodPicker from '@/components/qds/PeriodPicker.vue'
import Button from 'primevue/button'
import Chart from 'primevue/chart'

const router = useRouter()
const auth = useAuthStore()
const onboarding = useOnboardingStore()
const { startTour, isActive } = useOnboardingTour()

// 收入綠 / 支出紅（Chart.js 不能吃 CSS var，直接寫色票；對齊 --color-primary-500 / --color-danger）
const INCOME_COLOR  = '#00b39f'
const EXPENSE_COLOR = '#dc2626'

const today = new Date()

// ─── KPI 彙總（/dashboard/summary）─────────────────
const summary = ref<DashboardSummary | null>(null)
const pendingOutDesc = computed(() => {
  const r = summary.value?.pendingOut.reimbursementAmount ?? 0
  return r > 0 ? `含代墊款 ${formatCurrency(r)}` : '預計付款'
})
const pendingOverdueTag = computed(() => {
  const n = summary.value?.pendingOut.overdueCount ?? 0
  return n > 0 ? `逾期 ${n} 筆` : ''
})

// ─── 收支趨勢（/dashboard/trend）───────────────────
// 預設「近一年（近 12 個月）」；bucket 由 resolvePeriod 的 byDay 決定（短區間逐日）。
const trendPeriod = ref<Period>({ preset: '1y' })
const trend = ref<DashboardTrend | null>(null)

async function loadTrend() {
  const { start, end, byDay } = resolvePeriod(trendPeriod.value, today)
  try {
    trend.value = await getDashboardTrend({
      from: toIsoDate(start),
      to: toIsoDate(end),
      bucket: byDay ? 'day' : 'month',
    })
  } catch {
    trend.value = null
  }
}
watch(trendPeriod, loadTrend, { deep: true })

const trendIncomeTotal  = computed(() => (trend.value?.series.income ?? []).reduce((a, b) => a + b, 0))
const trendExpenseTotal = computed(() => (trend.value?.series.expense ?? []).reduce((a, b) => a + b, 0))
const trendEmpty = computed(() => trendIncomeTotal.value === 0 && trendExpenseTotal.value === 0)

// ISO 標籤顯示：month=「M月」、day=「M/D」
function formatTrendLabel(iso: string, bucket: DashboardTrendBucket) {
  const [, m, d] = iso.split('-').map((n) => Number(n))
  return bucket === 'month' ? `${m}月` : `${m}/${d}`
}
function formatTrendTitle(iso: string, bucket: DashboardTrendBucket) {
  const [y, m, d] = iso.split('-').map((n) => Number(n))
  return bucket === 'month' ? `${y} 年 ${m} 月` : `${y}/${String(m).padStart(2, '0')}/${String(d).padStart(2, '0')}`
}
function kLabel(n: number) {
  if (n >= 1000) {
    const k = n / 1000
    return `${k % 1 === 0 ? k : k.toFixed(1)}k`
  }
  return String(n)
}

const trendData = computed(() => {
  const labels = trend.value?.labels ?? []
  const bucket = trend.value?.range.bucket ?? 'month'
  return {
    labels: labels.map((l) => formatTrendLabel(l, bucket)),
    datasets: [
      {
        label: '收入',
        data: trend.value?.series.income ?? [],
        backgroundColor: INCOME_COLOR,
        hoverBackgroundColor: INCOME_COLOR,
        borderRadius: { topLeft: 6, topRight: 6 },
        borderSkipped: 'bottom' as const,
        maxBarThickness: 24,
        categoryPercentage: 0.9,
      },
      {
        label: '支出',
        data: trend.value?.series.expense ?? [],
        backgroundColor: EXPENSE_COLOR,
        hoverBackgroundColor: EXPENSE_COLOR,
        borderRadius: { topLeft: 6, topRight: 6 },
        borderSkipped: 'bottom' as const,
        maxBarThickness: 24,
        categoryPercentage: 0.9,
      },
    ],
  }
})
const trendOptions = computed(() => {
  const labels = trend.value?.labels ?? []
  const bucket = trend.value?.range.bucket ?? 'month'
  return {
    responsive: true,
    maintainAspectRatio: false,
    animation: { duration: 250 },
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: '#2a3140',
        padding: 10,
        cornerRadius: 6,
        displayColors: true,
        titleFont: { size: 12, weight: 600 },
        bodyFont: { size: 12 },
        callbacks: {
          title: (items: { dataIndex: number }[]) => {
            const iso = labels[items[0]?.dataIndex ?? 0]
            return iso ? formatTrendTitle(iso, bucket) : ''
          },
          label: (ctx: { dataset: { label?: string }; parsed: { y: number } }) =>
            ` ${ctx.dataset.label ?? ''}：${formatCurrency(ctx.parsed.y)}`,
        },
      },
    },
    scales: {
      x: {
        grid: { display: false },
        border: { color: '#e3e6ec' },
        ticks: { color: '#646d80', font: { size: 11 }, maxRotation: 0, autoSkip: true, maxTicksLimit: 12 },
      },
      y: {
        beginAtZero: true,
        grid: { color: '#e3e6ec' },
        border: { display: false, dash: [4, 4] },
        ticks: { color: '#646d80', font: { size: 11 }, maxTicksLimit: 5, callback: (v: string | number) => kLabel(Number(v)) },
      },
    },
  }
})

// ─── 費用類別分佈（/dashboard/category-breakdown）───
// 類別清單用於色票（依 sortOrder 給色）；slice 顏色靠本地 lookup，不由後端吐。
const activeCategories = ref<Category[]>([])
const categorySortOrderMap = computed(() => {
  const map = new Map<string, number>()
  for (const c of activeCategories.value) map.set(c.id, c.sortOrder)
  return map
})
const catPeriod = ref<Period>({ preset: 'month' })
const catBreakdown = ref<DashboardCategoryBreakdown | null>(null)

async function loadCategoryBreakdown() {
  const { start, end } = resolvePeriod(catPeriod.value, today)
  try {
    catBreakdown.value = await getDashboardCategoryBreakdown({
      from: toIsoDate(start),
      to:   toIsoDate(end),
      kind: 'expense',
    })
  } catch {
    catBreakdown.value = null
  }
}
watch(catPeriod, loadCategoryBreakdown, { deep: true })

interface CatSlice { id: string; label: string; color: string; amount: number; pct: number }
const catSlices = computed<CatSlice[]>(() =>
  (catBreakdown.value?.slices ?? []).map((s) => ({
    id: s.categoryId,
    label: s.categoryName,
    color: categoryColor(categorySortOrderMap.value.get(s.categoryId) ?? 0),
    amount: s.amount,
    pct: s.pct / 100,
  })),
)
const catTotal = computed(() => catBreakdown.value?.total ?? 0)
const hover = ref<string | null>(null)
const donut = ref<InstanceType<typeof Chart> | null>(null)
const catData = computed(() => ({
  labels: catSlices.value.map((s) => s.label),
  datasets: [
    {
      data: catSlices.value.map((s) => s.amount),
      backgroundColor: (ctx: { chart: { ctx: CanvasRenderingContext2D; chartArea?: { top: number; bottom: number } }; dataIndex: number }) => {
        const color = catSlices.value[ctx.dataIndex]?.color ?? '#8cddd4'
        const area = ctx.chart.chartArea
        if (!area) return color
        const g = ctx.chart.ctx.createLinearGradient(0, area.top, 0, area.bottom)
        g.addColorStop(0, color)
        g.addColorStop(1, `${color}aa`)
        return g
      },
      borderWidth: 2,
      borderColor: '#fff',
      hoverOffset: 6,
    },
  ],
}))
const catOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  cutout: '68%',
  animation: { duration: 250 },
  onHover: (_e: unknown, els: { index: number }[]) => {
    hover.value = els.length ? catSlices.value[els[0].index]?.id ?? null : null
  },
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#2a3140',
      padding: 10,
      cornerRadius: 6,
      displayColors: false,
      // 類別名已在 title 行；body 只放金額與百分比，避免 tooltip 被 canvas 右邊切掉。
      callbacks: {
        label: (ctx: { parsed: number }) => ` ${formatCurrency(ctx.parsed)}（${catTotal.value ? ((ctx.parsed / catTotal.value) * 100).toFixed(1) : 0}%）`,
      },
    },
  },
}))
function highlight(id: string | null) {
  hover.value = id
  // 讓圓環同步標示（Chart.js setActiveElements）
  const chart = (donut.value as unknown as { getChart?: () => { setActiveElements: (a: { datasetIndex: number; index: number }[]) => void; update: () => void } } | null)?.getChart?.()
  if (!chart) return
  const i = catSlices.value.findIndex((s) => s.id === id)
  chart.setActiveElements(i < 0 ? [] : [{ datasetIndex: 0, index: i }])
  chart.update()
}

// ─── 待簽核清單（/reimbursements/admin?status=in_review&per_page=5）─────
const pending = ref<ReimbursementSummary[]>([])
async function loadPending() {
  try {
    const res = await listAdminReimbursements({ status: 'in_review', perPage: 5 })
    pending.value = res.data
  } catch {
    pending.value = []
  }
}
function openReview(id: string) {
  router.push({ name: 'admin-review', query: { open: id } })
}

/**
 * Admin 首次進 dashboard 且未完成 onboarding → 自動觸發新手導覽。
 * 導覽尾步會 router.push 回本頁，需檢查 isActive() 避免重跑。
 */
onMounted(async () => {
  try {
    activeCategories.value = await listCategories({ kind: 'expense' })
  } catch {
    activeCategories.value = []
  }
  try {
    summary.value = await getDashboardSummary()
  } catch {
    summary.value = null
  }
  await Promise.all([loadTrend(), loadCategoryBreakdown(), loadPending()])

  const user = auth.currentUser
  if (!user || auth.role !== 'admin') return
  if (onboarding.isCompleted()) return
  if (isActive()) return
  await nextTick()
  startTour()
})
</script>

<template>
  <div class="dash-page" data-tour="dashboard-overview">
    <PageHeader title="儀表板" size="admin">
      <template #actions>
        <Button label="新增支出" icon="pi pi-plus" @click="router.push({ name: 'admin-expense-new' })" />
      </template>
    </PageHeader>

    <div class="kpi-grid">
      <StatCard
        tone="primary"
        icon="pi-arrow-down-left"
        label="本月收入"
        :value="formatCurrency(summary?.monthlyIncome.amount ?? 0)"
        desc="依開立日"
        :meta="`${summary?.monthlyIncome.count ?? 0} 筆`"
        :to="{ name: 'admin-incomes' }"
      />
      <StatCard
        tone="warning"
        icon="pi-arrow-up-right"
        label="本月支出"
        :value="formatCurrency(summary?.monthlyExpense.amount ?? 0)"
        desc="依費用發生日"
        :meta="`${summary?.monthlyExpense.count ?? 0} 筆`"
        :to="{ name: 'admin-expenses' }"
      />
      <StatCard
        tone="info"
        icon="pi-chart-line"
        label="淨額"
        :value="formatCurrency(summary?.monthlyNet ?? 0)"
        desc="本月收入 − 本月支出"
      />
      <StatCard
        tone="info"
        icon="pi-inbox"
        label="待收款"
        :value="formatCurrency(summary?.pendingIn.amount ?? 0)"
        desc="尚未收款"
        :meta="`${summary?.pendingIn.count ?? 0} 筆`"
        :to="{ name: 'admin-incomes', query: { status: 'uncollected' } }"
      />
      <StatCard
        tone="danger"
        icon="pi-clock"
        label="待付款"
        :value="formatCurrency(summary?.pendingOut.amount ?? 0)"
        :desc="pendingOutDesc"
        :meta="`${summary?.pendingOut.count ?? 0} 筆`"
        :alert-tag="pendingOverdueTag"
        :to="{ name: 'admin-expenses', query: { status: 'pending' } }"
      />
      <StatCard
        tone="warning"
        icon="pi-check-circle"
        label="待簽核"
        :value="formatCurrency(summary?.inReview.amount ?? 0)"
        desc="等待管理員簽核"
        :meta="`${summary?.inReview.count ?? 0} 筆`"
        :to="{ name: 'admin-review' }"
      />
    </div>

    <div class="dash-row">
      <section class="dash-panel" aria-labelledby="trend-title">
        <div class="dash-panel-head dash-panel-head-2">
          <div>
            <h2 id="trend-title" class="dash-panel-title">收支趨勢</h2>
          </div>
          <div class="trend-head-tools">
            <div class="trend-total" aria-label="區間收支合計">
              <span class="trend-pair">
                <i class="trend-dot" :style="{ background: INCOME_COLOR }" aria-hidden="true" />
                <span>收入</span>
                <b>{{ formatCurrency(trendIncomeTotal) }}</b>
              </span>
              <span class="trend-pair">
                <i class="trend-dot" :style="{ background: EXPENSE_COLOR }" aria-hidden="true" />
                <span>支出</span>
                <b>{{ formatCurrency(trendExpenseTotal) }}</b>
              </span>
            </div>
            <PeriodPicker v-model="trendPeriod" label="收支趨勢期間" default-preset="1y" size="sm" />
          </div>
        </div>
        <div v-if="trendEmpty" class="dash-empty dash-empty-lg flex-1 flex flex-col justify-center">
          <b class="text-[var(--color-ink)]">此區間內尚無收支資料</b>換個期間看看
        </div>
        <div v-else class="flex-1 min-h-[280px]">
          <Chart type="bar" :data="trendData" :options="trendOptions" class="h-full w-full" />
        </div>
      </section>

      <section class="dash-panel" aria-labelledby="cat-title">
        <div class="dash-panel-head dash-panel-head-2">
          <div>
            <h2 id="cat-title" class="dash-panel-title">費用類別分佈</h2>
          </div>
          <div class="chart-head-tools">
            <PeriodPicker v-model="catPeriod" label="類別分佈期間" default-preset="month" size="sm" />
          </div>
        </div>
        <div v-if="!catSlices.length" class="dash-empty dash-empty-lg">此區間內尚無支出資料</div>
        <template v-else>
          <div class="donut-wrap">
            <Chart ref="donut" type="doughnut" :data="catData" :options="catOptions" class="h-full w-full" />
            <div class="donut-center"><span>合計</span><b>{{ formatCurrency(catTotal) }}</b></div>
          </div>
          <ul class="cat-legend" @mouseleave="highlight(null)">
            <li
              v-for="s in catSlices"
              :key="s.id"
              tabindex="0"
              :class="{ on: hover === s.id, dim: hover && hover !== s.id }"
              @mouseenter="highlight(s.id)"
              @focus="highlight(s.id)"
              @blur="highlight(null)"
            >
              <span class="legend-dot" :style="{ background: s.color }" aria-hidden="true" />
              <span class="cat-name">{{ s.label }}</span>
              <span class="cat-pct">{{ (s.pct * 100).toFixed(1) }}%</span>
              <span class="cat-amt">{{ formatCurrency(s.amount) }}</span>
            </li>
          </ul>
        </template>
      </section>
    </div>

    <section class="dash-panel dashboard-list-panel" aria-labelledby="pending-title">
      <div class="dash-panel-head">
        <h2 id="pending-title" class="dash-panel-title">待簽核<span class="tab-count">{{ summary?.inReview.count ?? 0 }}</span></h2>
        <RouterLink class="dash-panel-link" :to="{ name: 'admin-review' }">查看全部</RouterLink>
      </div>
      <div v-if="!pending.length" class="dash-empty">目前沒有待簽核的請款</div>
      <div v-else class="action-list">
        <button v-for="r in pending" :key="r.id" type="button" class="ar-row" @click="openReview(r.id)">
          <div class="row-top"><span class="truncate">{{ r.employee.name }}<span class="sep" aria-hidden="true" />{{ r.category.name }}</span><span class="ar-time">{{ formatDate(r.createdAt) }}</span></div>
          <div class="ar-sub dashboard-pending-sub">
            <span class="dashboard-pending-desc">{{ r.description }}</span>
            <span class="dashboard-pending-amount">{{ formatCurrency(r.amount) }}</span>
          </div>
        </button>
      </div>
    </section>
  </div>
</template>

<style scoped>
.trend-head-tools,
.chart-head-tools {
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  flex-wrap: wrap;
}

.trend-total {
  display: inline-flex;
  align-items: baseline;
  gap: 16px;
  color: var(--color-muted);
  font-size: 14px;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  flex-wrap: wrap;
}

.trend-pair {
  display: inline-flex;
  align-items: baseline;
  gap: 6px;
}

.trend-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  transform: translateY(-1px);
}

.trend-total b {
  color: var(--color-ink);
  font-size: 18px;
  font-weight: 700;
}

.dashboard-list-panel .dash-panel-head {
  margin-bottom: var(--space-xs);
}

.dashboard-list-panel .action-list .ar-row:first-child {
  padding-top: var(--space-sm);
}

/* 清單列分隔線為直線，不做圓角（全域 .ar-row 有圓角，會讓底線兩端變圓） */
.dashboard-list-panel .action-list .ar-row {
  border-radius: 0;
}

.dashboard-pending-sub {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--space-sm);
}

.dashboard-pending-desc {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dashboard-pending-amount {
  flex-shrink: 0;
  color: var(--color-ink);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
</style>
