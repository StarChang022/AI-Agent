<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import type { Category, CategoryKind } from '@/types/domain'
import {
  listCategories,
  createCategory,
  updateCategory,
  archiveCategory,
  unarchiveCategory,
  reorderCategories,
  type CategoryWithUsage,
} from '@/api/categories'
import { HttpError } from '@/api/service'
import PageHeader from '@/components/PageHeader.vue'
import EmptyState from '@/components/EmptyState.vue'
import Button from 'primevue/button'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import Dialog from 'primevue/dialog'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Menu from 'primevue/menu'
import TabBar from '@/components/qds/TabBar.vue'
import SearchInput from '@/components/qds/SearchInput.vue'
import { ACCOUNT_SUBJECTS, accountSubjectLabel } from '@/constants/accountSubjects'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'

const confirm = useConfirm()
const toast = useToast()

// 兩種 kind 的使用中 / 已停用清單分開存；切 tab 時各自 fetch 一次。
type KindTab = CategoryKind
type ArchiveTab = 'active' | 'archived'

const activeKind = ref<KindTab>('expense')
const activeArchive = ref<ArchiveTab>('active')
const keyword = ref('')

const activeList = ref<CategoryWithUsage[]>([])
const archivedList = ref<CategoryWithUsage[]>([])
const loading = ref(false)

const kindTabs = computed(() => [
  { value: 'expense' as KindTab, label: '支出類別' },
  { value: 'income' as KindTab, label: '收入類別' },
])

const archiveTabs = computed(() => [
  { value: 'active' as ArchiveTab, label: '使用中', count: activeList.value.length },
  { value: 'archived' as ArchiveTab, label: '已停用', count: archivedList.value.length },
])

async function refreshLists() {
  loading.value = true
  try {
    const [active, archived] = await Promise.all([
      listCategories({ kind: activeKind.value, includeUsage: true }),
      listCategories({ kind: activeKind.value, archived: true, includeUsage: true }),
    ])
    activeList.value = active
    archivedList.value = archived
  } catch (err) {
    toast.add({ severity: 'error', summary: '載入類別失敗', detail: errorMessage(err), life: 3000 })
  } finally {
    loading.value = false
  }
}

onMounted(refreshLists)
watch(activeKind, () => {
  activeArchive.value = 'active'
  keyword.value = ''
  refreshLists()
})

// ─── 排序 ───
// 1. 自訂順序（拖曳）：決定全站下拉選單、預算列表等的先後，只在「使用中」、沒搜尋、沒點欄位排序時可拖
// 2. 欄位排序（點標題）：暫時換個方式看，不會存；再點到第三次回到自訂順序
const sortField = ref<string | undefined>(undefined)
const sortOrder = ref<number | undefined>(undefined)
const canReorder = computed(
  () => activeArchive.value === 'active' && !keyword.value.trim() && !sortField.value,
)

const visibleList = computed<CategoryWithUsage[]>(() => {
  const src = activeArchive.value === 'active' ? activeList.value : archivedList.value
  const kw = keyword.value.trim().toLowerCase()
  if (!kw) return src
  return src.filter(
    (c) =>
      c.name.toLowerCase().includes(kw) ||
      accountSubjectLabel(c.accountCode).toLowerCase().includes(kw),
  )
})

const tableRows = computed(() =>
  visibleList.value.map((c) => ({ ...c, usage: c.usageCount ?? 0 })),
)

async function onRowReorder(e: { value: CategoryWithUsage[] }) {
  const ids = e.value.map((c) => c.id)
  const prev = activeList.value
  // 樂觀更新：先畫出新順序，失敗再 refetch
  activeList.value = e.value
  try {
    const next = await reorderCategories(ids)
    // 回傳的清單不含 usageCount，用原有的 usageCount 填回
    const usageMap = new Map(prev.map((c) => [c.id, c.usageCount ?? 0]))
    activeList.value = next.map((c) => ({ ...c, usageCount: usageMap.get(c.id) ?? 0 }))
    toast.add({
      severity: 'success',
      summary: '已更新類別順序',
      detail: '新增支出、代墊款的類別選單與預算列表會依此順序顯示',
      life: 2500,
    })
  } catch (err) {
    toast.add({ severity: 'error', summary: '排序失敗', detail: errorMessage(err), life: 3000 })
    await refreshLists()
  }
}

