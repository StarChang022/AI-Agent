import { HttpError } from '@/api/service'

export interface UserToast {
  /** 標題：動作或狀態（例如「已標記付款，無法移至垃圾桶」「刪除失敗」） */
  summary: string
  /** 內文：原因與處理方式 */
  detail: string
}

/** 刪除被擋時的提示（只有標題，不另附說明）。前置檢查與後端 409 共用，確保收入與支出文案一致。 */
export const DELETE_BLOCKED = {
  paid: {
    summary: '已標記付款，無法移至垃圾桶',
  },
  collected: {
    summary: '已標記收款，無法移至垃圾桶',
  },
} as const

/** 後端已知錯誤代碼 → 提示內容；沒有 detail 的只顯示標題 */
const KNOWN_CODE_TOASTS: Record<string, { summary: string; detail?: string }> = {
  PAID_NOT_DELETABLE: DELETE_BLOCKED.paid,
  COLLECTED_NOT_DELETABLE: DELETE_BLOCKED.collected,
  REIMBURSEMENT_VOIDED: {
    summary: '來源代墊款已作廢',
    detail: '請到請款記錄取消作廢，支出會一起還原。',
  },
  VOID_REQUIRED: {
    summary: '無法永久刪除',
    detail: '永久刪除需同時作廢來源代墊款。',
  },
  PAYMENT_METHOD_REQUIRED: {
    summary: '請選擇發放方式',
    detail: '員工代墊款標記已付款時，需選擇匯款或現金。',
  },
  NO_RECORDS: {
    summary: '沒有可匯出的紀錄',
    detail: '紀錄可能已移至垃圾桶，請重新整理後再試。',
  },
  LINKED_EXPENSE_PURGED: {
    summary: '對應的支出已永久刪除，無法取消作廢',
    detail: '如需撥款，請申請人重新提交請款。',
  },
}

const REFERENCE_LABELS: Record<string, string> = {
  expenses: '支出',
  incomes: '收入',
  transfers: '資金移轉',
  reimbursements: '代墊款',
  recurringTemplates: '固定收支範本',
  budgets: '過往預算',
}

/** 例：3 筆支出、2 筆收入。references 的 key 會隨功能增加，沒對照到的算「其他紀錄」 */
export function describeReferences(references: Record<string, number>): string {
  return Object.entries(references)
    .filter(([, count]) => count > 0)
    .map(([key, count]) => `${count} 筆${REFERENCE_LABELS[key] ?? '其他紀錄'}`)
    .join('、')
}

const GENERIC_DETAIL = '請稍後再試。'
const CJK_PATTERN = /[一-鿿]/

/** 後端附帶的中文說明（`{ error: CODE, message: 中文 }` 形式） */
function backendErrorMessage(err: unknown): string {
  if (err instanceof HttpError) {
    const body = err.body as { message?: unknown } | undefined
    return typeof body?.message === 'string' ? body.message : ''
  }
  return ''
}

function backendErrorCode(err: unknown): string {
  if (err instanceof HttpError) {
    const body = err.body as { error?: unknown } | undefined
    return typeof body?.error === 'string' ? body.error : ''
  }
  return ''
}

/**
 * 將錯誤轉成使用者看得懂的提示。
 * - 已知代碼：使用對應的標題與內文
 * - 後端回傳中文訊息（error 或 message）：標題用 title，內文直接顯示後端訊息
 * - 其他（英文代碼、網路錯誤等）：標題用 title，內文為通用提示，不顯示英文
 */
export function userErrorToast(err: unknown, title: string): UserToast {
  const code = backendErrorCode(err)
  if (Object.prototype.hasOwnProperty.call(KNOWN_CODE_TOASTS, code)) {
    // 空字串的 detail 在 Toast 不會顯示，只剩標題
    const known = KNOWN_CODE_TOASTS[code]
    return { summary: known.summary, detail: known.detail ?? '' }
  }
  if (CJK_PATTERN.test(code)) return { summary: title, detail: code }
  const message = backendErrorMessage(err)
  if (CJK_PATTERN.test(message)) return { summary: title, detail: message }
  if (err instanceof Error && CJK_PATTERN.test(err.message)) {
    return { summary: title, detail: err.message }
  }
  return { summary: title, detail: GENERIC_DETAIL }
}

/** 批次操作每筆失敗的原因：後端中文說明優先，其次已知代碼，都沒有就用通用文字 */
export function batchFailureReason(failure: { error?: string; message?: string }): string {
  if (failure.message && CJK_PATTERN.test(failure.message)) return failure.message
  const known = failure.error ? KNOWN_CODE_TOASTS[failure.error] : undefined
  if (known) return known.summary
  return '處理失敗，請稍後再試'
}
