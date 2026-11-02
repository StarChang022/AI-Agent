// 網站基本資訊（單一來源）。網址由 .env.production 的 VITE_SITE_URL 提供，正式網域確定後只改那裡。
export const SITE_URL = String(import.meta.env.VITE_SITE_URL ?? '').replace(/\/$/, '')
export const SITE_NAME = 'QUICKEY'
export const SITE_LOCALE = 'zh_TW'
export const SITE_DEFAULT_DESCRIPTION = 'QUICKEY 中小企業收支管理工具：記下收支、輕鬆請款、預算看得見。'

/** 完整網址（相對路徑 → 絕對網址） */
export function absoluteUrl(path: string): string {
  return `${SITE_URL}${path === '/' ? '/' : path}`
}
