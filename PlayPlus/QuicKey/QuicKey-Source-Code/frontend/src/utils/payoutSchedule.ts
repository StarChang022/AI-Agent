/**
 * 付款日 helpers — 下拉選項、日期計算、顯示文案。
 *
 * 付款規則（docs/資料模型.md §3.1）：
 * - 每月一個付款日（1–31）。遇到天數較少的月份（例如 2 月沒有 30 號），改在該月最後一天。
 *   因此 31 等同「月底」。null = 關閉自動付款批次。
 * - 支出登錄 / 核准當下依公司 payoutDay 快照 plannedPayoutDate 與 autoPlannedPayoutDate
 *   寫入；之後公司改付款日「不動」任何已登錄支出。單筆要換付款日走「調整付款日」；
 *   「改回自動排程」把 plannedPayoutDate 還原為登錄當下的 autoPlannedPayoutDate。
 */

import { formatDate } from '@/utils/format'

export type PayoutDay = number
export const PAYOUT_DAY_MONTH_END = 31

/** 下拉選項：1–31 號，31 號標示「月底」，可輸入數字或「月底」搜尋 */
export const PAYOUT_DAY_OPTIONS: { value: PayoutDay; label: string }[] = Array.from({ length: 31 }, (_, i) => ({
  value: i + 1,
  label: i + 1 === PAYOUT_DAY_MONTH_END ? '31 號（月底）' : `${i + 1} 號`,
}))

/** 某年某月（month 0-based，可溢位）的付款日；超過該月天數時取該月最後一天 */
export function payoutDateOf(y: number, month: number, d: PayoutDay): Date {
  const last = new Date(y, month + 1, 0).getDate()
  return new Date(y, month, Math.min(d, last))
}

/** 登錄/核准日對應的付款日：登錄月的下個月付款日 */
export function autoPayoutDate(recordedIso: string, d: PayoutDay): Date {
  const [y, m] = recordedIso.slice(0, 10).split('-').map(Number)
  return payoutDateOf(y, m, d) // m 為 1-based，剛好就是「下個月」的 0-based index
}

/** 以登錄/核准日 + 付款日算出 snapshot ISO；day = null 時回傳 null */
export function snapshotPlannedPayoutDate(recordedIso: string, d: PayoutDay | null): string | null {
  if (d === null) return null
  const dt = autoPayoutDate(recordedIso, d)
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`
}

export function payoutDayLabel(d: PayoutDay): string {
  return d >= PAYOUT_DAY_MONTH_END ? '每月月底' : `每月 ${d} 號`
}

/**
 * 標記已付款確認視窗的付款日說明（PRD 規則 10）：付款日一律記為預計付款日，沒有才記今天。
 * 單筆寫出實際日期；多筆只說明規則。
 */
export function paidDateNote(rows: { plannedPayoutDate: string | null }[]): string {
  if (rows.length !== 1) return '付款日為各筆的預計付款日，若非此日期，請先調整預計付款日；沒有預計付款日的記為今天。'
  const planned = rows[0].plannedPayoutDate
  return planned
    ? `付款日為預計付款日 ${formatDate(planned)}，若非此日期，請先調整預計付款日。`
    : `付款日為今天 ${formatDate(new Date())}`
}
