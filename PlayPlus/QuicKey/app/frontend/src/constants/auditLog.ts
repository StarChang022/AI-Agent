/**
 * AuditLog 顯示用的 zh-TW 對照，後台稽核日誌頁與詳情抽屜的歷程共用。
 * 對應後端 AuditLog::ACTIONS 與各 target 的欄位。未對照的 key 直接顯示 snake_case
 * 原字（不會壞 render）。
 */
import type { AuditAction, AuditLogEntry, AuditTargetType } from '@/api/audit-logs'
import { accountSubjectLabel } from '@/constants/accountSubjects'
import { PAYMENT_METHOD_LABELS, RECURRING_DIRECTION_LABELS } from '@/types/domain'
import { formatCurrency, formatDate, formatDateTime } from '@/utils/format'

export const ACTION_LABELS: Record<string, string> = {
  create:         '建立',
  update:         '編輯',
  status_change:  '狀態切換',
  delete:         '刪除',
  restore:        '還原',
  purge:          '永久刪除',
  void:           '作廢',
  revert_void:    '取消作廢',
  export:         '匯出',
}

/** 對象類型，順序同篩選選單 */
export const AUDIT_TARGET_LABELS: Record<AuditTargetType, string> = {
  expense:            '支出',
  income:             '收入',
  reimbursement:      '代墊款',
  account:            '帳戶',
  recurring_template: '固定收支範本',
  category:           '類別',
  transfer:           '資金移轉',
  budget:             '預算',
  data_export:        '資料匯出',
}

export const AUDIT_TARGET_OPTIONS = (Object.keys(AUDIT_TARGET_LABELS) as AuditTargetType[]).map((value) => ({
  value,
  label: AUDIT_TARGET_LABELS[value],
}))

/** 動作篩選的 9 種，值與寫入端的 action 一致 */
export const AUDIT_ACTION_OPTIONS = (Object.keys(ACTION_LABELS) as AuditAction[]).map((value) => ({
  value,
  label: ACTION_LABELS[value],
}))

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
  export:         'pi-download',
}

/**
 * 常見 diff 欄位的 zh-TW 標籤。
 * key 用 camelCase（service.ts 已把 response 的 snake_case 轉成 camelCase，
 * 包含 jsonb 內的 key 也會轉）。
 */
export const FIELD_LABELS: Record<string, string> = {
  // 宣告順序就是變更內容的顯示順序（FIELD_ORDER），沒列到的欄位排最後。
  // 各對象的欄位共用同一份順序，所以依「識別 → 日期 → 對象 → 類別帳戶 → 期間 → 憑證 → 金額 → 狀態 → 附件 → 備註」排

  // 識別（名稱依對象覆寫，見 TARGET_FIELD_LABELS）
  name:         '名稱',
  kind:         '類別類型',
  employeeId:   '申請人',
  employeeName: '申請人',
  direction:    '收支方向',

  // 日期
  date:         '發生日期',
  invoiceDate:  '發票日期',
  incurredAt:   '發生日期',
  transferDate: '移轉日期',

  // 交易對象與說明
  vendor:       '賣方',
  customer:     '客戶',
  counterparty: '廠商或客戶',
  description:  '描述',

  // 類別、帳戶
  categoryId:      '類別',
  categoryName:    '類別',
  accountCode:     '會計科目',
  accountId:       '帳戶',
  accountName:     '帳戶',
  fromAccountId:   '轉出帳戶',
  fromAccountName: '轉出帳戶',
  toAccountId:     '轉入帳戶',
  toAccountName:   '轉入帳戶',
  accountType:     '帳戶類型',
  currency:        '幣別',

  // 預算期間
  cycle:       '週期',
  periodStart: '期間起',
  periodEnd:   '期間迄',

  // 固定收支範本與它產生的紀錄
  frequency:           '週期',
  dayOfMonth:          '日期',
  monthOfYear:         '月份',
  startMonth:          '開始月份',
  endMonth:            '結束月份',
  lastGeneratedPeriod: '已產生到',
  recurringPeriod:     '期數',

  // 憑證
  documentType: '憑證類型',
  taxId:        '統編',
  invoiceNo:    '發票號碼',
  taxRate:      '稅率',
  preTaxAmt:    '未稅金額',
  taxAmt:       '稅額',

  // 金額
  amount:        '金額',
  fee:           '手續費',
  openingAmount: '起始金額',
  openingMonth:  '起始月份',
  source:        '來源',

  // 狀態與收付款
  status:                '狀態',
  prevStatus:            '前狀態',
  rejectReason:          '駁回原因',
  payoutStatus:          '付款狀態',
  plannedPayoutDate:     '應付日期',
  plannedPayoutManual:   '手動調整應付日期',
  autoPlannedPayoutDate: '自動排程應付日期',
  paidAt:                '實付日期',
  paymentMethod:         '付款方式',
  collectionStatus:      '收款狀態',
  plannedCollectionDate: '應收日期',
  collectedAt:           '實收日期',

  // 品項與附件
  items:        '品項',
  attachments:  '憑證圖檔',
  // 舊紀錄（圖檔改實體檔案前）的代墊款憑證
  receiptUrls:  '憑證圖檔',
  receiptNames: '憑證圖檔',

  // 備註
  note:    '備註',
  comment: '備註',

  // 其他
  isArchived: '已停用',
  sortOrder:  '排序',
  deletedAt:  '刪除時間',
}

