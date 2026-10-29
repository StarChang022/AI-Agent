/**
 * Reimbursement API — 代墊款請款 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 backend/app/controllers/api/reimbursements_controller.rb。
 */

import type {
  DocumentType,
  Reimbursement,
  ReimbursementStatus,
  TaxRate,
} from '@/types/domain'
import { service } from './service'

export type { Reimbursement }

/**
 * 後台列表（/reimbursements/admin）回傳的精簡 Reimbursement。
 * 拿掉 receipt_urls / receipt_names（憑證 base64 單筆就可能數 MB，乘上公司上百筆
 * 非常重）與 history（可成長的事件陣列）。對應後端 admin_list_item。
 * 詳情抽屜 / 編輯頁要全欄位時走 getReimbursement(id)。
 */
export type ReimbursementSummary = Omit<
  Reimbursement,
  'receiptUrls' | 'receiptNames' | 'history'
>

/**
 * 前台「我的請款」(/reimbursements) 回傳的精簡 Reimbursement。
 * 資料量小（單一員工自己的），保留 receiptUrls / receiptNames 讓 HistoryView
 * 卡片顯示縮圖；只砍 history。對應後端 my_list_item。
 */
export type MyReimbursementSummary = Omit<Reimbursement, 'history'>

export interface PaginationMeta {
  total: number
  page: number
  pageSize: number
}

export interface Paginated<T> {
  data: T[]
  meta: PaginationMeta
}

// ═══════════════════════════════════════════════════════
// List
// ═══════════════════════════════════════════════════════

/**
 * 列表共用篩選。
 * - status：單一狀態
 * - statuses：多狀態 OR（HistoryView 「待處理」= rejected + draft 等複合 tab 用）；
 *   後端同時收到 status 與 statuses 時 statuses 優先
 * - q：對 vendor / description / invoice_no 三欄 OR 比對（ILIKE）
 * - categoryIds：多選類別；由 service.ts 展開為 `category_ids[]=a&category_ids[]=b`
 * - dateFrom / dateTo：incurred_at（費用發生日）區間，YYYY-MM-DD，包含當日
 * - amountMin / amountMax：amount 區間，包含邊界
 * - page：1-based 頁碼，預設 1
 * - perPage：每頁筆數，預設 10（後端 DEFAULT_PAGE_SIZE），上限 100
 */
export interface ReimbursementListFilters {
  status?: ReimbursementStatus
  statuses?: ReimbursementStatus[]
  q?: string
  categoryIds?: string[]
  dateFrom?: string
  dateTo?: string
  amountMin?: number
  amountMax?: number
  page?: number
  perPage?: number
}

/**
 * GET /reimbursements
 * 前台「我的請款」：僅限 current_user 自己送的請款。
 * 回傳信封：{ data: MyReimbursementSummary[], meta: { total, page, pageSize } }
 */
export function listReimbursements(
  query?: ReimbursementListFilters,
): Promise<Paginated<MyReimbursementSummary>> {
  return service.get<Paginated<MyReimbursementSummary>>('/reimbursements', { query })
}

/**
 * GET /reimbursements/admin
 * 後台列表（審核 / 紀錄共用）：回公司全部請款，排除他人草稿。admin only。
 * 比 ReimbursementListFilters 多了：
 * - employeeId：指定申請人
 * - pendingForMe：只看「我（當前 admin）該簽核的 in_review」
 * - reviewedByMe：只看「我處理過的（非 draft/in_review）」
 * Top-N 用法（Dashboard「待簽核前 5 筆」等）改用 perPage。
 */
export interface AdminReimbursementListFilters extends ReimbursementListFilters {
  employeeId?: string
  pendingForMe?: boolean
  reviewedByMe?: boolean
}

export function listAdminReimbursements(
  query?: AdminReimbursementListFilters,
): Promise<Paginated<ReimbursementSummary>> {
  return service.get<Paginated<ReimbursementSummary>>('/reimbursements/admin', { query })
}

// ═══════════════════════════════════════════════════════
// Home KPI
// ═══════════════════════════════════════════════════════

/**
 * 前台 HomeView KPI 匯總（一次打包回來）：
 * - totals：三個狀態的金額加總
 * - counts：所有筆數 + 退回筆數（給「有 N 筆被退回」提示）
 * - lastPaid：最近一筆已發放，null 代表尚無發放紀錄
 * - recent：最近 4 筆任何狀態，shape 為 ReimbursementSummary（HomeView 不顯示縮圖）
 */
export interface MyReimbursementSummaryKpi {
  totals: {
    inReview: number
    approved: number
    paid: number
  }
  counts: {
    all: number
    rejected: number
  }
  lastPaid: { id: string; amount: number; updatedAt: string } | null
  recent: ReimbursementSummary[]
}

