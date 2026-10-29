/**
 * AuditLog API — 稽核歷程查詢。
 *
 * 只有 index 一支：撈某 target（expense / income / reimbursement）的所有歷程，
 * admin 專用。UI 定位：三個詳情抽屜 inline 顯示該筆歷程，不做獨立後台頁。
 */
import { service } from './service'

export type AuditTargetType = 'expense' | 'income' | 'reimbursement'

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
  | 'refund'

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

export function listAuditLogs(
  targetType: AuditTargetType,
  targetId: string,
): Promise<AuditLogEntry[]> {
  return service.get<AuditLogEntry[]>('/audit-logs', {
    query: { targetType, targetId },
  })
}