/** 欄位顯示順序：依 FIELD_LABELS 的宣告順序 */
const FIELD_ORDER = new Map(Object.keys(FIELD_LABELS).map((key, i) => [key, i]))

/** 依對象覆寫的標籤：代墊款的付款叫「發放」 */
const TARGET_FIELD_LABELS: Partial<Record<AuditTargetType, Record<string, string>>> = {
  reimbursement: { paidAt: '發放日', paymentMethod: '發放方式' },
  account: { name: '帳戶名稱' },
  recurring_template: { name: '範本名稱' },
  category: { name: '類別名稱' },
}

/** 純內部 ID 不給使用者看；via 已標在動作上，不再列一行 */
export const HIDDEN_FIELDS = new Set(['sourceRefId', 'expenseId', 'paidById', 'recurringTemplateId', 'transferId', 'feeExpenseId', 'via'])

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
    rejected:   '駁回',
    paid:       '已發放',
    voided:     '已作廢',
  },
  prevStatus: {
    draft:      '草稿',
    in_review:  '簽核中',
    approved:   '已核銷',
    rejected:   '駁回',
    paid:       '已發放',
    voided:     '已作廢',
  },
  source:        { general: '一般支出', reimbursement: '代墊款', transfer_fee: '移轉手續費' },
  paymentMethod: PAYMENT_METHOD_LABELS,
  documentType: { invoice: '發票', receipt: '收據' },
  taxRate:      { business_5: '營業稅 5%', exempt_0: '免稅 0%' },
  via:          { excel_import: 'Excel 匯入', recurring: '固定收支自動產生', transfer_fee: '資金移轉手續費自動產生',
                  budget_template: '套用基本預算', category_clear: '類別停用或刪除連帶清除' },
  direction:    RECURRING_DIRECTION_LABELS,
  frequency:    { monthly: '每月', yearly: '每年' },
  cycle:        { month: '月', year: '年' },
  // 帳戶類型欄位已移除，保留對照讓舊稽核紀錄照常可讀
  accountType:  { bank: '銀行帳戶', cash: '現金' },
  kind:         { expense: '支出類別', income: '收入類別' },
}

export function actionLabel(action: AuditAction | string): string {
  return ACTION_LABELS[action] ?? action
}
/** 列表直接帶 via，抽屜的歷程只有 before / after，兩邊都要能算出動作名稱 */
interface EntryForActionLabel {
  action: AuditAction | string
  via?: string | null
  before?: Record<string, unknown> | null
  after?: Record<string, unknown> | null
}
/** 手續費支出的每筆異動都帶 via；永久刪除的 after 是 null，標記在 before */
function entryVia(entry: EntryForActionLabel): unknown {
  return entry.via ?? (entry.after ?? entry.before)?.via
}
/** 系統自動產生與 Excel 匯入不另設動作，以 via 區分；手續費支出的其他動作要保留動作本身 */
export function entryActionLabel(entry: EntryForActionLabel): string {
  const via = entryVia(entry)
  if (via === 'excel_import') return ENUM_LABELS.via.excel_import
  if (via === 'recurring' && entry.action === 'create') return ENUM_LABELS.via.recurring
  if (via === 'transfer_fee' && entry.action === 'create') return ENUM_LABELS.via.transfer_fee
  // 預算的來源每個動作都可能出現（建立、編輯、刪除），一律標在動作後面
  if (via === 'transfer_fee' || via === 'budget_template' || via === 'category_clear') {
    return `${actionLabel(entry.action)}（${ENUM_LABELS.via[via]}）`
  }
  return actionLabel(entry.action)
}
export function actionIcon(action: AuditAction | string): string {
  return ACTION_ICONS[action] ?? 'pi-circle-fill'
}
export function fieldLabel(key: string, targetType?: AuditTargetType): string {
  return (targetType && TARGET_FIELD_LABELS[targetType]?.[key]) ?? FIELD_LABELS[key] ?? key
}
/**
 * 對象欄：類型＋名稱；取不到名稱時只顯示類型。
 * 資料匯出沒有名稱，顯示範圍，例如「資料匯出（支出 2026/11/01–2026/11/30）」（資料模型 §2.7）
 */
