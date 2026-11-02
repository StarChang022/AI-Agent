/**
 * Onboarding API — 新手導覽完成狀態的雲端同步。
 *
 * 以 PATCH /api/users/me/onboarding 把 users.onboarding_completed_at 設為
 * 當下時間（completed=true）或 null（completed=false，供「重跑導覽」入口使用）。
 * 成功後把回傳的 user 寫回 auth store + localStorage 快照，讓重整後仍反映最新狀態。
 * 對應 backend/app/controllers/api/users_controller.rb#update_onboarding。
 */

import { service } from './service'
import { USER_STORAGE_KEY } from './auth'
import type { ApiUser } from './users'
import { useAuthStore } from '@/stores/auth'
import type { User } from '@/types/domain'

export function markOnboardingCompleted(): Promise<User> {
  return patchOnboarding(true)
}

export function resetOnboarding(): Promise<User> {
  return patchOnboarding(false)
}

async function patchOnboarding(completed: boolean): Promise<User> {
  const api = await service.patch<ApiUser>('/users/me/onboarding', { completed })
  const user: User = {
    id: api.id,
    name: api.name,
    email: api.email,
    role: api.role,
    status: api.status,
    createdAt: api.createdAt,
    onboardingCompletedAt: api.onboardingCompletedAt,
  }
  localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(user))
  useAuthStore().currentUser = user
  return user
}
