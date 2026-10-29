import { computed, onMounted, ref } from 'vue'
import { useToast } from 'primevue/usetoast'
import { HttpError } from '@/api/service'
import { useAuthStore } from '@/stores/auth'
import {
  getQuota,
  recognize,
  type OcrErrorBody,
  type OcrErrorCode,
  type OcrFieldConflict,
  type OcrFieldKey,
  type OcrFields,
  type OcrInvoiceConflict,
  type OcrItem,
  type OcrItemConflict,
  type OcrQuotaSnapshot,
  type OcrRecognizeResponse,
  type OcrRole,
} from '@/api/ocr'
import type { UserToast } from '@/utils/userFeedback'

/** 送辨識的一張憑證；label 是畫面上給使用者看的「憑證 N」 */
export interface OcrSource {
  file: File
  label: string
}

/** 發票號碼的一個候選：某張憑證的完整字軌 + 數字 */
export interface OcrInvoiceCandidate {
  invoicePrefix: string | null
  invoiceDigits: string | null
  sourceIndex: number
}

/**
 * 彈窗裡的一題。字軌與數字合成一題「發票號碼」，選一張就整組帶入，
 * 避免挑出 FV + 04855261 這種不存在的號碼（規格 §4）
 */
export type OcrFieldQuestion =
  | ({ kind: 'field' } & OcrFieldConflict)
  | { kind: 'invoice'; candidates: OcrInvoiceCandidate[] }

/**
 * 等使用者在彈窗挑選的衝突；sourceLabels[sourceIndex] 是該候選來自哪張憑證。
 * invoices 非空時先問「要用哪一張發票？」，整張帶入（規格 §3.2）
 */
export interface OcrConflictState {
  invoices: OcrInvoiceConflict[]
  fields: OcrFieldQuestion[]
  items: OcrItemConflict[]
  sourceLabels: string[]
}

/** 彈窗挑選結果：被挑中的欄位值 + 被挑中要保留的品項 */
export interface OcrConflictChoice {
  fields: Partial<OcrFields>
  items: OcrItem[]
}

/** 辨識失敗一律不動表單；提示說明原因與下一步 */
type OcrErrorToast = UserToast & { severity: 'warn' | 'error' }

const OCR_ERROR_TOASTS: Record<Exclude<OcrErrorCode, 'quota_exhausted'>, OcrErrorToast> = {
  invalid_role: { severity: 'error', summary: '辨識失敗', detail: '請重新整理頁面後再試。' },
  invalid_file_type: {
    severity: 'warn',
    summary: '檔案格式不支援',
    detail: '僅支援 JPG、PNG、WebP、HEIC 圖片與 PDF，請移除後重新上傳。',
  },
  too_many_files: { severity: 'warn', summary: '一次最多 5 張', detail: '請取消勾選部分憑證後再試。' },
  file_too_large: { severity: 'warn', summary: '單檔不得超過 5MB', detail: '請壓縮後重新上傳。' },
  ocr_no_result: {
    severity: 'warn',
    summary: '無法辨識，請改用手動輸入',
    detail: '已填的欄位都保留著，也可以換一張清楚的憑證再試。',
  },
  ocr_unavailable: {
    severity: 'error',
    summary: '辨識服務暫時無法使用',
    detail: '請稍後再試，或改用手動輸入。',
  },
}

const INVOICE_PARTS: ReadonlySet<OcrFieldKey> = new Set(['invoicePrefix', 'invoiceDigits'])

/**
 * 欄位衝突轉成彈窗題目：字軌 / 數字任一有衝突就合成一題，放在原本字軌或數字那題的位置。
 * 只有一半有衝突時，另一半用 merged 的值補上
 */
