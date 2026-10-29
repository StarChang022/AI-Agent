<script setup lang="ts">
/**
 * 通知中心：完整通知列表。走伺服器端分頁。
 * - 三個 tab（全部 / 未讀 / 已讀）對應後端 read filter
 * - 標準分頁：預設 10、ROWS_OPTIONS [10, 20, 50]
 * - 點列導向通知對應目的地，並 markRead（透過 useNotifications 讓鈴鐺紅點同步）
 * - 「全部標為已讀」只在有未讀時啟用；成功後重拉當前頁
 */
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable, { type DataTablePageEvent, type DataTableRowClickEvent } from 'primevue/datatable'
import { useToast } from 'primevue/usetoast'
import { listNotifications, type ListNotificationsQuery, type Notification } from '@/api/notifications'
import { describeNotification, useNotifications } from '@/composables/useNotifications'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import PageHeader from '@/components/PageHeader.vue'
import TabBar from '@/components/qds/TabBar.vue'

const router = useRouter()
const toast = useToast()
const { unreadCount, refreshUnreadCount, markRead, markAllRead } = useNotifications()

type Tab = 'all' | 'unread' | 'read'
const tab = ref<Tab>('all')
const tabs = computed(() => [
  { value: 'all' as Tab, label: '全部' },
  { value: 'unread' as Tab, label: '未讀', count: unreadCount.value },
  { value: 'read' as Tab, label: '已讀' },
])

// ─── 伺服器端分頁 state ─────────────────────────────
const rows = ref<Notification[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const loading = ref(false)

const rowViews = computed(() => rows.value.map(describeNotification))

async function refreshList() {
  loading.value = true
  try {
    const query: ListNotificationsQuery = {
      read: tab.value,
      page: page.value,
      perPage: pageSize.value,
    }
    const resp = await listNotifications(query)
    rows.value = resp.data
    total.value = resp.meta.total
  } catch {
    toast.add({ severity: 'error', summary: '載入通知失敗', life: 3000 })
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void refreshUnreadCount()
  void refreshList()
})

// 切 tab → 重設到第 1 頁、refetch
watch(tab, () => {
  page.value = 1
  void refreshList()
})
watch([page, pageSize], () => {
  void refreshList()
})

function onPage(evt: DataTablePageEvent) {
  pageSize.value = evt.rows
  page.value = evt.page + 1
}

async function openByView(view: { id: string }) {
  const n = rows.value.find((r) => r.id === view.id)
  if (!n) return
  const target = describeNotification(n).to
  if (!n.readAt) {
    await markRead(n.id)
    // 本地同步：讓當前列表的該筆也顯示已讀，不等重拉
    const idx = rows.value.findIndex((r) => r.id === n.id)
    if (idx >= 0) {
      rows.value[idx] = { ...rows.value[idx], readAt: new Date().toISOString() }
    }
  }
  router.push(target)
}
function onRowClick(e: DataTableRowClickEvent) {
  void openByView(e.data as { id: string })
}

async function onMarkAll() {
  await markAllRead()
  // markAllRead 後：unread tab 的資料集已全空，可就地清空；
  // all / read tab 的 total 會變動（read tab 新增了原本未讀的），一律重拉當前頁。
  if (tab.value === 'unread') {
    rows.value = []
    total.value = 0
  } else {
    await refreshList()
  }
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="通知中心" size="admin">
      <template #actions>
        <Button
          label="全部標為已讀"
          icon="pi pi-check"
          outlined
          :disabled="unreadCount === 0"
          @click="onMarkAll"
        />
      </template>
    </PageHeader>

    <section class="dash-panel dash-table-panel notif-table-panel" aria-label="通知列表">
      <div class="list-head">
        <TabBar v-model="tab" :tabs="tabs" label="通知狀態" variant="segmented" />
      </div>
      <DataTable
        :value="rowViews"
        data-key="id"
        :table-style="{ width: '100%' }"
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
          <div class="dash-empty dash-empty-lg">
            <i class="pi pi-inbox" style="font-size: 32px; color: var(--muted-soft)" aria-hidden="true" />
            <div>無任何通知</div>
          </div>
        </template>
        <Column header="標題">
          <template #body="{ data }">
            <span class="notif-row-title">{{ data.title }}</span>
          </template>
        </Column>
        <Column header="狀態" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="notif-dot-chip" :class="{ unread: !data.isRead }">
              <span class="notif-dot" aria-hidden="true" />{{ data.isRead ? '已讀' : '未讀' }}
            </span>
          </template>
        </Column>
        <Column header="時間" header-class="notif-time-cell" body-class="notif-time-cell" :style="{ width: '1%' }">
          <template #body="{ data }">{{ data.sub }}</template>
        </Column>
      </DataTable>
    </section>
  </div>
</template>

<style scoped>
.notif-row-title { font-size: 16px; color: var(--color-ink); }
/* 時間欄與狀態欄保持距離 */
.notif-table-panel :deep(.notif-time-cell) { padding-left: 48px; }
.notif-dot-chip { display: inline-flex; align-items: center; gap: 6px; font-size: 14px; color: var(--color-muted); }
.notif-dot-chip .notif-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--color-muted-soft); }
.notif-dot-chip.unread { color: var(--color-primary-700); font-weight: 600; }
.notif-dot-chip.unread .notif-dot { background: var(--color-primary-700); }
.dash-empty-lg { display: flex; flex-direction: column; align-items: center; gap: 10px; }
</style>
