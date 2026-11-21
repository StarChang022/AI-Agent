<script setup lang="ts">
/**
 * 方案表：從設定「查看方案」開啟，比較免費版／團隊版／企業版，標出公司目前的方案。
 * 不寫價格、不列加購；企業版尚未開放，整欄只寫「尚未開放」。
 */
import { computed } from 'vue'
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'
import type { CompanyPlan } from '@/api/company'
import { PLAN_LABELS } from '@/constants/plan'

const props = defineProps<{ visible: boolean; currentPlan: CompanyPlan | null }>()
const emit = defineEmits<{ 'update:visible': [value: boolean] }>()

const PLANS: CompanyPlan[] = ['free', 'team', 'enterprise']

/** 額度：null 表示該方案不含 */
const QUOTAS: { label: string; free: string | null; team: string }[] = [
  { label: '每月辨識次數', free: '30 次', team: '160 次' },
  { label: '管理者人數', free: '1 位', team: '1 位' },
  { label: '員工人數', free: null, team: '5 位' },
  { label: '儲存空間', free: '3 GB', team: '10 GB' },
]

const BASE_FEATURES = [
  '基礎儀表板',
  '一般支出與收入管理',
  '公司設定',
  '帳戶設定',
  '類別管理',
  '手機與 PWA 支援',
  '站內與 Email 通知',
]

const TEAM_FEATURES = [
  '代墊款請款',
  '資金移轉',
  '損益與現金流報表',
  '付款排程',
  '固定收支設定',
  '報表與收支資料匯出',
  '人員管理',
]

/** 企業版「尚未開放」要跨過的列數：額度 + 全部功能（團隊版多出的功能靠免費版欄的「—」辨識） */
const bodyRowCount = QUOTAS.length + BASE_FEATURES.length + TEAM_FEATURES.length

const currentLabel = computed(() => (props.currentPlan ? PLAN_LABELS[props.currentPlan] : ''))

function cellClass(plan: CompanyPlan) {
  return { 'is-current': plan === props.currentPlan }
}

function close() {
  emit('update:visible', false)
}
</script>

<template>
  <Dialog
    :visible="visible"
    header="方案比較"
    modal
    :dismissable-mask="true"
    :style="{ width: 'min(94vw, 640px)' }"
    @update:visible="emit('update:visible', $event)"
  >
    <table class="plan-table">
      <caption class="sr-only">
        方案比較{{ currentLabel ? `，公司目前為${currentLabel}` : '' }}
      </caption>
      <colgroup>
        <col class="plan-col-label" />
        <col v-for="p in PLANS" :key="p" />
      </colgroup>
      <thead>
        <tr>
          <th scope="col"><span class="sr-only">項目</span></th>
          <th v-for="p in PLANS" :key="p" scope="col" class="plan-head" :class="cellClass(p)">
            <span class="block">{{ PLAN_LABELS[p] }}</span>
            <span v-if="p === currentPlan" class="plan-current-badge">目前方案</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(q, i) in QUOTAS" :key="q.label">
          <th scope="row">{{ q.label }}</th>
          <td :class="cellClass('free')">
            <template v-if="q.free">{{ q.free }}</template>
            <template v-else><span aria-hidden="true">—</span><span class="sr-only">不含</span></template>
          </td>
          <td :class="cellClass('team')">{{ q.team }}</td>
          <td v-if="i === 0" :rowspan="bodyRowCount" class="plan-unavailable" :class="cellClass('enterprise')">
            尚未開放
          </td>
        </tr>

        <tr v-for="f in BASE_FEATURES" :key="f">
          <th scope="row">{{ f }}</th>
          <td :class="cellClass('free')">
            <i class="pi pi-check plan-check" aria-hidden="true" /><span class="sr-only">包含</span>
          </td>
          <td :class="cellClass('team')">
            <i class="pi pi-check plan-check" aria-hidden="true" /><span class="sr-only">包含</span>
          </td>
        </tr>
        <tr v-for="f in TEAM_FEATURES" :key="f">
          <th scope="row">{{ f }}</th>
          <td :class="cellClass('free')">
            <span aria-hidden="true">—</span><span class="sr-only">不含</span>
          </td>
          <td :class="cellClass('team')">
            <i class="pi pi-check plan-check" aria-hidden="true" /><span class="sr-only">包含</span>
          </td>
        </tr>
      </tbody>
    </table>

    <p class="q-help mt-3">封測期間所有公司皆為團隊版，暫不開放切換方案。</p>

    <template #footer>
      <Button label="關閉" outlined @click="close" />
    </template>
  </Dialog>
</template>

<style scoped>
.plan-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
  font-size: 14px;
  color: var(--color-ink);
}
.plan-col-label { width: 40%; }
.plan-table th,
.plan-table td {
  padding: 8px 10px;
  border-bottom: 1px solid var(--color-hairline);
  vertical-align: middle;
}
.plan-table tbody th {
  text-align: left;
  font-weight: 400;
  color: var(--color-slate);
}
.plan-table td {
  text-align: center;
  font-variant-numeric: tabular-nums;
  font-weight: 600;
}
.plan-head {
  text-align: center;
  font-weight: 600;
  color: var(--color-ink);
  border-radius: 12px 12px 0 0;
}
.plan-current-badge {
  display: inline-block;
  margin-top: 4px;
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--color-primary-solid);
  color: #fff;
  font-size: 12px;
  font-weight: 600;
  white-space: nowrap;
}
.is-current { background: var(--color-primary-50); }
.plan-check { color: var(--color-primary-text); font-size: 14px; }
.plan-unavailable {
  color: var(--color-muted);
  font-weight: 600;
}

@media (max-width: 639.98px) {
  .plan-table { font-size: 13px; }
  .plan-col-label { width: 36%; }
  .plan-table th,
  .plan-table td { padding: 7px 4px; }
  .plan-table tbody th { padding-left: 6px; }
}
</style>
