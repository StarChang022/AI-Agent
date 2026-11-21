/**
 * Notification API — 站內通知 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 backend/app/controllers/api/notifications_controller.rb。
 */

import type { Notification } from '@/types/domain'
import type { Paginated } from './reimbursements'
import { service } from './service'

export type { Notification }

/**
 * GET /notifications
 * - read: 'all' | 'unread' | 'read'，預設 all
 * - page / perPage：對齊公司分頁慣例（預設 10、ROWS_OPTIONS [10,20,50]）
 */
export interface ListNotificationsQuery {
  read?: 'all' | 'unread' | 'read'
  page?: number
  perPage?: number
}

export function listNotifications(
  query?: ListNotificationsQuery,
): Promise<Paginated<Notification>> {
  return service.get<Paginated<Notification>>('/notifications', { query })
}

/**
 * GET /notifications/unread-count
 * 鈴鐺紅點用。
 */
export function getUnreadCount(): Promise<{ unreadCount: number }> {
  return service.get<{ unreadCount: number }>('/notifications/unread-count')
}

/**
 * PATCH /notifications/:id/read
 * 標記單筆已讀；重複呼叫 no-op（保留第一次已讀時間）。
 */
export function markNotificationRead(id: string): Promise<Notification> {
  return service.patch<Notification>(`/notifications/${id}/read`)
}

/**
 * PATCH /notifications/mark-all-read
 * 批次標記所有未讀為已讀；回傳本次標了幾筆。
 */
export function markAllNotificationsRead(): Promise<{ updated: number }> {
  return service.patch<{ updated: number }>('/notifications/mark-all-read')
}
