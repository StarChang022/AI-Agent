import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import type { Role, User } from '@/types/domain'
import { USER_STORAGE_KEY } from '@/api/auth'

/**
 * 登入狀態 store。登入 / 登出 / 密碼流程皆走 `api/auth.ts`；本 store
 * 只負責持有 `currentUser` 與重整後的 hydration（讀 `api/auth.ts` 寫入的
 * user 快照）。
 */
export const useAuthStore = defineStore('auth', () => {
  const currentUser = ref<User | null>(loadInitialUser())

  const isLoggedIn = computed(() => currentUser.value !== null)
  const role = computed<Role | null>(() => currentUser.value?.role ?? null)

  return { currentUser, isLoggedIn, role }
})

function loadInitialUser(): User | null {
  const raw = localStorage.getItem(USER_STORAGE_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as User
  } catch {
    localStorage.removeItem(USER_STORAGE_KEY)
    return null
  }
}