function toQuestions(conflicts: OcrFieldConflict[], merged: OcrFields): OcrFieldQuestion[] {
  const prefix = conflicts.find((c) => c.field === 'invoicePrefix')
  const digits = conflicts.find((c) => c.field === 'invoiceDigits')
  const partOf = (c: OcrFieldConflict | undefined, sourceIndex: number, fallback: string | null) =>
    c ? ((c.candidates.find((x) => x.sourceIndex === sourceIndex)?.value ?? null) as string | null) : fallback
  const sourceIndexes = [...new Set([...(prefix?.candidates ?? []), ...(digits?.candidates ?? [])].map((c) => c.sourceIndex))]
    .sort((a, b) => a - b)

  const questions: OcrFieldQuestion[] = []
  for (const c of conflicts) {
    if (!INVOICE_PARTS.has(c.field)) {
      questions.push({ kind: 'field', ...c })
    } else if (!questions.some((q) => q.kind === 'invoice')) {
      questions.push({
        kind: 'invoice',
        candidates: sourceIndexes.map((i) => ({
          sourceIndex: i,
          invoicePrefix: partOf(prefix, i, merged.invoicePrefix),
          invoiceDigits: partOf(digits, i, merged.invoiceDigits),
        })),
      })
    }
  }
  return questions
}

/** 表單沒有對應欄位的「我方」資料，不需要讓使用者挑 */
const UNBOUND_FIELDS: ReadonlySet<OcrFieldKey> = new Set(['ourName', 'ourTaxId'])

interface Options {
  role: OcrRole
  /** 把辨識結果整份寫進表單（null 欄位清空；OCR 不給的欄位由表單自己保留） */
  apply: (fields: OcrFields, items: OcrItem[]) => void
  /** 辨識完成提示的內文，例如「欄位已自動帶入，請核對後儲存」 */
  successDetail: string
}

/** 已上傳憑證（data URL）轉成可送 multipart 的 File */
export async function dataUrlToFile(dataUrl: string, filename: string, mimeType?: string): Promise<File> {
  const blob = await (await fetch(dataUrl)).blob()
  return new File([blob], filename, { type: mimeType || blob.type })
}

/** 後端應回 camelCase 欄位名；保險起見 snake_case 也轉一次 */
function toFieldKey(raw: string): OcrFieldKey {
  return raw.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase()) as OcrFieldKey
}

/**
 * 三個表單（支出 / 代墊款 / 收入）共用的憑證辨識流程：
 * 進表單查一次剩餘次數 → 送勾選的憑證 → 結果交給表單 apply → 用回傳 quota 更新剩餘次數。
 */
