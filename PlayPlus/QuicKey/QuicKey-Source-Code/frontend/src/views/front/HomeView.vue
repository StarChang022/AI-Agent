<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useOnboardingStore } from '@/stores/onboarding'
import { useOnboardingTour } from '@/composables/useOnboardingTour'
import { getMyReimbursementSummary, type MyReimbursementSummaryKpi } from '@/api/reimbursements'
import { formatCurrency, formatDate } from '@/utils/format'
import StatusBadge from '@/components/StatusBadge.vue'
import EmptyState from '@/components/EmptyState.vue'
import Button from 'primevue/button'
import { useToast } from 'primevue/usetoast'

const auth = useAuthStore()
const onboarding = useOnboardingStore()
const { startTour, isActive } = useOnboardingTour()
const router = useRouter()
const toast = useToast()

const kpi = ref<MyReimbursementSummaryKpi | null>(null)
const isLoading = ref(false)

async function reload() {
  isLoading.value = true
  try {
    kpi.value = await getMyReimbursementSummary()
  } catch {
    toast.add({ severity: 'error', summary: '載入首頁資料失敗', life: 3000 })
    kpi.value = null
  } finally {
    isLoading.value = false
  }
}

/**
 * Employee 首次進首頁且未完成 onboarding → 自動觸發新手導覽（3 步）。
 * 之後透過使用者選單「新手導覽」重跑也走同一路徑。
 * isActive() 檢查：avoid tour 最後一步導回 front-home 時 remount 又 startTour，
 * 造成兩層遮罩 + 兩個 popover（與 DashboardView 同一種 race）。
 */
onMounted(async () => {
  reload()
  const user = auth.currentUser
  if (!user || auth.role !== 'employee') return
  if (onboarding.isCompleted()) return
  if (isActive()) return
  await nextTick()
  startTour()
})

const totalCount = computed(() => kpi.value?.counts.all ?? 0)
const rejectedCount = computed(() => kpi.value?.counts.rejected ?? 0)
const inReviewTotal = computed(() => kpi.value?.totals.inReview ?? 0)
const approvedTotal = computed(() => kpi.value?.totals.approved ?? 0)
const paidTotal = computed(() => kpi.value?.totals.paid ?? 0)
/** 待收款 = 已核銷待發放 + 簽核中（尚未拿到錢的兩種狀態） */
const receivableTotal = computed(() => approvedTotal.value + inReviewTotal.value)
const lastPaid = computed(() => kpi.value?.lastPaid ?? null)
const recentList = computed(() => kpi.value?.recent ?? [])

function goForm() {
  router.push({ name: 'front-new' })
}
function goHistory() {
  router.push({ name: 'front-history' })
}
function openDetail(id: string) {
  router.push({ name: 'front-expense-detail', params: { id } })
}
</script>

<template>
  <div class="front-page" data-tour="home-welcome">
    <div class="front-greeting">
      <div>
        <h1 class="front-title">{{ auth.currentUser?.name ?? '' }}，你好</h1>
        <p class="front-sub">快速新增代墊款，並追蹤簽核與發放狀態</p>
      </div>
      <Button label="新增代墊款" icon="pi pi-plus" @click="goForm" />
    </div>

    <div
      v-if="isLoading && kpi === null"
      class="py-12 flex flex-col items-center justify-center gap-2 text-[var(--color-muted)]"
    >
      <i class="pi pi-spin pi-spinner text-2xl" />
      <span class="text-[13px]">載入中…</span>
    </div>

    <template v-else-if="totalCount > 0">
      <div class="front-kpi-grid">
        <section class="front-panel front-kpi">
          <div class="front-kpi-head">
            <span class="front-kpi-label">待收款</span>
            <span class="front-kpi-icon"
              ><i class="pi pi-wallet" aria-hidden="true"
            /></span>
          </div>
          <div class="front-kpi-value">
            {{ formatCurrency(receivableTotal) }}
          </div>

          <div class="front-kpi-meta">
            <div class="front-kv">
              <span class="front-kv-dot" />
              <span>已核銷待發放</span>
              <b>{{ formatCurrency(approvedTotal) }}</b>
            </div>
            <div class="front-kv">
              <span
                class="front-kv-dot"
                style="background: var(--status-review)"
              />
              <span>簽核中</span>
              <b>{{ formatCurrency(inReviewTotal) }}</b>
            </div>
          </div>
        </section>

        <section class="front-panel front-kpi">
          <div class="front-kpi-head">
            <span class="front-kpi-label">已發放（累計）</span>
            <span
              class="front-kpi-icon"
              style="
                background: var(--status-paid-bg);
                color: var(--status-paid);
              "
              ><i class="pi pi-check" aria-hidden="true"
            /></span>
          </div>
          <div class="front-kpi-value" style="font-size: 22px">
            {{ formatCurrency(paidTotal) }}
          </div>
          <div class="front-kpi-meta">
            <div v-if="lastPaid" class="front-kv">
              <span>最近一次</span>
              <b
                >{{ formatDate(lastPaid.updatedAt) }}<span class="sep" aria-hidden="true" />{{ formatCurrency(lastPaid.amount) }}</b
              >
            </div>
            <div v-else class="front-kv">
              <span>尚無發放紀錄</span>
            </div>
          </div>
        </section>
      </div>

      <button
        v-if="rejectedCount > 0"
        type="button"
        class="front-alert"
        @click="goHistory"
      >
        <i class="pi pi-exclamation-triangle" aria-hidden="true" />
        <span class="flex-1 text-sm">
          你有 {{ rejectedCount }} 筆請款被退回，需要修改重送
        </span>
        <span class="text-sm font-semibold">查看</span>
      </button>

      <section class="front-panel">
        <div class="front-section-head">
          <h2 class="front-section-title">最近請款紀錄</h2>
          <button type="button" class="front-section-link" @click="goHistory">
            查看全部
          </button>
        </div>
        <div class="front-list">
          <button
            v-for="item in recentList"
            :key="item.id"
            type="button"
            class="front-list-row"
            @click="openDetail(item.id)"
          >
            <div class="front-list-top">
              <StatusBadge :status="item.status" />
              <i
                class="pi pi-chevron-right front-list-arrow"
                aria-hidden="true"
              />
            </div>
            <div class="front-list-bottom">
              <span class="front-list-main">
                <span class="category-chip">
                  {{ item.category.name }}
                </span>
                <span class="front-list-text">
                  {{ item.description || '（未填寫描述）' }}
                </span>
              </span>
              <span class="front-list-amount">
                {{ formatCurrency(item.amount) }}
              </span>
            </div>
          </button>
        </div>
      </section>
    </template>

    <EmptyState
      v-else
      icon="pi pi-inbox"
      title="還沒有任何請款紀錄"
      description="拍張發票，新增你的第一筆代墊款"
    >
      <template #action>
        <Button label="新增代墊款" @click="goForm" />
      </template>
    </EmptyState>
  </div>
</template>
