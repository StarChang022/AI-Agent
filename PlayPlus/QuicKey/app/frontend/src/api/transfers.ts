/**
 * Transfer API — 資金移轉 endpoints，僅 admin。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §2.10、docs/dev/transfers-api.md。
 */

import type { Transfer } from '@/types/domain'
import type { Paginated } from './expenses'
import { service } from './service'

export type { Transfer }

/** 列表回的精簡版，少了可能很大的 attachments；編輯、抽屜要全欄位時走 getTransfer */
export type TransferSummary = Omit<Transfer, 'attachments'>

/** 帳戶相關錯誤指出是哪個欄位，兩邊都有問題時兩個都列 */
export type TransferSide = 'from' | 'to'

export interface ListTransfersQuery {
  /** true 時回垃圾桶，依刪除時間新到舊；不帶時依移轉日期新到舊 */
  discarded?: boolean
  /** YYYY-MM-DD 起始，包含當日 */
  dateFrom?: string
  /** YYYY-MM-DD 迄止，包含當日 */
  dateTo?: string
  fromAccountId?: string
  toAccountId?: string
  page?: number
  perPage?: number
}

export function listTransfers(query: ListTransfersQuery): Promise<Paginated<TransferSummary>> {
  return service.get<Paginated<TransferSummary>>('/transfers', { query })
}

/** 垃圾桶內的也查得到。 */
export function getTransfer(id: string): Promise<Transfer> {
  return service.get<Transfer>(`/transfers/${id}`)
}

export interface TransferRequest {
  fromAccountId: string
  toAccountId: string
  amount: number
  fee: number
  transferDate: string
  note: string | null
  /** 要新掛上的暫存檔 id，接在最後；已存的不用帶（拿掉走 deleteTransferAttachment） */
  attachmentIds: string[]
}

/** 手續費大於 0 時同時產生手續費支出。 */
export function createTransfer(body: TransferRequest): Promise<Transfer> {
  return service.post<Transfer>('/transfers', body)
}

/** 手續費支出的金額、日期、帳戶會同步更新；手續費改為 0 時該支出進垃圾桶。 */
export function updateTransfer(id: string, body: TransferRequest): Promise<Transfer> {
  return service.patch<Transfer>(`/transfers/${id}`, body)
}

/**
 * DELETE /transfers/:id/attachments/:attachmentId — 編輯時刪除已儲存的圖檔，立即永久刪除。
 * 回整筆移轉。垃圾桶內 409 IN_TRASH。
 */
export function deleteTransferAttachment(id: string, attachmentId: string): Promise<Transfer> {
  return service.delete<Transfer>(`/transfers/${id}/attachments/${encodeURIComponent(attachmentId)}`)
}

/** 進垃圾桶，任何時候都可以；手續費支出一併移入。 */
export function deleteTransfer(id: string): Promise<void> {
  return service.delete<void>(`/transfers/${id}`)
}

/** 手續費支出一併還原。移轉日期早於任一帳戶起始月份時回 409 TRANSFER_DATE_BEFORE_OPENING。 */
export function restoreTransfer(id: string): Promise<Transfer> {
  return service.patch<Transfer>(`/transfers/${id}/restore`)
}

/** 永久刪除；所有指向它的手續費支出一併永久刪除。 */
export function purgeTransfer(id: string): Promise<void> {
  return service.delete<void>(`/transfers/${id}/purge`)
}
