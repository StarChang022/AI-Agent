/**
 * Invitation API — 員工邀請 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §3.3、§5.3、backend/app/controllers/api/invitations_controller.rb。
 */

import type { Invitation, User } from '@/types/domain'
import { service } from './service'
import { persistSession } from './auth'

export type { Invitation }

/**
 * POST /invitations
 * 發送邀請。後端 MUST 於單一 transaction 內：
 * - 驗 email 格式（不合法回 422 code=`INVALID_EMAIL`）
 * - 驗公司員工名額（active employee + 有效邀請 ≥ 公司方案的名額上限 回 409 code=`AT_LIMIT`）
 * - 驗 email 尚未被現有 active User 使用（回 409 code=`EMAIL_IN_USE`）
 * - 驗 email 尚未有有效邀請（回 409 code=`EMAIL_PENDING`）
 * - 產生 token digest 與 expiresAt（now + 3 天）、寄出邀請信（連結只在信內）
 */
export interface CreateInvitationRequest {
  email: string
  name: string
}

/**
 * GET /invitations
 * 列出邀請。預設回未接受、未撤回的邀請（含已過期，status 為 valid / expired）；
 * 名額只算 valid。`includeInactive=true` 時同時回傳已撤回 / 已接受的歷史。
 */
export interface ListInvitationsQuery {
  includeInactive?: boolean
}

/**
 * GET /invitations/by-token/:token（public，無 auth）
 * 供 Accept 頁驗 token 用；不揭露 revokedAt / acceptedAt / invitedByUserId 等
 * 內部欄位，只回 status + 顯示所需最小欄位。
 */
export interface GetInvitationByTokenResponse {
  status: 'valid' | 'expired' | 'revoked' | 'already_used' | 'not_found'
  email?: string
  name?: string
  companyName?: string
  expiresAt?: string
}

/**
 * POST /invitations/by-token/:token/accept（public，無 auth）
 * 接受邀請並建立員工帳號 + auto-login。姓名沿用 Invitation.name，
 * 因此 body 只需 password。
 */
export interface AcceptInvitationRequest {
  password: string
}

interface AcceptInvitationApiResponse {
  user: {
    id: string
    email: string
    name: string
    role: 'employee'
    status: 'active'
    onboardingCompletedAt: string | null
  }
  authToken: string
}

export function listInvitations(
  query?: ListInvitationsQuery,
): Promise<Invitation[]> {
  return service.get<Invitation[]>('/invitations', { query })
}

export function createInvitation(
  body: CreateInvitationRequest,
): Promise<Invitation> {
  return service.post<Invitation>('/invitations', body)
}

/**
 * POST /invitations/:id/resend
 * 邀請中或已過期的邀請重新寄送：換新 token（舊信連結作廢）、有效期限重算 3 天。
 * 錯誤：404 not_found；409 ALREADY_ACCEPTED / ALREADY_REVOKED / EMAIL_IN_USE /
 * EMAIL_IN_OTHER_COMPANY；409 AT_LIMIT（只有已過期的邀請才檢查名額）；
 * 429 RESEND_TOO_SOON（body 附 retryAfter 秒數，同一筆 1 分鐘內只能寄一次）。
 */
export function resendInvitation(id: string): Promise<Invitation> {
  return service.post<Invitation>(`/invitations/${id}/resend`)
}

/** DELETE /invitations/:id：撤回邀請中的邀請，或刪除已過期的邀請 */
export function revokeInvitation(id: string): Promise<void> {
  return service.delete<void>(`/invitations/${id}`)
}

export function getInvitationByToken(
  token: string,
): Promise<GetInvitationByTokenResponse> {
  return service.get<GetInvitationByTokenResponse>(
    `/invitations/by-token/${token}`,
    { skipAuth: true },
  )
}

/**
 * Business action：接受邀請並以回傳的 token 直接建立 session；
 * 完成後 view 只需 router.push 即可。
 */
export async function acceptInvitation(
  token: string,
  body: AcceptInvitationRequest,
): Promise<User> {
  const res = await service.post<AcceptInvitationApiResponse>(
    `/invitations/by-token/${token}/accept`,
    body,
    { skipAuth: true },
  )
  const user: User = {
    id: res.user.id,
    name: res.user.name,
    email: res.user.email,
    role: res.user.role,
    status: res.user.status,
    createdAt: '',
    onboardingCompletedAt: res.user.onboardingCompletedAt,
  }
  persistSession(res.authToken, user)
  return user
}
