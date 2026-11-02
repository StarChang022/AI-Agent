<script setup lang="ts">
/**
 * Excel 匯入視窗（支出／收入共用）。對應 docs/資料模型.md §5.4。
 *
 * 流程：下載範本（選用）→ 上傳 .xlsx（選檔後自動預覽）→ 預覽表 + 類別對應
 *      →「匯入 N 筆」整批建立 → 完成畫面（成功筆數、未匯入的列、需留意的列）。
 * 匯入成功即 emit `imported`，由列表頁重撈；完成畫面關閉後不保留清單。
 */
import { computed, nextTick, ref, watch } from 'vue'
import type { DataTablePageEvent } from 'primevue/datatable'
import {
  IMPORT_REPREVIEW_CODES,
  downloadImportTemplate,
  previewImport,
  runImport,
  type AccountMapping,
  type CategoryMapping,
  type ImportCategoryIssue,
  type ImportKind,
  type ImportMessage,
  type ImportPreviewRecord,
  type ImportPreviewResponse,
  type ImportRecordStatus,
  type ImportResult,
} from '@/api/imports'
import { listCategories, type Category } from '@/api/categories'
import { useAccountOptions } from '@/composables/useAccountOptions'
import { HttpError } from '@/api/service'
import { formatCurrency, formatDate } from '@/utils/format'
import { PAGE_REPORT, PAGINATOR_TEMPLATE, ROWS_OPTIONS } from '@/utils/table'
import { userErrorToast } from '@/utils/userFeedback'
import Button from 'primevue/button'
import Checkbox from 'primevue/checkbox'
import Column from 'primevue/column'
import DataTable from 'primevue/datatable'
import Dialog from 'primevue/dialog'
import Message from 'primevue/message'
import Paginator, { type PageState } from 'primevue/paginator'
import Select from 'primevue/select'
import { useToast } from 'primevue/usetoast'

const props = defineProps<{ visible: boolean; kind: ImportKind }>()
const emit = defineEmits<{ 'update:visible': [boolean]; imported: [] }>()

const toast = useToast()

const MAX_FILE_MB = 5
const MAX_ROWS = 1000

const KIND_TEXT = {
  expense: { title: '匯入支出 Excel', date: '日期', counterparty: '廠商' },
  income: { title: '匯入收入 Excel', date: '開立日', counterparty: '客戶' },
} as const
const text = computed(() => KIND_TEXT[props.kind])

const STATUS_META: Record<ImportRecordStatus, { label: string; tag: string }> = {
  ok: { label: '可匯入', tag: 'tag-success' },
  warning: { label: '補預設值', tag: 'tag-warn' },
  skipped: { label: '不匯入', tag: 'tag-danger' },
}
const OUTSIDE_CASH_FLOW_META = { label: '不計入現金流', tag: 'tag-warn' }

/** 收付款日早於起始月份不算補值，標「不計入現金流」；同一列兩者都有時兩個標籤都顯示 */
function statusTags(r: ImportPreviewRecord) {
  if (!r.summary.outsideCashFlow) return [STATUS_META[r.status]]
  // 不計入現金流本身佔一則訊息，多出來的就是補值
  return r.messages.length > 1 ? [OUTSIDE_CASH_FLOW_META, STATUS_META.warning] : [OUTSIDE_CASH_FLOW_META]
}

type Step = 'upload' | 'preview' | 'done'
const step = ref<Step>('upload')
const file = ref<File | null>(null)
const isDragging = ref(false)
const previewing = ref(false)
const importing = ref(false)
const downloading = ref(false)
/** 上傳步驟的錯誤（格式／大小不符、整份退回） */
const fileError = ref('')
/** 匯入時預覽已過期（類別已變更、移除的列對不上）→ 顯示原因並要求重新預覽 */
const repreviewMessage = ref('')
const preview = ref<ImportPreviewResponse | null>(null)
const result = ref<ImportResult | null>(null)
const categories = ref<Category[]>([])
const categoriesLoading = ref(false)
const categoriesFailed = ref(false)
const { options: accountOptions, loading: accountsLoading, load: loadAccounts } = useAccountOptions()
/** 預覽請求序號：關閉或重新選檔後，晚到的舊回應直接丟棄 */
let previewSeq = 0
const onlyIssues = ref(false)
/** 預覽時使用者移除的單據，以第一列 Excel 列號識別（= 送給後端的 excluded_rows） */
const excluded = ref<Set<number>>(new Set())
/** 讀屏播報移除動作 */
const removeNotice = ref('')
const tableFirst = ref(0)
const tableRows = ref(10)

// ─── 開關 ─────────────────────────────────────────
function reset() {
  previewSeq += 1
  step.value = 'upload'
  file.value = null
  isDragging.value = false
  previewing.value = false
  importing.value = false
  fileError.value = ''
  repreviewMessage.value = ''
  preview.value = null
  result.value = null
  mapping.value = {}
  accountMapping.value = {}
  excluded.value = new Set()
  removeNotice.value = ''
  onlyIssues.value = false
  tableFirst.value = 0
}

