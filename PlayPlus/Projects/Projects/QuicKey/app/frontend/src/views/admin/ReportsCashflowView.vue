<script setup lang="ts">
/**
 * 現金流報表（docs/收入管理規格.md §4、儀表板與報表-規格與實作計畫.md §三）。
 * 以實收日期 / 實付日期歸屬；垃圾桶、作廢代墊款不計入。
 * - 期間：預設當年度；可切單月 / 單季 / 自訂
 * - bucket：月（預設）/ 季 / 年
 * - 帳戶：預設所有帳戶合計，可切單一帳戶（待收付清單也只列該帳戶，並多一欄資金移轉）
 * - 畫面：合計卡（含期初、期末）+ line chart + 月份明細 + 待收款清單 + 待付款清單（逾期紅字）
 */
import { computed, onMounted, ref, watch } from 'vue'
import PageHeader from '@/components/PageHeader.vue'
import PeriodPicker from '@/components/qds/PeriodPicker.vue'
import SlideSelectButton from '@/components/qds/SlideSelectButton.vue'
import Button from 'primevue/button'
import Chart from 'primevue/chart'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import Select from 'primevue/select'
import { useToast } from 'primevue/usetoast'
import { formatCurrency, toIsoDate } from '@/utils/format'
import { resolvePeriod, type Period } from '@/utils/period'
import { useAccountOptions } from '@/composables/useAccountOptions'
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

/** Select 把空字串當成未選，「所有帳戶」要用實際的值 */
const ALL_ACCOUNTS = 'all'
const accountId = ref(ALL_ACCOUNTS)
const { options: accounts, load: loadAccounts } = useAccountOptions()
const accountFilterOptions = computed(() => [{ id: ALL_ACCOUNTS, name: '所有帳戶' }, ...accounts.value])

const query = computed(() => {
  const { start, end } = resolvePeriod(period.value, today)
  return {
    from: toIsoDate(start),
    to: toIsoDate(end),
    bucket: bucket.value,
    accountId: accountId.value === ALL_ACCOUNTS ? undefined : accountId.value,
  }
})

// 連續切換帳戶或期間時，晚回來的舊回應直接丟棄
let loadSeq = 0
async function load() {
  const seq = ++loadSeq
  loading.value = true
  try {
    const res = await getCashflow(query.value)
    if (seq !== loadSeq) return
    data.value = res
  } catch {
    if (seq !== loadSeq) return
    data.value = null
    toast.add({ severity: 'error', summary: '載入報表失敗', life: 3000 })
  } finally {
    if (seq === loadSeq) loading.value = false
  }
}
watch(query, load)

async function onExport() {
  if (downloading.value) return
  downloading.value = true
  try {
    await downloadCashflowXlsx(query.value)
    toast.add({ severity: 'success', summary: '已匯出 Excel', life: 2500 })
  } catch {
    toast.add({ severity: 'error', summary: '匯出 Excel 失敗', life: 3000 })
  } finally {
    downloading.value = false
  }
}

const rows        = computed(() => data.value?.rows        ?? [])
const total       = computed(() => data.value?.total       ?? { cashIn: 0, cashOut: 0, net: 0, openingCash: null, closingCash: null })
const pendingIn   = computed(() => data.value?.pendingIn   ?? [])
const pendingOut  = computed(() => data.value?.pendingOut  ?? [])
const noMovement  = computed(() => !rows.value.length || (total.value.cashIn === 0 && total.value.cashOut === 0 && !total.value.transferCount))
/** 只有單一帳戶的回應才有移轉欄位；所有帳戶時轉出轉入相抵，不顯示 */
const showTransfer = computed(() => total.value.transfer !== undefined)
// 沒有收付款但已有帳戶起始金額時，期初、期末仍有內容可以匯出
const empty       = computed(() => noMovement.value && total.value.openingCash === null)

/** 尚未有任何帳戶開始的期間，期初、期末為 null */
function cashText(n: number | null): string {
  return n == null ? '—' : formatCurrency(n)
}

/** 移轉要看出方向：轉入為正、轉出為負 */
function transferText(n: number): string {
  return n > 0 ? `+${formatCurrency(n)}` : formatCurrency(n)
}

// 期間標籤顯示：month '2026-01' → '2026/01'，quarter / year 原樣。
function displayLabel(label: string): string {
  const m = /^(\d{4})-(\d{2})$/.exec(label)
  return m ? `${m[1]}/${m[2]}` : label
}

// 逾期判定：應收／應付日期已過今天。no date → 不視為逾期。
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

