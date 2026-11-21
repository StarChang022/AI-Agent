/**
 * DataExport API — 資料匯出，admin 專用（PRD 第 24 條、docs/資料模型.md §3.7）。
 * 契約見 docs/dev/data-export-api.md。
 *
 * - createDataExport（POST /data-exports）：沒有圖檔時當下回 CSV 直接下載；有圖檔改背景產生，回 { id, status }
 * - getDataExport（GET /data-exports/:id）：下載頁
 * - getDataExportFileUrl（GET /data-exports/:id/files/:key）：取短效下載網址，前端直接跳轉
 */
import { resolveApiUrl, service } from './service'
import { toIsoDate } from '@/utils/format'
import type { CollectionStatus, PayoutStatus } from '@/types/domain'
import type { ExpenseSourceFilter } from './expenses'
import type { AdminReimbursementListFilters } from './reimbursements'

export type DataExportKind = 'expense' | 'income' | 'reimbursement'
/** single = 明細單筆；filtered = 頁首「全部」，依列表目前的分頁標籤與篩選 */
export type DataExportScope = 'single' | 'selected' | 'filtered'
export type DataExportStatus = 'queued' | 'processing' | 'completed' | 'failed'
export type DataExportFileKey = 'expense_csv' | 'income_csv' | 'reimbursement_csv' | 'attachments_zip'

/** 「全部」匯出的篩選條件：沿用列表查詢參數（不含分頁）；發生日期區間選填 */
export interface ExpenseExportFilters {
  dateFrom?: string
  dateTo?: string
  source?: ExpenseSourceFilter
  categoryIds?: string[]
  payoutStatus?: PayoutStatus
  q?: string
  missingInvoiceNo?: boolean
}
export interface IncomeExportFilters {
  dateFrom?: string
  dateTo?: string
  recurring?: boolean
  categoryIds?: string[]
  collectionStatus?: CollectionStatus
  q?: string
  missingInvoiceNo?: boolean
}
export type ReimbursementExportFilters = Omit<AdminReimbursementListFilters, 'page' | 'perPage'>

export type CreateDataExportRequest =
  | { kind: DataExportKind; scope: 'single' | 'selected'; ids: string[] }
  | { kind: 'expense'; scope: 'filtered'; filters: ExpenseExportFilters }
  | { kind: 'income'; scope: 'filtered'; filters: IncomeExportFilters }
  | { kind: 'reimbursement'; scope: 'filtered'; filters: ReimbursementExportFilters }

export type CreateDataExportResult =
  | { downloaded: true }
  | { downloaded: false; data: { id: string; status: DataExportStatus } }

export interface DataExportFile {
  key: DataExportFileKey
  kind: 'csv' | 'zip'
  filename: string
  byteSize: number
}

export interface DataExport {
  id: string
  scope: DataExportScope
  kind: DataExportKind
  /** 例：「支出 單筆」「支出 勾選 12 筆」「收入 全部」「支出 2026/11/01–2026/11/30」 */
  scopeLabel: string
  recordCount: number
  withAttachments: boolean
  /** false = 當下下載，沒有存檔 */
  background: boolean
  status: DataExportStatus
  createdAt: string
  completedAt: string | null
  expiresAt: string | null
  expired: boolean
  requestedBy: { id: string; name: string } | null
  /** 完成且未失效才有；其餘為 [] */
  files: DataExportFile[]
}

/** 當下下載時，伺服器沒給檔名才用這個 */
function fallbackFilename(kind: DataExportKind): string {
  const label = kind === 'income' ? '收入' : kind === 'expense' ? '支出' : '代墊款'
  return `${label}_${toIsoDate(new Date())}.csv`
}

export function createDataExport(body: CreateDataExportRequest): Promise<CreateDataExportResult> {
  return service.postMaybeFile<{ id: string; status: DataExportStatus }>('/data-exports', body, {
    fallbackFilename: fallbackFilename(body.kind),
  })
}

/** 只給匯出下載頁用：頁面自己處理 401（顯示請重新登入），不自動登出 */
export function getDataExport(id: string): Promise<DataExport> {
  return service.get<DataExport>(`/data-exports/${id}`, { keepSessionOn401: true })
}

/** 回可直接開啟的下載網址（已轉成完整網址） */
export async function getDataExportFileUrl(id: string, key: DataExportFileKey): Promise<string> {
  const { url } = await service.get<{ url: string }>(`/data-exports/${id}/files/${key}`, { keepSessionOn401: true })
  return resolveApiUrl(url)
}