watch(
  () => props.visible,
  (v) => {
    if (v) {
      loadCategories()
      loadAccounts()
    } else {
      reset()
    }
  },
)

async function loadCategories() {
  categoriesLoading.value = true
  categoriesFailed.value = false
  try {
    categories.value = await listCategories({ kind: props.kind })
  } catch {
    categories.value = []
    categoriesFailed.value = true
  } finally {
    categoriesLoading.value = false
  }
}

function close() {
  if (importing.value) return
  emit('update:visible', false)
}

// ─── 範本 ─────────────────────────────────────────
async function downloadTemplate() {
  downloading.value = true
  try {
    await downloadImportTemplate(props.kind)
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, '範本下載失敗'), life: 3500 })
  } finally {
    downloading.value = false
  }
}

// ─── 上傳 + 預覽 ───────────────────────────────────
const fileSizeText = computed(() => {
  if (!file.value) return ''
  const kb = file.value.size / 1024
  return kb < 1024 ? `${kb.toFixed(1)} KB` : `${(kb / 1024).toFixed(2)} MB`
})

function validateFile(f: File): string {
  if (!f.name.toLowerCase().endsWith('.xlsx')) return '只支援 .xlsx 檔，請使用範本或另存為 Excel 活頁簿。'
  if (f.size > MAX_FILE_MB * 1024 * 1024) return `檔案超過 ${MAX_FILE_MB} MB，請分批匯入。`
  return ''
}

function onFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  const f = target.files?.[0]
  target.value = ''
  if (f) pickFile(f)
}

function onDrop(event: DragEvent) {
  isDragging.value = false
  const f = event.dataTransfer?.files?.[0]
  if (f) pickFile(f)
}

function pickFile(f: File) {
  if (previewing.value) return
  const err = validateFile(f)
  if (err) {
    fileError.value = err
    return
  }
  file.value = f
  runPreview()
}

/** 錯誤說明：檔案太大、連線、系統錯誤分開講，其餘用後端回的中文說明 */
function errorDetail(err: unknown, fallback: string): string {
  if (err instanceof HttpError) {
    if (err.status === 413) return `檔案超過 ${MAX_FILE_MB} MB，請分批匯入。`
    if (err.status >= 500) return '系統暫時無法處理，請稍後再試。'
    const { detail } = userErrorToast(err, '')
    return detail === '請稍後再試。' ? fallback : detail
  }
  if (err instanceof TypeError) return '無法連線，請確認網路後再試一次。'
  return fallback
}

async function runPreview() {
  if (!file.value) return
  const seq = ++previewSeq
  previewing.value = true
  fileError.value = ''
  repreviewMessage.value = ''
  try {
    const resp = await previewImport(props.kind, file.value)
    if (seq !== previewSeq) return
    preview.value = resp
    excluded.value = new Set()
    removeNotice.value = ''
    initMapping(resp.categories)
    accountMapping.value = {}
    onlyIssues.value = false
    tableFirst.value = 0
    step.value = 'preview'
  } catch (err) {
    if (seq !== previewSeq) return
    // 整份退回（缺必填標題、沒有資料列…）停在上傳步驟顯示原因
    file.value = null
    preview.value = null
    step.value = 'upload'
    fileError.value = errorDetail(err, '無法讀取檔案，請確認是 Excel 活頁簿（.xlsx）且檔案沒有損毀。')
  } finally {
    if (seq === previewSeq) previewing.value = false
  }
}

function chooseAnotherFile() {
  if (importing.value) return
  previewSeq += 1
  previewing.value = false
  excluded.value = new Set()
  file.value = null
  preview.value = null
  fileError.value = ''
  repreviewMessage.value = ''
  step.value = 'upload'
}

// ─── 預覽統計 ──────────────────────────────────────
const records = computed(() => preview.value?.records ?? [])
function isExcluded(r: ImportPreviewRecord): boolean {
  return excluded.value.has(r.rows[0])
}
/** 被移除的單據不再出現在預覽表與統計 */
const keptRecords = computed(() => records.value.filter((r) => !isExcluded(r)))
const counts = computed(() => {
  const c = { ok: 0, warning: 0, skipped: 0 }
  for (const r of keptRecords.value) c[r.status] += 1
  return c
})
const importableCount = computed(() => counts.value.ok + counts.value.warning)
/** 上方總計的標籤筆數；兩種情況都有的列兩邊都算 */
const warningCounts = computed(() => {
  const c = { filled: 0, outside: 0 }
  for (const r of keptRecords.value) {
    const tags = statusTags(r)
    if (tags.includes(STATUS_META.warning)) c.filled += 1
    if (tags.includes(OUTSIDE_CASH_FLOW_META)) c.outside += 1
  }
  return c
})
const visibleRecords = computed(() =>
  onlyIssues.value ? keptRecords.value.filter((r) => r.status !== 'ok') : keptRecords.value,
)
// 移除後當頁沒資料時退回最後一頁
watch(
  () => visibleRecords.value.length,
  (len) => {
    if (tableFirst.value >= len && tableFirst.value > 0) {
      tableFirst.value = Math.max(0, Math.floor((len - 1) / tableRows.value) * tableRows.value)
    }
  },
)
/** 手機卡片列表的當頁資料（桌機由 DataTable 自己分頁） */
const pagedRecords = computed(() =>
  visibleRecords.value.slice(tableFirst.value, tableFirst.value + tableRows.value),
)
watch(onlyIssues, () => {
  tableFirst.value = 0
})
function onTablePage(evt: DataTablePageEvent | PageState) {
  tableFirst.value = evt.first
  tableRows.value = evt.rows
}

