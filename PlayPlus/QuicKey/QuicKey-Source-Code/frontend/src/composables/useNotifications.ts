/**
 * 通知清單共用 composable（見 docs/通知提醒.md）。
 *
 * 僅共用「鈴鐺紅點 + 操作 action」的狀態；通知中心頁的分頁 list 由頁面自己管。
 * 這樣鈴鐺跟通知中心任一方 markRead / markAllRead 後，另一方的紅點會同步。
 *
 * 已讀狀態由後端持久化（跨裝置同步），不再使用 localStorage。
 */
import { readonly, ref } from 'vue'
import type { RouteLocationRaw } from 'vue-router'
import {
  getUnreadCount,
  listNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type Notification,
} from '@/api/notifications'
import { formatDateTime } from '@/utils/format'

const PREVIEW_SIZE = 5

// 單例狀態：所有呼叫者共用同一份 unreadCount / preview
const unreadCount = ref(0)
const preview = ref<Notification[]>([])
const previewLoading = ref(false)

async function refreshUnreadCount() {
  try {
    const res = await getUnreadCount()
    unreadCount.value = res.unreadCount
  } catch {
    /* 失敗保留舊值，不打擾使用者 */
  }
}

async function refreshPreview() {
  previewLoading.value = true
  try {
    const res = await listNotifications({ read: 'unread', perPage: PREVIEW_SIZE })
    preview.value = res.data
    // meta.total 就是未讀總數（因 filter=unread），順手同步省一次 request
    unreadCount.value = res.meta.total
  } finally {
    previewLoading.value = false
  }
}

async function refresh() {
  await refreshPreview()
}

async function markRead(id: string) {
  const prevCount = unreadCount.value
  const prevPreview = preview.value
  // optimistic：先更新 UI，失敗時 rollback 再 refresh 保持一致
  unreadCount.value = Math.max(0, prevCount - 1)
  preview.value = prevPreview.filter((n) => n.id !== id)
  try {
    await markNotificationRead(id)
  } catch {
    unreadCount.value = prevCount
    preview.value = prevPreview
    await refreshPreview()
  }
}

async function markAllRead() {
  const prevCount = unreadCount.value
  const prevPreview = preview.value
  unreadCount.value = 0
  preview.value = []
  try {
    await markAllNotificationsRead()
  } catch {
    unreadCount.value = prevCount
    preview.value = prevPreview
  }
}

/**
 * 把後端 Notification 轉成列表顯示用的 title / sub / to。
 * payload 欄位對應見 docs/通知提醒.md；缺欄位時以空字串 fallback，避免 UI 爆掉。
 */
export interface NoticeView {
  id: string
  title: string
  sub: string
  readAt: string | null
  isRead: boolean
  to: RouteLocationRaw
}

export function describeNotification(n: Notification): NoticeView {
  const sub = formatDateTime(n.createdAt)
  return {
    id: n.id,
    title: titleFor(n),
    sub,
    readAt: n.readAt,
    isRead: n.readAt !== null,
    to: linkFor(n),
  }
}

function p(n: Notification, key: string): string {
  const v = n.payload?.[key]
  return v == null ? '' : String(v)
}

function titleFor(n: Notification): string {
  const desc = p(n, 'description')
  switch (n.kind) {
    case 'reimbursement_submitted':
      return `${p(n, 'actorName') || '員工'} 送出請款「${desc}」`
    case 'reimbursement_approved':
      return `你的請款「${desc}」已核准`
    case 'reimbursement_rejected':
      return `你的請款「${desc}」被駁回`
    case 'reimbursement_paid':
      return `你的請款「${desc}」已發放`
    case 'payout_overdue': {
      const count = p(n, 'overdueCount') || '多'
      const days = p(n, 'maxDays')
      return days
        ? `有 ${count} 筆代墊款逾期（最長 ${days} 天）`
        : `有 ${count} 筆代墊款逾期`
    }
    default:
      return '通知'
  }
}

function linkFor(n: Notification): RouteLocationRaw {
  const rid = p(n, 'reimbursementId')
  switch (n.kind) {
    case 'reimbursement_submitted':
      // admin 收：打開審核頁並 open 詳情
      return { name: 'admin-review', query: { open: rid } }
    case 'reimbursement_approved':
    case 'reimbursement_rejected':
    case 'reimbursement_paid':
      // employee 收：導向自己的請款詳情
      return { name: 'front-expense-detail', params: { id: rid } }
    case 'payout_overdue':
      // admin 收：導向待付款支出列表
      return { name: 'admin-expenses' }
    default:
      return { name: 'admin-notifications' }
  }
}

export function useNotifications() {
  return {
    unreadCount: readonly(unreadCount),
    preview: readonly(preview),
    previewLoading: readonly(previewLoading),
    refresh,
    refreshUnreadCount,
    refreshPreview,
    markRead,
    markAllRead,
  }
}
