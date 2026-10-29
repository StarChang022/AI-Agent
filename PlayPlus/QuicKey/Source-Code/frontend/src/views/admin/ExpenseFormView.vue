<script setup lang="ts">
import AttachmentPreviewDialog from '@/components/AttachmentPreviewDialog.vue'
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import type {
  DocumentType,
  ExpenseAttachment,
  ExpenseItem,
  PayoutStatus,
  TaxRate,
} from '@/types/domain'
import type { FormPageData } from '@/types/expense-form'
import { useAuthStore } from '@/stores/auth'
import {
  createExpense,
  getExpense,
  updateExpense as apiUpdateExpense,
  payExpense,
  revertPayExpense,
  type CreateExpenseRequest,
  type UpdateExpenseRequest,
} from '@/api/expenses'
import { takeImportedPages } from '@/composables/useStagedExpenseImport'
import { dataUrlToFile, useOcrRecognize, type OcrSource } from '@/composables/useOcrRecognize'
import { useFormReset } from '@/composables/useFormReset'
import OcrConflictDialog from '@/components/OcrConflictDialog.vue'
import type { OcrFields, OcrItem } from '@/api/ocr'
import {
  listCategories,
  createCategory,
  type Category,
} from '@/api/categories'
import { HttpError } from '@/api/service'
import {
  DOCUMENT_TYPE_OPTIONS,
  INVOICE_NUMBER_REGEX,
  TAX_RATE_OPTIONS,
  getTaxRateValue,
} from '@/constants/expense'
import { toIsoDate } from '@/utils/format'
import ExpenseFormPagination from '@/components/ExpenseFormPagination.vue'
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

const auth = useAuthStore()
const route = useRoute()

/**
 * 編輯模式下記錄載入當下的付款狀態；提交時用來判斷是否要走 /pay 或 /revert-pay。
 */
const loadedPayoutStatus = ref<PayoutStatus | null>(null)

/**
 * 使用中支出類別清單（進頁 fetch 一次）；提供下拉來源 + 新增類別後 push 進 local。
 * 類別 lookup（id → name/accountCode）用 Map 以 O(1) 查詢。
 */
const activeCategories = ref<Category[]>([])
const categoryMap = computed(() => {
  const m = new Map<string, Category>()
  for (const c of activeCategories.value) m.set(c.id, c)
  return m
})
onMounted(async () => {
  try {
    activeCategories.value = await listCategories({ kind: 'expense' })
  } catch {
    activeCategories.value = []
  }
})

const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

const allowLeave = ref(false)

// ─── 編輯模式（見 tasks.md §5.20 / router 的 admin-expense-edit）───
// route.name === 'admin-expense-edit' 且帶 params.id 時進入編輯模式：
// 從 store 找 expense 預填，onSubmit 走 updateExpense。找不到 → toast + 回列表。
const isEditMode = computed(() => route.name === 'admin-expense-edit')
const editingId = computed(() =>
  isEditMode.value ? (route.params.id as string) : null,
)

// ─── 表單 state ─────────────────────────────
const attachments = ref<ExpenseAttachment[]>([])
const documentType = ref<DocumentType>('invoice')
const incurredAt = ref<Date | null>(null)
const taxId = ref('')
const vendor = ref('')
// 發票號碼拆兩欄：前 2 碼英文 + 後 8 碼數字。組合成 `AB-12345678` 存回 domain。
const invoicePrefix = ref('')
const invoiceDigits = ref('')
const taxRate = ref<TaxRate>('business_5')
const preTaxAmt = ref<number | null>(null)
const taxAmt = ref<number | null>(null)
const amount = ref<number | null>(null)
const items = ref<ExpenseItem[]>([])
// categoryId 只存 Category.id；AutoComplete v-model 用 categoryObj computed 派生
const categoryId = ref<string | null>(null)
// 預設待付款，減少一次選擇；已付款再手動改
const payoutStatus = ref<PayoutStatus | null>('pending')
// 【原型】已付款時的付款日，預設今天；後端需新增 expenses.paid_at
const paidAt = ref<Date | null>(null)
watch(payoutStatus, (v) => {
  if (v === 'paid' && !paidAt.value) paidAt.value = new Date()
})
const note = ref('')

const PAYOUT_STATUS_OPTIONS: { value: PayoutStatus; label: string }[] = [
  { value: 'pending', label: '待付款' },
  { value: 'paid', label: '已付款' },
]

// ─── 多筆分頁狀態（見 design.md Decision 16 / tasks.md §6）───
// 圖片上傳/手動填表一律單頁（1 表單 = 1 支出）；只有 D 章節 PDF/Excel
// 批次匯入 Dialog 偵測到 N 張收據時才會 push N 筆到 pages 陣列。
// pages.length > 1 時 UI 顯示分頁元件；編輯模式一律單頁。
const pages = ref<FormPageData[]>([])
const currentPageIndex = ref(0)
const isMultiPage = computed(
  () => !isEditMode.value && pages.value.length > 1,
)