// ─── 移除單據 ──────────────────────────────────────
async function removeRecord(r: ImportPreviewRecord, event: Event) {
  // 移除後該按鈕消失，焦點移到同位置（或最後一個）的移除按鈕，避免焦點掉回頁首
  const container = (event.currentTarget as HTMLElement).closest('.imp-records')
  const buttons = () =>
    Array.from(container?.querySelectorAll<HTMLElement>('.imp-remove') ?? []).filter((b) => b.offsetParent !== null)
  const index = buttons().indexOf(event.currentTarget as HTMLElement)
  excluded.value = new Set(excluded.value).add(r.rows[0])
  removeNotice.value = `已移除${rowLabel(r.rows)}，可在上方全部復原`
  await nextTick()
  const after = buttons()
  ;(after[Math.min(index, after.length - 1)] ?? document.getElementById('imp-restore'))?.focus()
}

async function restoreAll() {
  excluded.value = new Set()
  removeNotice.value = '已全部復原'
  await nextTick()
  document.getElementById('imp-preview-title')?.focus()
}

// ─── 類別對應 ──────────────────────────────────────
// 選項值即送給後端的值：'create'／'reactivate'／既有類別 id
const CREATE = 'create'
const REACTIVATE = 'reactivate'
/** 會被匯入的單據（未移除、非「不匯入」）用到的列；類別名稱只有這些列用到時才需要對應 */
const importingRowSet = computed(() => {
  const set = new Set<number>()
  for (const r of keptRecords.value) if (r.status !== 'skipped') r.rows.forEach((n) => set.add(n))
  return set
})
const categoryIssues = computed(() =>
  (preview.value?.categories ?? []).filter((c) => c.rows.some((n) => importingRowSet.value.has(n))),
)
/** 類別名稱（未填類別為 ''）→ 選項值；只能對應既有類別的項目預設未選 */
const mapping = ref<Record<string, string | null>>({})

function initMapping(list: ImportCategoryIssue[]) {
  const next: Record<string, string | null> = {}
  for (const c of list) {
    next[c.name] = c.state === 'archived' ? REACTIVATE : c.creatable ? CREATE : null
  }
  mapping.value = next
}

/** 只能對應到既有類別、且必選：未填類別、在垃圾桶、名稱過長無法新增 */
function mustMapExisting(c: ImportCategoryIssue): boolean {
  return c.state === 'blank' || c.state === 'discarded' || (c.state === 'missing' && !c.creatable)
}

function mappingOptions(c: ImportCategoryIssue) {
  const existing = {
    label: '對應到既有類別',
    items: categories.value.map((cat) => ({ label: cat.name, value: cat.id })),
  }
  if (mustMapExisting(c)) return [existing]
  const special = c.state === 'archived'
    ? { label: '重新啟用此類別', value: REACTIVATE }
    : { label: '新增此類別', value: CREATE }
  return [{ label: '處理方式', items: [special] }, existing]
}

const blankUnmapped = computed(() =>
  categoryIssues.value.some((c) => mustMapExisting(c) && !mapping.value[c.name]),
)

function buildMapping(): CategoryMapping {
  const out: CategoryMapping = {}
  for (const c of categoryIssues.value) {
    const v = mapping.value[c.name]
    if (v) out[c.name] = v
  }
  return out
}

// ─── 帳戶對應 ──────────────────────────────────────
/** 檔內帳戶找不到或在垃圾桶時對應到既有帳戶；名稱只有會被匯入的單據用到時才需要對應 */
const accountIssues = computed(() =>
  (preview.value?.accounts ?? []).filter((a) => a.rows.some((n) => importingRowSet.value.has(n))),
)
/** 檔內帳戶名稱 → 既有帳戶 id；沒有預設，一律由使用者選 */
const accountMapping = ref<Record<string, string | null>>({})

const accountUnmapped = computed(() => accountIssues.value.some((a) => !accountMapping.value[a.name]))

function buildAccountMapping(): AccountMapping {
  const out: AccountMapping = {}
  for (const a of accountIssues.value) {
    const v = accountMapping.value[a.name]
    if (v) out[a.name] = v
  }
  return out
}

