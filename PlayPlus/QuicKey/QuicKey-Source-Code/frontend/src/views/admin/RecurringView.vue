<script setup lang="ts">
/**
 * 固定收支（PRD 規則 17、18；docs/dev/recurring-api.md）。
 * 兩層分頁比照類別管理：固定支出／固定收入 → 進行中／歷史。
 * 列表走伺服器端分頁；垃圾桶模式共用同一組分頁狀態，只有「還原 / 永久刪除」。
 */
import { computed, onMounted, ref, watch } from 'vue'
import type { DataTableRowClickEvent } from 'primevue/datatable'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import Drawer from 'primevue/drawer'
import Menu from 'primevue/menu'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import RecurringTemplateDetail from '@/components/admin/RecurringTemplateDetail.vue'
import RecurringTemplateDialog from '@/components/admin/RecurringTemplateDialog.vue'
import TabBar from '@/components/qds/TabBar.vue'
import {
  deleteRecurringTemplate,
  getRecurringTemplate,
  listRecurringTemplates,
  purgeRecurringTemplate,
  restoreRecurringTemplate,
  type RecurringCounts,
  type RecurringTemplatePage,
  type SavedRecurringTemplate,
} from '@/api/recurring'
import { HttpError } from '@/api/service'
import { useOpenQuery } from '@/composables/useOpenQuery'
import { usePagedList } from '@/composables/usePagedList'
import {
  RECURRING_DIRECTION_LABELS,
  type RecurringDirection,
  type RecurringTemplate,
} from '@/types/domain'
import { formatCurrencyExact, formatDate, formatMonth } from '@/utils/format'
import { categoryBlockedHint, scheduleLabel } from '@/utils/recurring'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import { userErrorToast } from '@/utils/userFeedback'

const confirm = useConfirm()
const toast = useToast()

type StatusTab = 'active' | 'history'

const direction = ref<RecurringDirection>('expense')
const statusTab = ref<StatusTab>('active')
const trashMode = ref(false)

const counts = ref<RecurringCounts | null>(null)

const directionCounts = computed(() => counts.value?.[direction.value])

const directionTabs = computed(() =>
  (['expense', 'income'] as const).map((value) => ({
    value,
    label: RECURRING_DIRECTION_LABELS[value],
    count: trashMode.value ? counts.value?.[value].trash : undefined,
  })),
)
const statusTabs = computed(() => [
  { value: 'active' as StatusTab, label: '進行中', count: directionCounts.value?.active },
  { value: 'history' as StatusTab, label: '歷史', count: directionCounts.value?.history },
])

const {
  rows,
  total,
  page,
  pageSize,
  loading,
  failed: loadFailed,
  refresh,
  reset,
  onPage,
} = usePagedList<RecurringTemplate, RecurringTemplatePage>({
  fetcher: (query) =>
    listRecurringTemplates({
      direction: direction.value,
      tab: trashMode.value ? 'trash' : statusTab.value,
      ...query,
    }),
  failTitle: () => (trashMode.value ? '載入垃圾桶失敗' : '載入範本失敗'),
  onLoaded: (res) => (counts.value = res.meta.counts),
})
onMounted(refresh)

watch([direction, statusTab, trashMode], () => {
  reset()
  void refresh()
})

const emptyText = computed(() => {
  if (loadFailed.value) return trashMode.value ? '垃圾桶載入失敗，請重新整理頁面' : '範本載入失敗，請重新整理頁面'
  if (trashMode.value) return '垃圾桶是空的'
  return statusTab.value === 'active' ? '沒有進行中的範本' : '沒有歷史範本'
})

const showEmptyGuide = computed(
  () =>
    !trashMode.value &&
    !loading.value &&
    !loadFailed.value &&
    !!directionCounts.value &&
    directionCounts.value.active + directionCounts.value.history === 0,
)

// ─── 建立 / 編輯 ─────────────────────────────────
const dialogOpen = ref(false)
const dialogDirection = ref<RecurringDirection>('expense')
const editing = ref<RecurringTemplate | null>(null)

