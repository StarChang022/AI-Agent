/**
 * Reports API — 後台報表（損益、現金流）。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，由 `api/service.ts`
 * 於 request/response 邊界自動雙向轉換。對應 docs/收入管理規格.md §4、
 * 儀表板與報表-規格與實作計畫.md §二、§三。
 */

import { service } from './service'

export type ProfitLossBucket = 'month' | 'quarter' | 'year'

export interface ProfitLossRange {
  from: string
  to: string
  bucket: ProfitLossBucket
}

export interface ProfitLossRow {
  /** 期間標籤（例：'2026-01' / '2026-Q1' / '2026'） */
  label: string
  income:  number
  expense: number
  net:     number
  budget:  number
  /** 預算執行率（%，expense/budget*100；budget=0 時回 0） */
  budgetUsagePct: number
}

export interface ProfitLossTotal {
  income:  number
  expense: number
  net:     number
  budget:  number
  budgetUsagePct: number
}

export interface ProfitLoss {
  range: ProfitLossRange
  rows:  ProfitLossRow[]
  total: ProfitLossTotal
}

export interface GetProfitLossQuery {
  from?:   string
  to?:     string
  bucket?: ProfitLossBucket
}

/**
 * GET /reports/profit-loss
 * 損益報表：以開立日 / 費用發生日歸屬。預設當年度、bucket=月。
 */
export function getProfitLoss(query: GetProfitLossQuery = {}): Promise<ProfitLoss> {
  return service.get<ProfitLoss>('/reports/profit-loss', { query })
}

/**
 * GET /reports/profit-loss.xlsx
 * 損益報表 Excel 匯出。觸發瀏覽器下載，不回傳資料。
 */
export function downloadProfitLossXlsx(query: GetProfitLossQuery = {}): Promise<void> {
  return service.downloadFile('/reports/profit-loss.xlsx', {
    query,
    filename: 'profit-loss.xlsx',
  })
}

// ─── 現金流報表（§三） ─────────────────────────────────────────

export type CashflowBucket = 'month' | 'quarter' | 'year'

export interface CashflowRange {
  from: string
  to: string
  bucket: CashflowBucket
}

export interface CashflowRow {
  /** 期間標籤（例：'2026-01' / '2026-Q1' / '2026'） */
  label: string
  cashIn:  number
  cashOut: number
  /** 收款 − 付款，單一帳戶時再加上 transfer */
  net:     number
  /** 移轉淨額，轉入為正、轉出為負；選所有帳戶時沒有這個欄位 */
  transfer?: number
  /** 移轉筆數；轉入、轉出相抵時 transfer 是 0，用這個判斷有沒有移轉 */
  transferCount?: number
  /** 期初現金；尚未有任何帳戶開始的期間為 null，不是 0 */
  openingCash: number | null
  /** 期末現金；null 規則同 openingCash */
  closingCash: number | null
}

export interface CashflowTotal {
  cashIn:  number
  cashOut: number
  net:     number
  transfer?: number
  transferCount?: number
  /** 第一個有值的期間的期初 */
  openingCash: number | null
  /** 最後一個期間的期末 */
  closingCash: number | null
}

export interface PendingIn {
  id: string
  customer: string
  amount: number
  /** 開立日 ISO date */
  date: string
}

export interface PendingOut {
  id: string
  vendor: string | null
  amount: number
  /** 預計付款日 ISO date；可能為 null */
  plannedPayoutDate: string | null
}

export interface Cashflow {
  range: CashflowRange
  rows:  CashflowRow[]
  total: CashflowTotal
  pendingIn:  PendingIn[]
  pendingOut: PendingOut[]
}

export interface GetCashflowQuery {
  from?:   string
  to?:     string
  bucket?: CashflowBucket
  /** 未帶 = 所有帳戶合計；有帶時待收款、待付款清單也只列該帳戶 */
  accountId?: string
}

/**
 * GET /reports/cashflow
 * 現金流報表：以收款日 / 付款日歸屬。預設當年度、bucket=月。
 * pending_in / pending_out 為整家公司快照、不受期間限制。
 */
export function getCashflow(query: GetCashflowQuery = {}): Promise<Cashflow> {
  return service.get<Cashflow>('/reports/cashflow', { query })
}

/**
 * GET /reports/cashflow.xlsx
 * 現金流報表 Excel 匯出（3 分頁：現金流 / 待收款 / 待付款）。觸發瀏覽器下載。
 */
export function downloadCashflowXlsx(query: GetCashflowQuery = {}): Promise<void> {
  return service.downloadFile('/reports/cashflow.xlsx', {
    query,
    filename: 'cashflow.xlsx',
  })
}