// 由 BatchImportDialog stage 資料進入的旗標。true 時隱藏憑證上傳區
// （批次匯入場景下憑證由後端連檔案一起處理；使用者這一步只做欄位核對）。
const fromImport = ref(false)

const fieldErrors = reactive({
  category: '',
  amount: '',
  incurredAt: '',
  invoiceNo: '',
  taxId: '',
  vendor: '',
  payoutStatus: '',
  paidAt: '',
})

function clearError(key: keyof typeof fieldErrors) {
  fieldErrors[key] = ''
}

// 「清除所有欄位」要還原的欄位；憑證不在內（清除時保留）
const formReset = useFormReset(
  [documentType, incurredAt, taxId, vendor, invoicePrefix, invoiceDigits, taxRate, preTaxAmt, taxAmt, amount, items, categoryId, payoutStatus, paidAt, note],
  fieldErrors,
)

// ─── 發票號碼拆 / 組 helpers ─────────────────
function splitInvoiceNo(raw: string | null): {
  prefix: string
  digits: string
} {
  if (!raw) return { prefix: '', digits: '' }
  const cleaned = raw.trim().replace(/-/g, '').toUpperCase()
  return {
    prefix: cleaned.slice(0, 2).replace(/[^A-Z]/g, ''),
    digits: cleaned.slice(2).replace(/\D/g, '').slice(0, 8),
  }
}

function combinedInvoiceNo(prefix = invoicePrefix.value, digits = invoiceDigits.value): string {
  const p = prefix.trim().toUpperCase()
  const d = digits.trim()
  if (!p && !d) return ''
  return `${p}-${d}`
}

function onInvoicePrefixInput(v: string) {
  const next = v.replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 2)
  const filled = next.length === 2 && invoicePrefix.value.length < 2
  invoicePrefix.value = next
  clearError('invoiceNo')
  // 英文 2 碼填滿就自動跳到數字欄
  if (filled) document.getElementById('invoiceDigits')?.focus()
}

function onInvoiceDigitsInput(v: string) {
  invoiceDigits.value = v.replace(/\D/g, '').slice(0, 8)
  clearError('invoiceNo')
}

/** 數字欄是空的時按 Backspace，跳回英文欄繼續刪 */
function onInvoiceDigitsKeydown(e: KeyboardEvent) {
  if (e.key === 'Backspace' && !invoiceDigits.value) {
    e.preventDefault()
    document.getElementById('invoicePrefix')?.focus()
  }
}

function pageHasContent(p: FormPageData): boolean {
  return (
    !!p.categoryId ||
    (p.amount ?? 0) > 0 ||
    !!p.incurredAt ||
    p.vendor.trim().length > 0 ||
    (p.preTaxAmt ?? 0) > 0 ||
    (p.taxAmt ?? 0) > 0 ||
    p.taxId.trim().length > 0 ||
    p.invoiceNo.trim().length > 0 ||
    p.note.trim().length > 0 ||
    p.items.length > 0
  )
}

function hasAnyInput(): boolean {
  if (attachments.value.length > 0) return true
  if (isMultiPage.value) {
    syncCurrentPageState()
    return pages.value.some(pageHasContent)
  }
  return pageHasContent(currentAsPageData())
}

// ─── 稅率 3 欄雙向連動 ───────────────────────
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
    // 切回發票：收據時自動設的免稅改回營業稅 5%，並重算未稅／稅額
    onTaxRateChange('business_5')
  }
}

const taxAmountText = computed(() => {
  const v = taxAmt.value
  if (documentType.value === 'receipt' || v === null || v <= 0) return ''
  return `營業稅額 NT$ ${v.toLocaleString('zh-TW')} 元`
})

// ─── 品項列表 ───────────────────────────────
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

// AutoComplete instance ref，focus 時 nextTick 主動 show() 展開面板
// （不使用 dropdown prop 以隱藏 chevron 按鈕）。
const categoryAutoComplete = ref<InstanceType<typeof AutoComplete> | null>(null)

// ─── 費用類別 AutoComplete + 新增類別 ──────
// 點擊 input 就 populate 全部（未停用）類別（見 tasks.md §5.9）；輸入無比對時
// 最後一筆為「新增類別「XX」+」，選擇後呼叫 createCategory API 建立新類別。
interface CategorySuggestion {
  value: string
  label: string
  accountCode: string
  isNew?: boolean
}

