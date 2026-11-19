/**
 * Auth API — 註冊 / 登入 / 密碼流程 endpoints，含副作用（localStorage、
 * Pinia store 更新、domain 型別轉換）。views 直接呼叫本檔的 business action
 * 函式即可，不需要在 view / store 內再串副作用。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 backend/app/controllers/api/auth_controller.rb。
 */

import { service, HttpError } from './service'
import { useAuthStore } from '@/stores/auth'
import type { User } from '@/types/domain'

/** JWT access token 儲存 localStorage 的 key。`api/service.ts` 讀寫此 key。 */
export const AUTH_TOKEN_STORAGE_KEY = 'quickey.auth.token'
/** 上次登入 user 快照的 localStorage key，供 `stores/auth.ts` 重整後 hydration。 */
export const USER_STORAGE_KEY = 'quickey.auth.user'

// ─── Wire types ─────────────────────────────────────────────────────────

/** 對應後端 `serialize_user`（backend/app/controllers/api/auth_controller.rb）。 */
export interface ApiUser {
  id: string
  email: string
  name: string
  role: 'admin' | 'employee'
  status: 'active' | 'invited' | 'suspended' | 'left'
  companyId: string
  onboardingCompletedAt: string | null
}

/** 對應後端 `serialize_company`。 */
export interface ApiCompany {
  id: string
  name: string
  companyType: 'limited' | 'corporation' | 'studio' | 'individual'
  taxId: string | null
  plan: string
}

export interface AuthSessionResponse {
  user: ApiUser
  company: ApiCompany
  token: string
}

// ─── Business actions（含副作用；view 直接呼叫）─────────────────────────

/**
 * 登入。成功 → 寫 token + user 進 localStorage、更新 auth store、回 domain user。
 * 401 → 回 null（供 view 顯示「Email 或密碼錯誤」）。
 * 其他錯誤（403 帳號停用、網路 / 5xx）throw HttpError，由 view 處理（停用用 isAccountSuspended 判斷）。
 */
export async function login(
  email: string,
  password: string,
): Promise<User | null> {
  try {
    const res = await service.post<AuthSessionResponse>(
      '/auth/login',
      { email, password },
      { skipAuth: true },
    )
    const user = apiUserToUser(res.user)
    persistSession(res.token, user)
    return user
  } catch (err) {
    if (err instanceof HttpError && err.status === 401) return null
    throw err
  }
}

/** 登入時帳號已停用：後端回 403 account_suspended（密碼正確才會回這個） */
export function isAccountSuspended(err: unknown): boolean {
  return err instanceof HttpError && err.status === 403 && (err.body as { error?: string } | undefined)?.error === 'account_suspended'
}

/**
 * 登出。後端 stateless，fire-and-forget 打 API；local state 一律清乾淨。
 */
export function logout(): void {
  service.post<void>('/auth/logout').catch(() => {})
  clearSession()
}

export type ForgotPasswordResult =
  | { ok: true }
  | { ok: false; error: 'NOT_FOUND' | 'SUSPENDED' | 'UNKNOWN' }

/**
 * 忘記密碼（寄重設密碼信）。
 * - 202 → 已寄出
 * - 404 email_not_found → NOT_FOUND（查無此帳號）
 * - 403 account_suspended → SUSPENDED（帳號已停用）
 * - 其他 → UNKNOWN
 */
export async function forgotPassword(email: string): Promise<ForgotPasswordResult> {
  try {
    await service.post<void>(
      '/auth/password/forgot',
      { email },
      { skipAuth: true },
    )
    return { ok: true }
  } catch (err) {
    if (err instanceof HttpError) {
      const code = (err.body as { error?: string } | undefined)?.error
      if (err.status === 404 && code === 'email_not_found') return { ok: false, error: 'NOT_FOUND' }
      if (err.status === 403 && code === 'account_suspended') return { ok: false, error: 'SUSPENDED' }
    }
    return { ok: false, error: 'UNKNOWN' }
  }
}

export type ResetPasswordResult =
  | { ok: true; user: User }
  | { ok: false; error: 'INVALID_OR_EXPIRED' | 'TOO_SHORT' | 'UNKNOWN' }

/**
 * 重設密碼。成功即自動登入（同步寫 storage + 更新 store）。
 * - 400 → INVALID_OR_EXPIRED（token 無效或過期）
 * - 422 → TOO_SHORT（密碼長度不足）
 * - 其他 → UNKNOWN（view 顯示通用錯誤）
 */
export async function resetPassword(
  token: string,
  newPassword: string,
): Promise<ResetPasswordResult> {
  try {
    const res = await service.post<AuthSessionResponse>(
      '/auth/password/reset',
      { token, newPassword },
      { skipAuth: true },
    )
    const user = apiUserToUser(res.user)
    persistSession(res.token, user)
    return { ok: true, user }
  } catch (err) {
    if (err instanceof HttpError) {
      if (err.status === 400) return { ok: false, error: 'INVALID_OR_EXPIRED' }
      if (err.status === 422) return { ok: false, error: 'TOO_SHORT' }
    }
    return { ok: false, error: 'UNKNOWN' }
  }
}

