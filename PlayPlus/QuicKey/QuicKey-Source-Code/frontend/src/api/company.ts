/**
 * Company API — 公司資訊 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 backend/app/controllers/api/companies_controller.rb。
 */

import { service } from './service'

/** 統一編號：8 位數字（前端格式 pre-check；後端 Company model 另做台灣統編檢核碼驗算） */
export const TAX_ID_RE = /^\d{8}$/

export interface ApiCompany {
  id: string
  name: string
  companyType: 'limited' | 'corporation' | 'studio' | 'individual'
  taxId: string | null
  plan: string
  /** 公司員工名額上限（免費方案硬性上限；對應 backend Company::MEMBER_LIMIT） */
  memberLimit: number
  /** 已佔用名額 = users 總數 + 有效邀請數；供顯示參考，前端有需要重算也行 */
  membersUsed: number
}

/**
 * GET /company
 * 回當前登入 user 所屬公司資訊 + 名額限制。
 */
export function getCompany(): Promise<ApiCompany> {
  return service.get<ApiCompany>('/company')
}

export interface UpdateCompanyInput {
  name: string
  /** 空字串會由後端 normalize 成 null（清空統編） */
  taxId: string | null
}

/**
 * PATCH /company
 * 僅管理員可呼叫；公司名稱必填、統編選填。
 * 後端 422 時 body.details 內會帶 { name: [...], tax_id: [...] } 便於欄位錯誤歸位。
 */
export function updateCompany(input: UpdateCompanyInput): Promise<ApiCompany> {
  return service.patch<ApiCompany>('/company', input)
}

export interface CompanyCheckResult {
  exists: boolean
  matchedName: string | null
}

/**
 * GET /companies/check?tax_id=xxx
 * public；註冊頁用來提示使用者「相同統編已有公司」。純 UX，後端不加唯一性約束。
 * 統編格式非 8 碼數字時後端一律回 exists: false，不用前端 pre-check。
 */
export function checkCompanyExists(taxId: string): Promise<CompanyCheckResult> {
  return service.get<CompanyCheckResult>('/companies/check', {
    query: { taxId },
    skipAuth: true,
  })
}
