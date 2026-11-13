import type { Attachment } from '@/types/domain'

/**
 * 圖檔簽章網址失效（約 1～2 小時）時，重撈該紀錄的單筆 API 拿新網址（docs/dev/attachments-api.md「讀取」）。
 * - 同一張只重撈一次：以失效的網址判斷，重撈拿到的網址還是讀不到就顯示「無法顯示」，不再重試；
 *   新網址日後再失效時可以再重撈
 * - 同一筆紀錄同時有好幾張失效時只打一次 API
 */
export function useAttachmentUrlRefresh() {
  const tried = new Set<string>()
  const inflight = new Map<string, Promise<Attachment[] | null>>()

  /**
   * failedUrl：讀不到的那個網址；recordKey：所屬紀錄（同一筆共用一次重撈）；
   * fetch：重撈單筆紀錄、回傳最新的圖檔清單。這個網址已重撈過或重撈失敗回 null
   */
  function refresh(
    failedUrl: string,
    recordKey: string,
    fetch: () => Promise<Attachment[]>,
  ): Promise<Attachment[] | null> {
    if (tried.has(failedUrl)) return Promise.resolve(null)
    tried.add(failedUrl)
    let p = inflight.get(recordKey)
    if (!p) {
      p = fetch()
        .catch(() => null)
        .finally(() => inflight.delete(recordKey))
      inflight.set(recordKey, p)
    }
    return p
  }

  return { refresh }
}

/** 新網址依 id 套回清單（清單由呼叫端持有） */
export function applyFreshUrls(
  list: ReadonlyArray<{ id: string | null; url: string | null }>,
  fresh: ReadonlyArray<Attachment>,
) {
  const urls = new Map(fresh.map((a) => [a.id, a.url]))
  for (const a of list) {
    const url = a.id ? urls.get(a.id) : undefined
    if (url) a.url = url
  }
}
