<script setup lang="ts">
/**
 * 收入新增 / 編輯。
 * 鏡像 ExpenseFormView 的欄位與驗證，差異：
 * - OCR 以 role=income 辨識，客戶 = 對方（買方）
 * - 收款狀態：Select（待收款 / 已收款）+ 條件顯示收款日 DatePicker（鏡像 payoutStatus / paidAt）
 * - 編輯模式可改收款狀態；form 內部依 diff 分別呼叫 collect / revertCollect / PATCH，
 *   以確保狀態切換走專用 endpoint、AuditLog 有正確的 status_change 事件
 * - 「賣方名稱」改成「客戶名稱」；統編欄位名為「買方統編」（我方開發票給誰）
 */
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import type {
  CollectionStatus,
  DocumentType,
  IncomeAttachment,
  IncomeItem,
  TaxRate,
} from '@/types/domain'
import type { IncomeFormPageData } from '@/types/expense-form'
import {
  listCategories,
  createCategory,
  type Category,
} from '@/api/categories'
import {
  collectIncome,
  createIncome,
  getIncome,
  revertCollectIncome,
  updateIncome,
  type CreateIncomeRequest,
  type UpdateIncomeRequest,
} from '@/api/incomes'
import { HttpError } from '@/api/service'
import { userErrorToast } from '@/utils/userFeedback'
import {
  DOCUMENT_TYPE_OPTIONS,
  INVOICE_NUMBER_REGEX,
  TAX_RATE_OPTIONS,
  getTaxRateValue,
} from '@/constants/expense'
import { toIsoDate } from '@/utils/format'
import { dataUrlToFile, useOcrRecognize, type OcrSource } from '@/composables/useOcrRecognize'
import { useFormReset } from '@/composables/useFormReset'
import { stagedIncomePages } from '@/composables/useStagedImport'
import OcrConflictDialog from '@/components/OcrConflictDialog.vue'
import type { OcrFields, OcrItem } from '@/api/ocr'
import { joinInvoiceNo } from '@/utils/ocrForm'
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import ExpenseFormPagination from '@/components/ExpenseFormPagination.vue'
import AccountSelect from '@/components/admin/AccountSelect.vue'
import CashFlowExcludedHint from '@/components/admin/CashFlowExcludedHint.vue'
import { isAccountUnavailable } from '@/api/accounts'
import { useAccountOptions } from '@/composables/useAccountOptions'
import PageHeader from '@/components/PageHeader.vue'
import AutoComplete from 'primevue/autocomplete'
import Button from 'primevue/button'
import DatePicker from 'primevue/datepicker'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Textarea from 'primevue/textarea'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'

const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

const isEditMode = computed(() => route.name === 'admin-income-edit')
const editingId = computed(() =>
  isEditMode.value ? (route.params.id as string) : null,
)
const pageTitle = computed(() => (isEditMode.value ? '編輯收入' : '新增收入'))
const submitLabel = computed(() => {
  if (isEditMode.value) return '更新'
  return isMultiPage.value ? `建立 ${pages.value.length} 筆` : '建立'
})

const allowLeave = ref(false)
const isSubmitting = ref(false)

// ─── 類別清單 ─────────────────────────────────────
const activeCategories = ref<Category[]>([])
const categoryMap = computed(() => {
  const m = new Map<string, Category>()
  for (const c of activeCategories.value) m.set(c.id, c)
  return m
})

// ─── 表單 state ────────────────────────────────────
const attachments = ref<IncomeAttachment[]>([])
const documentType = ref<DocumentType>('invoice')
const incomeDate = ref<Date | null>(null)
const taxId = ref('')
const customer = ref('')
const invoicePrefix = ref('')
const invoiceDigits = ref('')
const taxRate = ref<TaxRate>('business_5')
const preTaxAmt = ref<number | null>(null)
const taxAmt = ref<number | null>(null)
const amount = ref<number | null>(null)
const items = ref<IncomeItem[]>([])
const categoryId = ref<string | null>(null)
const accountId = ref<string | null>(null)
const note = ref('')

// 收款狀態與收款日。預設「待收款」；選「已收款」時出現收款日 DatePicker，預設今日。
// 編輯模式會從載入的 income 填回；儲存時依與 originalCollectionState 的差異分別呼叫
// collect / revertCollect / PATCH collectedAt，確保 AuditLog 有正確事件。
const collectionStatus = ref<CollectionStatus>('uncollected')
const collectedAt = ref<Date | null>(null)
const originalCollectionState = ref<{ status: CollectionStatus; dateIso: string | null } | null>(null)
watch(collectionStatus, (v) => {
  if (v === 'collected' && !collectedAt.value) collectedAt.value = new Date()
})

const COLLECTION_STATUS_OPTIONS: { value: CollectionStatus; label: string }[] = [
  { value: 'uncollected', label: '待收款' },
  { value: 'collected',   label: '已收款' },
]

// ─── 多筆分頁狀態 ─────────────────────────────────
// 同新增支出：只有批次匯入憑證（docs/資料模型.md §5.5）確認帶出 N 張憑證時才會有 N 筆 pages，
// 每筆帶自己那一頁的憑證。pages.length > 1 時 UI 顯示分頁元件；編輯模式一律單頁。
const pages = ref<IncomeFormPageData[]>([])
const currentPageIndex = ref(0)
const isMultiPage = computed(() => !isEditMode.value && pages.value.length > 1)

// 由批次匯入憑證 stage 資料進入的旗標。true 時憑證區只顯示這一筆自己的憑證、可補上傳，
// 不提供辨識（已在批次辨識扣過次）。
const fromImport = ref(false)

// 固定收支產生的紀錄（只會在編輯模式出現）：發票號碼事後補，可以留空
const isRecurringRecord = ref(false)

const fieldErrors = reactive({
  category: '',
  account: '',
  amount: '',
  date: '',
  invoiceNo: '',
  taxId: '',
  customer: '',
  collectedAt: '',
})

function clearError(key: keyof typeof fieldErrors) {
  fieldErrors[key] = ''
}

// 「清除所有欄位」要還原的欄位；憑證不在內（清除時保留）
const formReset = useFormReset(
  [documentType, incomeDate, taxId, customer, invoicePrefix, invoiceDigits, taxRate, preTaxAmt, taxAmt, amount, items, categoryId, note, collectionStatus, collectedAt],
  fieldErrors,
)

// ─── 發票號碼拆 / 組 helpers ─────────────────────
function splitInvoiceNo(raw: string | null): { prefix: string; digits: string } {
  if (!raw) return { prefix: '', digits: '' }
  const cleaned = raw.trim().replace(/-/g, '').toUpperCase()
  return {
    prefix: cleaned.slice(0, 2).replace(/[^A-Z]/g, ''),
    digits: cleaned.slice(2).replace(/\D/g, '').slice(0, 8),
  }
}

function combinedInvoiceNo(
  prefix = invoicePrefix.value,
  digits = invoiceDigits.value,
): string {
  return joinInvoiceNo(prefix, digits)
}

function onInvoicePrefixInput(v: string) {
  const next = v.replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 2)
  const filled = next.length === 2 && invoicePrefix.value.length < 2
  invoicePrefix.value = next
  clearError('invoiceNo')
  if (filled) document.getElementById('invoiceDigits')?.focus()
}

function onInvoiceDigitsInput(v: string) {
  invoiceDigits.value = v.replace(/\D/g, '').slice(0, 8)
  clearError('invoiceNo')
}

