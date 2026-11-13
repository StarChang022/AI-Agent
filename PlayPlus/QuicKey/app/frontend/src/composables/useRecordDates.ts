import { computed, ref } from 'vue'
import type { DocumentType } from '@/types/domain'
import { toIsoDate } from '@/utils/format'
import { snapshotPlannedPayoutDate, type PayoutDay } from '@/utils/payoutSchedule'

/**
 * 收支新增／編輯表單的日期欄位（PRD 第 23 條）：發生日期、發票日期、應收／應付日期。
 * 實收／實付日期與狀態綁在一起，仍由各表單自己管。
 *
 * - 發票日期第一次填入（手動或 OCR）時，發生日期若還是預設的今天、沒被改過，帶入同一天；
 *   編輯既有紀錄不做這項帶入（請款草稿沒有發生日期時比照新增）。
 * - 之後改發票日期（新增與編輯都適用，手動或 OCR）：發生日期若和修改前的發票日期同一天就跟著改，
 *   不同天不動；清空發票日期時發生日期不動，再填入時用清空前的發票日期比對。只單向，改發生日期不動發票日期。
 *   跟著改的發生日期不算手動修改，但應收／應付日期照樣跟著發生日期連動。
 * - 改發生日期時，應收／應付日期若和修改前的發生日期同一天就一起改：
 *   收入一律如此；支出只在「自動值就是發生日期」（公司關閉付款日）時才會同一天，
 *   由付款日算出的應付日期不跟著動。
 * - 支出的應付日期和自動值不同就算手動調整過，可「改回自動排程」；
 *   登錄當下公司已關閉付款日（沒有自動排程）的不顯示。
 */

/** 換頁（批次匯入多筆）時要存起來的日期狀態 */
export interface RecordDatesState {
  occurredAt: Date | null
  invoiceDate: Date | null
  /** null = 還沒決定，載入時帶預設值 */
  plannedDate: Date | null
  /** 發生日期不再做「第一次填入」的帶入（帶過一次或手動改過） */
  occurredLocked: boolean
  /** 最後一次填好的發票日期（清空後仍保留）；省略時用 invoiceDate */
  lastInvoiceDate?: Date | null
}

function iso(d: Date | null): string | null {
  return d ? toIsoDate(d) : null
}

function fromIso(s: string | null): Date | null {
  return s ? new Date(`${s.slice(0, 10)}T00:00:00`) : null
}

function today(): Date {
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  return d
}

/**
 * kind = 'reimbursement'（員工請款）只用發生日期與發票日期，沒有應收／應付日期（PRD 第 23 條「代墊款請款」）。
 */
