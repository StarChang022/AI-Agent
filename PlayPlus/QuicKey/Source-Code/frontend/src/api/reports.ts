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
  net:     number
}

export interface CashflowTotal {
  cashIn:  number
  cashOut: number
  net:     number
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