// ─── Add / Edit Dialog ───────────────────────────
type DialogMode = 'create' | 'edit' | null
const dialogMode = ref<DialogMode>(null)
const editingId = ref<string | null>(null)
const editingUsage = ref(0)

interface FormState {
  kind: CategoryKind
  name: string
  accountCode: string
}
const form = reactive<FormState>({ kind: 'expense', name: '', accountCode: '' })

const kindOptions = [
  { value: 'expense' as CategoryKind, label: '支出類別' },
  { value: 'income' as CategoryKind, label: '收入類別' },
]
const formError = ref('')
const submitting = ref(false)

/** 會計科目下拉（可輸入關鍵字搜尋代碼或名稱）；編輯時若是清單外的舊代碼，保留為選項 */
const subjectOptions = computed(() => {
  const list = ACCOUNT_SUBJECTS.map((s) => ({ value: s.code, label: `${s.code} ${s.name}` }))
  const cur = form.accountCode
  if (cur && !ACCOUNT_SUBJECTS.some((s) => s.code === cur)) list.push({ value: cur, label: cur })
  return list
})

// ─── 每列 ⋯ 選單 ───
const rowMenu = ref<InstanceType<typeof Menu> | null>(null)
const menuTarget = ref<Category | null>(null)
const rowMenuItems = computed(() => {
  const c = menuTarget.value
  if (!c) return []
  return [
    c.isArchived
      ? { label: '啟用', icon: 'pi pi-replay', command: () => unarchive(c) }
      : { label: '停用', icon: 'pi pi-ban', command: () => archive(c) },
  ]
})
function openRowMenu(e: MouseEvent, c: Category) {
  menuTarget.value = c
  rowMenu.value?.toggle(e)
}

// 編輯沿用該類別原本 kind（kind 不可改）；新增預設帶目前所在的 tab，可改。
const dialogTitle = computed(() => {
  if (dialogMode.value === 'edit') {
    return `編輯${form.kind === 'expense' ? '支出' : '收入'}類別`
  }
  return '新增類別'
})

function openCreate() {
  dialogMode.value = 'create'
  editingId.value = null
  editingUsage.value = 0
  form.kind = activeKind.value
  form.name = ''
  form.accountCode = ''
  formError.value = ''
}

function openEdit(c: CategoryWithUsage) {
  dialogMode.value = 'edit'
  editingId.value = c.id
  editingUsage.value = c.usageCount ?? 0
  form.kind = c.kind
  form.name = c.name
  form.accountCode = c.accountCode
  formError.value = ''
}

function closeDialog() {
  dialogMode.value = null
  editingId.value = null
  formError.value = ''
}

async function submitDialog() {
  const name = form.name.trim()
  // show-clear 清除時會變成 null
  const accountCode = (form.accountCode ?? '').trim()
  if (!name) {
    formError.value = '請填寫類別名稱'
    return
  }
  if (submitting.value) return
  submitting.value = true
  try {
    if (dialogMode.value === 'create') {
      await createCategory({ kind: form.kind, name, accountCode })
      toast.add({ severity: 'success', summary: '已新增類別', detail: name, life: 2500 })
      closeDialog()
      // 若在支出 tab 新增一個收入類別，切 tab 過去（watcher 會跟著 refetch），
      // 否則維持原 tab 自己 refetch。
      if (form.kind !== activeKind.value) activeKind.value = form.kind
      else await refreshLists()
    } else if (dialogMode.value === 'edit' && editingId.value) {
      await updateCategory(editingId.value, { name, accountCode })
      toast.add({ severity: 'success', summary: '已更新類別', detail: name, life: 2500 })
      closeDialog()
      await refreshLists()
    }
  } catch (err) {
    if (err instanceof HttpError && (err.body as { error?: string })?.error === 'DUPLICATE_NAME') {
      formError.value = '已有同名類別'
    } else {
      formError.value = errorMessage(err)
    }
  } finally {
    submitting.value = false
  }
}

