import { computed, ref } from 'vue'
import { useToast } from 'primevue/usetoast'
import { getAccountOptions, type AccountOption } from '@/api/accounts'
import { userErrorToast } from '@/utils/userFeedback'

/**
 * 帳戶下拉的資料來源（收支表單、代墊款核准、現金流報表共用）。
 * lastUsedAccountId 隨新增收支變動，每次打開表單都要重新 load，不做跨頁快取。
 * 帳戶一律在帳戶設定建立（PRD 第 20 條），這裡不提供新增。
 */
export function useAccountOptions() {
  const toast = useToast()
  const options = ref<AccountOption[]>([])
  const lastUsedAccountId = ref<string | null>(null)
  const loading = ref(false)
  /** 至少成功載入過一次；載入失敗時維持 false，不誤判成「沒有帳戶」 */
  const loaded = ref(false)

  /** 公司沒有任何帳戶（不含垃圾桶）；載入完成前為 false，避免入口閃一下停用 */
  const noAccounts = computed(() => loaded.value && options.value.length === 0)

  /** silent：只用來判斷入口要不要停用時，失敗不跳提示（維持 loaded=false，不誤停用） */
  async function load({ silent = false }: { silent?: boolean } = {}) {
    loading.value = true
    try {
      const res = await getAccountOptions()
      options.value = res.data
      lastUsedAccountId.value = res.lastUsedAccountId
      loaded.value = true
    } catch (err) {
      if (!silent) toast.add({ severity: 'error', ...userErrorToast(err, '載入帳戶失敗'), life: 3500 })
    } finally {
      loading.value = false
    }
  }

  /** 編輯既有紀錄時確保目前的帳戶選得到 */
  function add(account: AccountOption) {
    if (!options.value.some((a) => a.id === account.id)) options.value = [...options.value, account]
  }

  return { options, lastUsedAccountId, loading, loaded, noAccounts, load, add }
}

export type AccountOptionsState = ReturnType<typeof useAccountOptions>
