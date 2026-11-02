<script setup lang="ts">
/**
 * 帳戶設定（docs/資料模型.md §2.9、PRD 規則 18、20、21）。
 * 列表走伺服器端分頁；垃圾桶模式共用同一組分頁狀態，只有「還原 / 永久刪除」。
 */
import { computed, onMounted, ref } from 'vue'
import type { DataTablePageEvent } from 'primevue/datatable'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import Dialog from 'primevue/dialog'
import Menu from 'primevue/menu'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import AccountFormDialog from '@/components/admin/AccountFormDialog.vue'
import AuditLogList from '@/components/admin/AuditLogList.vue'
import {
  deleteAccount,
  listAccounts,
  listTrashedAccounts,
  purgeAccount,
  restoreAccount,
} from '@/api/accounts'
import { HttpError } from '@/api/service'
import { ACCOUNT_TYPE_LABELS, type Account } from '@/types/domain'
import { formatCurrencyExact, formatDate, formatMonth } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import { describeReferences, userErrorToast } from '@/utils/userFeedback'

const confirm = useConfirm()
const toast = useToast()

const rows = ref<Account[]>([])
const total = ref(0)
const page = ref(1)
const pageSize = ref(10)
const loading = ref(true)
const loadFailed = ref(false)
const trashMode = ref(false)

let fetchSeq = 0
async function refresh() {
  const seq = ++fetchSeq
  loading.value = true
  try {
    const query = { page: page.value, perPage: pageSize.value }
    const res = trashMode.value ? await listTrashedAccounts(query) : await listAccounts(query)
    if (seq !== fetchSeq) return
    // 刪掉最後一頁唯一的一筆後回到上一頁
    if (res.data.length === 0 && page.value > 1) {
      page.value -= 1
      await refresh()
      return
    }
    rows.value = res.data
    total.value = res.meta.total
    loadFailed.value = false
  } catch (err) {
    if (seq !== fetchSeq) return
    loadFailed.value = true
    rows.value = []
    total.value = 0
    toast.add({
      severity: 'error',
      ...userErrorToast(err, trashMode.value ? '載入垃圾桶失敗' : '載入帳戶失敗'),
      life: 3500,
    })
  } finally {
    if (seq === fetchSeq) loading.value = false
  }
}
onMounted(refresh)

function onPage(evt: DataTablePageEvent) {
  page.value = evt.page + 1
  pageSize.value = evt.rows
  void refresh()
}

function setTrashMode(on: boolean) {
  trashMode.value = on
  page.value = 1
  rows.value = []
  total.value = 0
  void refresh()
}

// ─── 新增 / 編輯 ─────────────────────────────────
const dialogOpen = ref(false)
const editing = ref<Account | null>(null)

function openCreate() {
  editing.value = null
  dialogOpen.value = true
}
function openEdit(a: Account) {
  editing.value = a
  dialogOpen.value = true
}

// ─── 移至垃圾桶 ──────────────────────────────────
/** 例：已有 3 筆支出、2 筆收入使用這個帳戶（含垃圾桶內的紀錄）。 */
function inUseReason(references: Record<string, number>): string {
  return `已有 ${describeReferences(references)}使用這個帳戶（含垃圾桶內的紀錄）。`
}

function confirmDelete(a: Account) {
  if (!a.deletable) {
    toast.add({ severity: 'warn', summary: '帳戶已被使用，無法刪除', detail: inUseReason(a.references), life: 3000 })
    return
  }
  confirm.require({
    header: '移至垃圾桶',
    message: `確定要把帳戶「${a.name}」移至垃圾桶嗎？可在垃圾桶還原。`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '移至垃圾桶',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: () => softDelete(a),
  })
}

/** 列表顯示後才被引用時，後端回 409 ACCOUNT_IN_USE */
function isInUse(err: unknown): boolean {
  return err instanceof HttpError && (err.body as { error?: string })?.error === 'ACCOUNT_IN_USE'
}

async function softDelete(a: Account) {
  try {
    await deleteAccount(a.id)
    toast.add({ severity: 'success', summary: '已移至垃圾桶', detail: '可從垃圾桶還原', life: 2500 })
  } catch (err) {
    toast.add({ severity: isInUse(err) ? 'warn' : 'error', ...userErrorToast(err, '刪除失敗'), life: 3500 })
  }
  await refresh()
}

// ─── 垃圾桶：還原 / 永久刪除 ───────────────────────
async function restoreOne(a: Account) {
  try {
    await restoreAccount(a.id)
    toast.add({ severity: 'success', summary: '已還原', detail: '回到帳戶列表', life: 2500 })
    await refresh()
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '還原失敗'), life: 3500 })
  }
}