function onInvoiceDigitsKeydown(e: KeyboardEvent) {
  if (e.key === 'Backspace' && !invoiceDigits.value) {
    e.preventDefault()
    document.getElementById('invoicePrefix')?.focus()
  }
}

// ─── 稅率 3 欄雙向連動 ────────────────────────────
let taxLinkGuard = false
function onPreTaxInput(v: number | null) {
  if (taxLinkGuard) return
  taxLinkGuard = true
  preTaxAmt.value = v
  if (v === null) {
    taxAmt.value = null
    amount.value = null
  } else {
    const rate = getTaxRateValue(taxRate.value)
    const tax = Math.round(v * rate)
    taxAmt.value = tax
    amount.value = v + tax
    clearError('amount')
  }
  taxLinkGuard = false
}
function onAmountInput(v: number | null) {
  if (taxLinkGuard) return
  taxLinkGuard = true
  amount.value = v
  if (v === null) {
    preTaxAmt.value = null
    taxAmt.value = null
  } else {
    const rate = getTaxRateValue(taxRate.value)
    const pre = Math.round(v / (1 + rate))
    preTaxAmt.value = pre
    taxAmt.value = v - pre
    clearError('amount')
  }
  taxLinkGuard = false
}
function onTaxRateChange(newRate: TaxRate) {
  taxRate.value = newRate
  if (preTaxAmt.value !== null) {
    const rate = getTaxRateValue(newRate)
    taxAmt.value = Math.round(preTaxAmt.value * rate)
    amount.value = preTaxAmt.value + taxAmt.value
  } else if (amount.value !== null) {
    const rate = getTaxRateValue(newRate)
    const pre = Math.round(amount.value / (1 + rate))
    preTaxAmt.value = pre
    taxAmt.value = amount.value - pre
  }
}
function setDocumentType(type: DocumentType) {
  documentType.value = type
  if (type === 'receipt') {
    invoicePrefix.value = ''
    invoiceDigits.value = ''
    fieldErrors.invoiceNo = ''
    onTaxRateChange('exempt_0')
  } else if (taxRate.value === 'exempt_0') {
    onTaxRateChange('business_5')
  }
}
const taxAmountText = computed(() => {
  const v = taxAmt.value
  if (documentType.value === 'receipt' || v === null || v <= 0) return ''
  return `營業稅額 NT$ ${v.toLocaleString('zh-TW')} 元`
})

// ─── 品項列表 ─────────────────────────────────────
function addItem() {
  items.value.push({ name: '', quantity: 1, unitPrice: 0, subtotal: 0 })
}
function removeItem(i: number) {
  items.value.splice(i, 1)
}
function recomputeItemSubtotal(i: number) {
  const it = items.value[i]
  const q = Number(it.quantity) || 0
  const p = Number(it.unitPrice) || 0
  it.subtotal = q * p
}

// ─── 類別 AutoComplete + 新增類別 ─────────────────
interface CategorySuggestion {
  value: string
  label: string
  accountCode: string
  isNew?: boolean
}
const NEW_CATEGORY_PREFIX = '__new__:'
const categorySuggestions = ref<CategorySuggestion[]>([])
const categoryAutoComplete = ref<InstanceType<typeof AutoComplete> | null>(null)

function currentOptions(): CategorySuggestion[] {
  return activeCategories.value.map((c) => ({
    value: c.id,
    label: c.name,
    accountCode: c.accountCode,
  }))
}
function refreshCategorySuggestions(query: string) {
  const q = query.trim()
  const qLower = q.toLowerCase()
  const all = currentOptions()
  if (!q) {
    categorySuggestions.value = all
    return
  }
  const matches = all.filter(
    (o) =>
      o.label.toLowerCase().includes(qLower) ||
      o.value.toLowerCase().includes(qLower),
  )
  const exact = all.some((o) => o.label === q || o.value === q)
  if (!exact) {
    matches.push({
      value: `${NEW_CATEGORY_PREFIX}${q}`,
      label: `新增類別「${q}」+`,
      accountCode: '',
      isNew: true,
    })
  }
  categorySuggestions.value = matches
}
function searchCategoriesEvent(event: { query: string }) {
  refreshCategorySuggestions(event.query)
}
function onCategoryFocus() {
  refreshCategorySuggestions('')
  nextTick(() => {
    const inst = categoryAutoComplete.value as unknown as {
      show?: (event?: Event) => void
    } | null
    inst?.show?.()
  })
}
const categoryObj = computed<CategorySuggestion | null>({
  get: () => {
    const v = categoryId.value
    if (!v) return null
    const c = categoryMap.value.get(v)
    return c
      ? { value: c.id, label: c.name, accountCode: c.accountCode }
      : { value: v, label: v, accountCode: '' }
  },
  set: (obj) => {
    if (!obj) {
      categoryId.value = null
      return
    }
    if (obj.isNew) {
      const raw = obj.value.slice(NEW_CATEGORY_PREFIX.length)
      void createNewCategory(raw)
    } else {
      categoryId.value = obj.value || null
    }
    if (categoryId.value) clearError('category')
  },
})
async function createNewCategory(name: string) {
  try {
    const created = await createCategory({ kind: 'income', name })
    activeCategories.value = [...activeCategories.value, created]
    categoryId.value = created.id
    nextTick(() => refreshCategorySuggestions(''))
  } catch (err) {
    if (err instanceof HttpError && err.status === 409) {
      const existing = (err.body as { category?: Category }).category
      if (existing) {
        if (!categoryMap.value.has(existing.id)) {
          activeCategories.value = [...activeCategories.value, existing]
        }
        categoryId.value = existing.id
        return
      }
    }
    toast.add({ severity: 'error', summary: '新增類別失敗', life: 2500 })
    categoryId.value = null
  }
}
function onCategorySelect(event: { value: CategorySuggestion }) {
  if (event?.value?.isNew) {
    nextTick(() => refreshCategorySuggestions(''))
  }
}

// ─── 帳戶 ───────────────────────────────────
const {
  options: accountOptions,
  lastUsedAccountId,
  loading: accountsLoading,
  load: loadAccounts,
  add: addAccountOption,
} = useAccountOptions()

onMounted(async () => {
  await loadAccounts()
  // 新增帶上一次使用的帳戶；批次匯入只帶第一筆，之後逐筆帶上一筆所選
  if (!isEditMode.value && !accountId.value) accountId.value = lastUsedAccountId.value
})

const selectedAccount = computed(() => accountOptions.value.find((a) => a.id === accountId.value))

/** 切到還沒選帳戶的那一筆時，帶目前這筆所選 */
function carryAccount(target: IncomeFormPageData) {
  if (!target.accountId) target.accountId = accountId.value
}

// ─── 憑證上傳 ─────────────────────────────────────
const previewAtt = ref<IncomeAttachment | null>(null)
const isDragging = ref(false)
const MAX_ATTACHMENT_MB = 5
const MAX_ATTACHMENTS = 5

