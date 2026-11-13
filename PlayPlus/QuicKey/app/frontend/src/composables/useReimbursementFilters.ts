/** 請款記錄/簽核/發放三頁共用的工具列篩選（即時套用）。 */
import { computed, reactive } from 'vue'
import type { Reimbursement } from '@/types/domain'
import { toIsoDate } from '@/utils/format'

export interface ReimbursementFilters {
  keyword: string
  categories: string[]
  dateRange: (Date | null)[] | null
  min: number | null
  max: number | null
}

export function useReimbursementFilters() {
  const empty = (): ReimbursementFilters => ({ keyword: '', categories: [], dateRange: null, min: null, max: null })
  const f = reactive<ReimbursementFilters>(empty())

  function passes(r: Reimbursement): boolean {
    // 草稿可缺類別、金額、發生日期：有設該條件時，空值一律不符合
    if (f.categories.length && !(r.category && f.categories.includes(r.category.id))) return false
    if (f.min !== null && (r.amount === null || r.amount < f.min)) return false
    if (f.max !== null && (r.amount === null || r.amount > f.max)) return false
    if (f.dateRange) {
      const [from, to] = f.dateRange
      if (from instanceof Date && (r.incurredAt === null || r.incurredAt < toIsoDate(from))) return false
      if (to instanceof Date && (r.incurredAt === null || r.incurredAt > toIsoDate(to))) return false
    }
    const kw = f.keyword.trim().toLowerCase()
    if (kw) {
      const hay = [r.employee.name, r.description, r.vendor, r.invoiceNo, r.category?.name].join(' ').toLowerCase()
      if (!hay.includes(kw)) return false
    }
    return true
  }
  const isFiltered = computed(
    () => !!f.keyword.trim() || f.categories.length > 0 || f.min !== null || f.max !== null || !!(f.dateRange && f.dateRange.some((d) => d instanceof Date)),
  )
  function reset() {
    Object.assign(f, empty())
  }
  return { f, passes, isFiltered, reset }
}
