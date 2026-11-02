import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { markOnboardingCompleted, resetOnboarding } from '@/api/onboarding'

/**
 * Onboarding 完成狀態 store。
 *
 * 真正的「是否完成」是 `authStore.currentUser.onboardingCompletedAt`（後端
 * users.onboarding_completed_at 欄位）：null = 未完成，有值 = 已完成。
 * 本 store 只是把那欄位包成好讀的 helper、並對應兩個 UI 暫態（tour 進行中
 * 的 sidebar highlight / UserBadge popup 開關）。
 *
 * markCompleted / reset 走 PATCH /api/users/me/onboarding，成功後由 api 層
 * 把回傳的 user 同步到 auth store + localStorage 快照，重整後仍會反映。
 */
export const useOnboardingStore = defineStore('onboarding', () => {
  /**
   * Tour 進行中「當前需高亮的 sidebar route name」；null = 無 tour 或非
   * sidebar 對應項。AdminLayout 用此值決定給哪個 nav item 掛 .tour-nav-active。
   */
  const activeSidebarRouteName = ref<string | null>(null)

  function setActiveSidebar(routeName: string | null): void {
    activeSidebarRouteName.value = routeName
  }

  /**
   * Tour 尾步要求打開右上角 UserBadge 選單以打亮「新手導覽」項目；
   * UserBadge 內 watch 此值來程式化開/關 PrimeVue Menu popup。
   */
  const userMenuOpen = ref<boolean>(false)

  function setUserMenuOpen(open: boolean): void {
    userMenuOpen.value = open
  }

  /** 當前登入者是否已完成新手導覽。未登入視為「已完成」避免 LoginView 誤觸發。 */
  function isCompleted(): boolean {
    return useAuthStore().currentUser?.onboardingCompletedAt != null
  }

  /**
   * 標記當前登入者完成導覽；fire-and-forget，driver onDestroyed 內呼叫不需 await。
   * API 失敗也不阻擋 tour 關閉；下次 remount 若 state 未更新則會再觸發一次，可接受。
   */
  function markCompleted(): void {
    void markOnboardingCompleted().catch(() => {})
  }

  /**
   * 「重跑導覽」入口使用：清掉 onboardingCompletedAt。
   * 回 Promise 讓 caller await，確保 state 清掉後才 startTour / 導航。
   */
  async function reset(): Promise<void> {
    await resetOnboarding()
  }

  return {
    activeSidebarRouteName,
    setActiveSidebar,
    userMenuOpen,
    setUserMenuOpen,
    isCompleted,
    markCompleted,
    reset,
  }
})
