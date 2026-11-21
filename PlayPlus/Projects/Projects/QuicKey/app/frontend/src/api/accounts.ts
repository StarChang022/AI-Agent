/**
 * Account API — 公司收付帳戶 endpoints，僅 admin。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §2.9、docs/dev/accounts-api.md。
 */

import type { Account, AccountRef } from '@/types/domain'
import type { Paginated } from './expenses'
import { HttpError, service } from './service'

export type { Account }

/** 下拉選單的一筆 */
export type AccountOption = AccountRef & {
  /** 實收／實付日期早於它時提示不計入現金流；紀錄內嵌的帳戶（只有 id、name）沒有這欄 */
  openingMonth?: string
}

/**
 * GET /accounts/options
 * 下拉選單用，全量不分頁。lastUsedAccountId 是這位使用者最後建立的一筆收支所用的帳戶
 * （支出、收入共用）；從未用過或該帳戶已刪除時為 null。值會隨新增收支變動，不要快取。
 */
export interface AccountOptionsResponse {
  data: AccountOption[]
  lastUsedAccountId: string | null
}

export function getAccountOptions(): Promise<AccountOptionsResponse> {
  return service.get<AccountOptionsResponse>('/accounts/options')
}

export interface ListAccountsQuery {
  page?: number
  perPage?: number
}

/** GET /accounts 帳戶設定頁列表，依建立時間舊到新。 */
export function listAccounts(query?: ListAccountsQuery): Promise<Paginated<Account>> {
  return service.get<Paginated<Account>>('/accounts', { query })
}

/** 垃圾桶列表；共用 /accounts index，依刪除時間新到舊。 */
export function listTrashedAccounts(query?: ListAccountsQuery): Promise<Paginated<Account>> {
  return service.get<Paginated<Account>>('/accounts', { query: { ...query, discarded: true } })
}

export interface CreateAccountRequest {
  name: string
  openingAmount: number
  /** YYYY-MM，範圍 2000 年 1 月至當月 */
  openingMonth: string
}

/** 名稱重複回 409 DUPLICATE_NAME（垃圾桶內的帳戶也算）。 */
export function createAccount(body: CreateAccountRequest): Promise<Account> {
  return service.post<Account>('/accounts', body)
}

/** 只帶要改的欄位。 */
export type UpdateAccountRequest = Partial<
  Pick<CreateAccountRequest, 'name' | 'openingAmount' | 'openingMonth'>
>

export function updateAccount(id: string, body: UpdateAccountRequest): Promise<Account> {
  return service.patch<Account>(`/accounts/${id}`, body)
}

export interface OpeningMonthImpact {
  /** 改完後實收／實付日期早於起始月份的已收付總筆數，原本就不計入的也算在內 */
  outsideCashFlowCount: number
  /** 垃圾桶外、日期早於這個月份的移轉筆數；大於 0 時這個月份存不了 */
  blockingTransferCount: number
  /** 上述移轉最早的日期；沒有時為 null */
  earliestTransferDate: string | null
}

/** GET /accounts/:id/opening-month-impact 只查詢，不寫入。 */
export function getOpeningMonthImpact(id: string, openingMonth: string): Promise<OpeningMonthImpact> {
  return service.get<OpeningMonthImpact>(`/accounts/${id}/opening-month-impact`, {
    query: { openingMonth },
  })
}

/** 進垃圾桶。被引用時回 409 ACCOUNT_IN_USE。 */
export function deleteAccount(id: string): Promise<void> {
  return service.delete<void>(`/accounts/${id}`)
}

export function restoreAccount(id: string): Promise<Account> {
  return service.patch<Account>(`/accounts/${id}/restore`)
}

export function purgeAccount(id: string): Promise<void> {
  return service.delete<void>(`/accounts/${id}/purge`)
}

/**
 * 收支選的帳戶已失效（在編輯期間被刪除）。檢查時已刪除回 ACCOUNT_NOT_FOUND；
 * 檢查通過後、存檔前才被刪除回 validation_failed，details.accountId 有訊息。
 */
export function isAccountUnavailable(err: unknown): boolean {
  if (!(err instanceof HttpError)) return false
  const body = err.body as { error?: string; details?: { accountId?: unknown } } | undefined
  return body?.error === 'ACCOUNT_NOT_FOUND' || !!body?.details?.accountId
}
