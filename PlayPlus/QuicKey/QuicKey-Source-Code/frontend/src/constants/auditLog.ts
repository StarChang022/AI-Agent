/**
 * AuditLog 顯示用的 zh-TW 對照。
 * 對應後端 AuditLog::ACTIONS 與各 target 常見欄位。未對照的 key 直接顯示 snake_case
 * 原字（不會壞 render）。
 */
import type { AuditAction, AuditLogEntry, AuditTargetType } from '@/api/audit-logs'
import { ACCOUNT_TYPE_LABELS, PAYMENT_METHOD_LABELS, RECURRING_DIRECTION_LABELS } from '@/types/domain'
import { formatDate, formatDateTime } from '@/utils/format'

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
  categoryName: '類別',
  accountId:    '帳戶',
  accountName:  '帳戶',
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
  deletedAt:    '刪除時間',
  // 建立紀錄的 after 才有（例如 Excel 匯入）；手續費支出每筆都有，改標在動作上。
  // 「來源」已用於一般支出／代墊款，故另取名
  via:          '建立方式',

  // Expense / Reimbursement
  source:            '來源',
  vendor:            '賣方',
  payoutStatus:      '付款狀態',
  paidAt:            '付款日',
  paymentMethod:     '付款方式',
  plannedPayoutDate: '預計付款日',
  plannedPayoutManual:   '手動調整預計付款日',
  autoPlannedPayoutDate: '系統預計付款日',

  // Account
  accountType:   '帳戶類型',
  currency:      '幣別',
  openingAmount: '起始金額',
  openingMonth:  '起始月份',

  // 固定收支範本與它產生的紀錄
  direction:           '收支方向',
  counterparty:        '廠商或客戶',
  frequency:           '週期',
  dayOfMonth:          '日期',
  monthOfYear:         '月份',
  startMonth:          '開始月份',
  endMonth:            '結束月份',
  lastGeneratedPeriod: '已產生到',
  recurringPeriod:     '期數',

  // 資金移轉
  fromAccountId:   '轉出帳戶',
  fromAccountName: '轉出帳戶',
  toAccountId:     '轉入帳戶',
  toAccountName:   '轉入帳戶',
  fee:             '手續費',
  transferDate:    '移轉日期',

  // Income
  customer:         '客戶',
  collectionStatus: '收款狀態',
  collectedAt:      '收款日',

  // Reimbursement 流程
  status:        '狀態',
  rejectReason:  '退回原因',
  prevStatus:    '前狀態',
  employeeId:    '申請人',
  employeeName:  '申請人',
  receiptUrls:   '憑證',
  receiptNames:  '憑證',
}

/** 依對象覆寫的標籤：代墊款的付款叫「發放」 */
const TARGET_FIELD_LABELS: Partial<Record<AuditTargetType, Record<string, string>>> = {
  reimbursement: { paidAt: '發放日', paymentMethod: '發放方式' },
  account: { name: '帳戶名稱' },
  recurring_template: { name: '範本名稱' },
}

/** 純內部 ID，不給使用者看 */
export const HIDDEN_FIELDS = new Set(['sourceRefId', 'expenseId', 'paidById', 'recurringTemplateId', 'transferId', 'feeExpenseId'])

/**
 * ID 欄位 → 同一筆紀錄裡的對應名稱欄位。有名稱時藏 ID；
 * 舊紀錄沒有名稱時才顯示 ID 欄位（標籤同名稱欄位）。
 */
export const ID_NAME_FIELDS: Record<string, string> = {
  categoryId:  'categoryName',
  accountId:   'accountName',
  fromAccountId: 'fromAccountName',
  toAccountId:   'toAccountName',
  employeeId:  'employeeName',
  receiptUrls: 'receiptNames',
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
  source:        { general: '一般支出', reimbursement: '代墊款', transfer_fee: '移轉手續費' },
  paymentMethod: PAYMENT_METHOD_LABELS,
  documentType: { invoice: '發票', receipt: '收據' },
  taxRate:      { business_5: '營業稅 5%', exempt_0: '免稅 0%' },
  via:          { excel_import: 'Excel 匯入', recurring: '固定收支自動產生', transfer_fee: '資金移轉手續費自動產生' },
  direction:    RECURRING_DIRECTION_LABELS,
  frequency:    { monthly: '每月', yearly: '每年' },
  accountType:  ACCOUNT_TYPE_LABELS,
}

export function actionLabel(action: AuditAction | string): string {
  return ACTION_LABELS[action] ?? action
}
/** 手續費支出的每筆異動都帶 via；永久刪除的 after 是 null，標記在 before */
export function isTransferFeeEntry(entry: Pick<AuditLogEntry, 'before' | 'after'>): boolean {
  return (entry.after ?? entry.before)?.via === 'transfer_fee'
}
/** 系統自動產生的紀錄，動作仍是 create，以 after.via 區分；手續費支出的其他動作要保留動作本身 */
export function entryActionLabel(entry: Pick<AuditLogEntry, 'action' | 'before' | 'after'>): string {
  if (entry.action === 'create' && entry.after?.via === 'recurring') return ENUM_LABELS.via.recurring
  if (isTransferFeeEntry(entry)) {
    const label = ENUM_LABELS.via.transfer_fee
    return entry.action === 'create' ? label : `${actionLabel(entry.action)}（${label}）`
  }
  return actionLabel(entry.action)
}
export function actionIcon(action: AuditAction | string): string {
  return ACTION_ICONS[action] ?? 'pi-circle-fill'
}
export function fieldLabel(key: string, targetType?: AuditTargetType): string {
  return (targetType && TARGET_FIELD_LABELS[targetType]?.[key]) ?? FIELD_LABELS[key] ?? key
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/
const DATETIME_RE = /^\d{4}-\d{2}-\d{2}T/

/**
 * 格式化 diff 的單一 value。
 * - null / undefined → '—'
 * - boolean → '是' / '否'
 * - 日期字串（YYYY-MM-DD）→ formatDate；含時間的 ISO 字串 → formatDateTime
 * - 列舉值走 ENUM_LABELS 翻譯
 * - 陣列 / 物件 → 顯示 '(N 項)' 或 '(已更新)'
 * - 其他原型值直接 toString
 */
export function formatValue(key: string, value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? '是' : '否'
  const map = ENUM_LABELS[key]
  if (map && typeof value === 'string' && map[value]) return map[value]
  if (Array.isArray(value)) return `（共 ${value.length} 項）`
  if (typeof value === 'object') return '（已更新）'
  if (typeof value === 'number') return value.toLocaleString('zh-TW')
  if (typeof value === 'string' && DATE_RE.test(value)) return formatDate(value)
  if (typeof value === 'string' && DATETIME_RE.test(value)) return formatDateTime(value)
  return String(value)
}
