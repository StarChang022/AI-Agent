import type { RecurringTemplate } from '@/types/domain'

/** 例：每月 5 號、每年 3 月 15 日 */
export function scheduleLabel(t: Pick<RecurringTemplate, 'frequency' | 'dayOfMonth' | 'monthOfYear'>): string {
  return t.frequency === 'yearly' ? `每年 ${t.monthOfYear} 月 ${t.dayOfMonth} 日` : `每月 ${t.dayOfMonth} 號`
}

/** 類別在垃圾桶或已停用時，範本不能還原、不能延長結束月份；類別正常時回空字串 */
export function categoryBlockedHint(category: RecurringTemplate['category']): string {
  if (category.deletedAt) {
    return `類別「${category.name}」在垃圾桶，不能還原範本或延長結束月份，請先到類別管理還原類別。`
  }
  if (category.isArchived) {
    return `類別「${category.name}」已停用，不能還原範本或延長結束月份，請先到類別管理啟用類別。`
  }
  return ''
}