function openCreate(d: RecurringDirection) {
  editing.value = null
  dialogDirection.value = d
  dialogOpen.value = true
}
function openEdit(t: RecurringTemplate) {
  editing.value = t
  dialogDirection.value = t.direction
  dialogOpen.value = true
}

async function onSaved(saved: SavedRecurringTemplate) {
  if (detailId.value === saved.id) detail.value = saved
  // 建立的方向和目前分頁不同時切過去，watcher 會 refetch
  if (saved.direction !== direction.value) direction.value = saved.direction
  else await refresh()
}

// ─── 明細抽屜 ────────────────────────────────────
const detailId = ref<string | null>(null)
const detail = ref<RecurringTemplate | null>(null)
const detailLoading = ref(false)

let detailSeq = 0
watch(detailId, async (id) => {
  const seq = ++detailSeq
  detail.value = null
  if (!id) return
  detailLoading.value = true
  try {
    const t = await getRecurringTemplate(id)
    if (seq !== detailSeq) return
    detail.value = t
    // 從支出、收入詳情連過來時，切到範本所在的分頁
    direction.value = t.direction
    trashMode.value = t.status === 'trash'
    if (t.status !== 'trash') statusTab.value = t.status
  } catch (err) {
    if (seq !== detailSeq) return
    toast.add({ severity: 'error', ...userErrorToast(err, '載入範本失敗'), life: 3500 })
    detailId.value = null
  } finally {
    if (seq === detailSeq) detailLoading.value = false
  }
})
useOpenQuery(detailId)

function onRowClick(evt: DataTableRowClickEvent) {
  detailId.value = (evt.data as RecurringTemplate).id
}

// ─── 移至垃圾桶 ──────────────────────────────────
function confirmDelete(t: RecurringTemplate) {
  confirm.require({
    header: '移至垃圾桶',
    message: `確定要把範本「${t.name}」移至垃圾桶嗎？之後不再產生紀錄，已產生的紀錄不受影響。可在垃圾桶還原。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '移至垃圾桶',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: () => softDelete(t),
  })
}

async function softDelete(t: RecurringTemplate) {
  try {
    await deleteRecurringTemplate(t.id)
    if (detailId.value === t.id) detailId.value = null
    toast.add({ severity: 'success', summary: '已移至垃圾桶', detail: '可從垃圾桶還原', life: 2500 })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '刪除失敗'), life: 3500 })
  }
  await refresh()
}

// ─── 垃圾桶：還原 / 永久刪除 ───────────────────────
/** 列表顯示後類別才進垃圾桶或停用時，後端回 409 */
function isCategoryBlocked(err: unknown): boolean {
  const code = err instanceof HttpError ? (err.body as { error?: string })?.error : undefined
  return code === 'CATEGORY_IN_TRASH' || code === 'CATEGORY_ARCHIVED'
}

async function restoreOne(t: RecurringTemplate) {
  if (!t.restorable) {
    toast.add({ severity: 'warn', summary: '無法還原範本', detail: categoryBlockedHint(t.category), life: 3000 })
    return
  }
  try {
    const restored = await restoreRecurringTemplate(t.id)
    const place = restored.status === 'history' ? '回到歷史' : '回到進行中'
    toast.add({
      severity: 'success',
      summary: '已還原',
      detail: restored.backfilledCount ? `${place}，已產生當期 ${restored.backfilledCount} 筆紀錄` : place,
      life: 2500,
    })
    if (detailId.value === t.id) detailId.value = null
  } catch (err) {
    toast.add({ severity: isCategoryBlocked(err) ? 'warn' : 'error', ...userErrorToast(err, '還原失敗'), life: 3500 })
  }
  await refresh()
}

function confirmPurge(t: RecurringTemplate) {
  confirm.require({
    header: '永久刪除',
    message: `將永久刪除範本「${t.name}」，已產生的紀錄會保留，但不再連回範本。刪除後無法還原。確定嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '永久刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    defaultFocus: 'reject',
    accept: () => purgeOne(t),
  })
}

