import { HttpError } from '@/api/service'

export interface UserToast {
  /** 標題：動作或狀態（例如「已標記付款，無法移至垃圾桶」「刪除失敗」） */
  summary: string
  /** 內文：原因與處理方式 */
  detail: string
}

/** 刪除被擋時的提示。前置檢查與後端 409 共用，確保收入與支出文案一致。 */
export const DELETE_BLOCKED = {
  paid: {
    summary: '已標記付款，無法移至垃圾桶',
    detail: '若付款狀態登錄有誤，請取消付款標記，再刪除。',
  },
  collected: {
    summary: '已標記收款，無法移至垃圾桶',
    detail: '若收款狀態登錄有誤，請取消收款標記，再刪除。',
  },
} as const

/** 後端已知錯誤代碼 → 提示內容 */
const KNOWN_CODE_TOASTS: Record<string, UserToast> = {
  PAID_NOT_DELETABLE: DELETE_BLOCKED.paid,
  COLLECTED_NOT_DELETABLE: DELETE_BLOCKED.collected,
}

const GENERIC_DETAIL = '請稍後再試。'
const CJK_PATTERN = /[一-鿿]/

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
 * - 後端回傳中文訊息：標題用 title，內文直接顯示後端訊息
 * - 其他（英文代碼、網路錯誤等）：標題用 title，內文為通用提示，不顯示英文
 */
export function userErrorToast(err: unknown, title: string): UserToast {
  const code = backendErrorCode(err)
  if (Object.prototype.hasOwnProperty.call(KNOWN_CODE_TOASTS, code)) {
    return KNOWN_CODE_TOASTS[code]
  }
  if (CJK_PATTERN.test(code)) return { summary: title, detail: code }
  if (err instanceof Error && CJK_PATTERN.test(err.message)) {
    return { summary: title, detail: err.message }
  }
  return { summary: title, detail: GENERIC_DETAIL }
}