/** 預覽表的帳戶欄：已對應的顯示對應後的帳戶，比對不分大小寫（同後端） */
function accountLabel(name: string | null): string {
  if (!name) return '—'
  const issue = accountIssues.value.find((a) => a.name.toLowerCase() === name.toLowerCase())
  const mapped = issue ? accountMapping.value[issue.name] : null
  return accountOptions.value.find((a) => a.id === mapped)?.name ?? name
}

// ─── 匯入 ─────────────────────────────────────────
const canImport = computed(
  () =>
    step.value === 'preview' &&
    importableCount.value > 0 &&
    !blankUnmapped.value &&
    !accountUnmapped.value &&
    !repreviewMessage.value &&
    !importing.value,
)

function needsRepreview(err: unknown): boolean {
  if (!(err instanceof HttpError)) return false
  const code = (err.body as { error?: string } | undefined)?.error
  return (IMPORT_REPREVIEW_CODES as readonly string[]).includes(code ?? '')
}

async function submitImport() {
  if (!canImport.value || !file.value) return
  importing.value = true
  repreviewMessage.value = ''
  try {
    result.value = await runImport(props.kind, file.value, buildMapping(), buildAccountMapping(), [...excluded.value])
    step.value = 'done'
    emit('imported')
  } catch (err) {
    if (needsRepreview(err)) {
      // 後端說明不一定有句號，補上後再接「沒有建立任何紀錄。」
      repreviewMessage.value = errorDetail(err, '預覽內容已過期，請重新預覽').replace(/[。.]?$/, '。')
      loadCategories()
      loadAccounts()
    } else {
      toast.add({
        severity: 'error',
        summary: '匯入失敗，沒有建立任何紀錄',
        detail: errorDetail(err, '請稍後再試。'),
        life: 3500,
      })
    }
  } finally {
    importing.value = false
  }
}

// ─── 顯示 helper ───────────────────────────────────
/** Excel 列號：連續列顯示區間（第 3–5 列），不連續以頓號分隔 */
function rowLabel(nums: number[]): string {
  const sorted = [...nums].sort((a, b) => a - b)
  if (sorted.length === 0) return '—'
  const contiguous = sorted.every((n, i) => i === 0 || n === sorted[i - 1] + 1)
  if (sorted.length > 1 && contiguous) return `第 ${sorted[0]}–${sorted[sorted.length - 1]} 列`
  return `第 ${sorted.join('、')} 列`
}

/** 多列單據的訊息前面標出是哪一列 */
function messageText(m: ImportMessage, rows: number[]): string {
  return rows.length > 1 ? `第 ${m.row} 列：${m.text}` : m.text
}

const dialogWidth = computed(() => (step.value === 'upload' ? 'min(92vw, 560px)' : 'min(96vw, 960px)'))

/** 讀屏播報：預覽完成、匯入完成 */
const liveText = computed(() => {
  if (previewing.value) return '正在讀取檔案'
  if (importing.value) return '匯入中'
  if (step.value === 'preview') {
    const count = `可匯入 ${importableCount.value} 筆`
    return removeNotice.value ? `${removeNotice.value}，目前${count}` : `預覽完成，${count}`
  }
  if (step.value === 'done' && result.value) return `已匯入 ${result.value.createdCount} 筆`
  return ''
})
</script>

