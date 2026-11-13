/**
 * 圖檔（憑證附件）API — 上傳成暫存檔、刪除暫存檔、讀取網址。
 * 對應 docs/dev/attachments-api.md、docs/資料模型.md §2.4。
 * 刪除已儲存的圖檔走各紀錄自己的 endpoint（api/expenses、incomes、transfers）。
 */

import type { Attachment } from '@/types/domain'
import { resolveApiUrl, service } from './service'

export type { Attachment }

/** 儲存紀錄時掛圖檔的錯誤代碼（422） */
export type AttachErrorCode = 'ATTACHMENT_NOT_FOUND' | 'TOO_MANY_ATTACHMENTS'

/** 每筆紀錄最多幾張、單檔上限（與後端相同） */
export const MAX_ATTACHMENTS = 5
export const MAX_ATTACHMENT_MB = 5

/**
 * POST /attachments — 上傳成暫存檔（一次 1～5 個），回傳順序同送出。
 * 任一個不符就整批不建立，throw HttpError（422）。
 */
export async function uploadAttachments(files: ReadonlyArray<File>): Promise<Attachment[]> {
  const form = new FormData()
  for (const f of files) form.append('files[]', f)
  const res = await service.post<{ data: Attachment[] }>('/attachments', form)
  return res.data
}

/**
 * DELETE /attachments — 刪除暫存檔。一律 204；已掛上紀錄、別人的、找不到的後端會略過，
 * 所以離開頁面時可以把這次上傳過的 id 全部送出。
 */
export function deleteTempAttachments(ids: ReadonlyArray<string>): Promise<void> {
  if (ids.length === 0) return Promise.resolve()
  if (ids.length === 1) return service.delete<void>(`/attachments/${encodeURIComponent(ids[0])}`)
  return service.delete<void>('/attachments', { query: { ids } })
}

/**
 * 圖檔的讀取網址。url 本身帶 token（不需登入標頭），可直接放 <img src>／<a href>。
 * download=true 時改為下載，檔名為原始檔名。網址約 1～2 小時後失效，失效時重撈單筆紀錄拿新網址。
 */
export function fileUrl(url: string, options: { download?: boolean } = {}): string {
  const resolved = resolveApiUrl(url)
  if (!options.download) return resolved
  return `${resolved}${resolved.includes('?') ? '&' : '?'}download=1`
}
