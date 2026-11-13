/**
 * Dashboard API — 後台儀表板彙總。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，由 `api/service.ts`
 * 於 request/response 邊界自動雙向轉換。對應 docs/收入管理規格.md §5、
 * 儀表板與報表-規格與實作計畫.md §一。
 */

import { service } from './service'

export interface DashboardAmount {
  amount: number
  count: number
}

export interface DashboardPendingOut extends DashboardAmount {
  /** 待付款總額裡來自代墊款（source=reimbursement）的部分 */
  reimbursementAmount: number
  /** 待付款裡 planned_payout_date 已逾期的筆數 */
  overdueCount: number
}

export interface DashboardSummary {
  month: { start: string; end: string }
  monthlyIncome:  DashboardAmount
  monthlyExpense: DashboardAmount
  /** 本月收入 − 本月支出 */
  monthlyNet: number
  pendingIn:  DashboardAmount
  pendingOut: DashboardPendingOut
  inReview:   DashboardAmount
}

/**
 * GET /dashboard/summary
 * 回本月收入 / 支出 / 淨額、待收款、待付款（含未結清代墊款與逾期筆數）、待簽核。
 * 本月以 incomes.date / expenses.date 歸屬；垃圾桶與草稿代墊款不計入。
 */
export function getDashboardSummary(): Promise<DashboardSummary> {
  return service.get<DashboardSummary>('/dashboard/summary')
}

export type DashboardTrendBucket = 'day' | 'month'

export interface DashboardTrendRange {
  from: string
  to: string
  bucket: DashboardTrendBucket
}

export interface DashboardTrend {
  range: DashboardTrendRange
  /** 由 from → to 連續 bucket 的標籤（day=YYYY-MM-DD、month=YYYY-MM） */
  labels: string[]
  series: {
    income:  number[]
    expense: number[]
  }
}

export interface GetDashboardTrendQuery {
  from?: string
  to?: string
  bucket?: DashboardTrendBucket
}

/**
 * GET /dashboard/trend
 * 收支趨勢。預設近 12 個月（含本月）、bucket=month。labels 保留空桶，數值補 0。
 */
export function getDashboardTrend(query: GetDashboardTrendQuery = {}): Promise<DashboardTrend> {
  return service.get<DashboardTrend>('/dashboard/trend', { query })
}

export type CategoryBreakdownKind = 'expense' | 'income'

export interface CategoryBreakdownSlice {
  categoryId: string
  categoryName: string
  amount: number
  /** 佔總額的百分比（0–100，保留兩位） */
  pct: number
}

export interface DashboardCategoryBreakdown {
  range: { from: string; to: string; kind: CategoryBreakdownKind }
  total: number
  /** 依金額新到舊；只回有值的類別 */
  slices: CategoryBreakdownSlice[]
}

export interface GetCategoryBreakdownQuery {
  from?: string
  to?: string
  kind?: CategoryBreakdownKind
}

/**
 * GET /dashboard/category-breakdown
 * 期間內依類別分組的金額加總。預設當月、kind=expense；垃圾桶排除。
 */
export function getDashboardCategoryBreakdown(
  query: GetCategoryBreakdownQuery = {},
): Promise<DashboardCategoryBreakdown> {
  return service.get<DashboardCategoryBreakdown>('/dashboard/category-breakdown', { query })
}