function isImageAttachment(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}
function isPdfFile(file: File): boolean {
  return (
    file.type === 'application/pdf' ||
    file.name.toLowerCase().endsWith('.pdf')
  )
}
function readFileAsDataUrl(file: Blob) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(file)
  })
}
async function addAttachmentFile(file: File) {
  if (attachments.value.length >= MAX_ATTACHMENTS) {
    toast.add({
      severity: 'warn',
      summary: `最多上傳 ${MAX_ATTACHMENTS} 張憑證`,
      life: 3000,
    })
    return
  }
  if (!file.type.startsWith('image/') && !isPdfFile(file)) {
    toast.add({
      severity: 'warn',
      summary: `${file.name} 不支援`,
      detail: '請上傳 JPG、PNG 或 PDF 憑證',
      life: 3500,
    })
    return
  }
  if (file.size > MAX_ATTACHMENT_MB * 1024 * 1024) {
    toast.add({
      severity: 'warn',
      summary: `${file.name} 超過 ${MAX_ATTACHMENT_MB}MB`,
      detail: '請壓縮後再上傳',
      life: 3500,
    })
    return
  }
  try {
    attachments.value.push({
      dataUrl: await readFileAsDataUrl(file),
      filename: file.name,
      mimeType:
        file.type ||
        (isPdfFile(file) ? 'application/pdf' : 'application/octet-stream'),
    })
  } catch {
    toast.add({ severity: 'error', summary: `${file.name} 讀取失敗`, life: 2500 })
  }
}
async function onAttachmentChange(event: Event) {
  const target = event.target as HTMLInputElement
  const files = Array.from(target.files ?? [])
  target.value = ''
  for (const f of files) await addAttachmentFile(f)
}
async function onAttachmentDrop(event: DragEvent) {
  isDragging.value = false
  for (const f of Array.from(event.dataTransfer?.files ?? []))
    await addAttachmentFile(f)
}
function removeAttachment(index: number) {
  ocrExcluded.value.delete(attachments.value[index])
  attachments.value.splice(index, 1)
}

// ─── 「開始辨識」OCR ───────────────────────────────
/**
 * 辨識結果整份寫進表單：客戶 = 對方（買方）；辨識不到的欄位清空。
 * 我方名稱 / 統編不帶回表單；類別、收款狀態、備註不是 OCR 會給的欄位，維持原值。
 */
function applyOcrResult(f: OcrFields, ocrItems: OcrItem[]) {
  documentType.value = f.documentType ?? 'invoice'
  incomeDate.value = f.incurredAt ? new Date(`${f.incurredAt}T00:00:00`) : null
  taxId.value = f.counterpartyTaxId ?? ''
  customer.value = f.counterpartyName ?? ''
  const isInvoice = documentType.value === 'invoice'
  invoicePrefix.value = isInvoice ? (f.invoicePrefix ?? '').replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 2) : ''
  invoiceDigits.value = isInvoice ? (f.invoiceDigits ?? '').replace(/\D/g, '').slice(0, 8) : ''
  taxRate.value = f.taxRate ?? 'business_5'
  // 只讀到其中一個金額時，用稅率補齊另外兩欄
  if (f.amount !== null && (f.preTaxAmt === null || f.taxAmt === null)) {
    onAmountInput(f.amount)
  } else if (f.amount === null && f.preTaxAmt !== null) {
    onPreTaxInput(f.preTaxAmt)
  } else {
    preTaxAmt.value = f.preTaxAmt
    taxAmt.value = f.taxAmt
    amount.value = f.amount
  }
  items.value = ocrItems.map((it) => ({ ...it }))
  ;(['date', 'taxId', 'customer', 'invoiceNo', 'amount'] as const).forEach(clearError)
}

const ocr = useOcrRecognize({
  role: 'income',
  apply: applyOcrResult,
  successDetail: '欄位已自動帶入，請核對後儲存',
  reviewHint: '辨識結果可能因字跡模糊、憑證污損等原因出錯，儲存前請再次核對各欄位。',
})
const isRecognizing = ocr.isRecognizing
const ocrQuotaText = ocr.quotaText
const ocrReviewHint = ocr.reviewHint
const ocrConflict = ocr.conflict

/** 不辨識的憑證（當作補充資料）；預設全部辨識，含 PDF */
const ocrExcluded = ref(new Set<IncomeAttachment>())
function toggleOcr(att: IncomeAttachment) {
  if (ocrExcluded.value.has(att)) ocrExcluded.value.delete(att)
  else ocrExcluded.value.add(att)
}
/** 編輯時從後端載入的已存檔憑證；不能再送辨識，只有新上傳的可以（規格 §6 前端帶入規則） */
const savedAttachments = ref(new Set<IncomeAttachment>())
/** 要送辨識的憑證：已勾選、且不是已存檔的 */
function isOcrTarget(att: IncomeAttachment) {
  return !savedAttachments.value.has(att) && !ocrExcluded.value.has(att)
}
const ocrSelectedCount = computed(() => attachments.value.filter(isOcrTarget).length)

/** 已辨識過的憑證張數；之後再辨識要提示會覆蓋表單內容 */
const recognizedCount = ref(0)

/** 新增模式「清除所有欄位」：欄位回到剛進新增頁的預設值，已上傳的憑證保留 */
function clearForm() {
  formReset.reset()
  accountId.value = lastUsedAccountId.value
  recognizedCount.value = 0
  toast.add({ severity: 'info', summary: '已清除所有欄位', detail: '已上傳的憑證仍保留', life: 2500 })
}
const recognizeLabel = computed(() => {
  if (isRecognizing.value) return '辨識中…'
  const n = ocrSelectedCount.value
  if (n === 0) {
    return attachments.value.every((a) => savedAttachments.value.has(a)) ? '上傳新憑證才能辨識' : '請勾選要辨識的憑證'
  }
  return `${recognizedCount.value ? '重新' : ''}辨識已選的 ${n} 張`
})

/** 已辨識過、或表單已有內容時，先確認會覆蓋 */
function startRecognize() {
  if (ocrSelectedCount.value === 0 || isRecognizing.value) return
  if (recognizedCount.value === 0 && !hasFormInput()) {
    void runRecognize()
    return
  }
  const n = ocrSelectedCount.value
  confirm.require({
    header: '重新辨識',
    message: `會用目前 ${n} 張憑證的辨識結果，覆蓋表單已填的日期、客戶、金額與品項等內容。確定要繼續嗎？`,
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '覆蓋並辨識',
    rejectLabel: '取消',
    accept: () => void runRecognize(),
  })
}

async function runRecognize() {
  const sources: OcrSource[] = []
  for (const [i, att] of attachments.value.entries()) {
    if (!isOcrTarget(att)) continue
    try {
      sources.push({ file: await dataUrlToFile(att.dataUrl, att.filename, att.mimeType), label: `憑證 ${i + 1}` })
    } catch {
      toast.add({ severity: 'error', summary: `${att.filename} 讀取失敗`, detail: '請移除後重新上傳', life: 3500 })
      return
    }
  }
  if (await ocr.run(sources)) recognizedCount.value = sources.length
}

// ─── 「有任何輸入？」用於離開頁守衛 ──────────────
/** 這一筆的欄位是否已有內容（不含憑證本身） */
function pageHasContent(p: IncomeFormPageData): boolean {
  return (
    !!p.categoryId ||
    (p.amount ?? 0) > 0 ||
    !!p.incomeDate ||
    p.customer.trim().length > 0 ||
    (p.preTaxAmt ?? 0) > 0 ||
    (p.taxAmt ?? 0) > 0 ||
    p.taxId.trim().length > 0 ||
    p.invoiceNo.trim().length > 0 ||
    p.note.trim().length > 0 ||
    p.items.length > 0
  )
}

