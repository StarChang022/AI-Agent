/**
 * OCR 辨識結果 → 表單欄位的純函數。
 * 單筆辨識（useOcrRecognize）與批次匯入憑證（BatchReceiptImportDialog）共用，避免兩套對應規則。
 */
import type { OcrFieldKey, OcrFields, OcrItem, OcrRecognizeResponse } from '@/api/ocr'
import { getTaxRateValue } from '@/constants/expense'
import type { Attachment, DocumentType, ExpenseItem, TaxRate } from '@/types/domain'
import { toFormAttachment } from '@/composables/useAttachmentUploads'
import type { FormPageData, IncomeFormPageData } from '@/types/expense-form'

/** 發票號碼字軌 + 數字組回 `AB-12345678`；兩者皆空時為空字串 */
export function joinInvoiceNo(prefix: string, digits: string): string {
  const p = prefix.trim().toUpperCase()
  const d = digits.trim()
  if (!p && !d) return ''
  return `${p}-${d}`
}

/** 後端應回 camelCase 欄位名；保險起見 snake_case 也轉一次 */
export function toOcrFieldKey(raw: string): OcrFieldKey {
  return raw.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase()) as OcrFieldKey
}

/** 辨識結果的基礎值：有衝突的欄位先清空（等使用者挑選或自行輸入） */
export function ocrBaseResult(
  res: Pick<OcrRecognizeResponse, 'merged' | 'conflicts'>,
): { fields: OcrFields; items: OcrItem[] } {
  const { items, ...fields } = res.merged
  for (const c of res.conflicts.fields) fields[toOcrFieldKey(c.field)] = null
  return {
    fields,
    items: items.map((it) => ({ ...it })),
  }
}

/** 支出表單由辨識結果決定的欄位（類別、付款狀態、備註不是 OCR 給的，不在此列） */
export interface OcrExpenseValues {
  documentType: DocumentType
  /** 辨識出的日期：發票填發票日期、收據填發生日期（PRD 第 23 條），由表單決定放哪一欄 */
  ocrDate: Date | null
  taxId: string
  vendor: string
  invoicePrefix: string
  invoiceDigits: string
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  amount: number | null
  items: ExpenseItem[]
}

/**
 * 支出：賣方 = 對方；辨識不到的欄位為空。
 * 只讀到其中一個金額時，依稅率補齊另外兩欄（算法同表單手動輸入金額）。
 */
export function ocrToExpenseValues(f: OcrFields, items: OcrItem[]): OcrExpenseValues {
  const documentType = f.documentType ?? 'invoice'
  const isInvoice = documentType === 'invoice'
  const taxRate = f.taxRate ?? 'business_5'
  const rate = getTaxRateValue(taxRate)

  let { preTaxAmt, taxAmt, amount } = f
  if (amount !== null && (preTaxAmt === null || taxAmt === null)) {
    preTaxAmt = Math.round(amount / (1 + rate))
    taxAmt = amount - preTaxAmt
  } else if (amount === null && preTaxAmt !== null) {
    taxAmt = Math.round(preTaxAmt * rate)
    amount = preTaxAmt + taxAmt
  }

  return {
    documentType,
    ocrDate: f.incurredAt ? new Date(`${f.incurredAt}T00:00:00`) : null,
    taxId: f.counterpartyTaxId ?? '',
    vendor: f.counterpartyName ?? '',
    invoicePrefix: isInvoice ? (f.invoicePrefix ?? '').replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 2) : '',
    invoiceDigits: isInvoice ? (f.invoiceDigits ?? '').replace(/\D/g, '').slice(0, 8) : '',
    taxRate,
    preTaxAmt,
    taxAmt,
    amount,
    items: items.map((it) => ({ ...it })),
  }
}

/**
 * 批次匯入憑證一筆的日期：發票的日期填發票日期並帶入發生日期，收據的直接填發生日期；
 * 辨識不到日期時發生日期為今天。應收／應付日期留 null，載入這筆時帶預設值。
 */
function ocrPageDates(documentType: DocumentType, ocrDate: Date | null) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return {
    occurred: ocrDate ? new Date(ocrDate) : today,
    invoiceDate: documentType === 'invoice' ? ocrDate : null,
    plannedDate: null,
    occurredLocked: !!ocrDate,
  }
}

/**
 * 批次匯入憑證：一張憑證的辨識結果 → 新增支出頁的一筆。
 * 類別、帳戶、付款狀態、備註不是 OCR 給的，帶新增頁的預設值；憑證只附這張所在的那一頁。
 */
export function ocrToExpensePage(
  res: Pick<OcrRecognizeResponse, 'merged' | 'conflicts'>,
  attachment: Attachment | null,
): FormPageData {
  const base = ocrBaseResult(res)
  const { invoicePrefix, invoiceDigits, ocrDate, ...v } = ocrToExpenseValues(base.fields, base.items)
  const { occurred, ...dates } = ocrPageDates(v.documentType, ocrDate)
  return {
    ...v,
    ...dates,
    incurredAt: occurred,
    invoiceNo: joinInvoiceNo(invoicePrefix, invoiceDigits),
    categoryId: null,
    accountId: null,
    payoutStatus: 'pending',
    paidAt: null,
    note: '',
    // 暫存檔；同一頁拆出的多筆共用同一個 id，各自建立時都帶這個 id
    attachments: attachment ? [toFormAttachment(attachment, false)] : [],
  }
}

/**
 * 批次匯入憑證：一張憑證的辨識結果 → 新增收入頁的一筆。客戶 = 對方（買方，後端依 role 對應）；
 * 類別、帳戶、收款狀態、備註不是 OCR 給的，帶新增頁的預設值；憑證只附這張所在的那一頁。
 */
export function ocrToIncomePage(
  res: Pick<OcrRecognizeResponse, 'merged' | 'conflicts'>,
  attachment: Attachment | null,
): IncomeFormPageData {
  const base = ocrBaseResult(res)
  const { ocrDate, vendor, invoicePrefix, invoiceDigits, ...v } = ocrToExpenseValues(base.fields, base.items)
  const { occurred, ...dates } = ocrPageDates(v.documentType, ocrDate)
  return {
    ...v,
    ...dates,
    incomeDate: occurred,
    customer: vendor,
    invoiceNo: joinInvoiceNo(invoicePrefix, invoiceDigits),
    categoryId: null,
    accountId: null,
    collectionStatus: 'uncollected',
    collectedAt: null,
    note: '',
    // 暫存檔；同一頁拆出的多筆共用同一個 id，各自建立時都帶這個 id
    attachments: attachment ? [toFormAttachment(attachment, false)] : [],
  }
}
