/**
 * 金額：一律「NT$ 12,340」（設計系統規範，tabular-nums 由呼叫端處理）。
 */
const numberFormatter = new Intl.NumberFormat('en-US', {
  maximumFractionDigits: 0,
})
const exactNumberFormatter = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 })

/** 空值（例如請款草稿還沒填金額）顯示「—」，同 formatDate */
export function formatCurrency(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—'
  const sign = n < 0 ? '−' : ''
  return `${sign}NT$ ${numberFormatter.format(Math.abs(Math.round(n)))}`
}

/** 同 formatCurrency，但保留小數（最多 2 位）；用在要看出小數差異的地方，例如帳戶起始金額 */
export function formatCurrencyExact(n: number): string {
  return `NT$ ${exactNumberFormatter.format(n)}`
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

/** 月份格式（YYYY/MM）；傳 YYYY-MM-DD 或 YYYY-MM */
export function formatMonth(iso: string): string {
  return iso.slice(0, 7).replace('-', '/')
}

/** Date → YYYY-MM */
export function toIsoMonth(d: Date): string {
  return toIsoDate(d).slice(0, 7)
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

/** 檔案大小（B / KB / MB / GB） */
export function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`
  const kb = n / 1024
  if (kb < 1024) return `${kb.toFixed(1)} KB`
  const mb = kb / 1024
  return mb < 1024 ? `${mb.toFixed(1)} MB` : `${(mb / 1024).toFixed(2)} GB`
}

/**
 * 請款在通知、提示裡的稱呼：描述有填用描述；空白（含只有空白字元）改用類別名稱。
 * 規則見 docs/通知提醒.md 最後一節。
 */
export function reimbursementLabel(
  description: string | null | undefined,
  categoryName: string | null | undefined,
): string {
  return description?.trim() ? description : (categoryName ?? '')
}
