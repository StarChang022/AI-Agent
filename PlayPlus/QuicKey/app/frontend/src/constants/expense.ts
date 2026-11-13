import type {
  DocumentType,
  Expense,
  ExpenseSource,
  ReimbursementStatus,
  TaxRate,
} from '@/types/domain'

export const STATUS_LABELS: Record<ReimbursementStatus, string> = {
  draft: '草稿',
  in_review: '簽核中',
  rejected: '駁回',
  approved: '已核銷',
  paid: '已發放',
  voided: '已作廢',
}

const EXPENSE_SOURCE_LABELS: Record<ExpenseSource, string> = {
  general: '一般支出',
  reimbursement: '代墊款',
  transfer_fee: '移轉手續費',
}

/** 支出列表的來源文字；固定收支產生的紀錄 source 仍是 general，以期數判斷 */
export function expenseSourceLabel(e: Pick<Expense, 'source' | 'recurringPeriod'>): string {
  if (e.recurringPeriod) return '固定'
  return EXPENSE_SOURCE_LABELS[e.source]
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

/** 與後端 Reimbursement::VOIDABLE_STATUSES 一致；已作廢、已發放的不再作廢 */
const VOIDABLE_REIMBURSEMENT: ReimbursementStatus[] = ['in_review', 'rejected', 'approved']

/** 來源代墊款還能作廢：刪除時詢問連帶作廢，永久刪除時一定一起作廢（PRD 第 12、18 條） */
export function canVoidSourceReimbursement(e: Pick<Expense, 'source' | 'sourceReimbursementStatus'>): boolean {
  return e.source === 'reimbursement' && !!e.sourceReimbursementStatus && VOIDABLE_REIMBURSEMENT.includes(e.sourceReimbursementStatus)
}
