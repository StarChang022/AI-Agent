<script setup lang="ts">
/**
 * 損益報表（docs/收入管理規格.md §4、儀表板與報表-規格與實作計畫.md §二）。
 * 以開立日 / 費用發生日歸屬；垃圾桶、作廢代墊款不計入。
 * - 期間：預設當年度；可切單月 / 單季 / 自訂
 * - bucket：月（預設）/ 季 / 年
 * - 畫面：合計卡 + bar chart + 表格；可匯出 Excel
 */
import { computed, onMounted, ref, watch } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import PeriodPicker from '@/components/qds/PeriodPicker.vue'
import SlideSelectButton from '@/components/qds/SlideSelectButton.vue'
import Button from 'primevue/button'
import Chart from 'primevue/chart'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import { useToast } from 'primevue/usetoast'
import { formatCurrency, toIsoDate } from '@/utils/format'
import { resolvePeriod, type Period } from '@/utils/period'
import {
  downloadProfitLossXlsx,
  getProfitLoss,
  type ProfitLoss,
  type ProfitLossBucket,
} from '@/api/reports'

const toast = useToast()

const INCOME_COLOR  = '#00b39f'
const EXPENSE_COLOR = '#dc2626'
const NET_COLOR     = '#3b4252'

const today = new Date()

const period = ref<Period>({ preset: 'year' })
const bucket = ref<ProfitLossBucket>('month')
const bucketOptions = [
  { value: 'month',   label: '月' },
  { value: 'quarter', label: '季' },
  { value: 'year',    label: '年' },
] as const

const data    = ref<ProfitLoss | null>(null)
const loading = ref(false)
const downloading = ref(false)

const queryRange = computed(() => {
  const { start, end } = resolvePeriod(period.value, today)
  return { from: toIsoDate(start), to: toIsoDate(end) }
})

async function load() {
  loading.value = true
  try {
    data.value = await getProfitLoss({ ...queryRange.value, bucket: bucket.value })
  } catch {
    data.value = null
    toast.add({ severity: 'error', summary: '載入報表失敗', life: 3000 })
  } finally {
    loading.value = false
  }
}
watch([period, bucket], load, { deep: true })

async function onExport() {
  if (downloading.value) return
  downloading.value = true
  try {
    await downloadProfitLossXlsx({ ...queryRange.value, bucket: bucket.value })
    toast.add({ severity: 'success', summary: '已匯出 Excel', life: 2500 })
  } catch {
    toast.add({ severity: 'error', summary: '匯出 Excel 失敗', life: 3000 })
  } finally {
    downloading.value = false
  }
}

const rows  = computed(() => data.value?.rows  ?? [])
const total = computed(() => data.value?.total ?? { income: 0, expense: 0, net: 0, budget: 0, budgetUsagePct: 0 })
const empty = computed(() => !rows.value.length || (total.value.income === 0 && total.value.expense === 0))

// 預算 0 時 execution rate 無意義 → 顯示 '—'
function formatPct(pct: number, budget: number): string {
  if (!budget) return '—'
  return `${pct}%`
}

// 期間標籤顯示（表格 / 圖軸共用）：
// month '2026-01' → '2026/01'，quarter '2026-Q1'、year '2026' 原樣。
function displayLabel(label: string): string {
  const m = /^(\d{4})-(\d{2})$/.exec(label)
  return m ? `${m[1]}/${m[2]}` : label
}

const chartData = computed(() => ({
  labels: rows.value.map((r) => displayLabel(r.label)),
  datasets: [
    {
      type: 'bar' as const,
      label: '收入',
      data: rows.value.map((r) => r.income),
      backgroundColor: INCOME_COLOR,
      borderRadius: { topLeft: 6, topRight: 6 },
      borderSkipped: 'bottom' as const,
      maxBarThickness: 28,
      order: 2,
    },
    {
      type: 'bar' as const,
      label: '支出',
      data: rows.value.map((r) => r.expense),
      backgroundColor: EXPENSE_COLOR,
      borderRadius: { topLeft: 6, topRight: 6 },
      borderSkipped: 'bottom' as const,
      maxBarThickness: 28,
      order: 2,
    },
    {
      type: 'line' as const,
      label: '淨額',
      data: rows.value.map((r) => r.net),
      borderColor: NET_COLOR,
      backgroundColor: NET_COLOR,
      pointBackgroundColor: '#fff',
      pointBorderColor: NET_COLOR,
      pointBorderWidth: 2,
      pointRadius: 4,
      tension: 0.25,
      order: 1,
    },
  ],
}))

function kLabel(n: number) {
  if (Math.abs(n) >= 1000) {
    const k = n / 1000
    return `${k % 1 === 0 ? k : k.toFixed(1)}k`
  }
  return String(n)
}

const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  animation: { duration: 250 },
  plugins: {
    legend: {
      position: 'bottom' as const,
      labels: { boxWidth: 10, boxHeight: 10, color: '#2a3140', font: { size: 12 } },
    },
    tooltip: {
      backgroundColor: '#2a3140',
      padding: 10,
      cornerRadius: 6,
      displayColors: true,
      callbacks: {
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
}))

