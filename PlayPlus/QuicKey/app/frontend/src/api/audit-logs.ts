/**
 * AuditLog API — 稽核日誌查詢，admin 專用。
 *
 * - listAuditLogHistory（GET /audit-logs/history）：某一筆對象的歷程，給詳情抽屜與帳戶設定頁 inline 顯示
 * - listAuditLogs（GET /audit-logs）/ getAuditLog（GET /audit-logs/:id）：後台稽核日誌頁（docs/資料模型.md §2.7）
 */
import type { Paginated } from './expenses'
import { service } from './service'

export type AuditTargetType =
  | 'expense'
  | 'income'
  | 'reimbursement'
  | 'account'
  | 'recurring_template'
  | 'category'
  | 'transfer'
  | 'budget'
  | 'data_export'

/**
 * 已知動作類型（對應後端 AuditLog::ACTIONS）。未來若後端加新動作，
 * 前端 fallback 顯示動作原文（snake_case）而不壞 render。
 */
export type AuditAction =
  | 'create'
  | 'update'
  | 'status_change'
  | 'delete'
  | 'restore'
  | 'purge'
  | 'void'
  | 'revert_void'
  | 'export'

export interface AuditLogEntry {
  id: string
  action: AuditAction | string
  /** 操作人姓名（取不到名字則退回 email）；極端狀況下可能為 null */
  actorName: string | null
  /** 變更前的 snapshot；create 時為 null */
  before: Record<string, unknown> | null
  /** 變更後的 snapshot；purge 時為 null */
  after: Record<string, unknown> | null
  /** ISO 8601 */
  createdAt: string
}

/** 稽核日誌頁的列表一筆：不含 before / after，明細走 getAuditLog */
export interface AuditLogSummary {
  id: string
  /** ISO 8601 */
  createdAt: string
  actorName: string | null
  targetType: AuditTargetType
  targetId: string
  /** 對象名稱；取不到時為 null，畫面只顯示類型 */
  targetLabel: string | null
  action: AuditAction | string
  /** 來源標示：excel_import / recurring / transfer_fee / budget_template / category_clear；一般操作為 null */
  via: string | null
}

export interface AuditLogDetail extends AuditLogSummary {
  before: Record<string, unknown> | null
  after: Record<string, unknown> | null
}

export interface ListAuditLogsQuery {
  targetType?: AuditTargetType
  action?: AuditAction
  actorId?: string
  /** YYYY-MM-DD 起始，包含當日；以操作時間為準 */
  dateFrom?: string
  /** YYYY-MM-DD 迄止，包含當日；以操作時間為準 */
  dateTo?: string
  page?: number
  perPage?: number
}

export function listAuditLogHistory(
  targetType: AuditTargetType,
  targetId: string,
): Promise<AuditLogEntry[]> {
  return service.get<AuditLogEntry[]>('/audit-logs/history', {
    query: { targetType, targetId },
  })
}

export function listAuditLogs(query: ListAuditLogsQuery): Promise<Paginated<AuditLogSummary>> {
  return service.get<Paginated<AuditLogSummary>>('/audit-logs', { query })
}

export function getAuditLog(id: string): Promise<AuditLogDetail> {
  return service.get<AuditLogDetail>(`/audit-logs/${id}`)
}