<template>
  <Dialog
    :visible="visible"
    modal
    :header="text.title"
    :closable="!importing"
    :close-on-escape="!importing"
    :style="{ width: dialogWidth }"
    :breakpoints="{ '640px': '96vw' }"
    @update:visible="(v) => !v && close()"
  >
    <p class="sr-only" aria-live="polite">{{ liveText }}</p>

    <!-- ① 上傳 -->
    <div v-if="step === 'upload'" class="imp-body">
      <div class="imp-template">
        <div>
          <b>先下載範本</b>
          <span>依範本欄位填寫，同一張單據多個品項時填相同的單據編號。</span>
        </div>
        <Button
          label="下載範本"
          icon="pi pi-download"
          outlined
          :loading="downloading"
          @click="downloadTemplate"
        />
      </div>

      <label
        class="upload-drop"
        :class="{ 'is-drag': isDragging, 'is-busy': previewing }"
        :aria-busy="previewing"
        @dragover.prevent="isDragging = true"
        @dragleave="isDragging = false"
        @drop.prevent="onDrop"
      >
        <template v-if="previewing">
          <i class="pi pi-spin pi-spinner upload-drop-icon" aria-hidden="true" />
          <b>讀取中…</b>
          <span>{{ file?.name }}</span>
        </template>
        <template v-else>
          <i class="pi pi-file-excel upload-drop-icon" aria-hidden="true" />
          <b>拖放 Excel 檔，或點擊上傳</b>
          <span>只支援 .xlsx，單檔 {{ MAX_FILE_MB }} MB 以內、最多 {{ MAX_ROWS.toLocaleString() }} 列</span>
        </template>
        <input
          type="file"
          accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          class="sr-only"
          aria-label="上傳 Excel 檔"
          :aria-describedby="fileError ? 'imp-file-err' : undefined"
          :disabled="previewing"
          @change="onFileChange"
        />
      </label>

      <span v-if="fileError" id="imp-file-err" class="q-error" role="alert">
        <i class="pi pi-exclamation-circle" aria-hidden="true" />{{ fileError }}
      </span>
      <p class="dlg-note">匯入的紀錄不含憑證，之後可在編輯時補上。</p>
    </div>

    <!-- ② 預覽 -->
    <div v-else-if="step === 'preview'" class="imp-body">
      <div class="imp-file">
        <i class="pi pi-file-excel" aria-hidden="true" />
        <div class="imp-file-meta">
          <b>{{ file?.name }}</b>
          <span>{{ fileSizeText }}</span>
        </div>
        <Button label="重新選擇" text :disabled="importing" @click="chooseAnotherFile" />
      </div>

      <p class="imp-summary">
        共 {{ keptRecords.length }} 筆：
        <span class="tag-soft tag-success">可匯入 {{ counts.ok }}</span>
        <span class="tag-soft tag-warn">補預設值 {{ warningCounts.filled }}</span>
        <span v-if="warningCounts.outside" class="tag-soft tag-warn">{{ OUTSIDE_CASH_FLOW_META.label }} {{ warningCounts.outside }}</span>
        <span class="tag-soft tag-danger">不匯入 {{ counts.skipped }}</span>
      </p>

      <div v-if="excluded.size" class="imp-removed">
        <span>已移除 {{ excluded.size }} 筆，這些單據不會建立。</span>
        <Button id="imp-restore" label="全部復原" icon="pi pi-undo" text size="small" :disabled="importing" @click="restoreAll" />
      </div>

      <Message v-if="repreviewMessage" severity="warn" :closable="false">
        <div class="imp-changed">
          <span>{{ repreviewMessage }}沒有建立任何紀錄。</span>
          <Button label="重新預覽" size="small" outlined :loading="previewing" @click="runPreview" />
        </div>
      </Message>

      <!-- 類別對應 -->
      <section v-if="categoryIssues.length" class="imp-section" aria-labelledby="imp-map-title">
        <h3 id="imp-map-title" class="imp-section-title">類別對應</h3>
        <p class="dlg-note">以下類別在系統中找不到、已停用或在垃圾桶，請選擇處理方式；標 * 的項目需指定要歸到哪個既有類別。</p>
        <span v-if="categoriesFailed" class="q-error imp-cat-failed" role="alert">
          <i class="pi pi-exclamation-circle" aria-hidden="true" />類別清單載入失敗，無法對應到既有類別。
          <Button label="重試" size="small" text :loading="categoriesLoading" @click="loadCategories" />
        </span>
        <div class="imp-map">
          <div v-for="(c, i) in categoryIssues" :key="c.name" class="imp-map-row">
            <label :for="`imp-cat-${i}`" class="imp-map-name">
              {{ c.state === 'blank' ? '（未填類別）' : c.name }}
              <span v-if="mustMapExisting(c)" class="req" aria-hidden="true">*</span>
              <small>{{ c.rows.length > 5 ? `共 ${c.rows.length} 列` : rowLabel(c.rows) }}<template v-if="c.state === 'archived'">・與停用中的類別同名</template><template v-else-if="c.state === 'discarded'">・此類別在垃圾桶</template><template v-else-if="c.state === 'missing' && !c.creatable">・名稱超過 50 字，無法新增</template></small>
            </label>
            <Select
              v-model="mapping[c.name]"
              :input-id="`imp-cat-${i}`"
              :options="mappingOptions(c)"
              option-label="label"
              option-value="value"
              option-group-label="label"
              option-group-children="items"
              :placeholder="mustMapExisting(c) ? '選擇類別' : undefined"
              :invalid="mustMapExisting(c) && !mapping[c.name]"
              :loading="categoriesLoading"
              :pt="mustMapExisting(c) ? { label: { 'aria-required': 'true', 'aria-describedby': !mapping[c.name] ? `imp-cat-err-${i}` : undefined } } : undefined"
              :disabled="importing"
              class="imp-map-select"
            />
            <span v-if="mustMapExisting(c) && !mapping[c.name]" :id="`imp-cat-err-${i}`" class="q-error imp-map-err">
              <i class="pi pi-exclamation-circle" aria-hidden="true" />請選擇要歸到哪個類別
            </span>
          </div>
        </div>
      </section>

      <!-- 帳戶對應 -->
      <section v-if="accountIssues.length" class="imp-section" aria-labelledby="imp-acct-title">
        <h3 id="imp-acct-title" class="imp-section-title">帳戶對應</h3>
        <p class="dlg-note">以下帳戶在系統中找不到或在垃圾桶，請選擇要歸到哪個既有帳戶。</p>
        <div class="imp-map">
          <div v-for="(a, i) in accountIssues" :key="a.name" class="imp-map-row">
            <label :id="`imp-acct-label-${i}`" :for="`imp-acct-${i}`" class="imp-map-name">
              {{ a.name }}
              <span class="req" aria-hidden="true">*</span>
              <small>{{ a.rows.length > 5 ? `共 ${a.rows.length} 筆` : rowLabel(a.rows) }}<template v-if="a.state === 'discarded'">・此帳戶在垃圾桶</template></small>
            </label>
            <Select
              v-model="accountMapping[a.name]"
              :input-id="`imp-acct-${i}`"
              :options="accountOptions"
              option-label="name"
              option-value="id"
              placeholder="選擇帳戶"
              empty-message="沒有可選的帳戶"
              :invalid="!accountMapping[a.name]"
              :loading="accountsLoading"
              :aria-labelledby="`imp-acct-label-${i}`"
              :pt="{ label: { 'aria-required': 'true', 'aria-describedby': !accountMapping[a.name] ? `imp-acct-err-${i}` : undefined } }"
              :disabled="importing"
              class="imp-map-select"
            />
            <span v-if="!accountMapping[a.name]" :id="`imp-acct-err-${i}`" class="q-error imp-map-err">
              <i class="pi pi-exclamation-circle" aria-hidden="true" />請選擇要歸到哪個帳戶
            </span>
          </div>
        </div>
      </section>

      <!-- 預覽表 -->
      <section class="imp-section imp-records" aria-labelledby="imp-preview-title">
        <div class="imp-section-head">
          <h3 id="imp-preview-title" class="imp-section-title" tabindex="-1">預覽</h3>
          <div class="imp-filter">
            <Checkbox v-model="onlyIssues" input-id="imp-only-issues" :binary="true" />
            <label for="imp-only-issues">只看有問題的列</label>
          </div>
        </div>
        <DataTable
          :value="visibleRecords"
          :data-key="(r) => String(r.rows[0])"
          :first="tableFirst"
          :rows="tableRows"
          paginator
          :rows-per-page-options="ROWS_OPTIONS"
          :paginator-template="PAGINATOR_TEMPLATE"
          :current-page-report-template="PAGE_REPORT"
          :table-style="{ width: '100%', minWidth: '860px' }"
          class="imp-table imp-desktop"
          @page="onTablePage"
        >
          <template #empty>
            <div class="dash-empty">沒有有問題的列</div>
          </template>
          <Column header="Excel 列號" :style="{ width: '1%' }">
            <template #body="{ data }"><span class="whitespace-nowrap">{{ rowLabel(data.rows) }}</span></template>
          </Column>
          <Column :header="text.date">
            <template #body="{ data }"><span class="tabular-nums whitespace-nowrap">{{ formatDate(data.summary.date) }}</span></template>
          </Column>
          <Column :header="text.counterparty" body-class="imp-wrap">
            <template #body="{ data }">{{ data.summary.party || '—' }}</template>
          </Column>
          <Column header="類別" body-class="imp-wrap">
            <template #body="{ data }">{{ data.summary.categoryName || '（未填類別）' }}</template>
          </Column>
          <Column header="帳戶" body-class="imp-wrap">
            <template #body="{ data }">{{ accountLabel(data.summary.accountName) }}</template>
          </Column>
          <Column header="金額" header-class="num" body-class="num">
            <template #body="{ data }">
              <span class="tabular-nums whitespace-nowrap">{{ data.summary.amount == null ? '—' : formatCurrency(data.summary.amount) }}</span>
            </template>
          </Column>
          <Column header="品項數" header-class="num" body-class="num" :style="{ width: '1%' }">
            <template #body="{ data }"><span class="tabular-nums">{{ data.summary.itemCount }}</span></template>
          </Column>
          <Column header="狀態與原因" body-class="imp-wrap">
            <template #body="{ data }">
              <div class="imp-status">
                <span v-for="t in statusTags(data as ImportPreviewRecord)" :key="t.label" :class="['tag-soft', t.tag]">
                  {{ t.label }}
                </span>
                <ul v-if="data.messages.length" class="imp-msgs">
                  <li v-for="(m, j) in data.messages" :key="j">{{ messageText(m, data.rows) }}</li>
                </ul>
              </div>
            </template>
          </Column>
          <Column :style="{ width: '1%' }" body-class="act">
            <template #header><span class="sr-only">移除</span></template>
            <template #body="{ data }">
              <Button
                v-if="data.status !== 'skipped'"
                v-tooltip.left="'不匯入這筆'"
                icon="pi pi-times"
                text
                rounded
                severity="secondary"
                class="imp-remove"
                :aria-label="`移除${rowLabel(data.rows)}`"
                :disabled="importing"
                @click="removeRecord(data as ImportPreviewRecord, $event)"
              />
            </template>
          </Column>
        </DataTable>

        <!-- 手機：卡片式，第 1 行列號 + 狀態、第 2 行對象 + 金額、第 3 行日期／類別／帳戶／品項、最後是原因 -->
        <div class="imp-mobile">
          <p v-if="pagedRecords.length === 0" class="dash-empty">沒有有問題的列</p>
          <ul v-else class="imp-cards">
            <li v-for="r in pagedRecords" :key="r.rows[0]" class="imp-card">
              <div class="imp-card-line">
                <b>{{ rowLabel(r.rows) }}</b>
                <span class="imp-card-actions">
                  <span v-for="t in statusTags(r)" :key="t.label" :class="['tag-soft', t.tag]">{{ t.label }}</span>
                  <Button
                    v-if="r.status !== 'skipped'"
                    icon="pi pi-times"
                    text
                    rounded
                    severity="secondary"
                    class="imp-remove"
                    :aria-label="`移除${rowLabel(r.rows)}`"
                    :disabled="importing"
                    @click="removeRecord(r, $event)"
                  />
                </span>
              </div>
              <div class="imp-card-line">
                <span class="imp-card-party">{{ r.summary.party || `（未填${text.counterparty}）` }}</span>
                <span class="tabular-nums">{{ r.summary.amount == null ? '—' : formatCurrency(r.summary.amount) }}</span>
              </div>
              <div class="imp-card-meta">
                <span class="tabular-nums">{{ formatDate(r.summary.date) }}</span>
                <span>{{ r.summary.categoryName || '（未填類別）' }}</span>
                <span v-if="r.summary.accountName">{{ accountLabel(r.summary.accountName) }}</span>
                <span>{{ r.summary.itemCount ? `${r.summary.itemCount} 個品項` : '無品項' }}</span>
              </div>
              <ul v-if="r.messages.length" class="imp-msgs">
                <li v-for="(m, j) in r.messages" :key="j">{{ messageText(m, r.rows) }}</li>
              </ul>
            </li>
          </ul>
          <Paginator
            v-if="visibleRecords.length > tableRows"
            :first="tableFirst"
            :rows="tableRows"
            :total-records="visibleRecords.length"
            template="PrevPageLink CurrentPageReport NextPageLink"
            current-page-report-template="第 {first}–{last} 筆，共 {totalRecords} 筆"
            @page="onTablePage"
          />
        </div>
      </section>
    </div>

    <!-- ③ 完成 -->
    <div v-else-if="result" class="imp-body">
      <div class="imp-done" role="status">
        <i class="pi pi-check-circle" aria-hidden="true" />
        <b>已匯入 {{ result.createdCount }} 筆</b>
        <span v-if="result.excludedCount">使用者移除 {{ result.excludedCount }} 筆，未建立。</span>
        <span v-if="result.outsideCashFlowCount" class="imp-done-warn">
          有 {{ result.outsideCashFlowCount }} 筆收付款日早於帳戶起始月份，不計入現金流。
        </span>
        <span>關閉後這份清單不會保留，需要留意的列請先記下或截圖。</span>
      </div>

      <p v-if="result.createdCategories.length || result.reactivatedCategories.length" class="dlg-note">
        <template v-if="result.createdCategories.length">
          已新增類別：{{ result.createdCategories.map((c) => c.name).join('、') }}。
        </template>
        <template v-if="result.reactivatedCategories.length">
          已重新啟用類別：{{ result.reactivatedCategories.map((c) => c.name).join('、') }}。
        </template>
      </p>

      <section v-if="result.skipped.length" class="imp-section" aria-labelledby="imp-skipped-title">
        <h3 id="imp-skipped-title" class="imp-section-title">未匯入的列（{{ result.skipped.length }}）</h3>
        <ul class="imp-notes">
          <li v-for="(n, i) in result.skipped" :key="i">
            <b>{{ rowLabel(n.rows) }}</b>
            <span>{{ n.messages.map((m) => messageText(m, n.rows)).join('；') }}</span>
          </li>
        </ul>
      </section>

      <section v-if="result.warnings.length" class="imp-section" aria-labelledby="imp-warn-title">
        <h3 id="imp-warn-title" class="imp-section-title">補了預設值或需要留意的列（{{ result.warnings.length }}）</h3>
        <ul class="imp-notes">
          <li v-for="(n, i) in result.warnings" :key="i">
            <b>{{ rowLabel(n.rows) }}</b>
            <span>{{ n.messages.map((m) => messageText(m, n.rows)).join('；') }}</span>
          </li>
        </ul>
      </section>
    </div>

    <template #footer>
      <template v-if="step === 'done'">
        <Button label="完成" @click="close" />
      </template>
      <template v-else>
        <span v-if="step === 'preview' && importableCount === 0 && excluded.size" class="imp-foot-hint">
          可匯入的資料都已移除，如要匯入請按上方「全部復原」。
        </span>
        <span v-else-if="step === 'preview' && importableCount === 0" class="imp-foot-hint">
          沒有可匯入的資料，請修正 Excel 後重新選擇檔案。
        </span>
        <span v-else-if="step === 'preview' && blankUnmapped" class="imp-foot-hint">
          請為標 * 的類別選擇要對應的既有類別。
        </span>
        <Button label="取消" outlined :disabled="importing" @click="close" />
        <Button
          v-if="step === 'preview'"
          :label="`匯入 ${importableCount} 筆`"
          icon="pi pi-upload"
          :loading="importing"
          :disabled="!canImport"
          @click="submitImport"
        />
      </template>
    </template>
  </Dialog>
