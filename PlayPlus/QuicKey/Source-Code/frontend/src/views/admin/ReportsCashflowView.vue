<script setup lang="ts">
/**
 * 現金流報表（docs/收入管理規格.md §4、儀表板與報表-規格與實作計畫.md §三）。
 * 以收款日 / 付款日歸屬；垃圾桶、作廢代墊款不計入。
 * - 期間：預設當年度；可切單月 / 單季 / 自訂
 * - bucket：月（預設）/ 季 / 年
 * - 畫面：合計卡 + line chart + 月份明細 + 待收款清單 + 待付款清單（逾期紅字）
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
  downloadCashflowXlsx,
  getCashflow,
  type Cashflow,
  type CashflowBucket,
} from '@/api/reports'

const toast = useToast()

const CASH_IN_COLOR  = '#00b39f'
const CASH_OUT_COLOR = '#dc2626'
const NET_COLOR      = '#3b4252'

const today = new Date()
const todayIso = toIsoDate(today)

const period = ref<Period>({ preset: 'year' })
const bucket = ref<CashflowBucket>('month')
const bucketOptions = [
  { value: 'month',   label: '月' },
  { value: 'quarter', label: '季' },
  { value: 'year',    label: '年' },
] as const

const data    = ref<Cashflow | null>(null)
const loading = ref(false)
const downloading = ref(false)

const queryRange = computed(() => {
  const { start, end } = resolvePeriod(period.value, today)
  return { from: toIsoDate(start), to: toIsoDate(end) }
})

async function load() {
  loading.value = true
  try {
    data.value = await getCashflow({ ...queryRange.value, bucket: bucket.value })
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
    await downloadCashflowXlsx({ ...queryRange.value, bucket: bucket.value })
    toast.add({ severity: 'success', summary: '已匯出 Excel', life: 2500 })
  } catch {
    toast.add({ severity: 'error', summary: '匯出 Excel 失敗', life: 3000 })
  } finally {
    downloading.value = false
  }
}

const rows        = computed(() => data.value?.rows        ?? [])
const total       = computed(() => data.value?.total       ?? { cashIn: 0, cashOut: 0, net: 0 })
const pendingIn   = computed(() => data.value?.pendingIn   ?? [])
const pendingOut  = computed(() => data.value?.pendingOut  ?? [])
const empty       = computed(() => !rows.value.length || (total.value.cashIn === 0 && total.value.cashOut === 0))

// 期間標籤顯示：month '2026-01' → '2026/01'，quarter / year 原樣。
function displayLabel(label: string): string {
  const m = /^(\d{4})-(\d{2})$/.exec(label)
  return m ? `${m[1]}/${m[2]}` : label
}

// 逾期判定：預計付款日已過今天。no date → 不視為逾期。
function isOverdue(dateIso: string | null): boolean {
  return !!dateIso && dateIso < todayIso
}

const chartData = computed(() => ({
  labels: rows.value.map((r) => displayLabel(r.label)),
  datasets: [
    {
      type: 'bar' as const,
      label: '收款',
      data: rows.value.map((r) => r.cashIn),
      backgroundColor: CASH_IN_COLOR,
      borderRadius: { topLeft: 6, topRight: 6 },
      borderSkipped: 'bottom' as const,
      maxBarThickness: 28,
      order: 2,
    },
    {
      type: 'bar' as const,
      label: '付款',
      data: rows.value.map((r) => r.cashOut),
      backgroundColor: CASH_OUT_COLOR,
      borderRadius: { topLeft: 6, topRight: 6 },
      borderSkipped: 'bottom' as const,
      maxBarThickness: 28,
      order: 2,
    },
    {
      type: 'line' as const,
      label: '淨流',
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
    <PageHeader title="現金流報表" size="admin">
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

    <section class="cf-summary" aria-label="期間合計">
      <div><span>收款合計</span><b class="income">{{ formatCurrency(total.cashIn) }}</b></div>
      <div><span>付款合計</span><b class="expense">{{ formatCurrency(total.cashOut) }}</b></div>
      <div><span>現金淨流</span><b :class="total.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(total.net) }}</b></div>
    </section>

    <section class="dash-panel" aria-labelledby="cf-chart-title">
      <div class="dash-panel-head">
        <h2 id="cf-chart-title" class="dash-panel-title">收付款與淨流</h2>
      </div>
      <div v-if="empty" class="dash-empty dash-empty-lg">此區間內尚無收付款</div>
      <div v-else class="cf-chart-wrap">
        <Chart type="bar" :data="chartData" :options="chartOptions" class="h-full w-full" />
      </div>
    </section>

    <section class="dash-panel dash-table-panel" aria-labelledby="cf-table-title">
      <div class="dash-panel-head">
        <h2 id="cf-table-title" class="dash-panel-title">各期間明細</h2>
      </div>
      <DataTable :value="rows" data-key="label" :table-style="{ width: '100%', minWidth: '480px' }">
        <template #empty>
          <div class="dash-empty">此區間內尚無收付款</div>
        </template>
        <Column header="期間">
          <template #body="{ data: r }">{{ displayLabel(r.label) }}</template>
        </Column>
        <Column header="收款" header-class="num" body-class="num">
          <template #body="{ data: r }">
            <span class="income">{{ formatCurrency(r.cashIn) }}</span>
          </template>
        </Column>
        <Column header="付款" header-class="num" body-class="num">
          <template #body="{ data: r }">
            <span class="expense">{{ formatCurrency(r.cashOut) }}</span>
          </template>
        </Column>
        <Column header="淨流" header-class="num" body-class="num">
          <template #body="{ data: r }">
            <span :class="r.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(r.net) }}</span>
          </template>
        </Column>
        <template #footer>
          <div class="cf-footer">
            <span>合計</span>
            <span class="income">{{ formatCurrency(total.cashIn) }}</span>
            <span class="expense">{{ formatCurrency(total.cashOut) }}</span>
            <span :class="total.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(total.net) }}</span>
          </div>
        </template>
      </DataTable>
    </section>

    <section class="dash-panel dash-table-panel" aria-labelledby="cf-pending-in-title">
      <div class="dash-panel-head">
        <h2 id="cf-pending-in-title" class="dash-panel-title">
          待收款清單
          <small class="dash-panel-sub">共 {{ pendingIn.length }} 筆</small>
        </h2>
      </div>
      <DataTable :value="pendingIn" data-key="id" :table-style="{ width: '100%', minWidth: '560px' }">
        <template #empty>
          <div class="dash-empty">目前沒有待收款</div>
        </template>
        <Column header="客戶" field="customer" />
        <Column header="金額" header-class="num" body-class="num" :style="{ width: '160px' }">
          <template #body="{ data: r }">{{ formatCurrency(r.amount) }}</template>
        </Column>
        <Column header="開立日" :style="{ width: '200px' }">
          <template #body="{ data: r }">{{ r.date }}</template>
        </Column>
      </DataTable>
    </section>

    <section class="dash-panel dash-table-panel" aria-labelledby="cf-pending-out-title">
      <div class="dash-panel-head">
        <h2 id="cf-pending-out-title" class="dash-panel-title">
          待付款清單
          <small class="dash-panel-sub">共 {{ pendingOut.length }} 筆</small>
        </h2>
      </div>
      <DataTable :value="pendingOut" data-key="id" :table-style="{ width: '100%', minWidth: '560px' }">
        <template #empty>
          <div class="dash-empty">目前沒有待付款</div>
        </template>
        <Column header="廠商">
          <template #body="{ data: r }">{{ r.vendor || '—' }}</template>
        </Column>
        <Column header="金額" header-class="num" body-class="num" :style="{ width: '160px' }">
          <template #body="{ data: r }">{{ formatCurrency(r.amount) }}</template>
        </Column>
        <Column header="預計付款日" :style="{ width: '200px' }">
          <template #body="{ data: r }">
            <span :class="{ 'cf-overdue': isOverdue(r.plannedPayoutDate) }">
              {{ r.plannedPayoutDate || '—' }}
              <span v-if="isOverdue(r.plannedPayoutDate)" class="cf-overdue-tag">逾期</span>
            </span>
          </template>
        </Column>
      </DataTable>
    </section>
  </div>
</template>

<style scoped>
.cf-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: var(--space-md);
  padding: var(--space-md) var(--space-lg);
  background: #fff;
  border: 1px solid var(--color-hairline);
  border-radius: var(--radius-card);
  margin-bottom: var(--space-md);
}
.cf-summary > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.cf-summary span {
  color: var(--color-muted);
  font-size: 13px;
}
.cf-summary b {
  color: var(--color-ink);
  font-size: 20px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.income { color: #00b39f; }
.expense { color: #dc2626; }
.neg { color: #dc2626; }
.pos { color: var(--color-ink); }

.cf-chart-wrap { height: 320px; }

/* 卡內有標題時，恢復上內距（dash-table-panel 預設 padding-top: 0 是給表格頂邊緣用的） */
.dash-panel.dash-table-panel { padding-top: var(--space-lg); }

.cf-footer {
  display: grid;
  grid-template-columns: minmax(0, 1fr) repeat(3, minmax(0, 1fr));
  gap: var(--space-sm);
  padding: 10px 12px;
  background: var(--color-surface-soft);
  border-top: 1px solid var(--color-hairline);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.cf-footer > span:first-child { color: var(--color-muted); }
.cf-footer > span:not(:first-child) { text-align: right; }

.cf-overdue { color: #dc2626; font-weight: 600; }
.cf-overdue-tag {
  display: inline-block;
  margin-left: 6px;
  padding: 1px 6px;
  font-size: 11px;
  font-weight: 600;
  color: #fff;
  background: #dc2626;
  border-radius: 999px;
}

.dash-panel-sub {
  margin-left: 8px;
  color: var(--color-muted);
  font-size: 12px;
  font-weight: 400;
}

@media (max-width: 639.98px) {
  .cf-summary b { font-size: 16px; }
  .cf-chart-wrap { height: 240px; }
}
</style>