export function auditTargetText(entry: { targetType: AuditTargetType; targetLabel: string | null }): string {
  const type = AUDIT_TARGET_LABELS[entry.targetType] ?? entry.targetType
  if (entry.targetType === 'data_export') return entry.targetLabel ? `${type}（${entry.targetLabel}）` : type
  return entry.targetLabel ? `${type}｜${entry.targetLabel}` : type
}

/** 金額欄位在部分紀錄裡是字串（如 "30.0"），要照數字顯示 */
const MONEY_FIELDS = new Set(['amount', 'fee', 'preTaxAmt', 'taxAmt', 'openingAmount'])
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/
const DATETIME_RE = /^\d{4}-\d{2}-\d{2}T/

/** 記檔名的欄位：update 為檔名陣列，create／purge 快照為 { filename, mimeType, byteSize } 陣列 */
const FILE_LIST_FIELDS = new Set(['attachments', 'receiptNames'])

/** 圖檔清單顯示檔名，以「、」分隔；沒有圖檔顯示「無」。認不出格式時退回張數 */
function formatFileList(value: unknown[]): string {
  if (value.length === 0) return '無'
  const names = value.map((v) =>
    typeof v === 'string' ? v : v && typeof v === 'object' && 'filename' in v ? String(v.filename) : null,
  )
  if (names.some((n) => n === null)) return `（共 ${value.length} 張）`
  return names.join('、')
}

/**
 * 格式化 diff 的單一 value。
 * - null / undefined → '—'
 * - boolean → '是' / '否'
 * - 日期字串（YYYY-MM-DD）→ formatDate；含時間的 ISO 字串 → formatDateTime
 * - 列舉值走 ENUM_LABELS 翻譯；會計科目顯示代碼加名稱
 * - 圖檔欄位 → 列出檔名
 * - 陣列 / 物件 → 顯示 '(N 項)' 或 '(已更新)'
 * - 其他原型值直接 toString
 */
export function formatValue(key: string, value: unknown): string {
  if (FILE_LIST_FIELDS.has(key) && Array.isArray(value)) return formatFileList(value)
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? '是' : '否'
  if (key === 'accountCode' && typeof value === 'string') return accountSubjectLabel(value)
  const map = ENUM_LABELS[key]
  if (map && typeof value === 'string' && map[value]) return map[value]
  if (Array.isArray(value)) return `（共 ${value.length} 項）`
  if (typeof value === 'object') return '（已更新）'
  if (typeof value === 'number') return value.toLocaleString('zh-TW')
  if (MONEY_FIELDS.has(key) && !Number.isNaN(Number(value))) return Number(value).toLocaleString('zh-TW')
  if (typeof value === 'string' && DATE_RE.test(value)) return formatDate(value)
  if (typeof value === 'string' && DATETIME_RE.test(value)) return formatDateTime(value)
  return String(value)
}

/** 藏掉內部 ID；ID 欄位有對應名稱欄位時藏 ID（舊紀錄沒名稱才顯示）；依 FIELD_ORDER 排序 */
function visibleFields(keys: Iterable<string>): string[] {
  const all = new Set(keys)
  const order = (k: string) => FIELD_ORDER.get(k) ?? Number.MAX_SAFE_INTEGER
  return [...all]
    .filter((k) => !HIDDEN_FIELDS.has(k) && !(ID_NAME_FIELDS[k] && all.has(ID_NAME_FIELDS[k])))
    .sort((x, y) => order(x) - order(y))
}

export interface AuditDiffRow {
  key: string
  label: string
  before?: string
  after?: string
  single?: string
}

const EXPORT_SCOPE_LABELS: Record<string, string> = { single: '單筆', selected: '勾選', filtered: '全部（依當時的篩選）' }
const EXPORT_KIND_LABELS: Record<string, string> = { expense: '支出', income: '收入', reimbursement: '代墊款' }
const EXPORT_SOURCE_LABELS: Record<string, string> = { general: '一般支出', reimbursement: '代墊款', recurring: '固定', transfer_fee: '移轉手續費' }

const isSet = (v: unknown) => v !== undefined && v !== null && v !== ''