</template>

<style scoped>
.imp-body { display: flex; flex-direction: column; gap: var(--space-md); }

.imp-template { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 12px 14px; background: var(--surface); border-radius: var(--radius-card); }
.imp-template b { display: block; font-weight: 600; color: var(--ink); }
.imp-template span { display: block; margin-top: 2px; font-size: 14px; color: var(--muted); }
.imp-template .p-button { flex-shrink: 0; }

.upload-drop.is-busy { cursor: progress; }

.imp-file { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border: 1px solid var(--hairline); border-radius: var(--radius-card); }
.imp-file > .pi { font-size: 24px; color: var(--primary-text); }
.imp-file-meta { flex: 1; min-width: 0; }
.imp-file-meta b { display: block; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.imp-file-meta span { font-size: 14px; color: var(--muted); font-variant-numeric: tabular-nums; }

.imp-summary { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 0; color: var(--ink); }
.imp-removed { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px; padding: 6px 6px 6px 14px; background: var(--surface); border-radius: var(--radius-card); font-size: 14px; color: var(--slate); }
.imp-changed { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px; width: 100%; }

.imp-section { display: flex; flex-direction: column; gap: var(--space-sm); }
.imp-section-head { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px; }
.imp-section-title { margin: 0; font-size: 16px; font-weight: 600; color: var(--ink); }
.imp-filter { display: inline-flex; align-items: center; gap: 8px; min-height: 44px; }
.imp-filter label { font-size: 14px; color: var(--slate); cursor: pointer; }

.imp-map { display: flex; flex-direction: column; gap: 8px; }
.imp-map-row { display: grid; grid-template-columns: minmax(0, 1fr) minmax(200px, 280px); align-items: center; gap: 12px; }
.imp-map-name { font-weight: 500; color: var(--ink); overflow-wrap: anywhere; }
.imp-map-name small { display: block; font-size: 14px; font-weight: 400; color: var(--muted); }
.imp-map-select { width: 100%; }

/* 全域表格儲存格不換行；文字欄與原因允許換行，避免撐出橫向捲軸 */
.imp-desktop :deep(td.imp-wrap) { white-space: normal; overflow-wrap: anywhere; }
.imp-status { display: flex; flex-direction: column; align-items: flex-start; gap: 4px; }
.imp-msgs { margin: 0; padding-left: 1.1em; font-size: 14px; color: var(--slate); }

.imp-done { display: flex; flex-direction: column; align-items: center; gap: 4px; padding: var(--space-md) 0; text-align: center; }
.imp-done > .pi { font-size: 36px; color: var(--status-paid); margin-bottom: 4px; }
.imp-done b { font-size: 18px; font-weight: 600; color: var(--ink); }
.imp-done span { font-size: 14px; color: var(--muted); }
.imp-done .imp-done-warn { color: var(--warning-text); }

.imp-notes { margin: 0; padding: 0; list-style: none; max-height: 240px; overflow-y: auto; border: 1px solid var(--hairline); border-radius: var(--radius-card); }
.imp-notes li { display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 12px; padding: 8px 12px; font-size: 14px; }
.imp-notes li + li { border-top: 1px solid var(--hairline); }
.imp-notes b { font-weight: 500; white-space: nowrap; color: var(--ink); }
.imp-notes span { color: var(--slate); }

.imp-cat-failed { flex-wrap: wrap; }
.imp-map-err { grid-column: 2; }
.imp-mobile { display: none; }
.imp-cards { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 8px; }
.imp-card { display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; border: 1px solid var(--hairline); border-radius: var(--radius-card); font-size: 14px; }
.imp-card-line { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.imp-card-line b { font-weight: 500; color: var(--ink); }
.imp-card-actions { display: inline-flex; flex-wrap: wrap; justify-content: flex-end; align-items: center; gap: 4px; }
.imp-remove.p-button { width: 44px; height: 44px; flex-shrink: 0; }
.imp-card-party { min-width: 0; overflow-wrap: anywhere; color: var(--ink); }
.imp-card-meta { display: flex; flex-wrap: wrap; gap: 4px 12px; color: var(--muted); }

.imp-foot-hint { margin-right: auto; align-self: center; font-size: 14px; color: var(--warning-text); }

@media (max-width: 639.98px) {
  .imp-template { flex-direction: column; align-items: stretch; }
  .imp-template b,
  .imp-file-meta b,
  .imp-summary,
  .imp-section-title,
  .imp-map-name,
  .imp-done b,
  .upload-drop > b { font-size: 14px; }
  .imp-map-row { grid-template-columns: 1fr; gap: 4px; }
  .imp-map-err { grid-column: 1; }
  .imp-desktop { display: none; }
  .imp-mobile { display: block; }
  .imp-foot-hint { flex-basis: 100%; margin-right: 0; }
}
</style>