function hasFormInput(): boolean {
  return pageHasContent(currentAsPageData())
}

function hasAnyInput(): boolean {
  if (isEditMode.value) return false
  if (attachments.value.length > 0) return true
  if (isMultiPage.value) {
    syncCurrentPageState()
    return pages.value.some(pageHasContent)
  }
  return hasFormInput()
}

// ─── 分頁 state 同步 ──────────────────────────────
function currentAsPageData(): IncomeFormPageData {
  return {
    documentType: documentType.value,
    incomeDate: incomeDate.value,
    taxId: taxId.value,
    customer: customer.value,
    invoiceNo: combinedInvoiceNo(),
    taxRate: taxRate.value,
    preTaxAmt: preTaxAmt.value,
    taxAmt: taxAmt.value,
    amount: amount.value,
    items: items.value.map((it) => ({ ...it })),
    categoryId: categoryId.value,
    accountId: accountId.value,
    collectionStatus: collectionStatus.value,
    collectedAt: collectedAt.value,
    note: note.value,
    attachments: [...attachments.value],
  }
}

function loadPageData(p: IncomeFormPageData) {
  documentType.value = p.documentType
  incomeDate.value = p.incomeDate
  taxId.value = p.taxId
  customer.value = p.customer
  const split = splitInvoiceNo(p.invoiceNo)
  invoicePrefix.value = split.prefix
  invoiceDigits.value = split.digits
  taxRate.value = p.taxRate
  preTaxAmt.value = p.preTaxAmt
  taxAmt.value = p.taxAmt
  amount.value = p.amount
  items.value = p.items.map((it) => ({ ...it }))
  categoryId.value = p.categoryId
  accountId.value = p.accountId
  collectionStatus.value = p.collectionStatus
  collectedAt.value = p.collectedAt
  note.value = p.note
  attachments.value = [...p.attachments]
  ;(Object.keys(fieldErrors) as (keyof typeof fieldErrors)[]).forEach(clearError)
}

function syncCurrentPageState() {
  if (pages.value.length === 0) return
  pages.value[currentPageIndex.value] = currentAsPageData()
}

function onPageChange(newIndex: number) {
  if (newIndex < 0 || newIndex >= pages.value.length || newIndex === currentPageIndex.value) return
  syncCurrentPageState()
  carryAccount(pages.value[newIndex])
  currentPageIndex.value = newIndex
  loadPageData(pages.value[newIndex])
}

/** 不要這筆（例如框到的不是憑證）：從分頁移除、不建立；已扣的辨識次數不退（§5.5） */
function removeCurrentPage() {
  confirm.require({
    header: '移除這筆',
    message: '移除後這筆不會建立，也不能復原；已扣的辨識次數不會退回。確定要移除嗎？',
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: '移除',
    rejectLabel: '取消',
    acceptProps: { severity: 'danger' },
    accept: () => {
      pages.value.splice(currentPageIndex.value, 1)
      currentPageIndex.value = Math.min(currentPageIndex.value, pages.value.length - 1)
      carryAccount(pages.value[currentPageIndex.value])
      loadPageData(pages.value[currentPageIndex.value])
    },
  })
}

