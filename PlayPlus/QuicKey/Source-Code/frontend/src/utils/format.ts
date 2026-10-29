/**
 * 金額：一律「NT$ 12,340」（設計系統規範，tabular-nums 由呼叫端處理）。
 */
const numberFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 0,
})

export function formatCurrency(n: number): string {
  const sign = n < 0 ? '−' : ''
  return `${sign}NT$ ${numberFormatter.format(Math.abs(Math.round(n)))}`
}

const dateFormatter = new Intl.DateTimeFormat('zh-TW', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
})

export function formatDate(input: string | Date | null | undefined): string {
  if (!input) return '—'
  const d = input instanceof Date ? input : new Date(input)
  if (Number.isNaN(d.getTime())) return '—'
  return dateFormatter.format(d)
}

const dateTimeFormatter = new Intl.DateTimeFormat('zh-TW', {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

export function formatDateTime(input: string | Date | null | undefined): string {
  if (!input) return '—'
  const d = input instanceof Date ? input : new Date(input)
  if (Number.isNaN(d.getTime())) return '—'
  return dateTimeFormatter.format(d)
}

/**
 * 把 Date object 轉成 ISO 日期字串（YYYY-MM-DD，本地時區）。
 * 主要用來比較 store 內的字串型日期欄位（e.g. `incurredAt`）。
 */
export function toIsoDate(d: Date): string {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/**
 * 短日期格式（MM/DD）。用在首頁「最近一次：MM/DD · NT$X」等空間受限的地方。
 */
export function formatShortDate(input: string | Date | null | undefined): string {
  if (!input) return ''
  const d = input instanceof Date ? input : new Date(input)
  if (Number.isNaN(d.getTime())) return ''
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${m}/${day}`
}
