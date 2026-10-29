/**
 * Income API — 收入 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §2.6、§4.3、docs/收入管理規格.md。
 */

import type {
  CollectionStatus,
  DocumentType,
  Income,
  IncomeAttachment,
  IncomeItem,
  TaxRate,
} from '@/types/domain'
import { service } from './service'

export type { Income }

/**
 * POST /incomes
 * 建立一筆收入。collectionStatus='collected' 時後端 MUST 立即寫入 collectionStatus + collectedAt：
 * - 若 client 一併帶 collectedAt → 以該日為收款日
 * - 未帶 collectedAt → 後端用今天
 * collectionStatus='uncollected'（或未帶）時 collectedAt 忽略。
 * 建立後要切換狀態走 /collect / /revert-collect 專用 endpoint，不走 PATCH。
 */
export interface CreateIncomeRequest {
  customer: string
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
  attachments: IncomeAttachment[]
  items: IncomeItem[]
  collectionStatus: CollectionStatus
  collectedAt: string | null
}

/**
 * PATCH /incomes/:id
 * 更新收入。所有欄位皆為 optional；後端 MUST 只覆寫 client 傳來的欄位。
 * MUST NOT 用此 endpoint 改 collectionStatus（走 /collect 與 /revert-collect 專用 endpoint）。
 * 可帶 collectedAt 修正收款日，但後端僅在 collection_status='collected' 時套用，
 * 否則回 COLLECTED_AT_REQUIRED / 忽略。
 */
export type UpdateIncomeRequest = Partial<
  Omit<CreateIncomeRequest, 'collectionStatus'>
>

/**
 * GET /incomes
 * 收入列表查詢；所有 filter 皆為 optional，未傳表示不過濾。
 * - q：對 customer / note / invoice_no 三欄 OR 比對（ILIKE）
 * - categoryIds：多選類別；由 service.ts 展開為 `category_ids[]=a&category_ids[]=b`
 * - discarded：true → 回垃圾桶（已軟刪）；未帶或 false → 正常列表
 */
export interface ListIncomesQuery {
  categoryIds?: string[]
  collectionStatus?: CollectionStatus
  q?: string
  /** YYYY-MM-DD 起始，包含當日 */
  dateFrom?: string
  /** YYYY-MM-DD 迄止，包含當日 */
  dateTo?: string
  discarded?: boolean
  page?: number
  pageSize?: number
}

export function listIncomes(query?: ListIncomesQuery): Promise<Income[]> {
  return service.get<Income[]>('/incomes', { query })
}

export function getIncome(id: string): Promise<Income> {
  return service.get<Income>(`/incomes/${id}`)
}

export function createIncome(body: CreateIncomeRequest): Promise<Income> {
  return service.post<Income>('/incomes', body)
}

export function updateIncome(
  id: string,
  body: UpdateIncomeRequest,
): Promise<Income> {
  return service.patch<Income>(`/incomes/${id}`, body)
}

/**
 * PATCH /incomes/:id/collect
 * 標記為已收款。collectedAt 可選；未帶時後端用今天。
 */
export function collectIncome(
  id: string,
  body?: { collectedAt?: string },
): Promise<Income> {
  return service.patch<Income>(`/incomes/${id}/collect`, body)
}

/**
 * PATCH /incomes/:id/revert-collect
 * 取消收款：改回 uncollected；後端 MUST 保留 collectedAt（規格要求資料不清空）。
 */
export function revertCollectIncome(id: string): Promise<Income> {
  return service.patch<Income>(`/incomes/${id}/revert-collect`)
}

/**
 * DELETE /incomes/:id
 * 軟刪：進垃圾桶（寫入 deletedAt）。已收款（collected）→ 後端回 409 COLLECTED_NOT_DELETABLE
 * （對齊規格「待收款、待付款才能刪除」）。
 */
export function deleteIncome(id: string): Promise<void> {
  return service.delete<void>(`/incomes/${id}`)
}

/**
 * GET /incomes?discarded=true
 * 垃圾桶列表；共用 /incomes index，shape 與正常列表一致，deletedAt 必非 null，
 * 排序依 deletedAt 新到舊。
 */
export function listTrashedIncomes(
  query?: Omit<ListIncomesQuery, 'discarded'>,
): Promise<Income[]> {
  return listIncomes({ ...query, discarded: true })
}

/**
 * PATCH /incomes/:id/restore
 * 從垃圾桶還原，清掉 deletedAt。
 */
export function restoreIncome(id: string): Promise<Income> {
  return service.patch<Income>(`/incomes/${id}/restore`)
}

/**
 * DELETE /incomes/:id/purge
 * 永久刪除；呼叫端須已做二次確認。
 */
export function purgeIncome(id: string): Promise<void> {
  return service.delete<void>(`/incomes/${id}/purge`)
}
