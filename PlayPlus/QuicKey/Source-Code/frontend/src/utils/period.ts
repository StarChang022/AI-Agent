/**
 * 期間選擇（period-picker）用的期間定義與換算。
 * 見 design-system/design-select-date.html「期間選擇」。
 */
export type PeriodPreset = 'today' | 'week' | 'month' | 'quarter' | '3m' | '6m' | '1y' | 'year' | 'custom'

export interface Period {
  preset: PeriodPreset
  /** preset === 'custom' 時的起訖日（含當天） */
  start?: Date | null
  end?: Date | null
}

export const PERIOD_OPTIONS: { value: Exclude<PeriodPreset, 'custom'>; label: string }[] = [
  { value: 'today', label: '本日' },
  { value: 'week', label: '本週' },
  { value: 'month', label: '本月' },
  { value: 'quarter', label: '本季' },
  { value: '3m', label: '近三個月' },
  { value: '6m', label: '近六個月' },
  { value: '1y', label: '近一年' },
  { value: 'year', label: '本年度' },
]

function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate())
}

/**
 * 把期間換成實際日期範圍（都算到今天）。本週從週一算。
 * byDay：本日/本週/本月，以及 31 天以內的自訂區間，圖表逐日顯示；其餘按月。
 */
export function resolvePeriod(p: Period, today: Date = new Date()): { start: Date; end: Date; byDay: boolean } {
  const t = startOfDay(today)
  const y = t.getFullYear()
  const m = t.getMonth()
  let start: Date
  let end: Date = t
  switch (p.preset) {
    case 'today':
      start = t
      break
    case 'week':
      start = new Date(y, m, t.getDate() - ((t.getDay() + 6) % 7))
      break
    case 'month':
      start = new Date(y, m, 1)
      break
    case 'quarter': {
      const qStart = Math.floor(m / 3) * 3
      start = new Date(y, qStart, 1)
      end = new Date(y, qStart + 3, 0)
      break
    }
    case '3m':
      start = new Date(y, m - 2, 1)
      break
    case '1y':
      start = new Date(y, m - 11, 1)
      break
    case 'year':
      start = new Date(y, 0, 1)
      end = new Date(y, 11, 31)
      break
    case 'custom':
      start = p.start ? startOfDay(p.start) : new Date(y, m - 5, 1)
      end = p.end ? startOfDay(p.end) : t
      break
    case '6m':
    default:
      start = new Date(y, m - 5, 1)
  }
  const days = (end.getTime() - start.getTime()) / 864e5
  const byDay = ['today', 'week', 'month'].includes(p.preset) || (p.preset === 'custom' && days < 31)
  return { start, end, byDay }
}

function pad(n: number) {
  return String(n).padStart(2, '0')
}

/** 期間按鈕上的文字：預設期間顯示名稱；自訂顯示起訖（同年省略結束年份） */
export function periodLabel(p: Period): string {
  if (p.preset !== 'custom' || !p.start || !p.end) {
    return PERIOD_OPTIONS.find((o) => o.value === p.preset)?.label ?? '自訂日期區間'
  }
  const a = p.start
  const b = p.end
  const left = `${a.getFullYear()}/${pad(a.getMonth() + 1)}/${pad(a.getDate())}`
  const right = a.getFullYear() === b.getFullYear() ? `${pad(b.getMonth() + 1)}/${pad(b.getDate())}` : `${b.getFullYear()}/${pad(b.getMonth() + 1)}/${pad(b.getDate())}`
  return `${left} – ${right}`
}

function ymd(d: Date) {
  return `${d.getFullYear()}/${pad(d.getMonth() + 1)}/${pad(d.getDate())}`
}

/**
 * 期間的實際起訖文字（例：2026/05/01 – 10/08；同年省略結束年份；單日只顯示一天）。
 * 用在選單選項右側與圖卡標題下方，讓「近六個月」這類預設期間看得出從哪天算起。
 */
export function periodRangeText(p: Period, today: Date = new Date()): string {
  const { start, end } = resolvePeriod(p, today)
  if (start.getTime() === end.getTime()) return ymd(start)
  const right = start.getFullYear() === end.getFullYear() ? `${pad(end.getMonth() + 1)}/${pad(end.getDate())}` : ymd(end)
  return `${ymd(start)} – ${right}`
}

// ─── Budget period helpers ─────────────────────────────
// 給預算模組用的「某月 / 某年」區間；回本地時區的 YYYY-MM-DD 字串
// （後端 Budget.period_start / period_end 用），不產生 Date 物件以免時區位移。

/**
 * 將 refDate 對應的自然月期間換算為 YYYY-MM-DD 字串（本地時區）。
 */
export function monthPeriod(refDate: Date): {
  periodStart: string
  periodEnd: string
} {
  const y = refDate.getFullYear()
  const m = refDate.getMonth()
  const start = new Date(y, m, 1)
  const end = new Date(y, m + 1, 0)
  return {
    periodStart: formatLocalDate(start),
    periodEnd: formatLocalDate(end),
  }
}

/**
 * 將 refDate 對應的自然年期間換算為 YYYY-MM-DD 字串（本地時區）。
 */
export function yearPeriod(refDate: Date): {
  periodStart: string
  periodEnd: string
} {
  const y = refDate.getFullYear()
  return {
    periodStart: `${y}-01-01`,
    periodEnd: `${y}-12-31`,
  }
}

export function formatLocalDate(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}