const NEW_CATEGORY_PREFIX = '__new__:'
const categorySuggestions = ref<CategorySuggestion[]>([])

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
  const matches: CategorySuggestion[] = all.filter(
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
    const created = await createCategory({ kind: 'expense', name })
    activeCategories.value = [...activeCategories.value, created]
    categoryId.value = created.id
    nextTick(() => refreshCategorySuggestions(''))
  } catch (err) {
    // 重複名時後端回 409 + 既有 category；直接選用該筆
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
    // Setter 已呼叫 createNewCategory；此處 refresh suggestions 讓下次立即看到新項
    nextTick(() => refreshCategorySuggestions(''))
  }
}

// ─── 憑證上傳 + 「開始辨識」 OCR ──────
/**
 * 辨識結果整份寫進表單：賣方 = 對方；辨識不到的欄位清空。
 * 類別、付款狀態、備註不是 OCR 會給的欄位，維持原值。
 */
function applyOcrResult(f: OcrFields, ocrItems: OcrItem[]) {
  documentType.value = f.documentType ?? 'invoice'
  incurredAt.value = f.incurredAt ? new Date(`${f.incurredAt}T00:00:00`) : null
  taxId.value = f.counterpartyTaxId ?? ''
  vendor.value = f.counterpartyName ?? ''
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
  pages.value = []
  currentPageIndex.value = 0
  ;(['incurredAt', 'taxId', 'vendor', 'invoiceNo', 'amount'] as const).forEach(clearError)
}

const ocr = useOcrRecognize({
  role: 'expense',
  apply: applyOcrResult,
  successDetail: '欄位已自動帶入，請核對後儲存',
})
const isRecognizing = ocr.isRecognizing
const ocrQuotaText = ocr.quotaText
const ocrConflict = ocr.conflict
const previewAtt = ref<ExpenseAttachment | null>(null)
const isDragging = ref(false)
/** 單檔上限；對齊後端 ReceiptAttachmentValidation::MAX_FILE_BYTES（5MB） */
const MAX_ATTACHMENT_MB = 5
/** 一筆支出最多幾張憑證（長收據可分 2–3 張拍） */
const MAX_ATTACHMENTS = 5

function isImageAttachment(mimeType: string): boolean {
  return mimeType.startsWith('image/')
}

function isPdfFile(file: File): boolean {
  return file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')
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
    toast.add({ severity: 'warn', summary: `最多上傳 ${MAX_ATTACHMENTS} 張憑證`, life: 3000 })
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
    // 多張：依序加在後面（例如長收據分段拍照）
    attachments.value.push({
      dataUrl: await readFileAsDataUrl(file),
      filename: file.name,
      // 有些系統選 PDF 時 file.type 會是空字串，用副檔名補上
      mimeType: file.type || (isPdfFile(file) ? 'application/pdf' : 'application/octet-stream'),
    })
  } catch {
    toast.add({
      severity: 'error',
      summary: `${file.name} 讀取失敗`,
      life: 2500,
    })
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
  for (const f of Array.from(event.dataTransfer?.files ?? [])) await addAttachmentFile(f)
}

function removeAttachment(index: number) {
  ocrExcluded.value.delete(attachments.value[index])
  attachments.value.splice(index, 1)
}

/** 【原型】不辨識的憑證（當作補充資料）；預設全部辨識，含 PDF */
const ocrExcluded = ref(new Set<ExpenseAttachment>())
function toggleOcr(att: ExpenseAttachment) {
  if (ocrExcluded.value.has(att)) ocrExcluded.value.delete(att)
  else ocrExcluded.value.add(att)
}
/** 編輯時從後端載入的已存檔憑證；不能再送辨識，只有新上傳的可以（規格 §6 前端帶入規則） */
const savedAttachments = ref(new Set<ExpenseAttachment>())
/** 要送辨識的憑證：已勾選、且不是已存檔的 */
function isOcrTarget(att: ExpenseAttachment) {
  return !savedAttachments.value.has(att) && !ocrExcluded.value.has(att)
}
const ocrSelectedCount = computed(() => attachments.value.filter(isOcrTarget).length)

/** 已辨識過的憑證張數；之後再辨識要提示會覆蓋表單內容 */
const recognizedCount = ref(0)