export function useOcrRecognize(options: Options) {
  const toast = useToast()
  const auth = useAuthStore()

  const quota = ref<OcrQuotaSnapshot | null>(null)
  const isRecognizing = ref(false)
  /** 非 null 時顯示衝突挑選彈窗 */
  const conflict = ref<OcrConflictState | null>(null)
  /** 衝突欄位清空後的結果；挑選完成時在這份上補值再整份帶入 */
  let pendingBase: { fields: OcrFields; items: OcrItem[] } | null = null

  onMounted(async () => {
    try {
      quota.value = await getQuota()
    } catch {
      // 查不到就不顯示剩餘次數，不影響辨識本身
      quota.value = null
    }
  })

  const quotaText = computed(() => {
    const q = quota.value
    if (!q) return ''
    if (q.purchasedRemaining > 0) {
      return `本月剩餘 ${q.monthlyRemaining} 次 / 加購 ${q.purchasedRemaining} 次`
    }
    return `本月剩餘 ${q.monthlyRemaining} 次`
  })

  function updateQuota(next: OcrQuotaSnapshot | undefined) {
    if (!next) return
    quota.value = {
      monthlyRemaining: next.monthlyRemaining,
      purchasedRemaining: next.purchasedRemaining,
    }
  }

  function errorToast(err: unknown): OcrErrorToast {
    const body = err instanceof HttpError ? (err.body as Partial<OcrErrorBody> & { error?: string } | undefined) : undefined
    const code = body?.code ?? body?.error
    // 429、422（已呼叫 Google 而扣次）會附剩餘次數；沒附就不動
    updateQuota(body?.quota)
    if (code === 'quota_exhausted') {
      // 加購頁上線前只有文字說明；員工不能加購，改請他找管理員（規格 §5）
      return auth.role === 'admin'
        ? { severity: 'warn', summary: '本月 OCR 辨識次數已用完', detail: '可以先改用手動輸入，下個月 1 日會重新計算。' }
        : { severity: 'warn', summary: '本月額度已用完，請聯絡管理員加購', detail: '可以先改用手動輸入。' }
    }
    if (code && Object.prototype.hasOwnProperty.call(OCR_ERROR_TOASTS, code)) {
      return OCR_ERROR_TOASTS[code as keyof typeof OCR_ERROR_TOASTS]
    }
    return { severity: 'error', summary: '辨識失敗', detail: '請稍後再試。' }
  }

  /** 衝突欄位先清空，等使用者在彈窗挑選；代墊款沒有品項 */
  function baseResult(res: OcrRecognizeResponse): { fields: OcrFields; items: OcrItem[] } {
    const { items, ...fields } = res.merged
    for (const c of res.conflicts.fields) fields[toFieldKey(c.field)] = null
    return {
      fields,
      items: options.role === 'reimbursement' ? [] : items.map((it) => ({ ...it })),
    }
  }

  /** 送辨識；成功回 true。失敗時表單欄位維持原狀 */
  async function run(sources: OcrSource[]): Promise<boolean> {
    if (sources.length === 0 || isRecognizing.value) return false
    isRecognizing.value = true
    try {
      const res = await recognize(
        sources.map((s) => s.file),
        options.role,
      )
      updateQuota(res.quota)
      const base = baseResult(res)
      options.apply(base.fields, base.items)
      const fieldConflicts = toQuestions(
        res.conflicts.fields
          .map((c) => ({ ...c, field: toFieldKey(c.field) }))
          .filter((c) => !UNBOUND_FIELDS.has(c.field)),
        res.merged,
      )
      const itemConflicts = options.role === 'reimbursement' ? [] : res.conflicts.items
      // 沒回 invoices 就是沒有多張發票，照原本流程
      const invoices = (res.conflicts.invoices ?? []).map((inv) => ({
        ...inv,
        items: options.role === 'reimbursement' ? [] : inv.items,
      }))
      // 挑哪一張發票算一題
      const conflictCount = (invoices.length > 0 ? 1 : 0) + fieldConflicts.length + itemConflicts.length
      // 有衝突時提示去彈窗挑選；其他一律固定請使用者核對，不依信心度另外提示（規格 §6）
      toast.add({
        severity: 'success',
        summary: '辨識完成',
        detail: conflictCount > 0 ? `有 ${conflictCount} 項結果不一致，請挑選要保留的內容` : options.successDetail,
        life: 2500,
      })
      if (conflictCount > 0) {
        // 一律讓使用者挑，不自動選信心度最高的（規格 §6）
        pendingBase = base
        conflict.value = {
          invoices,
          fields: fieldConflicts,
          items: itemConflicts,
          sourceLabels: sources.map((s) => s.label),
        }
      }
      return true
    } catch (err) {
      const t = errorToast(err)
      toast.add({ ...t, life: t.severity === 'error' ? 3500 : 3000 })
      return false
    } finally {
      isRecognizing.value = false
    }
  }

  /** 彈窗按「確認」：挑中的值補進結果，整份重新帶入表單 */
  function resolveConflicts(choice: OcrConflictChoice) {
    if (pendingBase) {
      options.apply(
        { ...pendingBase.fields, ...choice.fields },
        [...pendingBase.items, ...choice.items],
      )
    }
    dismissConflicts()
  }

  /** 彈窗沒挑完就關掉：衝突欄位維持空白，讓使用者自行輸入 */
  function dismissConflicts() {
    conflict.value = null
    pendingBase = null
  }

  return { quota, quotaText, isRecognizing, run, conflict, resolveConflicts, dismissConflicts }
}
