import type { CompanyPlan } from '@/api/company'

/** 公司方案顯示名稱 */
export const PLAN_LABELS: Record<CompanyPlan, string> = {
  free: '免費版',
  team: '團隊版',
  enterprise: '企業版',
}
