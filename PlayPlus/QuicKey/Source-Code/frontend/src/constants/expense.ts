import type {
  DocumentType,
  ReimbursementStatus,
  TaxRate,
} from '@/types/domain'

export const STATUS_LABELS: Record<ReimbursementStatus, string> = {
  draft: '草稿',
  in_review: '簽核中',
  rejected: '退回',
  approved: '已核銷',
  paid: '已發放',
  voided: '已作廢',
}

/**
 * 憑證類型（發票 / 收據）選項。radio 元件用。
 */
export const DOCUMENT_TYPE_OPTIONS: {
  value: DocumentType
  label: string
}[] = [
  { value: 'invoice', label: '發票' },
  { value: 'receipt', label: '收據' },
]

/**
 * 稅率選項（含機器判讀用的 rate 數值）。
 * business_5：營業稅 5%；exempt_0：免稅或收據 0%。
 * 見 design.md Decision 10
 */
export const TAX_RATE_OPTIONS: {
  value: TaxRate
  label: string
  rate: number
}[] = [
  { value: 'business_5', label: '營業稅 5%', rate: 0.05 },
  { value: 'exempt_0', label: '免稅 0%', rate: 0 },
]

/** 快速查表：TaxRate → 實際 rate 數值 */
export function getTaxRateValue(v: TaxRate): number {
  return TAX_RATE_OPTIONS.find((o) => o.value === v)?.rate ?? 0
}

/**
 * 台灣統一發票號碼格式：2 個英文字母 + 8 個數字，中間可含或不含連字號。
 * 見 design.md Decision 13
 */
export const INVOICE_NUMBER_REGEX = /^[A-Za-z]{2}-?\d{8}$/