async function purgeOne(t: RecurringTemplate) {
  try {
    await purgeRecurringTemplate(t.id)
    if (detailId.value === t.id) detailId.value = null
    toast.add({ severity: 'success', summary: '已永久刪除', life: 2500 })
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '永久刪除失敗'), life: 3500 })
  }
  await refresh()
}

// ─── 選單 ────────────────────────────────────────
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = [{ label: '垃圾桶', icon: 'pi pi-trash', command: () => (trashMode.value = true) }]

const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<RecurringTemplate | null>(null)
const rowMenuItems = computed(() => {
  const t = menuTarget.value
  if (!t) return []
  return [
    { label: '查看明細', icon: 'pi pi-eye', command: () => (detailId.value = t.id) },
    { label: '編輯', icon: 'pi pi-pencil', command: () => openEdit(t) },
    { separator: true },
    { label: '移至垃圾桶', icon: 'pi pi-trash', class: 'menu-danger', command: () => confirmDelete(t) },
  ]
})
function openRowMenu(e: MouseEvent, t: RecurringTemplate) {
  menuTarget.value = t
  rowMenu.value?.toggle(e)
}
</script>

<template>
  <div class="dash-page">
    <PageHeader :title="trashMode ? '固定收支垃圾桶' : '固定收支'" size="admin">
      <template #actions>
        <Button v-if="trashMode" label="返回固定收支" icon="pi pi-arrow-left" outlined @click="trashMode = false" />
        <template v-else>
          <Button label="建立固定收入" icon="pi pi-plus" :outlined="direction !== 'income'" @click="openCreate('income')" />
          <Button label="建立固定支出" icon="pi pi-plus" :outlined="direction !== 'expense'" @click="openCreate('expense')" />
          <Button
            v-tooltip.bottom="'更多動作'"
            icon="pi pi-ellipsis-h"
            outlined
            aria-label="更多動作"
            aria-haspopup="true"
            @click="pageMenu?.toggle($event)"
          />
          <Menu ref="pageMenu" :model="pageMenuItems" popup />
        </template>
      </template>
    </PageHeader>

    <TabBar v-model="direction" :tabs="directionTabs" label="收支方向" class="recurring-direction-tabs" />

    <EmptyState
      v-if="showEmptyGuide"
      icon="pi pi-sync"
      :title="`還沒有${RECURRING_DIRECTION_LABELS[direction]}`"
      description="建立範本後，系統會依週期自動產生待收款、待付款紀錄。"
    >
      <template #action>
        <Button :label="`建立${RECURRING_DIRECTION_LABELS[direction]}`" icon="pi pi-plus" @click="openCreate(direction)" />
      </template>
    </EmptyState>

    <section
      v-else
      class="dash-panel dash-table-panel"
      :class="{ 'trash-table-panel': trashMode }"
      :aria-label="trashMode ? '固定收支垃圾桶' : '固定收支範本列表'"
    >
      <div v-if="!trashMode" class="list-head">
        <TabBar v-model="statusTab" :tabs="statusTabs" label="範本狀態" variant="segmented" />
      </div>
      <DataTable
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: trashMode ? '860px' : '940px' }"
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
          <div class="dash-empty">{{ loading ? '' : emptyText }}</div>
        </template>
        <Column header="名稱">
          <template #body="{ data }">
            <div class="cell-trunc" :title="data.name">{{ data.name }}</div>
            <div class="cell-sub" :title="data.counterparty">{{ data.counterparty }}</div>
          </template>
        </Column>
        <Column header="類別">
          <template #body="{ data }">
            {{ data.category.name }}
            <div v-if="data.category.deletedAt" class="cell-sub">在垃圾桶</div>
            <div v-else-if="data.category.isArchived" class="cell-sub">已停用</div>
          </template>
        </Column>
        <Column v-if="!trashMode" header="帳戶">
          <template #body="{ data }">{{ data.account.name }}</template>
        </Column>
        <Column header="金額" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrencyExact(data.amount) }}</template>
        </Column>
        <Column header="週期">
          <template #body="{ data }"><span class="whitespace-nowrap">{{ scheduleLabel(data) }}</span></template>
        </Column>
        <Column v-if="!trashMode" header="開始月份">
          <template #body="{ data }"><span class="tabular-nums">{{ formatMonth(data.startMonth) }}</span></template>
        </Column>
        <Column v-if="!trashMode" header="結束月份">
          <template #body="{ data }">
            <span class="tabular-nums">{{ data.endMonth ? formatMonth(data.endMonth) : '持續' }}</span>
          </template>
        </Column>
        <Column v-if="!trashMode" header="已產生到">
          <template #body="{ data }">
            <span class="tabular-nums whitespace-nowrap">{{ data.lastGeneratedPeriod ? formatMonth(data.lastGeneratedPeriod) : '尚未產生' }}</span>
          </template>
        </Column>
        <Column v-if="trashMode" header="刪除時間" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="tabular-nums whitespace-nowrap">{{ data.deletedAt ? formatDate(data.deletedAt) : '—' }}</span>
          </template>
        </Column>
        <Column v-if="trashMode" header="操作人" :style="{ width: '1%' }">
          <template #body="{ data }"><span class="whitespace-nowrap">{{ data.deletedBy?.name ?? '—' }}</span></template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <div v-if="trashMode" class="flex gap-1 justify-end">
              <Button label="還原" icon="pi pi-undo" text size="small" @click.stop="restoreOne(data as RecurringTemplate)" />
              <Button
                label="永久刪除"
                icon="pi pi-trash"
                text
                size="small"
                severity="danger"
                @click.stop="confirmPurge(data as RecurringTemplate)"
              />
            </div>
            <Button v-else icon="pi pi-ellipsis-h" text rounded severity="secondary" class="row-more" :aria-label="`${data.name} 更多動作`" aria-haspopup="true" @click.stop="openRowMenu($event, data as RecurringTemplate)" />
          </template>
        </Column>
      </DataTable>
    </section>

    <Drawer
      :visible="detailId !== null"
      position="right"
      class="!w-full sm:!w-[560px]"
      @update:visible="(v: boolean) => { if (!v) detailId = null }"
    >
      <template #header>
        <div class="q-drawer-head">
          <span>範本明細</span>
          <span v-if="detail?.status === 'trash'" class="tag-soft tag-neutral">垃圾桶</span>
          <span v-else-if="detail" class="tag-soft" :class="{ 'tag-neutral': detail.status === 'history' }">
            {{ detail.status === 'history' ? '歷史' : '進行中' }}
          </span>
        </div>
      </template>
      <div v-if="detailLoading" class="dash-empty"><i class="pi pi-spin pi-spinner" aria-hidden="true" />&nbsp;載入中…</div>
      <RecurringTemplateDetail v-else-if="detail" :key="detail.updatedAt" :template="detail" />
      <template v-if="detail" #footer>
        <div class="q-drawer-foot">
          <template v-if="detail.status === 'trash'">
            <Button label="永久刪除" severity="danger" text @click="confirmPurge(detail)" />
            <span class="q-gap" />
            <Button label="還原" @click="restoreOne(detail)" />
          </template>
          <template v-else>
            <Button label="移至垃圾桶" severity="danger" text @click="confirmDelete(detail)" />
            <span class="q-gap" />
            <Button label="編輯" @click="openEdit(detail)" />
          </template>
        </div>
      </template>
    </Drawer>

    <RecurringTemplateDialog
      v-model:visible="dialogOpen"
      :direction="dialogDirection"
      :template="editing"
      @saved="onSaved"
    />

    <Menu ref="rowMenu" :model="rowMenuItems" popup />
  </div>
</template>

<style scoped>
.recurring-direction-tabs { margin-bottom: 0.75rem; }
</style>
