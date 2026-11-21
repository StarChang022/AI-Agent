import { watch, type Ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

/**
 * 抽屜開關與網址 ?open=<id> 同步：
 * - 打開抽屜 → 網址帶 ?open；關閉 → 移除（用 replace，不多產生瀏覽紀錄）。
 * - 從其他頁連過來（?open=…）或按「上一頁」回來，都會自動打開對應抽屜。
 * 站內關聯連結（對應支出 ↔ 對應請款單）因此可以直接用一般連結跳轉，上一頁能回到原本的抽屜。
 */
export function useOpenQuery(openId: Ref<string | null>, exists?: (id: string) => boolean) {
  const route = useRoute()
  const router = useRouter()
  const queryId = () => (typeof route.query.open === 'string' ? route.query.open : null)

  watch(
    queryId,
    (id) => {
      if (id && exists && !exists(id)) {
        router.replace({ query: { ...route.query, open: undefined } })
        return
      }
      if (id !== openId.value) openId.value = id
    },
    { immediate: true },
  )
  watch(openId, (id) => {
    if (id !== queryId()) router.replace({ query: { ...route.query, open: id ?? undefined } })
  })
}