export type ChangePasswordResult =
  | { ok: true }
  | { ok: false; error: 'INVALID_OLD' | 'TOO_SHORT' | 'UNKNOWN' }

/**
 * 修改密碼（需已登入）。舊密碼由後端比對 bcrypt hash，不在前端驗證。
 * - 401 → INVALID_OLD（舊密碼錯誤）
 * - 422 → TOO_SHORT（新密碼長度不足；防禦性，前端也會 pre-check）
 * - 其他 → UNKNOWN
 */
export async function changePassword(
  oldPassword: string,
  newPassword: string,
): Promise<ChangePasswordResult> {
  try {
    // 舊密碼錯誤也回 401，不能因此被登出
    await service.post<void>('/auth/password/change', { oldPassword, newPassword }, { keepSessionOn401: true })
    return { ok: true }
  } catch (err) {
    if (err instanceof HttpError) {
      if (err.status === 401) return { ok: false, error: 'INVALID_OLD' }
      if (err.status === 422) return { ok: false, error: 'TOO_SHORT' }
    }
    return { ok: false, error: 'UNKNOWN' }
  }
}

// ─── Internals ──────────────────────────────────────────────────────────

/**
 * 把 backend 回傳的 ApiUser 轉成前端 domain User。
 * ID 兩邊都是 UUID string，直接帶；wrapper 只負責補 createdAt（登入 endpoint 不回這欄）。
 */
function apiUserToUser(u: ApiUser): User {
  return {
    id: u.id,
    name: u.name,
    email: u.email,
    role: u.role,
    status: u.status,
    createdAt: '',
    onboardingCompletedAt: u.onboardingCompletedAt,
  }
}

/**
 * 寫 token + user 進 localStorage，並同步更新 auth store。
 * export 給 api/invitations.ts acceptInvitation、未來 signupComplete 等
 * 其他「換得 session」的 endpoint 共用。
 */
export function persistSession(token: string, user: User): void {
  localStorage.setItem(AUTH_TOKEN_STORAGE_KEY, token)
  localStorage.setItem(USER_STORAGE_KEY, JSON.stringify(user))
  useAuthStore().currentUser = user
}

let sessionExpiredNotice = false

/** 登入失效（已登入時 API 回 401）：清掉登入資料，並讓登入頁顯示一次「登入已失效」 */
export function expireSession(): void {
  clearSession()
  sessionExpiredNotice = true
}

/** 登入頁讀取「登入已失效」提示，讀過即清除（只顯示一次） */
export function consumeSessionExpiredNotice(): boolean {
  const v = sessionExpiredNotice
  sessionExpiredNotice = false
  return v
}

/** 清掉 localStorage 兩把鑰匙 + auth store 的 currentUser。 */
function clearSession(): void {
  localStorage.removeItem(AUTH_TOKEN_STORAGE_KEY)
  localStorage.removeItem(USER_STORAGE_KEY)
  useAuthStore().currentUser = null
}

// ─── Signup (3-step) ────────────────────────────────────────────────────

/**
 * 註冊表單一次填齊：email + 密碼 + 公司類型 / 名稱 / 統編。
 * payload 全部存進 SignupToken，使用者點完驗證信連結後直接建帳號、不再被要求輸入。
 */
export interface SignupRequestRequest {
  email: string
  password: string
  companyType: ApiCompany['companyType']
  companyName: string
  taxId?: string | null
}

export interface SignupVerifyResponse {
  email: string
  provider: string | null
}

export interface SignupCompleteRequest {
  token: string
}

/**
 * POST /auth/signup/request
 * 後端一律回 202：email 已被註冊時靜默略過（避免帳號枚舉）。
 */
export function signupRequest(body: SignupRequestRequest): Promise<void> {
  return service.post<void>('/auth/signup/request', body, { skipAuth: true })
}

/**
 * GET /auth/signup/verify?token=
 * 僅檢查 token 有效性（不消耗）；SignupVerifyView 顯示「連結已過期」等狀態用。
 */
export function signupVerify(token: string): Promise<SignupVerifyResponse> {
  return service.get<SignupVerifyResponse>('/auth/signup/verify', {
    query: { token },
    skipAuth: true,
  })
}

/**
 * POST /auth/signup/complete
 * 只送 token；後端從 SignupToken 取 payload 建 Company + admin User，回 JWT。
 * 成功後 view 直接呼叫 persistSession 即可自動登入。
 */
export function signupComplete(
  body: SignupCompleteRequest,
): Promise<AuthSessionResponse> {
  return service.post<AuthSessionResponse>('/auth/signup/complete', body, {
    skipAuth: true,
  })
}