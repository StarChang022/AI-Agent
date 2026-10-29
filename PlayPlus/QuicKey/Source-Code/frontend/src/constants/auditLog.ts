/**
 * AuditLog 顯示用的 zh-TW 對照。
 * 對應後端 AuditLog::ACTIONS 與各 target 常見欄位。未對照的 key 直接顯示 snake_case
 * 原字（不會壞 render）。
 */
import type { AuditAction } from '@/api/audit-logs'

export const ACTION_LABELS: Record<string, string> = {
  create:         '建立',
  update:         '更新資料',
  status_change:  '狀態變更',
  delete:         '移至垃圾桶',
  restore:        '從垃圾桶還原',
  purge:          '永久刪除',
  void:           '作廢',
  revert_void:    '取消作廢',
  refund:         '退款',
}

/** 動作對應的 icon（PrimeIcon class），用於 timeline 左側標記 */
export const ACTION_ICONS: Record<string, string> = {
  create:         'pi-plus',
  update:         'pi-pencil',
  status_change:  'pi-sync',
  delete:         'pi-trash',
  restore:        'pi-undo',
  purge:          'pi-times-circle',
  void:           'pi-ban',
  revert_void:    'pi-undo',
  refund:         'pi-reply',
}

/**
 * 常見 diff 欄位的 zh-TW 標籤。
 * key 用 camelCase（service.ts 已把 response 的 snake_case 轉成 camelCase，
 * 包含 jsonb 內的 key 也會轉）。
 */
export const FIELD_LABELS: Record<string, string> = {
  // 共用
  amount:       '金額',
  categoryId:   '類別',
  date:         '日期',
  note:         '備註',
  description:  '描述',
  incurredAt:   '交易日期',
  documentType: '憑證類型',
  taxId:        '統編',
  invoiceNo:    '發票號碼',
  taxRate:      '稅率',
  preTaxAmt:    '未稅金額',
  taxAmt:       '稅額',
  items:        '品項',
  attachments:  '附件',
  comment:      '備註',

  // Expense / Reimbursement
  vendor:            '賣方',
  payoutStatus:      '付款狀態',
  paidAt:            '付款日',
  paymentMethod:     '付款方式',
  plannedPayoutDate: '預計付款日',

  // Income
  customer:         '客戶',
  collectionStatus: '收款狀態',
  collectedAt:      '收款日',

  // Reimbursement 流程
  status:        '狀態',
  rejectReason:  '退回原因',
  prevStatus:    '前狀態',
  expenseId:     '連動支出',
}

/** 列舉值翻譯；key 為欄位（camelCase）、value 為該欄位的 enum→label 對照 */
export const ENUM_LABELS: Record<string, Record<string, string>> = {
  payoutStatus:     { pending: '待付款', paid: '已付款' },
  collectionStatus: { uncollected: '待收款', collected: '已收款' },
  status: {
    draft:      '草稿',
    in_review:  '簽核中',
    approved:   '已核銷',
    rejected:   '退回',
    paid:       '已發放',
    voided:     '已作廢',
  },
  prevStatus: {
    draft:      '草稿',
    in_review:  '簽核中',
    approved:   '已核銷',
    rejected:   '退回',
    paid:       '已發放',
    voided:     '已作廢',
  },
  documentType: { invoice: '發票', receipt: '收據' },
  taxRate:      { business_5: '營業稅 5%', exempt_0: '免稅 0%' },
}

export function actionLabel(action: AuditAction | string): string {
  return ACTION_LABELS[action] ?? action
}
export function actionIcon(action: AuditAction | string): string {
  return ACTION_ICONS[action] ?? 'pi-circle-fill'
}
export function fieldLabel(key: string): string {
  return FIELD_LABELS[key] ?? key
}

/**
 * 格式化 diff 的單一 value。
 * - null / undefined → '—'
 * - 列舉值走 ENUM_LABELS 翻譯
 * - 陣列 / 物件 → 顯示 '(N 項)' 或 '(已更新)'
 * - 其他原型值直接 toString
 */
export function formatValue(key: string, value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  const map = ENUM_LABELS[key]
  if (map && typeof value === 'string' && map[value]) return map[value]
  if (Array.isArray(value)) return `（共 ${value.length} 項）`
  if (typeof value === 'object') return '（已更新）'
  if (typeof value === 'number') return value.toLocaleString('zh-TW')
  return String(value)
}