// ─── Archive / Unarchive ─────────────────
function archive(c: Category) {
  confirm.require({
    message: `確定要停用「${c.name}」？停用後：不會出現在新增${activeKind.value === 'expense' ? '支出/請款' : '收入'}的下拉選單；該類別的基本預算與當期/未來預算會被清除（過往期間保留）；既有紀錄仍會保留類別名稱。`,
    header: '停用類別',
    acceptLabel: '確認停用',
    rejectLabel: '取消',
    acceptProps: { severity: 'warn' } as unknown as Record<string, unknown>,
    accept: async () => {
      try {
        await archiveCategory(c.id)
        toast.add({ severity: 'success', summary: '已停用', detail: c.name, life: 2500 })
        await refreshLists()
      } catch (err) {
        toast.add({ severity: 'error', summary: '停用失敗', detail: errorMessage(err), life: 3000 })
      }
    },
  })
}

async function unarchive(c: Category) {
  try {
    await unarchiveCategory(c.id)
    toast.add({ severity: 'success', summary: '已解除停用', detail: c.name, life: 2500 })
    await refreshLists()
  } catch (err) {
    toast.add({ severity: 'error', summary: '操作失敗', detail: errorMessage(err), life: 3000 })
  }
}

function errorMessage(err: unknown): string {
  if (err instanceof HttpError) return (err.body as { error?: string })?.error ?? err.message
  if (err instanceof Error) return err.message
  return String(err)
}
</script>

