/**
 * User API — 公司內人員管理 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 backend/app/controllers/api/users_controller.rb。
 *
 * 本檔不含「使用者改自己密碼」：那條走 `api/auth.ts` 的 `changePassword()`
 * （後端 `POST /auth/password/change`），屬 credential 範疇，不在 users 這條線上。
 */

import type { Role, User, UserStatus } from '@/types/domain'
import { service } from './service'
import { USER_STORAGE_KEY } from './auth'
import { useAuthStore } from '@/stores/auth'

/**
 * 後端 UsersController serialize 回傳欄位。
 * 比 `api/auth.ts` 的 `ApiUser` 多 `createdAt` / `lastLoginAt`（list 需用來排序 / 顯示）。
 */
export interface ApiUser {
  id: string
  email: string
  name: string
  role: Role
  status: UserStatus
  companyId: string
  createdAt: string
  lastLoginAt: string | null
  onboardingCompletedAt: string | null
}

/**
 * GET /users?status=active|suspended|invited
 * 需 admin。未帶 status 回該公司所有 user（含 suspended），
 * 讓前端 UsersView 的「使用中 / 停用」tab 自己切。
 */
export interface ListUsersQuery {
  status?: 'active' | 'suspended' | 'invited'
}

export async function listUsers(query?: ListUsersQuery): Promise<User[]> {
  const rows = await service.get<ApiUser[]>('/users', { query })
  return rows.map(apiUserToUser)
}

/**
 * PATCH /users/me
 * 本人改姓名。email / role / status / password 不走這條。
 * 成功時同步更新 auth store 的 currentUser 與 localStorage 快照，
 * 讓頂欄頭像、審核紀錄顯示即時反映新姓名。
 * - 422 code=`INVALID_NAME`：姓名空白
 */
export interface UpdateMeRequest {
  name: string
}

export async function updateMe(body: UpdateMeRequest): Promise<User> {
  const user = apiUserToUser(await service.patch<ApiUser>('/users/me', body))
  syncLocalSession(user)
  return user
}

/**
 * PATCH /users/:id
 * 需 admin，只能改同公司且非本人的姓名。
 * - 404：目標不存在或非同公司
 * - 422 code=`USE_SELF_ENDPOINT`：目標是本人，應走 /users/me
 * - 422 code=`INVALID_NAME`：姓名空白
 */
export interface UpdateUserRequest {
  name: string
}

export async function updateUser(
  id: string,
  body: UpdateUserRequest,
): Promise<User> {
  return apiUserToUser(await service.patch<ApiUser>(`/users/${id}`, body))
}

/**
 * PATCH /users/:id/status
 * 需 admin。停用 / 重啟同公司人員。
 * - 404：目標不存在
 * - 422 code=`CANNOT_TARGET_SELF`：禁對自己操作
 * - 422 code=`INVALID_STATUS`：status 非 'active' | 'suspended'
 *
 * 已知限制：JWT stateless，被停用者仍可用既有 token 直到過期；要立即踢
 * 需後端加 token_version 欄位。
 */
export interface SetUserStatusRequest {
  status: 'active' | 'suspended'
}

export async function setUserStatus(
  id: string,
  body: SetUserStatusRequest,
): Promise<User> {
  return apiUserToUser(
    await service.patch<ApiUser>(`/users/${id}/status`, body),
  )
}

/**
 * PATCH /users/:id/password
 * 需 admin。代為重設同公司人員的密碼，不需舊密碼。
 * 本人改自己密碼走 `api/auth.ts` 的 `changePassword()`。
 * - 404：目標不存在
 * - 422 code=`USE_SELF_ENDPOINT`：禁對自己操作
 * - 422 code=`WEAK_PASSWORD`：新密碼 < 8 碼
 *
 * 已知限制：同上，目標的既有 session 不會被立即失效。
 */
export interface AdminResetPasswordRequest {
  newPassword: string
}

export function adminResetPassword(
  id: string,
  body: AdminResetPasswordRequest,
): Promise<void> {
  return service.patch<void>(`/users/${id}/password`, body)
}

function apiUserToUser(u: ApiUser): User {
  return {
    id: u.id,
    name: u.name,
    email: u.email,
    role: u.role,
    status: u.status,
    createdAt: u.createdAt,
    onboardingCompletedAt: u.onboardingCompletedAt,
  }
}

/**
 * updateMe 成功後把本人的最新快照同步到 auth store + localStorage，
 * 避免重整後舊姓名回來。
 */
function syncLocalSession(user: User): void {
  localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(user))
  useAuthStore().currentUser = user
}