onMounted(load)
</script>

<template>
  <div class="dash-page">
    <PageHeader title="損益報表" size="admin">
      <template #actions>
        <Button
          label="匯出 Excel"
          icon="pi pi-download"
          outlined
          :disabled="downloading || empty"
          :loading="downloading"
          @click="onExport"
        />
      </template>
    </PageHeader>

    <div class="dash-list-tools" aria-label="報表工具">
      <div class="dash-filter">
        <span class="dash-filter-action">
          <SlideSelectButton
            v-model="bucket"
            :options="bucketOptions"
            option-label="label"
            option-value="value"
            :allow-empty="false"
            aria-label="彙總單位"
          />
        </span>
        <PeriodPicker v-model="period" label="報表期間" default-preset="year" size="sm" />
      </div>
    </div>

    <section class="pl-summary" aria-label="期間合計">
      <div><span>收入合計</span><b class="income">{{ formatCurrency(total.income) }}</b></div>
      <div><span>支出合計</span><b class="expense">{{ formatCurrency(total.expense) }}</b></div>
      <div><span>淨額</span><b :class="total.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(total.net) }}</b></div>
      <div><span>預算合計</span><b>{{ formatCurrency(total.budget) }}</b></div>
      <div><span>整體預算執行率</span><b>{{ formatPct(total.budgetUsagePct, total.budget) }}</b></div>
    </section>

    <section class="dash-panel" aria-labelledby="pl-chart-title">
      <div class="dash-panel-head">
        <h2 id="pl-chart-title" class="dash-panel-title">收支與淨額</h2>
      </div>
      <div v-if="empty" class="dash-empty dash-empty-lg">此區間內尚無收支資料</div>
      <div v-else class="pl-chart-wrap">
        <Chart type="bar" :data="chartData" :options="chartOptions" class="h-full w-full" />
      </div>
    </section>

    <section class="dash-panel dash-table-panel" aria-labelledby="pl-table-title">
      <div class="dash-panel-head">
        <h2 id="pl-table-title" class="dash-panel-title">各期間明細</h2>
      </div>
      <DataTable :value="rows" data-key="label" :table-style="{ width: '100%', minWidth: '720px' }">
        <template #empty>
          <div class="dash-empty">此區間內尚無收支資料</div>
        </template>
        <Column header="期間">
          <template #body="{ data: r }">{{ displayLabel(r.label) }}</template>
        </Column>
        <Column header="收入" header-class="num" body-class="num">
          <template #body="{ data: r }">
            <span class="income">{{ formatCurrency(r.income) }}</span>
          </template>
        </Column>
        <Column header="支出" header-class="num" body-class="num">
          <template #body="{ data: r }">
            <span class="expense">{{ formatCurrency(r.expense) }}</span>
          </template>
        </Column>
        <Column header="淨額" header-class="num" body-class="num">
          <template #body="{ data: r }">
            <span :class="r.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(r.net) }}</span>
          </template>
        </Column>
        <Column header="預算" header-class="num" body-class="num">
          <template #body="{ data: r }">{{ formatCurrency(r.budget) }}</template>
        </Column>
        <Column header="預算執行率" header-class="num" body-class="num">
          <template #body="{ data: r }">{{ formatPct(r.budgetUsagePct, r.budget) }}</template>
        </Column>
        <template #footer>
          <div class="pl-footer">
            <span>合計</span>
            <span class="income">{{ formatCurrency(total.income) }}</span>
            <span class="expense">{{ formatCurrency(total.expense) }}</span>
            <span :class="total.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(total.net) }}</span>
            <span>{{ formatCurrency(total.budget) }}</span>
            <span>{{ formatPct(total.budgetUsagePct, total.budget) }}</span>
          </div>
        </template>
      </DataTable>
    </section>
  </div>
</template>

<style scoped>
.pl-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: var(--space-md);
  padding: var(--space-md) var(--space-lg);
  background: #fff;
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-card);
  margin-bottom: var(--space-md);
}
.pl-summary > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.pl-summary span {
  color: var(--color-muted);
  font-size: 13px;
}
.pl-summary b {
  color: var(--color-ink);
  font-size: 20px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.income { color: #00b39f; }
.expense { color: #dc2626; }
.neg { color: #dc2626; }
.pos { color: var(--color-ink); }

.pl-chart-wrap { height: 320px; }

/* 卡內有標題時，恢復上內距（dash-table-panel 預設 padding-top: 0 是給表格頂邊緣用的） */
.dash-panel.dash-table-panel { padding-top: var(--space-lg); }

.pl-footer {
  display: grid;
  grid-template-columns: minmax(0, 1fr) repeat(5, minmax(0, 1fr));
  gap: var(--space-sm);
  padding: 10px 12px;
  background: var(--color-surface-soft);
  border-top: 1px solid var(--color-hairline);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.pl-footer > span:first-child { color: var(--color-muted); }
.pl-footer > span:not(:first-child) { text-align: right; }

@media (max-width: 639.98px) {
  .pl-summary b { font-size: 16px; }
  .pl-chart-wrap { height: 240px; }
}
</style>