<template>
  <div class="dash-page">
    <PageHeader title="類別管理" size="admin">
      <template #actions>
        <Button label="新增類別" icon="pi pi-plus" data-tour="categories-add-button" @click="openCreate" />
      </template>
    </PageHeader>

    <TabBar v-model="activeKind" :tabs="kindTabs" label="類別種類" class="categories-kind-tabs" />

    <section class="dash-panel dash-table-panel" aria-label="類別列表">
      <div class="list-head list-head-stacked">
        <TabBar v-model="activeArchive" :tabs="archiveTabs" label="類別狀態" variant="segmented" />
        <div class="list-head-tools">
          <SearchInput v-model="keyword" placeholder="搜尋類別或會計科目" />
        </div>
      </div>
      <DataTable
        v-model:sort-field="sortField"
        v-model:sort-order="sortOrder"
        :value="tableRows"
        :loading="loading"
        data-key="id"
        row-hover
        removable-sort
        @row-reorder="onRowReorder"
      >
        <template #empty>
          <EmptyState
            variant="plain"
            icon="pi pi-tags"
            :title="keyword.trim() ? '沒有符合條件的類別' : activeArchive === 'active' ? '還沒有使用中的類別' : '沒有停用的類別'"
          />
        </template>
        <!-- 用 row-reorder-icon（不用自訂 slot），PrimeVue 才會在把手上掛 data-pc-section，按住才能拖曳 -->
        <Column v-if="canReorder" row-reorder row-reorder-icon="pi pi-bars" header-class="reorder-col" body-class="reorder-col" :style="{ width: '48px' }" />
        <Column header="類別名稱" field="name">
          <template #body="{ data }"><span :class="{ 'text-[var(--color-muted)]': data.isArchived }">{{ data.name }}</span></template>
        </Column>
        <Column header="會計科目" field="accountCode" sortable>
          <template #body="{ data }">
            <span v-if="data.accountCode" class="tabular-nums">{{ accountSubjectLabel(data.accountCode) }}</span>
            <span v-else class="cell-sub">未設定</span>
          </template>
        </Column>
        <Column header="使用筆數" field="usage" sortable header-class="num" body-class="num">
          <template #body="{ data }">{{ data.usage }}</template>
        </Column>
        <Column header-class="act" body-class="act">
          <template #header><span class="sr-only">操作</span></template>
          <template #body="{ data }">
            <span class="row-actions">
              <!-- 已停用的類別不提供編輯；需要修改請先啟用（⋯ → 啟用） -->
              <Button v-if="!data.isArchived" icon="pi pi-pencil" outlined size="small" :aria-label="`編輯 ${data.name}`" v-tooltip.top="'編輯'" @click="openEdit(data)" />
              <Button icon="pi pi-ellipsis-h" outlined size="small" aria-label="更多動作" aria-haspopup="true" v-tooltip.top="'更多動作'" @click="openRowMenu($event, data)" />
            </span>
          </template>
        </Column>
      </DataTable>
      <div class="dash-table-summary">{{ visibleList.length }} 個類別</div>
    </section>

    <Dialog :visible="dialogMode !== null" modal :header="dialogTitle" :style="{ width: 'min(92vw, 440px)' }" @update:visible="closeDialog">
      <form class="flex flex-col gap-4" @submit.prevent="submitDialog">
        <div v-if="dialogMode === 'create'" class="q-field">
          <label for="cat-kind">類別種類 <span class="req">*</span></label>
          <Select
            v-model="form.kind"
            input-id="cat-kind"
            :options="kindOptions"
            option-label="label"
            option-value="value"
            fluid
          />
        </div>
        <div class="q-field">
          <label for="cat-name">類別名稱 <span class="req">*</span></label>
          <InputText id="cat-name" v-model="form.name" placeholder="例如：計程車資、Q3 行銷活動" maxlength="50" autofocus :invalid="!!formError" @input="formError = ''" />
          <span v-if="formError" class="q-error"><i class="pi pi-exclamation-circle" aria-hidden="true" />{{ formError }}</span>
        </div>
        <div class="q-field">
          <label for="cat-subject">會計科目（選填）</label>
          <Select
            v-model="form.accountCode"
            input-id="cat-subject"
            :options="subjectOptions"
            option-label="label"
            option-value="value"
            filter
            auto-filter-focus
            reset-filter-on-hide
            filter-placeholder="輸入代碼或名稱搜尋"
            placeholder="請選擇會計科目"
            empty-filter-message="找不到符合的科目"
            show-clear
            fluid
          />
        </div>
        <p v-if="dialogMode === 'edit' && editingUsage > 0" class="dash-dialog-text">這個類別已被 {{ editingUsage }} 筆紀錄使用，改名後舊紀錄會顯示新名稱。</p>
        <button type="submit" class="hidden" />
      </form>
      <template #footer>
        <Button label="取消" outlined @click="closeDialog" />
        <Button label="儲存" :loading="submitting" @click="submitDialog" />
      </template>
    </Dialog>

    <Menu ref="rowMenu" :model="rowMenuItems" popup />
  </div>
</template>

<style scoped>
.categories-kind-tabs { margin-bottom: 0.75rem; }
.categories-kind-tabs :deep(.tabbar) { align-self: flex-start; }

/* 手機：tab 一行、搜尋另一行；桌機（>=640px）：同一行，tab 左、搜尋右 */
.list-head-stacked { flex-direction: column; align-items: stretch; gap: 0.75rem; }
.list-head-stacked > :deep(.q-tabbar) { align-self: flex-start; }
@media (min-width: 640px) {
  .list-head-stacked { flex-direction: row; align-items: center; gap: 12px 24px; }
  .list-head-stacked > :deep(.q-tabbar) { align-self: auto; }
  .list-head-stacked .list-head-tools { margin-left: auto; }
}

:deep(.p-datatable-reorderable-row-handle) { color: var(--color-muted); cursor: grab; }
:deep(.p-datatable-reorderable-row-handle:hover) { color: var(--color-ink); }
:deep(.p-datatable-tbody > tr.p-datatable-dragpoint-bottom > td) { box-shadow: inset 0 -2px 0 var(--color-primary-700, #0f766e); }
:deep(.p-datatable-tbody > tr.p-datatable-dragpoint-top > td) { box-shadow: inset 0 2px 0 var(--color-primary-700, #0f766e); }
</style>
