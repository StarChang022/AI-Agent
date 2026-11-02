import { ref } from 'vue'
import { useToast } from 'primevue/usetoast'
import { getAccountOptions, type AccountOption } from '@/api/accounts'
import { userErrorToast } from '@/utils/userFeedback'

/**
 * 帳戶下拉的資料來源（收支表單、代墊款核准、現金流報表共用）。
 * lastUsedAccountId 隨新增收支變動，每次打開表單都要重新 load，不做跨頁快取。
 */
export function useAccountOptions() {
  const toast = useToast()
  const options = ref<AccountOption[]>([])
  const lastUsedAccountId = ref<string | null>(null)
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      const res = await getAccountOptions()
      options.value = res.data
      lastUsedAccountId.value = res.lastUsedAccountId
    } catch (err) {
      toast.add({ severity: 'error', ...userErrorToast(err, '載入帳戶失敗'), life: 3500 })
    } finally {
      loading.value = false
    }
  }

  /** 表單內新增帳戶後補進清單；編輯既有紀錄時確保目前的帳戶選得到 */
  function add(account: AccountOption) {
    if (!options.value.some((a) => a.id === account.id)) options.value = [...options.value, account]
  }

  return { options, lastUsedAccountId, loading, load, add }
}
