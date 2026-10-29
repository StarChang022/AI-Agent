import type { Reimbursement } from '@/types/domain'
import { formatDate } from '@/utils/format'

/**
 * 代墊款的發放日資訊（員工端與管理端共用）。
 * - 已核銷：取對應支出的 plannedPayoutDate →「預計發放」
 * - 已發放：paidAt →「發放日」
 * 資料來自 Reimbursement.linkedExpense（後端 serializer 已帶入摘要）。
 */
export interface PayoutInfo {
  kind: 'planned' | 'paid'
  label: string
  /** yyyy/mm/dd */
  date: string
  /** mm/dd（列表卡片用） */
  short: string
}

/**
 * payoutInfo 只用到四個欄位；用 Pick 鬆綁讓完整 Reimbursement 與 list Summary
 * （admin / my 兩種）都能傳入 — list 都保留這四欄。
 */
export type PayoutInput = Pick<
  Reimbursement,
  'status' | 'paidAt' | 'updatedAt' | 'linkedExpense'
>

function shortDate(iso: string): string {
  const [, m, d] = iso.slice(0, 10).split('-')
  return `${m}/${d}`
}

export function useReimbursementPayout() {
  function payoutInfo(r: PayoutInput): PayoutInfo | null {
    if (r.status === 'paid') {
      const iso = r.paidAt ?? r.updatedAt.slice(0, 10)
      return { kind: 'paid', label: '發放日', date: formatDate(iso), short: shortDate(iso) }
    }
    if (r.status === 'approved') {
      const e = r.linkedExpense
      if (!e || e.payoutStatus !== 'pending') return null
      const iso = e.plannedPayoutDate
      return iso ? { kind: 'planned', label: '預計發放', date: formatDate(iso), short: shortDate(iso) } : null
    }
    return null
  }

  return { payoutInfo }
}
