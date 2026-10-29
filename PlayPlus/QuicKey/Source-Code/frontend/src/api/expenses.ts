/**
 * Expense API — 一般支出 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §2.2、§4.2、§5.1。
 */

import type {
  DocumentType,
  Expense,
  ExpenseAttachment,
  ExpenseItem,
  ExpenseSource,
  PaymentMethod,
  PayoutStatus,
  TaxRate,
} from '@/types/domain'
import { service } from './service'

export type { Expense }

/**
 * 列表 API 回傳的精簡 Expense：拿掉 attachments 與 items 兩個可能很大的
 * jsonb 欄位（憑證 base64 單筆就可能數 MB），以及 autoPlannedPayoutDate
 * （只有詳情抽屜的「改回自動排程」會用到，列表不顯示）。對應後端 list_serialize。
 *
 * 詳情抽屜 / 編輯頁要全欄位時走 getExpense(id) 取 full Expense。
 */
export type ExpenseSummary = Omit<Expense, 'attachments' | 'items' | 'autoPlannedPayoutDate'>

/**
 * POST /expenses
 * 建立一筆一般支出（source 固定為 'general'，後端寫死；client 不傳）。
 * payoutStatus='paid' 時後端 MUST 立即寫入 payoutStatus + paidAt + paidBy：
 * - 若 client 一併帶 paidAt → 以該日為付款日
 * - 未帶 paidAt → 後端用今天
 * payoutStatus='pending'（或未帶）時 paidAt / paidBy 忽略。
 * 建立後要切換狀態走 /pay / /revert-pay 專用 endpoint，不走 PATCH。
 */
export interface CreateExpenseRequest {
  vendor: string | null
  taxId: string | null
  invoiceNo: string | null
  documentType: DocumentType
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  amount: number
  categoryId: string
  date: string
  note: string | null
  attachments: ExpenseAttachment[]
  items: ExpenseItem[]
  tags: string[]
  payoutStatus: PayoutStatus
  paidAt: string | null
}

/**
 * PATCH /expenses/:id
 * 更新支出。所有欄位皆為 optional；後端 MUST 只覆寫 client 傳來的欄位。
 * MUST NOT 用此 endpoint 改 payoutStatus（走 /pay 與 /revert-pay 專用 endpoint）。
 * 可帶 paidAt 修正付款日，但後端僅在 payout_status='paid' 時套用。
 */
export type UpdateExpenseRequest = Partial<
  Omit<CreateExpenseRequest, 'payoutStatus'>
>

/**
 * GET /expenses
 * 支出列表查詢；所有 filter 皆為 optional，未傳表示不過濾。
 * - q：對 vendor / note / invoice_no 三欄 OR 比對（ILIKE）
 * - categoryIds：多選類別；由 service.ts 展開為 `category_ids[]=a&category_ids[]=b`
 * - discarded：true → 回垃圾桶（已軟刪）；未帶或 false → 正常列表
 * - page：1-based 頁碼，預設 1
 * - perPage：每頁筆數，預設 10（後端 DEFAULT_PAGE_SIZE），上限 100
 *
 * 回傳信封：{ data: Expense[], meta: { total, page, pageSize } }
 */
export interface ListExpensesQuery {
  source?: ExpenseSource
  categoryIds?: string[]
  payoutStatus?: PayoutStatus
  q?: string
  /** YYYY-MM-DD 起始，包含當日 */
  dateFrom?: string
  /** YYYY-MM-DD 迄止，包含當日 */
  dateTo?: string
  discarded?: boolean
  page?: number
  perPage?: number
}

export interface PaginationMeta {
  total: number
  page: number
  pageSize: number
}

export interface Paginated<T> {
  data: T[]
  meta: PaginationMeta
}

export function listExpenses(query?: ListExpensesQuery): Promise<Paginated<ExpenseSummary>> {
  return service.get<Paginated<ExpenseSummary>>('/expenses', { query })
}

/**
 * GET /expenses/pending-batches
 * 待付款支出依預計付款日分組；逾期（< today）合併為一組 overdue。
 * 公司未設 payout_day 時後端回空陣列，前端自行決定 fallback（通常改用非分組視圖）。
 *
 * 一次回全部 pending（不分頁），把分組邏輯內聚到後端，避免前端用脆弱的
 * `perPage=100` 上限自己 group。
 */