function confirmPurge(a: Account) {
  confirm.require({
    header: '永久刪除',
    message: `將永久刪除帳戶「${a.name}」，刪除後無法還原。確定嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '永久刪除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    defaultFocus: 'reject',
    accept: () => purgeOne(a),
  })
}

async function purgeOne(a: Account) {
  try {
    await purgeAccount(a.id)
    toast.add({ severity: 'success', summary: '已永久刪除', life: 2500 })
  } catch (err) {
    toast.add({ severity: isInUse(err) ? 'warn' : 'error', ...userErrorToast(err, '永久刪除失敗'), life: 3500 })
  }
  await refresh()
}

// ─── 歷程 ────────────────────────────────────────
const historyTarget = ref<Account | null>(null)

// ─── 選單 ────────────────────────────────────────
const pageMenu = ref<InstanceType<typeof Menu> | null>(null)
const pageMenuItems = [{ label: '垃圾桶', icon: 'pi pi-trash', command: () => setTrashMode(true) }]

const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<Account | null>(null)
const rowMenuItems = computed(() => {
  const a = menuTarget.value
  if (!a) return []
  return [
    { label: '查看歷程', icon: 'pi pi-history', command: () => (historyTarget.value = a) },
    { separator: true },
    { label: '移至垃圾桶', icon: 'pi pi-trash', class: 'menu-danger', command: () => confirmDelete(a) },
  ]
})
function openRowMenu(e: MouseEvent, a: Account) {
  menuTarget.value = a
  rowMenu.value?.toggle(e)
}

const showEmptyGuide = computed(
  () => !trashMode.value && !loading.value && !loadFailed.value && total.value === 0,
)
</script>

<template>
  <div class="dash-page" data-tour="accounts-page">
    <PageHeader :title="trashMode ? '帳戶垃圾桶' : '帳戶設定'" size="admin">
      <template #actions>
        <Button v-if="trashMode" label="返回帳戶列表" icon="pi pi-arrow-left" outlined @click="setTrashMode(false)" />
        <template v-else>
          <Button label="新增帳戶" icon="pi pi-plus" @click="openCreate" />
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

    <EmptyState
      v-if="showEmptyGuide"
      icon="pi pi-wallet"
      title="還沒有帳戶"
      description="新增銀行帳戶或現金帳戶後，才能登錄收入與支出。"
    >
      <template #action>
        <Button label="新增帳戶" icon="pi pi-plus" @click="openCreate" />
      </template>
    </EmptyState>

    <!-- 垃圾桶模式：獨立 table，只有「還原 / 永久刪除」 -->
    <section v-else-if="trashMode" class="dash-panel dash-table-panel trash-table-panel" aria-label="帳戶垃圾桶">
      <DataTable
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '840px' }"
        lazy
        paginator
        :first="(page - 1) * pageSize"
        :rows="pageSize"
        :total-records="total"
        :loading="loading"
        :rows-per-page-options="ROWS_OPTIONS"
        :paginator-template="PAGINATOR_TEMPLATE"
        :current-page-report-template="PAGE_REPORT"
        @page="onPage"
      >
        <template #empty>
          <div class="dash-empty">{{ loadFailed ? '垃圾桶載入失敗，請重新整理頁面' : '垃圾桶是空的' }}</div>
        </template>
        <Column header="帳戶名稱" field="name" />
        <Column header="類型">
          <template #body="{ data }">{{ ACCOUNT_TYPE_LABELS[(data as Account).accountType] }}</template>
        </Column>
        <Column header="起始金額" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrencyExact(data.openingAmount) }}</template>
        </Column>
        <Column header="起始月份">
          <template #body="{ data }"><span class="tabular-nums">{{ formatMonth(data.openingMonth) }}</span></template>
        </Column>
        <Column header="刪除時間" :style="{ width: '1%' }">
          <template #body="{ data }">
            <span class="tabular-nums whitespace-nowrap">{{ data.deletedAt ? formatDate(data.deletedAt) : '—' }}</span>
          </template>
        </Column>
        <Column header="操作人" :style="{ width: '1%' }">
          <template #body="{ data }"><span class="whitespace-nowrap">{{ data.deletedBy?.name ?? '—' }}</span></template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <div class="flex gap-1 justify-end">
              <Button label="還原" icon="pi pi-undo" text size="small" @click="restoreOne(data as Account)" />
              <Button
                label="永久刪除"
                icon="pi pi-trash"
                text
                size="small"
                severity="danger"
                @click="confirmPurge(data as Account)"
              />
            </div>
          </template>
        </Column>
      </DataTable>
    </section>

    <section v-else class="dash-panel dash-table-panel" aria-label="帳戶列表">
      <DataTable
        :value="rows"
        data-key="id"
        :table-style="{ width: '100%', minWidth: '640px' }"
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
        @page="onPage"
      >
        <template #empty>
          <div class="dash-empty">帳戶載入失敗，請重新整理頁面</div>
        </template>
        <Column header="帳戶名稱" field="name" />
        <Column header="類型">
          <template #body="{ data }">{{ ACCOUNT_TYPE_LABELS[(data as Account).accountType] }}</template>
        </Column>
        <Column header="起始金額" header-class="num" body-class="num">
          <template #body="{ data }">{{ formatCurrencyExact(data.openingAmount) }}</template>
        </Column>
        <Column header="起始月份">
          <template #body="{ data }"><span class="tabular-nums">{{ formatMonth(data.openingMonth) }}</span></template>
        </Column>
        <Column header-class="act" body-class="act" :style="{ width: '1%' }">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <span class="row-actions">
              <Button v-tooltip.top="'編輯'" icon="pi pi-pencil" outlined size="small" :aria-label="`編輯 ${data.name}`" @click="openEdit(data as Account)" />
              <Button v-tooltip.top="'更多動作'" icon="pi pi-ellipsis-h" outlined size="small" aria-label="更多動作" aria-haspopup="true" @click="openRowMenu($event, data as Account)" />
            </span>
          </template>
        </Column>
      </DataTable>
    </section>

    <AccountFormDialog v-model:visible="dialogOpen" :account="editing" @saved="refresh" />

    <Dialog
      :visible="historyTarget !== null"
      modal
      :header="historyTarget ? `${historyTarget.name} 的歷程` : ''"
      :style="{ width: 'min(92vw, 560px)' }"
      @update:visible="historyTarget = null"
    >
      <AuditLogList v-if="historyTarget" target-type="account" :target-id="historyTarget.id" default-open />
    </Dialog>

    <Menu ref="rowMenu" :model="rowMenuItems" popup />
  </div>
</template>