onMounted(() => {
  void load()
  void loadAccounts()
})
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
        <span id="cf-account-label" class="sr-only">帳戶</span>
        <Select
          v-model="accountId"
          :options="accountFilterOptions"
          option-label="name"
          option-value="id"
          aria-labelledby="cf-account-label"
          size="small"
          class="cf-account"
        />
      </div>
    </div>

    <section class="cf-summary" aria-label="期間合計">
      <div><span>期初現金</span><b>{{ cashText(total.openingCash) }}</b></div>
      <div><span>收款合計</span><b class="income">{{ formatCurrency(total.cashIn) }}</b></div>
      <div><span>付款合計</span><b class="expense">{{ formatCurrency(total.cashOut) }}</b></div>
      <div v-if="showTransfer"><span>資金移轉</span><b :class="total.transfer! < 0 ? 'neg' : 'pos'">{{ transferText(total.transfer!) }}</b></div>
      <div><span>現金淨流</span><b :class="total.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(total.net) }}</b></div>
      <div><span>期末現金</span><b>{{ cashText(total.closingCash) }}</b></div>
    </section>

    <section class="dash-panel" aria-labelledby="cf-chart-title">
      <div class="dash-panel-head">
        <h2 id="cf-chart-title" class="dash-panel-title">收付款與淨流</h2>
      </div>
      <div v-if="noMovement" class="dash-empty dash-empty-lg">此區間內尚無收付款</div>
      <div v-else class="cf-chart-wrap">
        <Chart type="bar" :data="chartData" :options="chartOptions" class="h-full w-full" />
      </div>
    </section>

    <section class="dash-panel dash-table-panel" aria-labelledby="cf-table-title">
      <div class="dash-panel-head">
        <h2 id="cf-table-title" class="dash-panel-title">各期間明細</h2>
      </div>
      <DataTable :value="rows" data-key="label" :table-style="{ width: '100%', minWidth: showTransfer ? '860px' : '720px' }">
        <template #empty>
          <div class="dash-empty">此區間內尚無收付款</div>
        </template>
        <!-- 合計放在各欄的 footer：在表格內，窄螢幕可一起橫捲，也和欄位對齊 -->
        <Column header="期間" footer="合計">
          <template #body="{ data: r }">{{ displayLabel(r.label) }}</template>
        </Column>
        <Column header="期初現金" header-class="num" body-class="num" footer-class="num" :footer="cashText(total.openingCash)">
          <template #body="{ data: r }">{{ cashText(r.openingCash) }}</template>
        </Column>
        <Column header="收款" header-class="num" body-class="num" footer-class="num">
          <template #body="{ data: r }">
            <span class="income">{{ formatCurrency(r.cashIn) }}</span>
          </template>
          <template #footer><span class="income">{{ formatCurrency(total.cashIn) }}</span></template>
        </Column>
        <Column header="付款" header-class="num" body-class="num" footer-class="num">
          <template #body="{ data: r }">
            <span class="expense">{{ formatCurrency(r.cashOut) }}</span>
          </template>
          <template #footer><span class="expense">{{ formatCurrency(total.cashOut) }}</span></template>
        </Column>
        <Column v-if="showTransfer" header="資金移轉" header-class="num" body-class="num" footer-class="num">
          <template #body="{ data: r }">
            <span :class="r.transfer < 0 ? 'neg' : 'pos'">{{ transferText(r.transfer) }}</span>
          </template>
          <template #footer><span :class="total.transfer! < 0 ? 'neg' : 'pos'">{{ transferText(total.transfer!) }}</span></template>
        </Column>
        <Column header="淨流" header-class="num" body-class="num" footer-class="num">
          <template #body="{ data: r }">
            <span :class="r.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(r.net) }}</span>
          </template>
          <template #footer><span :class="total.net < 0 ? 'neg' : 'pos'">{{ formatCurrency(total.net) }}</span></template>
        </Column>
        <Column header="期末現金" header-class="num" body-class="num" footer-class="num" :footer="cashText(total.closingCash)">
          <template #body="{ data: r }">{{ cashText(r.closingCash) }}</template>
        </Column>
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
        <Column header="應收日期" :style="{ width: '200px' }">
          <template #body="{ data: r }">
            <span :class="{ 'cf-overdue': isOverdue(r.plannedCollectionDate) }">
              {{ r.plannedCollectionDate || '—' }}
              <span v-if="isOverdue(r.plannedCollectionDate)" class="cf-overdue-tag">逾期</span>
            </span>
          </template>
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
        <Column header="應付日期" :style="{ width: '200px' }">
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
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
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

:deep(.p-datatable-tfoot > tr > td) {
  background: var(--color-surface-soft);
  border-top: 1px solid var(--color-hairline);
  font-size: 14px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
:deep(.p-datatable-tfoot > tr > td:first-child) { color: var(--color-muted); }

.cf-account { width: 180px; }

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