export interface PendingBatchGroup {
  /** 'YYYY-MM-DD' 或 '0000-overdue'；UI 用來做 Vue :key */
  key: string
  /** 組內預計付款日；overdue 組取最早一筆，可能為 null（組內全無預計日） */
  date: string | null
  overdue: boolean
  total: number
  sourceMeta: { general: number; reimbursement: number }
  rows: ExpenseSummary[]
}

export function listPendingBatches(): Promise<{ groups: PendingBatchGroup[] }> {
  return service.get<{ groups: PendingBatchGroup[] }>('/expenses/pending-batches')
}

export function getExpense(id: string): Promise<Expense> {
  return service.get<Expense>(`/expenses/${id}`)
}

export function createExpense(body: CreateExpenseRequest): Promise<Expense> {
  return service.post<Expense>('/expenses', body)
}

export function updateExpense(
  id: string,
  body: UpdateExpenseRequest,
): Promise<Expense> {
  return service.patch<Expense>(`/expenses/${id}`, body)
}

/**
 * PATCH /expenses/:id/pay
 * - paidAt：未帶→後端用今天；帶→以指定日期為付款日
 * - paymentMethod：代墊款來源（source='reimbursement'）的支出 MUST 帶
 *   （'bank_transfer' | 'cash'），用於反向同步到連動的 Reimbursement；
 *   一般支出不要求、也不會儲存。
 */
export interface PayExpenseOptions {
  paidAt?: string | null
  paymentMethod?: PaymentMethod | null
}

export function payExpense(id: string, options?: PayExpenseOptions): Promise<Expense> {
  return service.patch<Expense>(`/expenses/${id}/pay`, options)
}

export function revertPayExpense(id: string): Promise<Expense> {
  return service.patch<Expense>(`/expenses/${id}/revert-pay`)
}

/**
 * PATCH /expenses/:id/adjust-payout-date
 * - date 有值 → 寫入並鎖定（plannedPayoutManual=true）
 * - date = null → 用公司當前付款日規則重新 snapshot 並解除鎖定
 * 僅 pending 可調（paid/voided 由後端擋）。
 */
export function adjustPayoutDate(id: string, date: string | null): Promise<Expense> {
  return service.patch<Expense>(`/expenses/${id}/adjust-payout-date`, { date })
}

/**
 * DELETE /expenses/:id?void_reimbursement=&void_comment=
 * 軟刪：進垃圾桶（寫入 deletedAt）。
 * - 已付款（paid）→ 後端回 409 PAID_NOT_DELETABLE
 * - 代墊款來源 → UI 可選是否連帶把對應代墊款作廢；需帶 voidReimbursement=true + voidComment
 */
export interface DeleteExpenseOptions {
  /** 連帶作廢來源代墊款（僅對 source='reimbursement' 的支出有意義） */
  voidReimbursement?: boolean
  /** voidReimbursement=true 時必填：作廢原因 */
  voidComment?: string
}

export function deleteExpense(
  id: string,
  options?: DeleteExpenseOptions,
): Promise<void> {
  return service.delete<void>(`/expenses/${id}`, { query: options })
}

/**
 * GET /expenses?discarded=true
 * 垃圾桶列表；共用 /expenses index，shape 與正常列表一致，deletedAt 必非 null，
 * 排序依 deletedAt 新到舊。
 */
export function listTrashedExpenses(
  query?: Omit<ListExpensesQuery, 'discarded'>,
): Promise<Paginated<ExpenseSummary>> {
  return listExpenses({ ...query, discarded: true })
}

/**
 * PATCH /expenses/:id/restore
 * 從垃圾桶還原，清掉 deletedAt。
 */
export function restoreExpense(id: string): Promise<Expense> {
  return service.patch<Expense>(`/expenses/${id}/restore`)
}

/**
 * DELETE /expenses/:id/purge
 * 永久刪除；呼叫端須已做二次確認。
 */
export function purgeExpense(id: string): Promise<void> {
  return service.delete<void>(`/expenses/${id}/purge`)
}