// ─── 驗證 ──────────────────────────────────────────
function validate(): boolean {
  fieldErrors.category = !categoryId.value ? '請選擇收入類別' : ''
  fieldErrors.account = !accountId.value ? '請選擇帳戶' : ''
  fieldErrors.amount = !amount.value || amount.value <= 0 ? '請填寫含稅金額' : ''
  fieldErrors.date = !incomeDate.value ? '請選擇開立日期' : ''
  const taxIdRaw = taxId.value.trim()
  if (!taxIdRaw) {
    fieldErrors.taxId = ''
  } else if (!/^\d{8}$/.test(taxIdRaw)) {
    fieldErrors.taxId = '買方統編應為 8 碼數字'
  } else {
    fieldErrors.taxId = ''
  }
  fieldErrors.customer = !customer.value.trim() ? '請填寫客戶名稱' : ''
  fieldErrors.collectedAt =
    collectionStatus.value === 'collected' && !collectedAt.value
      ? '請選擇收款日'
      : ''
  if (documentType.value === 'invoice') {
    const p = invoicePrefix.value.trim().toUpperCase()
    const d = invoiceDigits.value.trim()
    if (!p && !d) {
      fieldErrors.invoiceNo = isRecurringRecord.value ? '' : '發票號碼必填'
    } else if (!/^[A-Z]{2}$/.test(p)) {
      fieldErrors.invoiceNo = '前段需為 2 個英文字母'
    } else if (!/^\d{8}$/.test(d)) {
      fieldErrors.invoiceNo = '後段需為 8 碼數字'
    } else if (!INVOICE_NUMBER_REGEX.test(combinedInvoiceNo(p, d))) {
      fieldErrors.invoiceNo = '格式應為 2 英文字 + 8 數字'
    } else {
      fieldErrors.invoiceNo = ''
    }
  } else {
    fieldErrors.invoiceNo = ''
  }
  return (
    !fieldErrors.category &&
    !fieldErrors.account &&
    !fieldErrors.amount &&
    !fieldErrors.date &&
    !fieldErrors.invoiceNo &&
    !fieldErrors.taxId &&
    !fieldErrors.customer &&
    !fieldErrors.collectedAt
  )
}
async function scrollToFirstError() {
  const order = ['date', 'taxId', 'customer', 'invoiceNo', 'amount', 'category', 'account', 'collectedAt'] as const
  const first = order.find((k) => fieldErrors[k])
  if (!first) return
  await nextTick()
  document.getElementById(`field-${first}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  document.getElementById(first)?.focus()
}

// ─── 送出 ──────────────────────────────────────────
function toCreatePayload(p: IncomeFormPageData): CreateIncomeRequest {
  return {
    customer: p.customer.trim(),
    taxId: p.taxId.trim() || null,
    invoiceNo: p.invoiceNo.trim() || null,
    documentType: p.documentType,
    taxRate: p.taxRate,
    preTaxAmt: p.preTaxAmt,
    taxAmt: p.taxAmt,
    amount: p.amount as number,
    categoryId: p.categoryId as string,
    accountId: p.accountId as string,
    date: toIsoDate(p.incomeDate as Date),
    note: p.note.trim() || null,
    attachments: p.attachments,
    items: p.items.filter((it) => it.name.trim().length > 0),
    collectionStatus: p.collectionStatus,
    collectedAt: p.collectionStatus === 'collected' && p.collectedAt
      ? toIsoDate(p.collectedAt)
      : null,
  }
}
function toUpdatePayload(): UpdateIncomeRequest {
  const base = toCreatePayload(currentAsPageData())
  // 狀態切換走 /collect / /revert-collect，PATCH 不帶 collectionStatus
  const { collectionStatus: _ignoredStatus, collectedAt: _ignoredAt, ...rest } = base
  return rest
}

/**
 * 編輯模式送出：
 * 1. 狀態與 original 不同 → 走 collect / revertCollect endpoint（AuditLog 會有 status_change 事件）
 * 2. 狀態同為 collected、僅收款日改變 → PATCH 帶 collectedAt
 * 3. 其他欄位變更 → PATCH 補送（Rails 端 assign_fields 只覆寫傳來的欄位）
 */
async function applyEditChanges(id: string) {
  const original = originalCollectionState.value
  if (!original) throw new Error('missing original collection state')
  const newStatus = collectionStatus.value
  const newDateIso = collectedAt.value ? toIsoDate(collectedAt.value) : null

  if (newStatus !== original.status) {
    if (newStatus === 'collected') {
      await collectIncome(id, newDateIso ? { collectedAt: newDateIso } : undefined)
    } else {
      await revertCollectIncome(id)
    }
  }

  const patch: UpdateIncomeRequest = toUpdatePayload()
  const sameStatusCollected =
    newStatus === original.status && newStatus === 'collected'
  if (sameStatusCollected && newDateIso && newDateIso !== original.dateIso) {
    patch.collectedAt = newDateIso
  }
  await updateIncome(id, patch)

  // 寫完後更新 originalCollectionState，避免同頁連續儲存時誤判
  originalCollectionState.value = { status: newStatus, dateIso: newDateIso }
}

/** 多筆建立部分失敗後，之前已建立的筆數；重送成功時提示寫全部建立的筆數 */
const createdBefore = ref(0)

/** 帳戶在填表期間被刪除：清掉該筆帳戶並重新取得清單，讓使用者重選 */
function markAccountMissing(err: unknown) {
  if (!isAccountUnavailable(err)) return
  accountId.value = null
  fieldErrors.account = '請重新選擇帳戶'
  void loadAccounts()
}

/** 批次帶出的多筆：全部驗證通過才開始建立，中途失敗時已建立的從分頁移除，重送不會重複建立 */
async function submitPages() {
  syncCurrentPageState()
  for (let i = 0; i < pages.value.length; i++) {
    if (i !== currentPageIndex.value) {
      carryAccount(pages.value[i])
      currentPageIndex.value = i
      loadPageData(pages.value[i])
    }
    if (!validate()) {
      await scrollToFirstError()
      return
    }
  }
  isSubmitting.value = true
  let created = 0
  for (const p of pages.value) {
    try {
      await createIncome(toCreatePayload(p))
      created++
    } catch (err) {
      // 跳回失敗的那一筆（驗證迴圈會停在最後一筆，這裡一律重新載入）
      pages.value = pages.value.slice(created)
      currentPageIndex.value = 0
      loadPageData(pages.value[0])
      markAccountMissing(err)
      createdBefore.value += created
      const failed = userErrorToast(err, '第 1 筆建立失敗')
      toast.add({
        severity: 'error',
        ...(createdBefore.value > 0
          ? { summary: `已建立 ${createdBefore.value} 筆，剩下 ${pages.value.length} 筆請修正後再送出`, detail: failed.detail }
          : failed),
        life: 3500,
      })
      isSubmitting.value = false
      return
    }
  }
  toast.add({ severity: 'success', summary: `已建立 ${createdBefore.value + created} 筆收入`, life: 2500 })
  isSubmitting.value = false
  allowLeave.value = true
  router.push({ name: 'admin-incomes' })
}

async function onSubmit() {
  if (isSubmitting.value) return
  if (isMultiPage.value) {
    await submitPages()
    return
  }
  if (!validate()) {
    await scrollToFirstError()
    return
  }
  isSubmitting.value = true
  try {
    if (isEditMode.value && editingId.value) {
      await applyEditChanges(editingId.value)
      toast.add({ severity: 'success', summary: '收入已更新', life: 2500 })
    } else {
      await createIncome(toCreatePayload(currentAsPageData()))
      toast.add({
        severity: 'success',
        summary: createdBefore.value > 0
          ? `已建立 ${createdBefore.value + 1} 筆收入`
          : collectionStatus.value === 'collected'
            ? '收入已建立（已收款）'
            : '收入已建立（待收款）',
        life: 2500,
      })
    }
    allowLeave.value = true
    router.push({ name: 'admin-incomes' })
  } catch (err) {
    markAccountMissing(err)
    toast.add({ severity: 'error', ...userErrorToast(err, '儲存失敗'), life: 3000 })
  } finally {
    isSubmitting.value = false
  }
}

// ─── 掛載：載入類別，編輯模式再 fetch 原始資料 ────
onMounted(async () => {
  try {
    activeCategories.value = await listCategories({ kind: 'income' })
  } catch {
    activeCategories.value = []
  }
  if (isEditMode.value && editingId.value) {
    try {
      const target = await getIncome(editingId.value)
      isRecurringRecord.value = !!target.recurringPeriod
      documentType.value = target.documentType
      incomeDate.value = target.date ? new Date(`${target.date}T00:00:00`) : null
      taxId.value = target.taxId ?? ''
      customer.value = target.customer
      const split = splitInvoiceNo(target.invoiceNo)
      invoicePrefix.value = split.prefix
      invoiceDigits.value = split.digits
      taxRate.value = target.taxRate
      preTaxAmt.value = target.preTaxAmt
      taxAmt.value = target.taxAmt
      amount.value = target.amount
      items.value = target.items.map((it) => ({ ...it }))
      categoryId.value = target.category.id
      // 類別若已停用、不在 active 清單 → 補一筆保留原名
      if (!categoryMap.value.has(target.category.id)) {
        activeCategories.value = [
          ...activeCategories.value,
          {
            id: target.category.id,
            kind: 'income',
            name: target.category.name,
            accountCode: target.category.accountCode,
            isArchived: false,
            sortOrder: Number.MAX_SAFE_INTEGER,
            createdAt: '',
            updatedAt: '',
          },
        ]
      }
      accountId.value = target.account.id
      addAccountOption(target.account)
      note.value = target.note ?? ''
      attachments.value = target.attachments.map((a) => ({ ...a }))
      savedAttachments.value = new Set(attachments.value)
      collectionStatus.value = target.collectionStatus
      collectedAt.value = target.collectedAt ? new Date(`${target.collectedAt}T00:00:00`) : null
      originalCollectionState.value = {
        status: target.collectionStatus,
        dateIso: target.collectedAt,
      }
    } catch (err) {
      const notFound = err instanceof HttpError && err.status === 404
      toast.add({
        severity: 'error',
        summary: notFound ? '找不到該筆收入' : '載入失敗',
        detail: notFound ? '可能已被刪除；已為你返回列表' : '請稍後再試',
        life: 3000,
      })
      allowLeave.value = true
      router.replace({ name: 'admin-incomes' })
    }
    return
  }

  const imported = stagedIncomePages.take()
  if (!imported) return
  fromImport.value = true
  pages.value = imported
  currentPageIndex.value = 0
  loadPageData(pages.value[0])
  const noAttachment = imported.filter((p) => p.attachments.length === 0).length
  toast.add({
    severity: 'info',
    summary: `已載入 ${imported.length} 筆匯入資料`,
    detail: noAttachment
      ? `請逐筆核對後按「建立」；其中 ${noAttachment} 筆沒有憑證檔案，請在該筆補上`
      : '請逐筆核對後按「建立」',
    life: 3000,
  })
})

// 批次匯入憑證已扣次，暫存只在記憶體：重新整理或關分頁前用瀏覽器提示擋一下
function onBeforeUnload(e: BeforeUnloadEvent) {
  if (!fromImport.value || allowLeave.value) return
  e.preventDefault()
  e.returnValue = ''
}
window.addEventListener('beforeunload', onBeforeUnload)
onBeforeUnmount(() => window.removeEventListener('beforeunload', onBeforeUnload))

// ─── 離開頁守衛 ────────────────────────────────────
onBeforeRouteLeave(() => {
  if (allowLeave.value) return true
  if (!hasAnyInput()) return true
  return new Promise<boolean>((resolve) => {
    let done = false
    const settle = (v: boolean) => {
      if (done) return
      done = true
      resolve(v)
    }
    confirm.require({
      header: '離開表單頁',
      message: '目前填寫的內容尚未儲存，離開後將會遺失。確定要離開嗎？',
      icon: 'pi pi-exclamation-triangle',
      acceptLabel: '離開',
      rejectLabel: '留下',
      acceptProps: { severity: 'danger' },
      accept: () => settle(true),
      reject: () => settle(false),
      onHide: () => settle(false),
    })
  })
})
</script>

<template>
  <div class="p-4 sm:p-6">
    <PageHeader :title="pageTitle" size="admin">
      <template #actions>
        <div class="flex flex-col items-start gap-1 sm:items-end">
          <Button
            label="返回列表"
            text
            icon="pi pi-arrow-left"
            @click="router.push({ name: 'admin-incomes' })"
          />
          <Button
            v-if="!isEditMode && !fromImport"
            label="清除所有欄位"
            text
            icon="pi pi-eraser"
            :disabled="isRecognizing"
            @click="clearForm"
          />
        </div>
      </template>
    </PageHeader>

    <form @submit.prevent="onSubmit">
      <!-- 辨識中整份表單暫停編輯，避免結果回來時覆蓋到正在輸入的欄位；建立多筆時也暫停，避免中途換頁 -->
      <fieldset class="space-y-5 min-w-0" :disabled="isRecognizing || isSubmitting" :aria-busy="isRecognizing || isSubmitting">
      <!-- 1. 憑證上傳 + 開始辨識（批次匯入憑證進入時：只顯示這一筆自己的憑證、可補上傳，不提供辨識，避免重複扣次） -->
      <div>
        <div class="field-label">憑證（發票/收據）</div>
        <div class="card p-4 space-y-3">
          <div
            v-if="attachments.length > 0"
            class="grid grid-cols-4 sm:grid-cols-5 gap-2 items-start"
          >
            <div
              v-for="(att, i) in attachments"
              :key="i"
              class="att-cell"
              :class="{ 'is-off': !isOcrTarget(att) }"
            >
              <div class="relative aspect-square">
                <button
                  type="button"
                  class="att-thumb absolute inset-0 w-full h-full rounded-chip border border-[var(--color-hairline)] bg-white overflow-hidden cursor-pointer block"
                  :aria-label="`預覽 ${att.filename}`"
                  @click="previewAtt = att"
                >
                  <img
                    v-if="isImageAttachment(att.mimeType)"
                    :src="att.dataUrl"
                    :alt="att.filename"
                    class="w-full h-full object-cover"
                  />
                  <span
                    v-else
                    class="w-full h-full flex flex-col items-center justify-center gap-1 bg-[var(--color-surface)]"
                  >
                    <i class="pi pi-file-pdf text-3xl text-[var(--color-danger)]" aria-hidden="true" />
                    <span class="text-xs font-semibold text-[var(--color-slate)]">PDF</span>
                  </span>
                </button>
                <label v-if="!fromImport && !savedAttachments.has(att)" class="att-pick" :title="ocrExcluded.has(att) ? '不辨識（補充資料）' : '辨識這張'">
                  <input type="checkbox" :checked="!ocrExcluded.has(att)" :aria-label="`辨識 ${att.filename}`" @change="toggleOcr(att)" />
                </label>
                <button
                  type="button"
                  class="absolute -top-1.5 -right-1.5 z-10 w-6 h-6 rounded-full bg-[var(--color-ink)] text-white flex items-center justify-center hover:opacity-90"
                  :aria-label="`移除 ${att.filename}`"
                  @click="removeAttachment(i)"
                >
                  <i class="pi pi-times text-xs" aria-hidden="true" />
                </button>
              </div>
              <span class="att-name" :title="att.filename">{{ att.filename }}</span>
            </div>
            <label
              v-if="attachments.length < MAX_ATTACHMENTS"
              class="att-add aspect-square"
              :class="{ 'is-drag': isDragging }"
              @dragover.prevent="isDragging = true"
              @dragleave="isDragging = false"
              @drop.prevent="onAttachmentDrop"
            >
              <i class="pi pi-plus" aria-hidden="true" />
              <span>加入</span>
              <small>JPG／PNG／PDF</small>
              <input type="file" accept="image/*,application/pdf,.pdf" multiple class="hidden" @change="onAttachmentChange" />
            </label>
          </div>

          <label
            v-if="attachments.length === 0"
            class="upload-drop form-drop"
            :class="{ 'is-drag': isDragging }"
            @dragover.prevent="isDragging = true"
            @dragleave="isDragging = false"
            @drop.prevent="onAttachmentDrop"
          >
            <i class="pi pi-cloud-upload upload-drop-icon" aria-hidden="true" />
            <b>拖放檔案，或點擊上傳</b>
            <span>JPG、PNG 或 PDF，可一次選多張（最多 {{ MAX_ATTACHMENTS }} 張），單檔 {{ MAX_ATTACHMENT_MB }}MB 以內</span>
            <input
              type="file"
              accept="image/*,application/pdf,.pdf"
              multiple
              class="hidden"
              @change="onAttachmentChange"
            />
          </label>
          <Button
            v-else-if="!fromImport"
            type="button"
            :label="recognizeLabel"
            :icon="isRecognizing ? 'pi pi-spin pi-spinner' : 'pi pi-sparkles'"
            :disabled="isRecognizing || ocrSelectedCount === 0"
            @click="startRecognize"
          />

          <p v-if="fromImport && attachments.length === 0" class="alert-warn" role="status">
            <i class="pi pi-exclamation-triangle" aria-hidden="true" />
            這筆沒有帶出憑證檔案，請上傳這筆的發票或收據。
          </p>
          <p v-else-if="fromImport" class="text-sm text-[var(--color-muted)]">
            這是批次辨識時這筆所在的那一頁，建立時只會附上這一筆的憑證。
          </p>
          <p v-if="!fromImport" class="mt-2 text-sm text-[var(--color-muted)]">
            <template v-if="attachments.length === 0">
              上傳後可使用辨識功能帶入開立日期、客戶與金額。
            </template>
            <template v-else>
              勾選的憑證會合併辨識，沒勾的當補充資料，不會扣辨識次數。<template v-if="attachments.some((a) => savedAttachments.has(a))">已存檔的憑證不能再辨識；如需重新辨識，請移除後重新上傳。</template>
            </template>
          </p>
          <p v-if="!fromImport && ocrQuotaText" class="text-sm text-[var(--color-muted)]" aria-live="polite">
            <i class="pi pi-sparkles text-xs" aria-hidden="true" /> OCR 辨識{{ ocrQuotaText }}
          </p>
          <p class="text-sm text-[var(--color-muted)]">
            <i class="pi pi-info-circle text-xs" aria-hidden="true" /> {{ ocrReviewHint }}
          </p>
        </div>
      </div>

      <!-- 2. 憑證類型 -->
      <div>
        <div class="field-label">憑證類型</div>
        <div class="choice-cards doc-type-cards" role="radiogroup" aria-label="憑證類型">
          <label v-for="opt in DOCUMENT_TYPE_OPTIONS" :key="opt.value" :for="`doc-${opt.value}`">
            <input
              :id="`doc-${opt.value}`"
              :checked="documentType === opt.value"
              :value="opt.value"
              type="radio"
              name="documentType"
              @change="setDocumentType(opt.value as DocumentType)"
            />
            <span>
              {{ opt.label }}
              <small>{{ opt.value === 'invoice' ? '統一發票，含發票號碼與營業稅額' : '收據或免用發票收據，無發票號碼與稅額' }}</small>
            </span>
          </label>
        </div>
      </div>

      <!-- 3. 開立日期 / 買方統編 / 客戶名稱 / 發票號碼 -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div id="field-date">
          <label for="date" class="field-label">
            開立日期 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <DatePicker
            v-model="incomeDate"
            input-id="date"
            date-format="yy-mm-dd"
            placeholder="請選擇日期"
            show-icon
            icon-display="input"
            class="w-full"
            @update:model-value="clearError('date')"
          />
          <p v-if="fieldErrors.date" class="mt-1 text-sm text-[var(--color-status-rejected)]">
            {{ fieldErrors.date }}
          </p>
        </div>
        <div id="field-taxId">
          <label for="taxId" class="field-label">
            買方統編
            <span class="field-optional">（選填）</span>
          </label>
          <InputText
            id="taxId"
            v-model="taxId"
            placeholder="8 碼數字"
            maxlength="8"
            inputmode="numeric"
            class="w-full"
            @update:model-value="clearError('taxId')"
          />
          <p v-if="fieldErrors.taxId" class="mt-1 text-sm text-[var(--color-status-rejected)]">
            {{ fieldErrors.taxId }}
          </p>
        </div>
        <div id="field-customer">
          <label for="customer" class="field-label">
            客戶名稱 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <InputText
            id="customer"
            v-model="customer"
            placeholder="例：鉅邦科技有限公司"
            class="w-full"
            @update:model-value="clearError('customer')"
          />
          <p v-if="fieldErrors.customer" class="mt-1 text-sm text-[var(--color-status-rejected)]">
            {{ fieldErrors.customer }}
          </p>
        </div>
        <div v-if="documentType === 'invoice'" id="field-invoiceNo">
          <label for="invoicePrefix" class="field-label">
            發票號碼 <span v-if="!isRecurringRecord" class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <div class="flex items-center gap-2">
            <InputText
              id="invoicePrefix"
              :model-value="invoicePrefix"
              placeholder="AB"
              maxlength="2"
              class="w-16 sm:w-20 text-center uppercase tabular-nums"
              autocomplete="off"
              inputmode="text"
              aria-label="發票號碼前段（英文 2 碼）"
              @update:model-value="(v) => onInvoicePrefixInput(String(v ?? ''))"
            />
            <span class="text-[var(--color-muted)] tabular-nums select-none" aria-hidden="true">-</span>
            <InputText
              id="invoiceDigits"
              :model-value="invoiceDigits"
              placeholder="12345678"
              maxlength="8"
              inputmode="numeric"
              class="flex-1 tabular-nums"
              autocomplete="off"
              aria-label="發票號碼後段（數字 8 碼）"
              @update:model-value="(v) => onInvoiceDigitsInput(String(v ?? ''))"
              @keydown="onInvoiceDigitsKeydown"
            />
          </div>
          <p v-if="fieldErrors.invoiceNo" class="mt-1 text-sm text-[var(--color-status-rejected)]">
            {{ fieldErrors.invoiceNo }}
          </p>
        </div>
      </div>

      <!-- 4. 金額 -->
      <div id="field-amount">
        <div class="field-label">
          金額 <span class="text-[var(--color-status-rejected)]">*</span>
        </div>
        <div :class="documentType === 'invoice' ? 'grid grid-cols-1 sm:grid-cols-3 gap-3' : 'grid grid-cols-1 sm:grid-cols-2 gap-3'">
          <div v-if="documentType === 'invoice'">
            <label for="preTaxAmt" class="field-sublabel mb-1 block">未稅金額</label>
            <InputNumber
              :model-value="preTaxAmt"
              input-id="preTaxAmt"
              mode="currency"
              currency="TWD"
              locale="zh-TW"
              :min-fraction-digits="0"
              :max-fraction-digits="0"
              :min="0"
              placeholder="0"
              class="w-full"
              input-class="w-full"
              @update:model-value="onPreTaxInput"
            />
          </div>
          <div v-if="documentType === 'invoice'">
            <label for="taxRate" class="field-sublabel mb-1 block">稅率</label>
            <Select
              :model-value="taxRate"
              input-id="taxRate"
              :options="TAX_RATE_OPTIONS"
              option-label="label"
              option-value="value"
              class="w-full"
              :disabled="isRecognizing"
              @update:model-value="onTaxRateChange"
            />
          </div>
          <div>
            <label for="amount" class="field-sublabel mb-1 block">
              {{ documentType === 'invoice' ? '含稅金額' : '總金額' }}
            </label>
            <InputNumber
              :model-value="amount"
              input-id="amount"
              mode="currency"
              currency="TWD"
              locale="zh-TW"
              :min-fraction-digits="0"
              :max-fraction-digits="0"
              :min="0"
              placeholder="0"
              class="w-full"
              input-class="w-full"
              @update:model-value="onAmountInput"
            />
          </div>
        </div>
        <p v-if="taxAmountText" class="mt-1 text-sm text-[var(--color-muted)] tabular-nums">
          {{ taxAmountText }}
        </p>
        <p v-if="fieldErrors.amount" class="mt-1 text-sm text-[var(--color-status-rejected)]">
          {{ fieldErrors.amount }}
        </p>
      </div>

      <!-- 5. 品項 -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <div class="field-label !mb-0">品項</div>
          <Button
            v-if="items.length > 0"
            type="button"
            label="新增品項"
            icon="pi pi-plus"
            size="small"
            text
            @click="addItem"
          />
        </div>
        <div v-if="items.length === 0" class="items-empty">
          <b>尚未加入品項</b>
          <span>品項為選填，需要明細時再新增。</span>
          <Button type="button" label="新增品項" icon="pi pi-plus" outlined @click="addItem" />
        </div>
        <div v-else class="space-y-3 sm:space-y-2">
          <div class="hidden sm:flex items-center gap-2 field-sublabel" aria-hidden="true">
            <div class="flex-1 basis-0 min-w-0">品項名稱</div>
            <div class="w-32">數量</div>
            <div class="w-32">單價</div>
            <div class="w-32">小計</div>
            <div class="w-8" />
          </div>

          <div v-for="(it, i) in items" :key="i">
            <!-- Desktop -->
            <div class="hidden sm:flex items-center gap-2">
              <InputText
                v-model="it.name"
                placeholder="例：顧問服務費"
                :aria-label="`第 ${i + 1} 筆品項名稱`"
                class="flex-1 basis-0 min-w-0"
              />
              <InputNumber
                v-model="it.quantity"
                :min="0"
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                :aria-label="`第 ${i + 1} 筆數量`"
                class="w-32"
                input-class="w-full"
                placeholder="數量"
                @update:model-value="recomputeItemSubtotal(i)"
              />
              <InputNumber
                v-model="it.unitPrice"
                :min="0"
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                :aria-label="`第 ${i + 1} 筆單價`"
                class="w-32"
                input-class="w-full"
                placeholder="單價"
                @update:model-value="recomputeItemSubtotal(i)"
              />
              <InputNumber
                :model-value="it.subtotal"
                disabled
                :min-fraction-digits="0"
                :max-fraction-digits="0"
                :aria-label="`第 ${i + 1} 筆小計`"
                class="w-32"
                input-class="w-full"
                placeholder="小計"
              />
              <Button
                type="button"
                severity="secondary"
                text
                rounded
                icon="pi pi-trash"
                size="small"
                :aria-label="`移除第 ${i + 1} 筆品項`"
                class="flex-none"
                @click="removeItem(i)"
              />
            </div>

            <!-- Mobile -->
            <div class="sm:hidden flex flex-col gap-2 rounded-lg border border-[var(--color-hairline)] p-2">
              <div class="flex items-center gap-2">
                <InputText
                  v-model="it.name"
                  placeholder="例：顧問服務費"
                  :aria-label="`第 ${i + 1} 筆品項名稱`"
                  class="flex-1"
                />
                <Button
                  type="button"
                  severity="secondary"
                  text
                  rounded
                  icon="pi pi-trash"
                  size="small"
                  :aria-label="`移除第 ${i + 1} 筆品項`"
                  class="flex-none"
                  @click="removeItem(i)"
                />
              </div>
              <div class="grid grid-cols-3 gap-2">
                <div>
                  <label class="block field-sublabel mb-1" :for="`m-qty-${i}`">數量</label>
                  <InputNumber
                    v-model="it.quantity"
                    :input-id="`m-qty-${i}`"
                    :min="0"
                    :min-fraction-digits="0"
                    :max-fraction-digits="0"
                    class="w-full"
                    input-class="w-full"
                    placeholder="0"
                    @update:model-value="recomputeItemSubtotal(i)"
                  />
                </div>
                <div>
                  <label class="block field-sublabel mb-1" :for="`m-unit-${i}`">單價</label>
                  <InputNumber
                    v-model="it.unitPrice"
                    :input-id="`m-unit-${i}`"
                    :min="0"
                    :min-fraction-digits="0"
                    :max-fraction-digits="0"
                    class="w-full"
                    input-class="w-full"
                    placeholder="0"
                    @update:model-value="recomputeItemSubtotal(i)"
                  />
                </div>
                <div>
                  <label class="block field-sublabel mb-1" :for="`m-sub-${i}`">小計</label>
                  <InputNumber
                    :model-value="it.subtotal"
                    :input-id="`m-sub-${i}`"
                    disabled
                    :min-fraction-digits="0"
                    :max-fraction-digits="0"
                    class="w-full"
                    input-class="w-full"
                    placeholder="0"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 6. 類別 + 收款狀態 / 收款日（鏡像 ExpenseFormView；編輯模式亦可修改） -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div id="field-category">
          <label for="category" class="field-label">
            收入類別 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <AutoComplete
            ref="categoryAutoComplete"
            v-model="categoryObj"
            input-id="category"
            :suggestions="categorySuggestions"
            option-label="label"
            placeholder="請選擇類別"
            :force-selection="false"
            class="w-full"
            input-class="w-full"
            @focus="onCategoryFocus"
            @complete="searchCategoriesEvent"
            @option-select="onCategorySelect"
          >
            <template #option="{ option }">
              <div class="flex items-center justify-between gap-3 w-full">
                <span :class="option.isNew ? 'text-[var(--color-primary)] font-medium' : ''">
                  {{ option.label }}
                </span>
                <span
                  v-if="option.accountCode"
                  class="text-sm text-[var(--color-muted)] tabular-nums"
                  aria-hidden="true"
                >
                  {{ option.accountCode }}
                </span>
              </div>
            </template>
          </AutoComplete>
          <p v-if="fieldErrors.category" class="mt-1 text-sm text-[var(--color-status-rejected)]">
            {{ fieldErrors.category }}
          </p>
        </div>
        <div id="field-account">
          <label id="account-label" for="account" class="field-label">
            帳戶 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <AccountSelect
            v-model="accountId"
            input-id="account"
            labelled-by="account-label"
            :options="accountOptions"
            :loading="accountsLoading"
            :invalid="!!fieldErrors.account"
            :error-id="fieldErrors.account ? 'account-error' : undefined"
            :disabled="isRecognizing"
            @update:model-value="clearError('account')"
            @created="addAccountOption"
          />
          <p
            v-if="fieldErrors.account"
            id="account-error"
            class="mt-1 text-sm text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.account }}
          </p>
        </div>

        <div class="flex gap-4">
          <div id="field-collectionStatus" class="flex-1 min-w-0">
            <label for="collectionStatus" class="field-label">
              收款狀態 <span class="text-[var(--color-status-rejected)]">*</span>
            </label>
            <Select
              v-model="collectionStatus"
              input-id="collectionStatus"
              :options="COLLECTION_STATUS_OPTIONS"
              option-label="label"
              option-value="value"
              class="w-full"
              :disabled="isRecognizing"
            />
          </div>
          <div
            v-if="collectionStatus === 'collected'"
            id="field-collectedAt"
            class="flex-1 min-w-0"
          >
            <label for="collectedAt" class="field-label">
              收款日 <span class="text-[var(--color-status-rejected)]">*</span>
            </label>
            <DatePicker
              v-model="collectedAt"
              input-id="collectedAt"
              date-format="yy-mm-dd"
              placeholder="請選擇收款日"
              show-icon
              icon-display="input"
              class="w-full"
              @update:model-value="clearError('collectedAt')"
            />
            <p
              v-if="fieldErrors.collectedAt"
              class="mt-1 text-sm text-[var(--color-status-rejected)]"
            >
              {{ fieldErrors.collectedAt }}
            </p>
          </div>
        </div>
        <CashFlowExcludedHint
          class="sm:col-span-2"
          date-label="收款日"
          :date="collectionStatus === 'collected' ? collectedAt : null"
          :account="selectedAccount"
        />
      </div>

      <!-- 7. 備註 -->
      <div>
        <label for="note" class="field-label">描述</label>
        <Textarea
          id="note"
          v-model="note"
          auto-resize
          rows="2"
          class="w-full"
          placeholder="選填"
        />
      </div>

      <!-- 分頁元件（多筆才顯示；編輯模式不顯示） -->
      <div v-if="isMultiPage" class="flex flex-wrap items-center justify-center gap-2 pt-2">
        <ExpenseFormPagination
          :total="pages.length"
          :current="currentPageIndex"
          @change="onPageChange"
        />
        <Button
          type="button"
          label="移除這筆"
          icon="pi pi-trash"
          severity="secondary"
          text
          size="small"
          @click="removeCurrentPage"
        />
      </div>

      <!-- 送出 -->
      <div class="flex flex-col-reverse sm:flex-row justify-end gap-2 pt-2">
        <Button
          type="button"
          label="取消"
          outlined
          :disabled="isSubmitting"
          @click="router.push({ name: 'admin-incomes' })"
        />
        <Button type="submit" :label="submitLabel" :loading="isSubmitting" />
      </div>
      </fieldset>
    </form>

    <AttachmentPreviewDialog
      :src="previewAtt?.dataUrl ?? null"
      :filename="previewAtt?.filename"
      :mime-type="previewAtt?.mimeType"
      @close="previewAtt = null"
    />

    <OcrConflictDialog
      :conflict="ocrConflict"
      role="income"
      @confirm="ocr.resolveConflicts"
      @close="ocr.dismissConflicts"
    />
  </div>
</template>