/** 新增模式「清除所有欄位」：欄位回到剛進新增頁的預設值，已上傳的憑證保留 */
function clearForm() {
  formReset.reset()
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

/**
 * 辨識：所有上傳的圖片視為同一張憑證（長收據分段拍），一起辨識後帶入表單。
 * 已辨識過、或表單已有內容時，先確認會覆蓋。
 */
function startRecognize() {
  if (ocrSelectedCount.value === 0 || isRecognizing.value) return
  const filled = recognizedCount.value > 0 || pageHasContent(currentAsPageData())
  if (!filled) {
    void runRecognize()
    return
  }
  const n = ocrSelectedCount.value
  confirm.require({
    header: '重新辨識',
    message: `會用目前 ${n} 張憑證的辨識結果，覆蓋表單已填的日期、賣方、金額與品項等內容。確定要繼續嗎？`,
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

// ─── 分頁 state 同步（見 tasks.md §6.2）───
function currentAsPageData(): FormPageData {
  return {
    documentType: documentType.value,
    incurredAt: incurredAt.value,
    taxId: taxId.value,
    vendor: vendor.value,
    invoiceNo: combinedInvoiceNo(),
    taxRate: taxRate.value,
    preTaxAmt: preTaxAmt.value,
    taxAmt: taxAmt.value,
    amount: amount.value,
    items: items.value.map((it) => ({ ...it })),
    categoryId: categoryId.value,
    payoutStatus: payoutStatus.value,
    paidAt: paidAt.value,
    note: note.value,
  }
}

function loadPageData(p: FormPageData) {
  documentType.value = p.documentType
  incurredAt.value = p.incurredAt
  taxId.value = p.taxId
  vendor.value = p.vendor
  const split = splitInvoiceNo(p.invoiceNo)
  invoicePrefix.value = split.prefix
  invoiceDigits.value = split.digits
  taxRate.value = p.taxRate
  preTaxAmt.value = p.preTaxAmt
  taxAmt.value = p.taxAmt
  amount.value = p.amount
  items.value = p.items.map((it) => ({ ...it }))
  categoryId.value = p.categoryId
  payoutStatus.value = p.payoutStatus ?? 'pending'
  paidAt.value = p.paidAt ?? null
  note.value = p.note
  ;(Object.keys(fieldErrors) as (keyof typeof fieldErrors)[]).forEach((k) => {
    fieldErrors[k] = ''
  })
}

function syncCurrentPageState() {
  if (pages.value.length === 0) return
  pages.value[currentPageIndex.value] = currentAsPageData()
}

function onPageChange(newIndex: number) {
  if (
    newIndex < 0 ||
    newIndex >= pages.value.length ||
    newIndex === currentPageIndex.value
  ) {
    return
  }
  syncCurrentPageState()
  currentPageIndex.value = newIndex
  loadPageData(pages.value[newIndex])
}

// ─── 驗證 + 送出 ──────────────────────────
function validate(): boolean {
  fieldErrors.category = !categoryId.value ? '請選擇費用類別' : ''
  fieldErrors.amount = !amount.value || amount.value <= 0 ? '請填寫含稅金額' : ''
  fieldErrors.incurredAt = !incurredAt.value ? '請選擇交易日期' : ''
  const taxIdRaw = taxId.value.trim()
  // 收據（例如小攤販）可能沒有統編：收據時選填，有填才檢查格式
  if (!taxIdRaw) {
    fieldErrors.taxId = documentType.value === 'receipt' ? '' : '請填寫賣方統編'
  } else if (!/^\d{8}$/.test(taxIdRaw)) {
    fieldErrors.taxId = '賣方統編應為 8 碼數字'
  } else {
    fieldErrors.taxId = ''
  }
  fieldErrors.vendor = !vendor.value.trim() ? '請填寫賣方名稱' : ''
  fieldErrors.payoutStatus = !payoutStatus.value ? '請選擇付款狀態' : ''
  fieldErrors.paidAt = payoutStatus.value === 'paid' && !paidAt.value ? '請選擇付款日' : ''
  if (documentType.value === 'invoice') {
    const p = invoicePrefix.value.trim().toUpperCase()
    const d = invoiceDigits.value.trim()
    if (!p && !d) {
      fieldErrors.invoiceNo = '發票號碼必填'
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
    !fieldErrors.amount &&
    !fieldErrors.incurredAt &&
    !fieldErrors.invoiceNo &&
    !fieldErrors.taxId &&
    !fieldErrors.vendor &&
    !fieldErrors.payoutStatus &&
    !fieldErrors.paidAt
  )
}

async function scrollToFirstError() {
  const order = [
    'incurredAt',
    'taxId',
    'vendor',
    'invoiceNo',
    'amount',
    'category',
    'payoutStatus',
    'paidAt',
  ] as const
  const first = order.find((k) => fieldErrors[k])
  if (!first) return
  await nextTick()
  document
    .getElementById(`field-${first}`)
    ?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  document.getElementById(first)?.focus()
}

/**
 * 新增：POST /expenses。編輯：PATCH /expenses/:id；若付款狀態與載入時不同，
 * 另外走 /pay 或 /revert-pay 專用 endpoint。
 */
async function createOneExpense(p: FormPageData): Promise<void> {
  if (!auth.currentUser) return
  const cat = categoryMap.value.get(p.categoryId as string)
  if (!cat) return
  const paidIso = p.paidAt ? toIsoDate(p.paidAt) : null
  const nextStatus: PayoutStatus = p.payoutStatus === 'paid' ? 'paid' : 'pending'
  const base = {
    documentType: p.documentType,
    vendor: p.vendor.trim() || null,
    taxId: p.taxId.trim() || null,
    invoiceNo: p.invoiceNo.trim() || null,
    taxRate: p.taxRate,
    preTaxAmt: p.preTaxAmt,
    taxAmt: p.taxAmt,
    amount: p.amount as number,
    categoryId: cat.id,
    date: toIsoDate(p.incurredAt as Date),
    note: p.note.trim() || null,
    attachments: attachments.value,
    items: p.items.filter((it) => it.name.trim().length > 0),
    tags: [] as string[],
  }

  if (isEditMode.value && editingId.value) {
    const id = editingId.value
    const prev = loadedPayoutStatus.value
    const body: UpdateExpenseRequest = { ...base }
    // 只有在「維持 paid」時 PATCH 才帶 paidAt；paid↔pending 轉換交給 /pay 與 /revert-pay 處理
    if (prev === 'paid' && nextStatus === 'paid') {
      body.paidAt = paidIso
    }
    await apiUpdateExpense(id, body)
    if (prev === 'pending' && nextStatus === 'paid') {
      await payExpense(id, { paidAt: paidIso })
    } else if (prev === 'paid' && nextStatus === 'pending') {
      await revertPayExpense(id)
    }
    return
  }

  const createBody: CreateExpenseRequest = {
    ...base,
    payoutStatus: nextStatus,
    paidAt: nextStatus === 'paid' ? paidIso : null,
  }
  await createExpense(createBody)
}

function submitError(err: unknown): string {
  if (err instanceof HttpError) {
    const body = err.body as { error?: string } | undefined
    return body?.error ?? `HTTP ${err.status}`
  }
  return err instanceof Error ? err.message : '未知錯誤'
}

const submitting = ref(false)

async function onSubmit() {
  if (!auth.currentUser || submitting.value) return
  if (!isMultiPage.value) {
    if (!validate()) {
      await scrollToFirstError()
      return
    }
    const isPaid = payoutStatus.value === 'paid'
    submitting.value = true
    try {
      await createOneExpense(currentAsPageData())
    } catch (err) {
      toast.add({ severity: 'error', summary: isEditMode.value ? '更新支出失敗' : '建立支出失敗', detail: submitError(err), life: 3000 })
      submitting.value = false
      return
    }
    toast.add({
      severity: 'success',
      summary: isEditMode.value
        ? '支出已更新'
        : isPaid
          ? '支出已建立（已付款）'
          : '支出已建立（待付款）',
      life: 2500,
    })
    submitting.value = false
    allowLeave.value = true
    router.push({ name: 'admin-expenses' })
    return
  }
  syncCurrentPageState()
  for (let i = 0; i < pages.value.length; i++) {
    if (i !== currentPageIndex.value) {
      currentPageIndex.value = i
      loadPageData(pages.value[i])
    }
    if (!validate()) {
      await scrollToFirstError()
      return
    }
  }
  submitting.value = true
  let created = 0
  for (const p of pages.value) {
    try {
      await createOneExpense(p)
      created++
    } catch (err) {
      toast.add({
        severity: 'error',
        summary: `第 ${created + 1} 筆建立失敗`,
        detail: submitError(err),
        life: 3000,
      })
      submitting.value = false
      return
    }
  }
  toast.add({
    severity: 'success',
    summary: `已建立 ${created} 筆支出`,
    life: 2500,
  })
  submitting.value = false
  allowLeave.value = true
  router.push({ name: 'admin-expenses' })
}

// ─── 掛載時分派：編輯模式優先、其次批次匯入、再其次新增空白表單 ─
onMounted(async () => {
  if (isEditMode.value && editingId.value) {
    let target
    try {
      target = await getExpense(editingId.value)
    } catch (err) {
      if (err instanceof HttpError && err.status === 404) {
        toast.add({
          severity: 'error',
          summary: '找不到該筆支出',
          detail: '可能已被刪除；已為你返回列表',
          life: 3000,
        })
      } else {
        toast.add({
          severity: 'error',
          summary: '載入支出失敗',
          detail: submitError(err),
          life: 3000,
        })
      }
      allowLeave.value = true
      router.replace({ name: 'admin-expenses' })
      return
    }
    documentType.value = target.documentType
    incurredAt.value = target.date
      ? new Date(`${target.date}T00:00:00`)
      : null
    taxId.value = target.taxId ?? ''
    vendor.value = target.vendor ?? ''
    const split = splitInvoiceNo(target.invoiceNo)
    invoicePrefix.value = split.prefix
    invoiceDigits.value = split.digits
    taxRate.value = target.taxRate
    preTaxAmt.value = target.preTaxAmt
    taxAmt.value = target.taxAmt
    amount.value = target.amount
    items.value = target.items.map((it) => ({ ...it }))
    categoryId.value = target.category.id
    // 編輯既有紀錄時，若其類別不在使用中清單（例如已停用）→ 補進 local，確保下拉可顯示原名
    if (!categoryMap.value.has(target.category.id)) {
      activeCategories.value = [
        ...activeCategories.value,
        {
          id: target.category.id,
          kind: 'expense',
          name: target.category.name,
          accountCode: target.category.accountCode,
          isArchived: false,
          sortOrder: Number.MAX_SAFE_INTEGER,
          createdAt: '',
          updatedAt: '',
        },
      ]
    }
    payoutStatus.value = target.payoutStatus
    loadedPayoutStatus.value = target.payoutStatus
    paidAt.value = target.paidAt ? new Date(`${target.paidAt}T00:00:00`) : null
    note.value = target.note ?? ''
    attachments.value = target.attachments.map((a) => ({ ...a }))
    savedAttachments.value = new Set(attachments.value)
    return
  }

  const imported = takeImportedPages()
  if (!imported || imported.length === 0) return
  fromImport.value = true
  pages.value = imported.map((p) => ({
    ...p,
    incurredAt: p.incurredAt ? new Date(p.incurredAt) : null,
    items: p.items.map((it) => ({ ...it })),
  }))
  currentPageIndex.value = 0
  loadPageData(pages.value[0])
  toast.add({
    severity: 'info',
    summary: `已載入 ${imported.length} 筆匯入資料`,
    detail: '請逐筆核對後按「建立」',
    life: 3000,
  })
})

// ─── 離開頁守衛 ──────────────────────────
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

const pageTitle = computed(() =>
  isEditMode.value ? '編輯支出' : '新增支出',
)
const submitLabel = computed(() => {
  if (isEditMode.value) return '更新'
  return isMultiPage.value ? `建立 ${pages.value.length} 筆` : '建立'
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
            @click="router.push({ name: 'admin-expenses' })"
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
      <!-- 辨識中整份表單暫停編輯，避免結果回來時覆蓋到正在輸入的欄位 -->
      <fieldset class="space-y-5 min-w-0" :disabled="isRecognizing" :aria-busy="isRecognizing">
      <!-- 1. 憑證上傳 + 開始辨識（由匯入進入時隱藏；批次匯入場景下憑證由原檔案承載） -->
      <div v-if="!fromImport" data-tour="expense-upload-area">
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
                <label v-if="!savedAttachments.has(att)" class="att-pick" :title="ocrExcluded.has(att) ? '不辨識（補充資料）' : '辨識這張'">
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
            <!-- 繼續加入（長收據可分段拍） -->
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
            v-else
            type="button"
            :label="recognizeLabel"
            :icon="isRecognizing ? 'pi pi-spin pi-spinner' : 'pi pi-sparkles'"
            :disabled="isRecognizing || ocrSelectedCount === 0"
            @click="startRecognize"
          />

          <p class="mt-2 text-sm text-[var(--color-muted)]">
            <template v-if="attachments.length === 0">
              上傳後可使用辨識功能帶入日期、賣方與金額。
            </template>
            <template v-else>
              勾選的憑證會合併辨識，沒勾的當補充資料，不會扣辨識次數。<template v-if="attachments.some((a) => savedAttachments.has(a))">已存檔的憑證不能再辨識；如需重新辨識，請移除後重新上傳。</template>
            </template>
          </p>
          <p v-if="ocrQuotaText" class="text-sm text-[var(--color-muted)]" aria-live="polite">
            <i class="pi pi-sparkles text-xs" aria-hidden="true" /> OCR 辨識{{ ocrQuotaText }}
          </p>
        </div>
      </div>

      <!-- 3. 憑證類型 -->
      <div>
        <div class="field-label">憑證類型</div>
        <div class="choice-cards doc-type-cards" role="radiogroup" aria-label="憑證類型">
          <label
            v-for="opt in DOCUMENT_TYPE_OPTIONS"
            :key="opt.value"
            :for="`doc-${opt.value}`"
          >
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

      <!-- 4. 交易日期 / 賣方統編 / 賣方名稱 / 發票號碼 -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div id="field-incurredAt">
          <label for="incurredAt" class="field-label">
            交易日期 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <DatePicker
            v-model="incurredAt"
            input-id="incurredAt"
            date-format="yy-mm-dd"
            placeholder="請選擇日期"
            show-icon
            icon-display="input"
            class="w-full"
            @update:model-value="clearError('incurredAt')"
          />
          <p
            v-if="fieldErrors.incurredAt"
            class="mt-1 text-sm text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.incurredAt }}
          </p>
        </div>
        <div id="field-taxId">
          <label for="taxId" class="field-label">
            賣方統編
            <span v-if="documentType === 'invoice'" class="text-[var(--color-status-rejected)]">*</span>
            <span v-else class="field-optional">（選填）</span>
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
          <p
            v-if="fieldErrors.taxId"
            class="mt-1 text-sm text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.taxId }}
          </p>
        </div>
        <div id="field-vendor">
          <label for="vendor" class="field-label">
            賣方名稱 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <InputText
            id="vendor"
            v-model="vendor"
            placeholder="例：福華文具行"
            class="w-full"
            @update:model-value="clearError('vendor')"
          />
          <p
            v-if="fieldErrors.vendor"
            class="mt-1 text-sm text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.vendor }}
          </p>
        </div>
        <div v-if="documentType === 'invoice'" id="field-invoiceNo">
          <label for="invoicePrefix" class="field-label">
            發票號碼
            <span
              v-if="documentType === 'invoice'"
              class="text-[var(--color-status-rejected)]"
              >*</span
            >
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
              :aria-label="'發票號碼前段（英文 2 碼）'"
              @update:model-value="(v) => onInvoicePrefixInput(String(v ?? ''))"
            />
            <span
              class="text-[var(--color-muted)] tabular-nums select-none"
              aria-hidden="true"
              >-</span
            >
            <InputText
              id="invoiceDigits"
              :model-value="invoiceDigits"
              placeholder="12345678"
              maxlength="8"
              inputmode="numeric"
              class="flex-1 tabular-nums"
              autocomplete="off"
              :aria-label="'發票號碼後段（數字 8 碼）'"
              @update:model-value="(v) => onInvoiceDigitsInput(String(v ?? ''))"
              @keydown="onInvoiceDigitsKeydown"
            />
          </div>
          <p
            v-if="fieldErrors.invoiceNo"
            class="mt-1 text-sm text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.invoiceNo }}
          </p>
        </div>
      </div>

      <!-- 5. 金額 -->
      <div id="field-amount">
        <div class="field-label">
          金額 <span class="text-[var(--color-status-rejected)]">*</span>
        </div>
        <div :class="documentType === 'invoice' ? 'grid grid-cols-1 sm:grid-cols-3 gap-3' : 'grid grid-cols-1 sm:grid-cols-2 gap-3'">
          <div v-if="documentType === 'invoice'">
            <label
              for="preTaxAmt"
              class="field-sublabel mb-1 block"
            >
              未稅金額
            </label>
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
            <label
              for="taxRate"
              class="field-sublabel mb-1 block"
            >
              稅率
            </label>
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
            <label
              for="amount"
              class="field-sublabel mb-1 block"
            >
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
        <p
          v-if="taxAmountText"
          class="mt-1 text-sm text-[var(--color-muted)] tabular-nums"
        >
          {{ taxAmountText }}
        </p>
        <p
          v-if="fieldErrors.amount"
          class="mt-1 text-sm text-[var(--color-status-rejected)]"
        >
          {{ fieldErrors.amount }}
        </p>
      </div>

      <!-- 6. 品項列表（桌面 grid-cols-12；手機第 1 行品項名+刪除、第 2 行金額 3 欄）-->
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
        <div
          v-if="items.length === 0"
          class="items-empty"
        >
          <b>尚未加入品項</b>
          <span>品項為選填，需要明細時再新增。</span>
          <Button type="button" label="新增品項" icon="pi pi-plus" outlined @click="addItem" />
        </div>
        <div v-else class="space-y-3 sm:space-y-2">
          <!-- Desktop header row（跟 desktop 佈局同步：flex + 相同 basis/gap） -->
          <div
            class="hidden sm:flex items-center gap-2 field-sublabel"
            aria-hidden="true"
          >
            <div class="flex-1 basis-0 min-w-0">品項名稱</div>
            <div class="w-32">數量</div>
            <div class="w-32">單價</div>
            <div class="w-32">小計</div>
            <div class="w-8" />
          </div>

          <div v-for="(it, i) in items" :key="i">
            <!-- Desktop：flex 佈局，刪除按鈕貼齊 小計 右邊 -->
            <div class="hidden sm:flex items-center gap-2">
              <InputText
                v-model="it.name"
                placeholder="例：A4 影印紙"
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

            <!-- 手機：卡片式，第 1 行品項名 + 刪除、第 2 行數量/單價/小計 -->
            <div
              class="sm:hidden flex flex-col gap-2 rounded-lg border border-[var(--color-hairline)] p-2"
            >
              <div class="flex items-center gap-2">
                <InputText
                  v-model="it.name"
                  placeholder="例：A4 影印紙"
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
                  <label
                    class="block field-sublabel mb-1"
                    :for="`m-qty-${i}`"
                  >
                    數量
                  </label>
                  <InputNumber
                    v-model="it.quantity"
                    :input-id="`m-qty-${i}`"
                    :min="0"
                    :min-fraction-digits="0"
                    :max-fraction-digits="0"
                    :aria-label="`第 ${i + 1} 筆數量（手機）`"
                    class="w-full"
                    input-class="w-full"
                    placeholder="0"
                    @update:model-value="recomputeItemSubtotal(i)"
                  />
                </div>
                <div>
                  <label
                    class="block field-sublabel mb-1"
                    :for="`m-unit-${i}`"
                  >
                    單價
                  </label>
                  <InputNumber
                    v-model="it.unitPrice"
                    :input-id="`m-unit-${i}`"
                    :min="0"
                    :min-fraction-digits="0"
                    :max-fraction-digits="0"
                    :aria-label="`第 ${i + 1} 筆單價（手機）`"
                    class="w-full"
                    input-class="w-full"
                    placeholder="0"
                    @update:model-value="recomputeItemSubtotal(i)"
                  />
                </div>
                <div>
                  <label
                    class="block field-sublabel mb-1"
                    :for="`m-sub-${i}`"
                  >
                    小計
                  </label>
                  <InputNumber
                    :model-value="it.subtotal"
                    :input-id="`m-sub-${i}`"
                    disabled
                    :min-fraction-digits="0"
                    :max-fraction-digits="0"
                    :aria-label="`第 ${i + 1} 筆小計（手機）`"
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

      <!-- 7. 費用類別 + 付款狀態 -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div id="field-category">
          <label for="category" class="field-label">
            費用類別 <span class="text-[var(--color-status-rejected)]">*</span>
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
                <span
                  :class="
                    option.isNew
                      ? 'text-[var(--color-primary)] font-medium'
                      : ''
                  "
                >
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
          <p
            v-if="fieldErrors.category"
            class="mt-1 text-sm text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.category }}
          </p>
        </div>
        <div class="flex gap-4">
          <div id="field-payoutStatus" class="flex-1 min-w-0">
            <label for="payoutStatus" class="field-label">
              付款狀態 <span class="text-[var(--color-status-rejected)]">*</span>
            </label>
            <Select
              v-model="payoutStatus"
              input-id="payoutStatus"
              :options="PAYOUT_STATUS_OPTIONS"
              option-label="label"
              option-value="value"
              placeholder="請選擇付款狀態"
              class="w-full"
              :disabled="isRecognizing"
              @update:model-value="clearError('payoutStatus')"
            />
            <p
              v-if="fieldErrors.payoutStatus"
              class="mt-1 text-sm text-[var(--color-status-rejected)]"
            >
              {{ fieldErrors.payoutStatus }}
            </p>
          </div>
          <div
            v-if="payoutStatus === 'paid'"
            id="field-paidAt"
            class="flex-1 min-w-0"
          >
            <label for="paidAt" class="field-label">
              付款日 <span class="text-[var(--color-status-rejected)]">*</span>
            </label>
            <DatePicker
              v-model="paidAt"
              input-id="paidAt"
              date-format="yy-mm-dd"
              placeholder="請選擇付款日"
              show-icon
              icon-display="input"
              class="w-full"
              @update:model-value="clearError('paidAt')"
            />
            <p
              v-if="fieldErrors.paidAt"
              class="mt-1 text-sm text-[var(--color-status-rejected)]"
            >
              {{ fieldErrors.paidAt }}
            </p>
          </div>
        </div>
      </div>

      <!-- 8. 描述（資料欄位仍為 note） -->
      <div>
        <label for="note" class="field-label">描述</label>
        <Textarea
          auto-resize
          id="note"
          v-model="note"
          rows="2"
          class="w-full"
          placeholder="選填"
        />
      </div>

      <!-- 分頁元件（多筆才顯示；編輯模式不顯示） -->
      <div v-if="isMultiPage" class="flex justify-center pt-2">
        <ExpenseFormPagination
          :total="pages.length"
          :current="currentPageIndex"
          @change="onPageChange"
        />
      </div>

      <!-- 送出 -->
      <div
        class="flex flex-col-reverse sm:flex-row justify-end gap-2 pt-2"
      >
        <Button
          type="button"
          label="取消"
          outlined
          @click="router.push({ name: 'admin-expenses' })"
        />
        <Button type="submit" :label="submitLabel" />
      </div>
      </fieldset>
    </form>

    <!-- 憑證放大預覽（圖片/PDF） -->
    <AttachmentPreviewDialog
      :src="previewAtt?.dataUrl ?? null"
      :filename="previewAtt?.filename"
      :mime-type="previewAtt?.mimeType"
      @close="previewAtt = null"
    />

    <OcrConflictDialog
      :conflict="ocrConflict"
      role="expense"
      @confirm="ocr.resolveConflicts"
      @close="ocr.dismissConflicts"
    />
  </div>
</template>
