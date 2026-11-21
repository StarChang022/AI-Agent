import { ref, shallowRef } from 'vue'
import type { DataTablePageEvent } from 'primevue/datatable'
import { useToast } from 'primevue/usetoast'
import type { Paginated } from '@/api/expenses'
import { userErrorToast } from '@/utils/userFeedback'

interface PagedListOptions<R> {
  fetcher: (query: { page: number; perPage: number }) => Promise<R>
  /** 載入失敗的提示標題；同一份列表切到垃圾桶時標題不同，所以用函式 */
  failTitle: () => string
  onLoaded?: (res: R) => void
}

/**
 * 伺服器端分頁列表的共用狀態（固定收支範本、資金移轉、類別垃圾桶）：
 * 丟掉過期回應、刪光最後一頁回上一頁、失敗時清空並提示。
 */
export function usePagedList<T, R extends Paginated<T> = Paginated<T>>(options: PagedListOptions<R>) {
  const toast = useToast()
  const rows = shallowRef<T[]>([])
  const total = ref(0)
  const page = ref(1)
  const pageSize = ref(10)
  const loading = ref(false)
  const failed = ref(false)

  let fetchSeq = 0
  async function refresh() {
    const seq = ++fetchSeq
    loading.value = true
    try {
      const res = await options.fetcher({ page: page.value, perPage: pageSize.value })
      if (seq !== fetchSeq) return
      // 刪掉最後一頁唯一的一筆後回到上一頁
      if (res.data.length === 0 && page.value > 1) {
        page.value -= 1
        await refresh()
        return
      }
      rows.value = res.data
      total.value = res.meta.total
      failed.value = false
      options.onLoaded?.(res)
    } catch (err) {
      if (seq !== fetchSeq) return
      failed.value = true
      rows.value = []
      total.value = 0
      toast.add({ severity: 'error', ...userErrorToast(err, options.failTitle()), life: 3500 })
    } finally {
      if (seq === fetchSeq) loading.value = false
    }
  }

  /** 換查詢條件時回到第一頁並清掉舊資料 */
  function reset() {
    page.value = 1
    rows.value = []
    total.value = 0
  }

  function onPage(evt: DataTablePageEvent) {
    page.value = evt.page + 1
    pageSize.value = evt.rows
    void refresh()
  }

  return { rows, total, page, pageSize, loading, failed, refresh, reset, onPage }
}
