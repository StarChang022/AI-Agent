<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import type { DocumentType, ExpenseItem, TaxRate } from '@/types/domain'
import {
  createReimbursement,
  getReimbursement,
  updateReimbursement,
  type CreateReimbursementRequest,
} from '@/api/reimbursements'
import { listCategories, type Category } from '@/api/categories'
import {
  DOCUMENT_TYPE_OPTIONS,
  INVOICE_NUMBER_REGEX,
  TAX_RATE_OPTIONS,
  getTaxRateValue,
} from '@/constants/expense'
import { toIsoDate } from '@/utils/format'
import { asDate, useRecordDates } from '@/composables/useRecordDates'
import { userErrorToast } from '@/utils/userFeedback'
import { useOcrPicks, useOcrRecognize } from '@/composables/useOcrRecognize'
import { toFormAttachment, useAttachmentUploads } from '@/composables/useAttachmentUploads'
import { MAX_ATTACHMENTS as MAX_RECEIPTS } from '@/api/attachments'
import type { FormAttachment } from '@/types/expense-form'
import AttachmentField from '@/components/AttachmentField.vue'
import OcrConflictDialog from '@/components/OcrConflictDialog.vue'
import type { OcrFields, OcrItem } from '@/api/ocr'
import ItemsEditor from '@/components/ItemsEditor.vue'
import PageHeader from '@/components/PageHeader.vue'
import Button from 'primevue/button'
import DatePicker from '@/components/qds/DatePicker'
import InputNumber from 'primevue/inputnumber'
import InputText from 'primevue/inputtext'
import Select from 'primevue/select'
import Textarea from 'primevue/textarea'
import { useConfirm } from 'primevue/useconfirm'
import { useToast } from 'primevue/usetoast'
import imageCompression from 'browser-image-compression'

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
const categoryOptions = computed(() =>
  activeCategories.value.map((c) => ({
    value: c.id,
    label: c.name,
    accountCode: c.accountCode,
  })),
)
const route = useRoute()
const router = useRouter()
const toast = useToast()
const confirm = useConfirm()

/** 標記為 true 時 onBeforeRouteLeave 直接放行；saveDraft/submitForReview/cancelResubmit 等主動導頁前設定。 */
const allowLeave = ref(false)

const editingId = computed(() =>
  typeof route.params.id === 'string' ? route.params.id : null,
)
const isEditing = computed(() => editingId.value !== null)
const editingStatus = ref<'draft' | 'rejected' | null>(null)
const isResubmitting = computed(() => editingStatus.value === 'rejected')
const pageTitle = computed(() => {
  if (!isEditing.value) return '新增代墊款'
  return isResubmitting.value ? '重新編輯（重送簽核）' : '編輯草稿'
})

// ─── 表單 state ─────────────────────────────
const receipts = ref<FormAttachment[]>([])
const documentType = ref<DocumentType>('invoice')
// 發生日期（預設今天）與發票日期；帶入與改文件類型規則同後台收支（PRD 第 23 條「代墊款請款」）。
// 編輯草稿或駁回重送視同編輯既有紀錄，不自動帶入
const dates = useRecordDates('reimbursement', isEditing.value)
const { occurredAt: incurredAt, invoiceDate } = dates
const taxId = ref('')
const vendor = ref('')
const invoicePrefix = ref('')
const invoiceDigits = ref('')
const taxRate = ref<TaxRate>('business_5')
const preTaxAmt = ref<number | null>(null)
const taxAmt = ref<number | null>(null)
const amount = ref<number | null>(null)
const categoryId = ref<string | null>(null)
const description = ref('')
/** 品項明細（選填，不強制與金額相等） */
const items = ref<ExpenseItem[]>([])

/** 每個欄位獨立的驗證訊息（inline 顯示在欄位下方） */
const fieldErrors = reactive({
  invoiceDate: '',
  incurredAt: '',
  taxId: '',
  vendor: '',
  invoiceNo: '',
  amount: '',
  category: '',
})


