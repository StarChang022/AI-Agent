import { isNavigationFailure, NavigationFailureType, useRouter } from 'vue-router'
import { getAccountOptions } from '@/api/accounts'
import { listExpenses } from '@/api/expenses'
import { listIncomes } from '@/api/incomes'
import { useOnboardingStore } from '@/stores/onboarding'

export type RecordKind = 'expense' | 'income'

/**
 * begin() 的判斷要打好幾支 API；快速重新開始導覽時，舊一次的結果可能比新的晚回來。
 * 每次 begin()／skip() 遞增，判斷完只採用最新一次。多個元件各自呼叫 useFirstSetupGuide，所以放模組層。
 */
let beginSeq = 0

/**
 * 管理員導覽結束後的首次設定引導（PRD 第 22 條）。
 *
 * 依公司當下的資料決定下一步，帳戶、收支都不含垃圾桶：
 * - 沒有帳戶 → 詢問是否建立第一個帳戶；選「建立帳戶」前往帳戶設定並自動開啟新增帳戶視窗，
 *   未儲存就關閉視同結束（AccountsView 處理）
 * - 有帳戶、沒有任何收支 → 詢問是否新增第一筆收支
 *   （兩個詢問視窗都在 FirstSetupDialogs）
 * - 都有 → 不引導
 * 建立第一個帳戶後接著詢問新增收支；選了新增支出／收入就帶到新增頁，由 FirstRecordGuide
 * 逐步引導到儲存成功為止；引導期間離開新增頁視同結束。
 * 每一步都可選「之後再說」或結束，之後這次不再出現。
 *
 * 判斷不開新 API：帳戶看 /accounts/options、支出看 /expenses?per_page=1 的 total；
 * 收入列表不分頁，只在支出為 0 筆時才查（已和後端對齊）。
 */
export function useFirstSetupGuide() {
  const router = useRouter()
  const onboarding = useOnboardingStore()

  async function hasAnyRecord(): Promise<boolean> {
    const expenses = await listExpenses({ page: 1, perPage: 1 })
    if (expenses.meta.total > 0) return true
    const incomes = await listIncomes()
    return incomes.length > 0
  }

  /** 導覽結束時呼叫。查詢失敗就不引導，不影響其他功能 */
  async function begin(): Promise<void> {
    const seq = ++beginSeq
    onboarding.setFirstSetupStep(null)
    try {
      const { data: accounts } = await getAccountOptions()
      if (seq !== beginSeq) return
      if (accounts.length === 0) {
        onboarding.setFirstSetupStep('account-ask')
        return
      }
      const hasRecord = await hasAnyRecord()
      if (seq !== beginSeq) return
      if (!hasRecord) onboarding.setFirstSetupStep('record')
    } catch {
      /* 判斷失敗時不引導 */
    }
  }

  /** 詢問視窗選「建立帳戶」：前往帳戶設定，由 AccountsView 自動開啟新增帳戶視窗 */
  async function chooseCreateAccount(): Promise<void> {
    onboarding.setFirstSetupStep('account-form')
    try {
      const failure = await router.push({ name: 'admin-accounts' })
      // 已經在帳戶設定頁（duplicated）不算失敗，頁面會直接開視窗；其他導頁失敗就結束引導
      if (failure && !isNavigationFailure(failure, NavigationFailureType.duplicated)) accountFormClosed()
    } catch {
      accountFormClosed()
    }
  }

  /** 引導中的新增帳戶視窗：儲存成功 → 接著詢問新增第一筆收支 */
  function accountCreated(): void {
    if (onboarding.firstSetupStep === 'account-form') onboarding.setFirstSetupStep('record')
  }

  /** 引導中的新增帳戶視窗未儲存就關閉 → 結束引導 */
  function accountFormClosed(): void {
    if (onboarding.firstSetupStep === 'account-form') onboarding.setFirstSetupStep(null)
  }

  function chooseRecord(kind: RecordKind): void {
    onboarding.setFirstSetupStep(`${kind}-form`)
    void router.push({ name: kind === 'expense' ? 'admin-expense-new' : 'admin-income-new' })
  }

  /** 新增頁是否正在引導這一種收支 */
  function isGuidingForm(kind: RecordKind): boolean {
    return onboarding.firstSetupStep === `${kind}-form`
  }

  /** 新增頁儲存成功：結束引導。回傳 true 表示這次是引導中的第一筆，由呼叫端顯示完成提示 */
  function completeRecord(kind: RecordKind): boolean {
    if (!isGuidingForm(kind)) return false
    onboarding.setFirstSetupStep(null)
    return true
  }

  /** 離開新增頁（含按「結束引導」）：結束這一種收支的引導 */
  function endRecordForm(kind: RecordKind): void {
    if (isGuidingForm(kind)) onboarding.setFirstSetupStep(null)
  }

  function skip(): void {
    beginSeq++
    onboarding.setFirstSetupStep(null)
  }

  return { begin, chooseCreateAccount, accountCreated, accountFormClosed, chooseRecord, isGuidingForm, completeRecord, endRecordForm, skip }
}