export function getMyReimbursementSummary(): Promise<MyReimbursementSummaryKpi> {
  return service.get<MyReimbursementSummaryKpi>('/reimbursements/my-summary')
}

// ═══════════════════════════════════════════════════════
// CRUD
// ═══════════════════════════════════════════════════════

/**
 * POST /reimbursements
 * 建立請款。asDraft=true → 存草稿（draft）；false → 直接送審（in_review）。
 * categoryId / amount / incurredAt 為 draft 專屬可空；送審時後端會強制必填。
 */
export interface CreateReimbursementRequest {
  categoryId: string | null
  amount: number | null
  description: string
  incurredAt: string | null
  receiptUrls: string[]
  receiptNames: string[]
  documentType: DocumentType
  vendor: string | null
  taxId: string | null
  invoiceNo: string | null
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  asDraft: boolean
}

/**
 * PATCH /reimbursements/:id
 * 更新請款。僅 draft / rejected 可編輯；rejected 一律重新送審（忽略 asDraft）。
 */
export type UpdateReimbursementRequest = CreateReimbursementRequest

export function getReimbursement(id: string): Promise<Reimbursement> {
  return service.get<Reimbursement>(`/reimbursements/${id}`)
}

export function createReimbursement(
  body: CreateReimbursementRequest,
): Promise<Reimbursement> {
  return service.post<Reimbursement>('/reimbursements', body)
}

export function updateReimbursement(
  id: string,
  body: UpdateReimbursementRequest,
): Promise<Reimbursement> {
  return service.patch<Reimbursement>(`/reimbursements/${id}`, body)
}

export function deleteReimbursement(id: string): Promise<void> {
  return service.delete<void>(`/reimbursements/${id}`)
}

// ═══════════════════════════════════════════════════════
// Approve / Reject / Void（admin only）
// ═══════════════════════════════════════════════════════

/**
 * PATCH /reimbursements/:id/approve
 * 核准（in_review → approved）；核准同時自動建立對應一般支出。
 */
export interface ApproveReimbursementRequest {
  comment?: string | null
}

/**
 * PATCH /reimbursements/:id/reject
 * 駁回（in_review → rejected）；comment 必填（空字串後端會回 422）。
 */
export interface RejectReimbursementRequest {
  comment: string
}

/**
 * PATCH /reimbursements/:id/void
 * 作廢（in_review / rejected / approved → voided）；paid 需先 revert_pay。
 * comment 必填。deleteExpense=true 時連帶把對應支出軟刪進垃圾桶。
 */
export interface VoidReimbursementRequest {
  comment: string
  deleteExpense?: boolean
}

export function approveReimbursement(
  id: string,
  body?: ApproveReimbursementRequest,
): Promise<Reimbursement> {
  return service.patch<Reimbursement>(`/reimbursements/${id}/approve`, body)
}

export function rejectReimbursement(
  id: string,
  body: RejectReimbursementRequest,
): Promise<Reimbursement> {
  return service.patch<Reimbursement>(`/reimbursements/${id}/reject`, body)
}

export function voidReimbursement(
  id: string,
  body: VoidReimbursementRequest,
): Promise<Reimbursement> {
  return service.patch<Reimbursement>(`/reimbursements/${id}/void`, body)
}

/**
 * PATCH /reimbursements/:id/withdraw
 * 申請人取消簽核（in_review → draft）；清空 approvalProgress，寫入 withdraw 事件。
 */
export function withdrawReimbursement(id: string): Promise<Reimbursement> {
  return service.patch<Reimbursement>(`/reimbursements/${id}/withdraw`)
}

/**
 * PATCH /reimbursements/:id/revert-void
 * 管理員取消作廢（voided → approved）。不自動還原連帶被軟刪的對應支出。
 */
export function revertVoidReimbursement(id: string): Promise<Reimbursement> {
  return service.patch<Reimbursement>(`/reimbursements/${id}/revert-void`)
}

// ═══════════════════════════════════════════════════════
// Export（admin only）
// ═══════════════════════════════════════════════════════

/**
 * GET /reimbursements/export?format=csv|xlsx
 * 匯出當前篩選結果（不分頁）；吃跟 /admin 相同的 filter 參數，但不帶 page/perPage。
 * filename 由伺服器 Content-Disposition 決定，傳入值僅在伺服器未指定時 fallback 用。
 */
export type ReimbursementExportFormat = 'csv' | 'xlsx'

export function exportReimbursements(
  format: ReimbursementExportFormat,
  filters?: Omit<AdminReimbursementListFilters, 'page' | 'perPage'>,
): Promise<void> {
  const today = new Date().toISOString().slice(0, 10)
  return service.downloadFile('/reimbursements/export', {
    query: { ...filters, format },
    filename: `請款記錄_${today}.${format}`,
  })
}