function clearFieldError(key: keyof typeof fieldErrors) {
  fieldErrors[key] = ''
}
function clearAllFieldErrors() {
  fieldErrors.invoiceDate = ''
  fieldErrors.incurredAt = ''
  fieldErrors.taxId = ''
  fieldErrors.vendor = ''
  fieldErrors.invoiceNo = ''
  fieldErrors.amount = ''
  fieldErrors.category = ''
}

// ─── 發票號碼拆 / 組 helpers（與 admin ExpenseFormView 同邏輯）─────
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

function combinedInvoiceNo(
  prefix = invoicePrefix.value,
  digits = invoiceDigits.value,
): string {
  const p = prefix.trim().toUpperCase()
  const d = digits.trim()
  if (!p && !d) return ''
  return `${p}-${d}`
}

function onInvoicePrefixInput(v: string) {
  invoicePrefix.value = v.replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 2)
  clearFieldError('invoiceNo')
}

function onInvoiceDigitsInput(v: string) {
  invoiceDigits.value = v.replace(/\D/g, '').slice(0, 8)
  clearFieldError('invoiceNo')
}

// ─── 稅率 3 欄雙向連動（與 admin 同邏輯）────
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
    clearFieldError('amount')
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
    clearFieldError('amount')
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

/** 收據：沒有發票號碼與營業稅，只填總金額（同管理端） */
function setDocumentType(type: DocumentType) {
  if (type === documentType.value) return
  documentType.value = type
  dates.onDocumentTypeChange()
  fieldErrors.invoiceDate = ''
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

/** 編輯模式下載入中（async getReimbursement）：期間不顯示表單避免跳動。 */
const isLoadingExisting = ref(false)

onMounted(async () => {
  if (!editingId.value) {
    captureSnapshot()
    return
  }
  isLoadingExisting.value = true
  let existing
  try {
    existing = await getReimbursement(editingId.value)
  } catch {
    toast.add({ severity: 'error', summary: '載入請款資料失敗', life: 3000 })
    allowLeave.value = true
    router.replace({ name: 'front-history' })
    return
  } finally {
    isLoadingExisting.value = false
  }
  if (existing.status !== 'draft' && existing.status !== 'rejected') {
    toast.add({
      severity: 'warn',
      summary: '這筆請款無法編輯',
      detail: '只有草稿或已駁回的紀錄可以編輯',
      life: 2500,
    })
    allowLeave.value = true
    router.replace({ name: 'front-history' })
    return
  }
  editingStatus.value = existing.status
  amount.value = existing.amount
  categoryId.value = existing.category?.id ?? null
  // 編輯既有紀錄時，若其類別不在使用中清單（例如已停用）→ 補進 local，確保下拉可顯示原名
  if (existing.category && !categoryMap.value.has(existing.category.id)) {
    activeCategories.value = [
      ...activeCategories.value,
      {
        id: existing.category.id,
        kind: 'expense',
        name: existing.category.name,
        accountCode: existing.category.accountCode,
        isArchived: false,
        sortOrder: Number.MAX_SAFE_INTEGER,
        createdAt: '',
        updatedAt: '',
      },
    ]
  }
  description.value = existing.description
  // 草稿可能還沒填發生日期：維持空白，不補今天
  dates.loadSaved({ date: existing.incurredAt, invoiceDate: existing.invoiceDate, plannedDate: null })
  receipts.value = existing.attachments.map((a) => toFormAttachment(a, true))
  documentType.value = existing.documentType ?? 'invoice'
  vendor.value = existing.vendor ?? ''
  taxId.value = existing.taxId ?? ''
  const split = splitInvoiceNo(existing.invoiceNo)
  invoicePrefix.value = split.prefix
  invoiceDigits.value = split.digits
  taxRate.value = existing.taxRate ?? 'business_5'
  preTaxAmt.value = existing.preTaxAmt
  taxAmt.value = existing.taxAmt
  items.value = existing.items.map((it) => ({ ...it }))
  captureSnapshot()
})

const IMAGE_TARGET_MB = 1
const IMAGE_MAX_DIM = 1600

const isTouchDevice =
  typeof window !== 'undefined' &&
  window.matchMedia('(hover: none) and (pointer: coarse)').matches

/** 圖片先壓縮成 JPEG 再上傳；PDF 原檔上傳 */
async function prepareReceipt(file: File): Promise<File> {
  if (!file.type.startsWith('image/')) return file
  const compressed = await imageCompression(file, {
    maxSizeMB: IMAGE_TARGET_MB,
    maxWidthOrHeight: IMAGE_MAX_DIM,
    useWebWorker: true,
    initialQuality: 0.8,
    fileType: 'image/jpeg',
  })
  const base = file.name.replace(/\.[^.]+$/, '')
  return new File([compressed], `${base}.jpg`, { type: 'image/jpeg' })
}

/**
 * 憑證：選檔後壓縮並立即上傳成暫存檔；移除未儲存的直接刪暫存檔。
 * 代墊款不做立即刪除：已存的只從畫面移除，儲存時（送出完整清單）才拿掉。離開頁面時清掉未儲存的暫存檔。
 */
const uploads = useAttachmentUploads(receipts, {
  prepare: prepareReceipt,
  fetchSaved: isEditing.value ? () => getReimbursement(editingId.value as string).then((r) => r.attachments) : undefined,
})

/** 圖片壓縮與上傳處理中；期間停用上傳按鈕、顯示 loading，避免使用者重複點擊或超過張數 */
const isCompressing = computed(() => uploads.isUploading.value)

async function addReceipts(files: File[]) {
  await uploads.addFiles(files)
}

/** 拍照、選擇檔案按鈕（觸控裝置）選的檔 */
async function onPickerChange(event: Event) {
  const target = event.target as HTMLInputElement
  const files = Array.from(target.files ?? [])
  target.value = ''
  await addReceipts(files)
}


// ─── 「開始辨識」OCR ───────────────────────
/**
 * 辨識結果整份寫進表單：賣方 = 對方；辨識不到的欄位清空。
 * 類別與說明不是 OCR 會給的欄位，維持原值（說明欄不預填任何文字）。
 */
function applyOcrResult(f: OcrFields, ocrItems: OcrItem[]) {
  documentType.value = f.documentType ?? 'invoice'
  // 發票的日期填發票日期（再依規則帶入發生日期），收據的填發生日期
  dates.applyOcrDate(documentType.value, f.incurredAt ? new Date(`${f.incurredAt}T00:00:00`) : null)
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
  clearAllFieldErrors()
}

const ocr = useOcrRecognize({
  role: 'reimbursement',
  apply: applyOcrResult,
  successDetail: '欄位已自動帶入，請核對後送出',
  reviewHint: '辨識結果可能因字跡模糊、憑證污損等原因出錯，送出前請再次核對各欄位。',
})
/** OCR 辨識中；期間停用按鈕與表單、顯示 spinner */
const isRecognizing = ocr.isRecognizing
const ocrQuotaText = ocr.quotaText
const ocrReviewHint = ocr.reviewHint
const ocrConflict = ocr.conflict

/** 辨識勾選：新上傳的預設勾選，已儲存的預設不勾（OCR 規格 §6） */
const ocrPicks = useOcrPicks(receipts)
const ocrSelectedCount = ocrPicks.selectedCount

/** 已辨識過的張數；之後再辨識要提示會覆蓋表單內容 */
const recognizedCount = ref(0)
const recognizeLabel = computed(() => {
  if (isRecognizing.value) return '辨識中…'
  if (uploads.isUploading.value) return '憑證上傳中…'
  const n = ocrSelectedCount.value
  if (n === 0) return '請勾選要辨識的憑證'
  return `${recognizedCount.value ? '重新' : ''}辨識已選的 ${n} 張`
})

/** 表單欄位是否已有內容（不含憑證本身） */
function hasFormInput() {
  return (
    (amount.value ?? 0) > 0 ||
    (preTaxAmt.value ?? 0) > 0 ||
    !!categoryId.value ||
    (isEditing.value ? !!incurredAt.value : dates.occurredLocked.value) ||
    !!invoiceDate.value ||
    description.value.trim().length > 0 ||
    vendor.value.trim().length > 0 ||
    taxId.value.trim().length > 0 ||
    invoicePrefix.value.trim().length > 0 ||
    invoiceDigits.value.trim().length > 0 ||
    items.value.length > 0
  )
}

function startRecognize() {
  if (ocrSelectedCount.value === 0 || isRecognizing.value || uploads.isUploading.value) return
  if (recognizedCount.value > 0 || hasFormInput()) {
    const n = ocrSelectedCount.value
    confirm.require({
      header: '重新辨識',
      message: `會用目前 ${n} 張憑證的辨識結果，覆蓋表單已填的日期、賣方、金額與品項等內容。確定要繼續嗎？`,
      acceptLabel: '覆蓋並辨識',
      rejectLabel: '取消',
      accept: () => void runRecognize(),
    })
    return
  }
  void runRecognize()
}

async function runRecognize() {
  const sources = ocrPicks.sources()
  if (await ocr.run(sources)) recognizedCount.value = sources.length
}

function hasAnyInput() {
  return (
    (amount.value ?? 0) > 0 ||
    (preTaxAmt.value ?? 0) > 0 ||
    !!categoryId.value ||
    (isEditing.value ? !!incurredAt.value : dates.occurredLocked.value) ||
    !!invoiceDate.value ||
    description.value.trim().length > 0 ||
    vendor.value.trim().length > 0 ||
    taxId.value.trim().length > 0 ||
    invoicePrefix.value.trim().length > 0 ||
    invoiceDigits.value.trim().length > 0 ||
    items.value.length > 0 ||
    receipts.value.length > 0
  )
}

/**
 * 掛載後（新增：空狀態 / 編輯：載入完成）拍一份 snapshot 當作「原始值」。
 * isDirty() 拿目前欄位跟 snapshot 逐項比對，用於路由離開守衛。
 */
interface FormSnapshot {
  amount: number | null
  preTaxAmt: number | null
  taxAmt: number | null
  taxRate: TaxRate
  categoryId: string | null
  incurredAt: string | null
  invoiceDate: string | null
  description: string
  documentType: DocumentType
  vendor: string
  taxId: string
  invoiceNo: string
  items: string
  receiptKeys: string[]
}

const initialSnapshot = ref<FormSnapshot | null>(null)

function captureSnapshot() {
  initialSnapshot.value = {
    amount: amount.value,
    preTaxAmt: preTaxAmt.value,
    taxAmt: taxAmt.value,
    taxRate: taxRate.value,
    categoryId: categoryId.value,
    incurredAt: incurredAt.value ? toIsoDate(incurredAt.value) : null,
    invoiceDate: invoiceDate.value ? toIsoDate(invoiceDate.value) : null,
    description: description.value,
    documentType: documentType.value,
    vendor: vendor.value,
    taxId: taxId.value,
    invoiceNo: combinedInvoiceNo(),
    items: JSON.stringify(items.value),
    receiptKeys: receipts.value.map((r) => r.key),
  }
}

function isDirty(): boolean {
  const snap = initialSnapshot.value
  if (!snap) return hasAnyInput()
  if ((amount.value ?? null) !== snap.amount) return true
  if ((preTaxAmt.value ?? null) !== snap.preTaxAmt) return true
  if ((taxAmt.value ?? null) !== snap.taxAmt) return true
  if (taxRate.value !== snap.taxRate) return true
  if (categoryId.value !== snap.categoryId) return true
  const nowDate = incurredAt.value ? toIsoDate(incurredAt.value) : null
  if (nowDate !== snap.incurredAt) return true
  if ((invoiceDate.value ? toIsoDate(invoiceDate.value) : null) !== snap.invoiceDate) return true
  if (description.value !== snap.description) return true
  if (documentType.value !== snap.documentType) return true
  if (vendor.value !== snap.vendor) return true
  if (taxId.value !== snap.taxId) return true
  if (combinedInvoiceNo() !== snap.invoiceNo) return true
  if (JSON.stringify(items.value) !== snap.items) return true
  if (receipts.value.length !== snap.receiptKeys.length) return true
  for (let i = 0; i < receipts.value.length; i++) {
    if (receipts.value[i].key !== snap.receiptKeys[i]) return true
  }
  return false
}

/**
 * 送出失敗時捲動並 focus 到第一個有錯誤的欄位。
 * 欄位順序 = 表單視覺順序。
 */
async function scrollToFirstError() {
  const order = [
    'invoiceDate',
    'incurredAt',
    'taxId',
    'vendor',
    'invoiceNo',
    'amount',
    'category',
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
 * 送出簽核前的完整驗證。把訊息寫進 fieldErrors 讓各欄位下方 inline 顯示，
 * 回傳是否通過驗證（true = 全部 OK）。
 */
function validateForSubmit(): boolean {
  fieldErrors.amount =
    !amount.value || amount.value <= 0 ? '請填寫金額' : ''
  fieldErrors.category = !categoryId.value ? '請選擇費用類別' : ''
  fieldErrors.incurredAt = !incurredAt.value ? '請選擇發生日期' : ''
  fieldErrors.invoiceDate = documentType.value === 'invoice' && !invoiceDate.value ? '請選擇發票日期' : ''

  const taxIdRaw = taxId.value.trim()
  if (!taxIdRaw) {
    // 【原型】收據常沒有賣方統編，改為選填；發票維持必填
    fieldErrors.taxId = documentType.value === 'receipt' ? '' : '請填寫賣方統編'
  } else if (!/^\d{8}$/.test(taxIdRaw)) {
    fieldErrors.taxId = '賣方統編應為 8 碼數字'
  } else {
    fieldErrors.taxId = ''
  }

  fieldErrors.vendor = !vendor.value.trim() ? '請填寫賣方名稱' : ''

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
    !fieldErrors.amount &&
    !fieldErrors.category &&
    !fieldErrors.incurredAt &&
    !fieldErrors.invoiceDate &&
    !fieldErrors.taxId &&
    !fieldErrors.vendor &&
    !fieldErrors.invoiceNo
  )
}

function buildRequest(asDraft: boolean): CreateReimbursementRequest {
  const invoiceNo = combinedInvoiceNo().trim()
  return {
    categoryId: categoryId.value,
    amount: amount.value,
    description: description.value.trim(),
    incurredAt: incurredAt.value ? toIsoDate(incurredAt.value) : null,
    invoiceDate: documentType.value === 'invoice' && invoiceDate.value ? toIsoDate(invoiceDate.value) : null,
    // 代墊款帶完整清單：保留的已存圖檔 + 新的暫存檔；沒列到的已存圖檔會被拿掉
    attachmentIds: receipts.value.filter((r) => r.id).map((r) => r.id as string),
    documentType: documentType.value,
    vendor: vendor.value.trim() || null,
    taxId: taxId.value.trim() || null,
    invoiceNo: invoiceNo && invoiceNo !== '-' ? invoiceNo : null,
    taxRate: taxRate.value,
    preTaxAmt: preTaxAmt.value,
    taxAmt: taxAmt.value,
    // 名稱空白的列不送（後端不檢查內容）
    items: items.value.filter((it) => it.name.trim().length > 0),
    asDraft,
  }
}

/** 送出中：期間停用按鈕，避免重複點擊造成重送。 */
const isSubmitting = ref(false)

async function saveOrSubmit(asDraft: boolean) {
  if (isSubmitting.value) return
  if (uploads.isUploading.value) {
    toast.add({ severity: 'warn', summary: '憑證上傳中', detail: '請等上傳完成後再送出。', life: 3000 })
    return
  }
  const body = buildRequest(asDraft)
  isSubmitting.value = true
  try {
    if (isEditing.value) {
      await updateReimbursement(editingId.value!, body)
    } else {
      await createReimbursement(body)
    }
    uploads.markAttached(receipts.value)
  } catch (err) {
    toast.add({ severity: 'error', ...userErrorToast(err, asDraft ? '儲存草稿失敗' : '送出失敗'), life: 3000 })
    void uploads.handleSaveError(err)
    isSubmitting.value = false
    return
  }
  const summary = asDraft
    ? (isEditing.value ? '草稿已更新' : '已存為草稿')
    : (isResubmitting.value ? '已重新送出簽核' : '已送出簽核')
  toast.add({
    severity: 'success',
    summary,
    detail: asDraft ? undefined : '你可以在歷史記錄追蹤進度',
    life: 2500,
  })
  allowLeave.value = true
  router.push({ name: 'front-history' })
}

function saveDraft() {
  clearAllFieldErrors()
  if (!hasAnyInput()) {
    toast.add({
      severity: 'warn',
      summary: '至少填寫一個欄位才能存草稿',
      life: 2500,
    })
    return
  }
  saveOrSubmit(true)
}

function submitForReview() {
  if (!validateForSubmit()) {
    scrollToFirstError()
    return
  }
  saveOrSubmit(false)
}

function cancelResubmit() {
  allowLeave.value = true
  if (editingId.value) {
    router.push({
      name: 'front-expense-detail',
      params: { id: editingId.value },
    })
  } else {
    router.back()
  }
}

/**
 * 表單未儲存就想離開頁時彈確認框。
 * - 已成功送出/存草稿/主動取消 → allowLeave = true，直接放行
 * - 欄位相對進入時未變更 → 直接放行
 * - 否則跳 confirm；按「離開」放行，其餘（留在此頁、關閉、外部點擊）都取消導航
 */
onBeforeRouteLeave(() => {
  if (allowLeave.value) return true
  if (!isDirty()) return true
  return new Promise<boolean>((resolve) => {
    let done = false
    const settle = (v: boolean) => {
      if (done) return
      done = true
      resolve(v)
    }
    confirm.require({
      header: '離開表單頁',
      message: '填寫的內容尚未儲存，離開後將會遺失。確定要離開嗎？',
      icon: 'pi pi-exclamation-triangle',
      acceptLabel: '確定',
      rejectLabel: '取消',
      acceptProps: { severity: 'danger' },
      accept: () => settle(true),
      reject: () => settle(false),
      onHide: () => settle(false),
    })
  })
})
</script>

<template>
  <div>
    <button
      v-if="isEditing"
      type="button"
      class="dash-back mt-6"
      @click="router.back()"
    >
      <i class="pi pi-chevron-left text-xs" aria-hidden="true" /><span>返回</span>
    </button>
    <PageHeader :title="pageTitle" />

    <div
      v-if="isLoadingExisting"
      class="py-12 flex flex-col items-center justify-center gap-2 text-[var(--color-muted)]"
    >
      <i class="pi pi-spin pi-spinner text-2xl" aria-hidden="true" />
      <span class="text-[13px]">載入中…</span>
    </div>

    <form
      v-else
      @submit.prevent="submitForReview"
    >
      <!-- 辨識中整份表單暫停編輯，避免結果回來時覆蓋到正在輸入的欄位 -->
      <fieldset class="space-y-4 min-w-0" :disabled="isRecognizing" :aria-busy="isRecognizing">
      <!-- 1. 發票或收據 + 開始辨識 -->
      <div id="field-receipts" data-tour="expense-upload-area">
        <div class="field-label">
          發票或收據
        </div>

        <!-- 上傳區＋已上傳縮圖（同管理端原型：多張、序號、「加入」小格繼續加入，最多 5 張） -->
        <div class="card p-4 flex flex-col gap-3">
          <AttachmentField
            :attachments="receipts"
            :busy="isCompressing"
            accept="image/*,application/pdf"
            :hint="`JPG、PNG 或 PDF，可一次選多張（最多 ${MAX_RECEIPTS} 張），圖片會自動壓縮`"
            pdf-download
            :saved-deletes-now="false"
            :is-off="(r) => !ocrPicks.isPicked(r)"
            @add="addReceipts"
            @remove="uploads.remove"
            @expired="uploads.onExpired"
          >
            <template #cell-extra="{ att }">
              <label class="att-pick" :title="ocrPicks.isPicked(att) ? '辨識這張' : '不辨識（補充資料）'">
                <input type="checkbox" :checked="ocrPicks.isPicked(att)" :aria-label="`辨識 ${att.filename}`" @change="ocrPicks.toggle(att)" />
              </label>
            </template>
            <template v-if="isTouchDevice" #drop-extra>
              <div class="flex flex-wrap gap-2 justify-center mt-4" :class="{ 'opacity-60 pointer-events-none': isCompressing }">
                <label class="upload-pick">
                  <i class="pi pi-camera" aria-hidden="true" />
                  拍照
                  <input type="file" accept="image/*" capture="environment" class="sr-only" :disabled="isCompressing" @change="onPickerChange" />
                </label>
                <label class="upload-pick">
                  <i class="pi pi-folder-open" aria-hidden="true" />
                  選擇檔案
                  <input type="file" accept="image/*,application/pdf" multiple class="sr-only" :disabled="isCompressing" @change="onPickerChange" />
                </label>
              </div>
            </template>
          </AttachmentField>

          <div v-if="receipts.length > 0" class="flex flex-wrap items-center gap-2">
            <label
              v-if="isTouchDevice && receipts.length < MAX_RECEIPTS"
              class="upload-pick"
              :class="{ 'opacity-60 pointer-events-none': isCompressing }"
            >
              <i class="pi pi-camera" aria-hidden="true" />
              拍照加入
              <input type="file" accept="image/*" capture="environment" class="sr-only" :disabled="isCompressing" @change="onPickerChange" />
            </label>
            <Button
              type="button"
              :label="recognizeLabel"
              :icon="isRecognizing ? 'pi pi-spin pi-spinner' : 'pi pi-sparkles'"
              :disabled="isRecognizing || isCompressing || ocrSelectedCount === 0"
              @click="startRecognize"
            />
          </div>
          <p v-if="receipts.length > 0" class="text-sm text-[var(--color-muted)]">
            勾選的憑證會合併辨識，沒勾的當補充資料，不會扣辨識次數。
          </p>
          <p v-if="ocrQuotaText" class="text-sm text-[var(--color-muted)]" aria-live="polite">
            <i class="pi pi-sparkles text-xs" aria-hidden="true" /> OCR 辨識{{ ocrQuotaText }}
          </p>
          <p class="text-sm text-[var(--color-muted)]">
            <i class="pi pi-info-circle text-xs" aria-hidden="true" /> {{ ocrReviewHint }}
          </p>
        </div>
      </div>

      <!-- 2. 憑證類型 radio -->
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

      <!-- 3. 發票日期（發票才有）/ 發生日期 / 賣方統編 / 賣方名稱 / 發票號碼 -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div v-if="documentType === 'invoice'" id="field-invoiceDate">
          <label for="invoiceDate" class="field-label">
            發票日期 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <DatePicker
            :model-value="invoiceDate"
            input-id="invoiceDate"
            date-format="yy-mm-dd"
            placeholder="請選擇發票日期"
            class="w-full"
            show-icon
            icon-display="input"
            @update:model-value="(v) => { dates.setInvoiceDate(asDate(v)); clearFieldError('invoiceDate'); clearFieldError('incurredAt') }"
            @date-select="dates.commitInvoiceDate()"
            @blur="dates.commitInvoiceDate()"
          />
          <p
            v-if="fieldErrors.invoiceDate"
            class="mt-1 text-xs text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.invoiceDate }}
          </p>
        </div>
        <div id="field-incurredAt">
          <label for="incurredAt" class="field-label">
            發生日期 <span class="text-[var(--color-status-rejected)]">*</span>
          </label>
          <DatePicker
            :model-value="incurredAt"
            input-id="incurredAt"
            date-format="yy-mm-dd"
            placeholder="請選擇發生日期"
            class="w-full"
            show-icon
            icon-display="input"
            @update:model-value="(v) => { dates.setOccurred(asDate(v)); clearFieldError('incurredAt') }"
          />
          <p
            v-if="fieldErrors.incurredAt"
            class="mt-1 text-xs text-[var(--color-status-rejected)]"
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
            @update:model-value="clearFieldError('taxId')"
          />
          <p
            v-if="fieldErrors.taxId"
            class="mt-1 text-xs text-[var(--color-status-rejected)]"
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
            @update:model-value="clearFieldError('vendor')"
          />
          <p
            v-if="fieldErrors.vendor"
            class="mt-1 text-xs text-[var(--color-status-rejected)]"
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
              aria-label="發票號碼前段（英文 2 碼）"
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
              aria-label="發票號碼後段（數字 8 碼）"
              @update:model-value="(v) => onInvoiceDigitsInput(String(v ?? ''))"
            />
          </div>
          <p
            v-if="fieldErrors.invoiceNo"
            class="mt-1 text-xs text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.invoiceNo }}
          </p>
        </div>
        <!-- 收據：金額與名稱並排（發票的金額 3 欄維持在下方獨立一區） -->
        <div v-if="documentType === 'receipt'" id="field-amount">
          <label for="amount" class="field-label">
            總金額 <span class="text-[var(--color-status-rejected)]">*</span>
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
          <p
            v-if="fieldErrors.amount"
            class="mt-1 text-xs text-[var(--color-status-rejected)]"
          >
            {{ fieldErrors.amount }}
          </p>
        </div>
      </div>

      <!-- 4. 稅率 3 欄（未稅金額 / 稅率 / 含稅金額） -->
      <div v-if="documentType === 'invoice'" id="field-amount">
        <div class="field-label">
          金額 <span class="text-[var(--color-status-rejected)]">*</span>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div>
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
          <div>
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
              含稅金額
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
          class="mt-1 text-xs text-[var(--color-muted)] tabular-nums"
        >
          {{ taxAmountText }}
        </p>
        <p
          v-if="fieldErrors.amount"
          class="mt-1 text-xs text-[var(--color-status-rejected)]"
        >
          {{ fieldErrors.amount }}
        </p>
      </div>

      <!-- 5. 品項明細（選填） -->
      <ItemsEditor v-model="items" />

      <!-- 6. 費用類別 -->
      <div id="field-category">
        <label
          for="category"
          class="field-label"
        >
          費用類別 <span class="text-[var(--color-status-rejected)]">*</span>
        </label>
        <Select
          v-model="categoryId"
          input-id="category"
          :options="categoryOptions"
          option-label="label"
          option-value="value"
          placeholder="請選擇類別"
          class="w-full"
          :disabled="isRecognizing"
          @update:model-value="clearFieldError('category')"
        >
          <template #option="{ option }">
            <span class="text-sm">{{ option.label }}</span>
            <span
              v-if="option.accountCode"
              class="ml-2 text-xs text-[var(--color-muted)] tabular-nums"
            >
              {{ option.accountCode }}
            </span>
          </template>
        </Select>
        <p
          v-if="fieldErrors.category"
          class="mt-1 text-xs text-[var(--color-status-rejected)]"
        >
          {{ fieldErrors.category }}
        </p>
      </div>

      <!-- 7. 描述 -->
      <div>
        <label
          for="description"
          class="field-label"
        >
          描述
        </label>
        <Textarea
          auto-resize
          id="description"
          v-model="description"
          rows="3"
          class="w-full"
          placeholder="說明費用用途、對象等（選填）"
        />
      </div>

      <!-- 按鈕列：放在表單底部（同管理端新增支出） -->
      <div class="front-form-actions">
        <Button
          v-if="isResubmitting"
          type="button"
          outlined
          label="取消"
          :disabled="isSubmitting"
          @click="cancelResubmit"
        />
        <Button
          v-else
          type="button"
          outlined
          label="儲存草稿"
          :disabled="isSubmitting"
          @click="saveDraft"
        />
        <Button
          type="submit"
          :label="isResubmitting ? '重新送出簽核' : '送出簽核'"
          :loading="isSubmitting"
        />
      </div>
      </fieldset>
    </form>

    <OcrConflictDialog
      :conflict="ocrConflict"
      role="reimbursement"
      @confirm="ocr.resolveConflicts"
      @close="ocr.dismissConflicts"
    />
  </div>
</template>