export function useRecordDates(kind: 'expense' | 'income' | 'reimbursement', isEdit: boolean) {
  const occurredAt = ref<Date | null>(isEdit ? null : today())
  const invoiceDate = ref<Date | null>(null)
  // 新增：先等於發生日期（今天）；支出載入公司付款日後再換成預覽值
  const plannedDate = ref<Date | null>(isEdit ? null : today())
  const occurredLocked = ref(isEdit)
  /**
   * 支出依付款日算出的應付日期：新增時是預覽值，編輯時是登錄當下存下的自動值。
   * null = 公司關閉付款日，自動值就是發生日期。收入一律 null。
   */
  const fixedAutoPlanned = ref<string | null>(null)

  /**
   * 清空前最後一個發生日期：發生日期清空後再重選時，用它比對應收／應付日期要不要跟著改，
   * 清空期間自動值也沿用它。
   */
  const lastOccurredIso = ref<string | null>(iso(occurredAt.value))

  /**
   * 修改前的發票日期：最後一次填好（commit）的發票日期，清空後仍保留，
   * 改發票日期時用它判斷發生日期要不要跟著改。
   */
  const lastInvoiceIso = ref<string | null>(null)

  /** 應收／應付日期的自動值 */
  const autoPlannedIso = computed(
    () => fixedAutoPlanned.value ?? iso(occurredAt.value) ?? lastOccurredIso.value,
  )
  /**
   * 支出應付日期被手動改過（和自動值不同）→ 顯示「改回自動排程」。
   * 公司關閉付款日（fixedAutoPlanned 為 null）時沒有自動排程可改回，不顯示；
   * 應付日期跟著發生日期的連動在 setOccurred，不受影響。
   */
  const plannedIsManual = computed(
    () =>
      kind === 'expense' &&
      fixedAutoPlanned.value !== null &&
      !!plannedDate.value &&
      iso(plannedDate.value) !== autoPlannedIso.value,
  )

  function setOccurred(v: Date | null, manual = true) {
    occurredAt.value = v
    if (manual) occurredLocked.value = true
    // 清空時應收／應付日期不動，等重選後再用清空前的日期比對
    if (!v) return
    const before = lastOccurredIso.value
    lastOccurredIso.value = iso(v)
    const follows = kind === 'income' || fixedAutoPlanned.value === null
    if (follows && before && iso(plannedDate.value) === before) {
      plannedDate.value = new Date(v)
    }
  }

  function setInvoiceDate(v: Date | null) {
    invoiceDate.value = v
  }

  /**
   * 發票日期填完（從日曆選定或離開欄位）才帶入發生日期：手動逐字輸入時 DatePicker 會先解析出
   * 打到一半的日期，若在那時就比對、帶入，半成品會被當成「修改前的發票日期」。
   */
  function commitInvoiceDate() {
    const v = invoiceDate.value
    // 清空：發生日期不動，保留清空前的發票日期供之後比對
    if (!v) return
    const before = lastInvoiceIso.value
    const next = iso(v)
    if (next === before) return
    lastInvoiceIso.value = next
    if (!occurredLocked.value) {
      // 第一次填入：發生日期還是預設值（或草稿空白）→ 帶入
      setOccurred(new Date(v), false)
      occurredLocked.value = true
    } else if (before && iso(occurredAt.value) === before) {
      // 修改：發生日期和修改前的發票日期同一天 → 跟著改（不算手動）
      setOccurred(new Date(v), false)
    }
  }

  function setPlanned(v: Date | null) {
    plannedDate.value = v
  }

  function resetPlanned() {
    plannedDate.value = fromIso(autoPlannedIso.value)
  }

  /** 改文件類型：發票日期一律清空（收據沒有；改成發票時為空白待填） */
  function onDocumentTypeChange() {
    invoiceDate.value = null
  }

  /** OCR 辨識出的日期：發票填發票日期（再依規則帶發生日期），收據直接填發生日期 */
  function applyOcrDate(type: DocumentType, d: Date | null) {
    invoiceDate.value = null
    if (type === 'invoice') {
      setInvoiceDate(d)
      commitInvoiceDate()
    } else if (d) setOccurred(d)
  }

  /**
   * 新增支出：依公司付款日算應付日期預覽（從今天含當天往後找最近的付款日）。
   * 應付日期還停在原本的自動值（使用者沒改過）時換成新的自動值。
   */
  function applyPayoutDay(day: PayoutDay | null) {
    const wasAuto = !plannedDate.value || iso(plannedDate.value) === autoPlannedIso.value
    fixedAutoPlanned.value = kind === 'expense' ? snapshotPlannedPayoutDate(toIsoDate(today()), day) : null
    if (wasAuto) resetPlanned()
  }

  /** 編輯：帶入已存的值；支出另帶登錄當下的自動值 */
  function loadSaved(saved: {
    /** 請款草稿可能還沒填發生日期 → null，維持空白 */
    date: string | null
    invoiceDate: string | null
    plannedDate: string | null
    autoPlannedDate?: string | null
  }) {
    occurredAt.value = fromIso(saved.date)
    lastOccurredIso.value = iso(occurredAt.value)
    invoiceDate.value = fromIso(saved.invoiceDate)
    lastInvoiceIso.value = iso(invoiceDate.value)
    fixedAutoPlanned.value = kind === 'expense' ? (saved.autoPlannedDate ?? null) : null
    plannedDate.value = fromIso(saved.plannedDate) ?? fromIso(autoPlannedIso.value)
    // 沒存過發生日期（草稿）時同新增：之後填發票日期會帶入一次
    occurredLocked.value = saved.date !== null
  }

  function snapshot(): RecordDatesState {
    return {
      occurredAt: occurredAt.value,
      invoiceDate: invoiceDate.value,
      plannedDate: plannedDate.value,
      occurredLocked: occurredLocked.value,
      lastInvoiceDate: fromIso(lastInvoiceIso.value),
    }
  }

  function load(s: RecordDatesState) {
    occurredAt.value = s.occurredAt
    lastOccurredIso.value = iso(s.occurredAt)
    invoiceDate.value = s.invoiceDate
    lastInvoiceIso.value = iso(s.lastInvoiceDate !== undefined ? s.lastInvoiceDate : s.invoiceDate)
    occurredLocked.value = s.occurredLocked
    plannedDate.value = s.plannedDate
    if (!plannedDate.value) resetPlanned()
  }

  /** 新增頁「清除所有欄位」：日期回到剛進頁的預設 */
  function reset() {
    load({ occurredAt: today(), invoiceDate: null, plannedDate: null, occurredLocked: false })
  }

  /** 送出用：發票日期只在發票時帶 */
  function payload(type: DocumentType) {
    return {
      date: iso(occurredAt.value) as string,
      invoiceDate: type === 'invoice' ? iso(invoiceDate.value) : null,
      plannedDate: iso(plannedDate.value) as string,
    }
  }

  return {
    occurredAt,
    invoiceDate,
    plannedDate,
    occurredLocked,
    autoPlannedIso,
    plannedIsManual,
    setOccurred,
    setInvoiceDate,
    commitInvoiceDate,
    setPlanned,
    resetPlanned,
    onDocumentTypeChange,
    applyOcrDate,
    applyPayoutDay,
    loadSaved,
    snapshot,
    load,
    reset,
    payload,
  }
}

/** DatePicker 的 update:model-value 型別較寬，表單只用單日 */
export function asDate(v: unknown): Date | null {
  return v instanceof Date ? v : null
}