/** 「全部」匯出套用的列表篩選（不含發生日期），轉成一句話；沒有篩選時回 null */
function describeExportFilters(filters: Record<string, unknown>): string | null {
  const out: string[] = []
  const status = filters.payoutStatus ?? filters.collectionStatus ?? filters.status
  if (typeof status === 'string') {
    out.push(ENUM_LABELS.payoutStatus[status] ?? ENUM_LABELS.collectionStatus[status] ?? ENUM_LABELS.status[status] ?? status)
  }
  if (typeof filters.source === 'string') out.push(EXPORT_SOURCE_LABELS[filters.source] ?? filters.source)
  if (filters.recurring === true || filters.recurring === 'true') out.push('固定')
  // 類別記發起當下的名稱（categoryNames，順序同 categoryIds）；取不到名稱時退回類數
  const names = Array.isArray(filters.categoryNames)
    ? filters.categoryNames.filter((n): n is string => typeof n === 'string' && n.trim() !== '')
    : []
  if (names.length) out.push(`類別：${names.join('、')}`)
  else if (Array.isArray(filters.categoryIds) && filters.categoryIds.length) out.push(`類別 ${filters.categoryIds.length} 類`)
  if (isSet(filters.amountMin) || isSet(filters.amountMax)) {
    const min = isSet(filters.amountMin) ? formatCurrency(Number(filters.amountMin)) : ''
    const max = isSet(filters.amountMax) ? formatCurrency(Number(filters.amountMax)) : ''
    out.push(min && max ? `金額 ${min}–${max}` : min ? `金額 ${min} 以上` : `金額 ${max} 以下`)
  }
  if (typeof filters.q === 'string' && filters.q.trim()) out.push(`關鍵字「${filters.q.trim()}」`)
  if (filters.missingInvoiceNo === true || filters.missingInvoiceNo === 'true') out.push('未填發票號碼')
  return out.length ? out.join('、') : null
}

/** 發生日期區間（選填，可只有起或迄）；都沒有回 null */
function describeExportDateRange(from: unknown, to: unknown): string | null {
  if (!isSet(from) && !isSet(to)) return null
  if (isSet(from) && isSet(to)) return `${formatValue('dateFrom', from)}–${formatValue('dateTo', to)}`
  return isSet(from) ? `${formatValue('dateFrom', from)} 起` : `至 ${formatValue('dateTo', to)}`
}

/** 資料匯出的日誌內容：範圍、類型、篩選、筆數、是否含圖檔（資料模型 §2.7） */
function dataExportRows(after: Record<string, unknown>): AuditDiffRow[] {
  const rows: AuditDiffRow[] = []
  const scope = String(after.scope ?? '')
  rows.push({ key: 'scope', label: '匯出範圍', single: EXPORT_SCOPE_LABELS[scope] ?? (scope || '—') })
  if (typeof after.kind === 'string') rows.push({ key: 'kind', label: '類型', single: EXPORT_KIND_LABELS[after.kind] ?? after.kind })
  const criteria = (after.criteria && typeof after.criteria === 'object' ? after.criteria : {}) as Record<string, unknown>
  if (scope === 'filtered') {
    const filters = (criteria.filters && typeof criteria.filters === 'object' ? criteria.filters : {}) as Record<string, unknown>
    const range = describeExportDateRange(filters.dateFrom ?? criteria.dateFrom, filters.dateTo ?? criteria.dateTo)
    if (range) rows.push({ key: 'dateRange', label: '發生日期區間', single: range })
    rows.push({ key: 'filters', label: '篩選條件', single: describeExportFilters(filters) ?? '無' })
  }
  if (after.recordCount !== undefined) rows.push({ key: 'recordCount', label: '筆數', single: `${formatValue('recordCount', after.recordCount)} 筆` })
  if (after.withAttachments !== undefined) rows.push({ key: 'withAttachments', label: '含圖檔', single: formatValue('withAttachments', after.withAttachments) })
  return rows
}

/**
 * 把 before / after 轉成 diff 條目：
 * - create（before 為 null）：顯示 after 的全部欄位，value 單值呈現
 * - update / status_change：取 before ∪ after 的 key，value 為 old → new
 * - delete / restore / purge / void 等（after 為 null 或值極少）：
 *   有 before 就顯示 before 的欄位當上下文（例如 void 的 prev_status / comment）
 */
export function auditDiffRows(
  entry: Pick<AuditLogEntry, 'before' | 'after'>,
  targetType: AuditTargetType,
): AuditDiffRow[] {
  if (targetType === 'data_export') return dataExportRows(entry.after ?? {})
  const b = entry.before ?? {}
  const a = entry.after ?? {}
  const keys = visibleFields([...Object.keys(b), ...Object.keys(a)])
  // create：單值；其他動作也在 before 為空時走單值分支
  if (!entry.before) {
    return keys.map((k) => ({ key: k, label: fieldLabel(k, targetType), single: formatValue(k, a[k]) }))
  }
  // purge、預算的 delete：只有 before 的資料；after 若只剩 via 之類的隱藏欄位也算
  if (!entry.after || !visibleFields(Object.keys(a)).length) {
    return keys.map((k) => ({ key: k, label: fieldLabel(k, targetType), single: formatValue(k, b[k]) }))
  }
  return keys.map((k) => ({
    key: k,
    label: fieldLabel(k, targetType),
    before: formatValue(k, b[k]),
    after: formatValue(k, a[k]),
  }))
}
