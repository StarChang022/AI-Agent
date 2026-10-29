<script setup lang="ts">
/**
 * 頂欄全域搜尋：找整個後台的請款單、支出、收入（廠商/客戶、說明、發票號碼）。
 * 點結果會開對應列表頁並直接打開明細（?open=<id>）。見 design-system 後台原型。
 *
 * 走伺服器端搜尋：關鍵字 debounce 300ms 後打三支 list endpoint（各取 5 筆）。
 * 請款單在前端再濾掉 draft，與列表頁預設檢視一致。
 * incomes 目前尚未分頁，前端 slice(0, 5) 當上限。
 */
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { listAdminReimbursements, type ReimbursementSummary } from '@/api/reimbursements'
import { listExpenses, type ExpenseSummary } from '@/api/expenses'
import { listIncomes, type Income } from '@/api/incomes'
import { formatCurrency, formatDate } from '@/utils/format'
import StatusBadge from '@/components/StatusBadge.vue'

const router = useRouter()

const q = ref('')
const open = ref(false)
const active = ref(-1)
const loading = ref(false)
const reqHits = ref<ReimbursementSummary[]>([])
const expHits = ref<ExpenseSummary[]>([])
const incHits = ref<Income[]>([])

const flat = computed(() => [
  ...reqHits.value.map((r) => ({ kind: 'req' as const, id: r.id })),
  ...expHits.value.map((e) => ({ kind: 'exp' as const, id: e.id })),
  ...incHits.value.map((i) => ({ kind: 'inc' as const, id: i.id })),
])

let debounceTimer: number | null = null
let fetchSeq = 0

async function runSearch(keyword: string) {
  const seq = ++fetchSeq
  loading.value = true
  try {
    const [reqs, exps, incs] = await Promise.all([
      listAdminReimbursements({ q: keyword, perPage: 5 }),
      listExpenses({ q: keyword, perPage: 5 }),
      listIncomes({ q: keyword }),
    ])
    if (seq !== fetchSeq) return
    reqHits.value = reqs.data.filter((r) => r.status !== 'draft').slice(0, 5)
    expHits.value = exps.data
    incHits.value = incs.slice(0, 5)
  } catch {
    if (seq !== fetchSeq) return
    reqHits.value = []
    expHits.value = []
    incHits.value = []
  } finally {
    if (seq === fetchSeq) loading.value = false
  }
}

watch(q, (val) => {
  active.value = -1
  const keyword = val.trim()
  if (debounceTimer !== null) {
    window.clearTimeout(debounceTimer)
    debounceTimer = null
  }
  if (!keyword) {
    fetchSeq++
    reqHits.value = []
    expHits.value = []
    incHits.value = []
    loading.value = false
    return
  }
  debounceTimer = window.setTimeout(() => {
    debounceTimer = null
    runSearch(keyword)
  }, 300)
})

onBeforeUnmount(() => {
  if (debounceTimer !== null) window.clearTimeout(debounceTimer)
})

function go(kind: 'req' | 'exp' | 'inc', id: string) {
  open.value = false
  q.value = ''
  const name = kind === 'req' ? 'admin-records' : kind === 'exp' ? 'admin-expenses' : 'admin-incomes'
  // 延到下個事件 loop 再換頁：避免目前 click 冒泡到新開 Drawer 的 mask 判定為「點外面」而關閉。
  setTimeout(() => router.push({ name, query: { open: id } }), 0)
}
function onKey(e: KeyboardEvent) {
  if (e.key === 'ArrowDown') { e.preventDefault(); open.value = true; active.value = Math.min(active.value + 1, flat.value.length - 1) }
  else if (e.key === 'ArrowUp') { e.preventDefault(); active.value = Math.max(active.value - 1, -1) }
  else if (e.key === 'Enter' && active.value > -1) { const h = flat.value[active.value]; if (h) go(h.kind, h.id) }
  else if (e.key === 'Escape') { open.value = false; active.value = -1 }
}
function onInput() { open.value = !!q.value.trim(); active.value = -1 }
function onBlur() { window.setTimeout(() => { open.value = false }, 150) }
</script>

<template>
  <div class="dash-gsearch">
    <label class="tb-search">
      <i class="pi pi-search" aria-hidden="true" />
      <input
        v-model="q"
        type="search"
        placeholder="搜尋請款、支出、收入"
        aria-label="全域搜尋"
        role="combobox"
        autocomplete="off"
        :aria-expanded="open"
        aria-controls="gsearch-list"
        @input="onInput"
        @focus="onInput"
        @blur="onBlur"
        @keydown="onKey"
      />
    </label>
    <div v-if="open" id="gsearch-list" class="dash-gsearch-panel" role="listbox">
      <div v-if="loading" class="gs-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;搜尋中…</div>
      <template v-else-if="flat.length">
        <template v-if="reqHits.length">
          <div class="gs-group">請款單</div>
          <button
            v-for="(r, i) in reqHits"
            :key="r.id"
            type="button"
            role="option"
            class="gs-item"
            :class="{ active: active === i }"
            @mousedown.prevent="go('req', r.id)"
          >
            <span class="gs-main">{{ r.employee.name || '—' }}<span class="sep" aria-hidden="true" />{{ r.description }}</span>
            <span class="gs-sub">{{ r.category.name }}<span class="sep" aria-hidden="true" />{{ formatCurrency(r.amount) }}</span>
            <span class="gs-right"><StatusBadge :status="r.status" /></span>
          </button>
        </template>
        <template v-if="expHits.length">
          <div class="gs-group">支出</div>
          <button
            v-for="(x, i) in expHits"
            :key="x.id"
            type="button"
            role="option"
            class="gs-item"
            :class="{ active: active === reqHits.length + i }"
            @mousedown.prevent="go('exp', x.id)"
          >
            <span class="gs-main">{{ x.vendor || x.category.name }}</span>
            <span class="gs-sub">{{ x.category.name }}<span class="sep" aria-hidden="true" />{{ formatDate(x.date) }}</span>
            <span class="gs-right">{{ formatCurrency(x.amount) }}</span>
          </button>
        </template>
        <template v-if="incHits.length">
          <div class="gs-group">收入</div>
          <button
            v-for="(n, i) in incHits"
            :key="n.id"
            type="button"
            role="option"
            class="gs-item"
            :class="{ active: active === reqHits.length + expHits.length + i }"
            @mousedown.prevent="go('inc', n.id)"
          >
            <span class="gs-main">{{ n.customer || n.category.name }}</span>
            <span class="gs-sub">{{ n.category.name }}<span class="sep" aria-hidden="true" />{{ formatDate(n.date) }}</span>
            <span class="gs-right">{{ formatCurrency(n.amount) }}</span>
          </button>
        </template>
      </template>
      <div v-else class="gs-empty">找不到「{{ q }}」相關的請款、支出或收入</div>
    </div>
  </div>
</template>
