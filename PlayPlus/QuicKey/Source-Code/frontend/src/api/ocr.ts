/**
 * OCR API — 憑證辨識 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 response 邊界自動轉換（request 為 multipart，欄位名直接寫 snake_case）。
 * 對應 docs/OCR辨識規格.md §1、§2、§5。
 */

import type { DocumentType, TaxRate } from '@/types/domain'
import { service } from './service'

/** 決定「我方 vs 對方」欄位對應（見規格 §2 Role → 欄位對應） */
export type OcrRole = 'expense' | 'reimbursement' | 'income'

export interface OcrItem {
  name: string
  quantity: number
  unitPrice: number
  subtotal: number
}

/** 可自動合併的頂層欄位；辨識不到為 null */
export interface OcrFields {
  documentType: DocumentType | null
  /** YYYY-MM-DD */
  incurredAt: string | null
  ourTaxId: string | null
  ourName: string | null
  counterpartyTaxId: string | null
  counterpartyName: string | null
  invoicePrefix: string | null
  invoiceDigits: string | null
  /** null 時前端預設帶 business_5（規格 §4 稅率推導） */
  taxRate: TaxRate | null
  preTaxAmt: number | null
  taxAmt: number | null
  amount: number | null
}

export type OcrFieldKey = keyof OcrFields

export interface OcrMerged extends OcrFields {
  items: OcrItem[]
}

export interface OcrFieldCandidate {
  value: OcrFields[OcrFieldKey]
  /** 對應送出時 files[] 的索引（0 起算） */
  sourceIndex: number
  confidence: number
}

export interface OcrFieldConflict {
  field: OcrFieldKey
  candidates: OcrFieldCandidate[]
}

export interface OcrItemCandidate {
  item: OcrItem
  sourceIndex: number
}

/** 判定為同一品項、但數量或小計不同的一組候選；使用者挑一個保留 */
export interface OcrItemConflict {
  candidates: OcrItemCandidate[]
}

/**
 * 同一個檔案解出多張不同號碼的電子發票時，列出本次所有解出的發票，讓使用者整張挑一張（規格 §3.2）。
 * fields 只放 QR 有的欄位；品項不齊全時 items 為 []
 */
export interface OcrInvoiceConflict {
  sourceIndex: number
  /** 該發票在自己檔案裡的順序，從 1 開始 */
  invoiceIndex: number
  fields: Partial<OcrFields>
  items: OcrItem[]
}

/** 辨識回應 / 422、429 錯誤附帶的剩餘次數 */
export interface OcrQuotaSnapshot {
  /** 本次扣除的次數；429 時為 0 或不帶 */
  used?: number
  monthlyRemaining: number
  purchasedRemaining: number
}

export interface OcrRecognizeResponse {
  merged: OcrMerged
  conflicts: {
    fields: OcrFieldConflict[]
    items: OcrItemConflict[]
    /** 沒有任何檔案出現多張發票時不回；有的話 QR 欄位與品項不進 merged / fields / items */
    invoices?: OcrInvoiceConflict[]
  }
  confidence: {
    /** 0–1；前端不使用，僅供除錯 */
    overall: number
    /**
     * merged 裡有值、但屬於推測（低信心度）的欄位，例如 ["counterpartyName", "items"]。
     * 前端不逐欄提示（成功提示已固定請使用者核對欄位），僅保留型別對應後端回應
     */
    lowFields?: string[]
  }
  warnings: string[]
  quota: OcrQuotaSnapshot
}

export type OcrErrorCode =
  | 'invalid_role'
  | 'invalid_file_type'
  | 'too_many_files'
  | 'file_too_large'
  | 'ocr_no_result'
  | 'quota_exhausted'
  | 'ocr_unavailable'

/** 錯誤 payload（`quota` 僅 422、429 時附上） */
export interface OcrErrorBody {
  code: OcrErrorCode
  message: string
  quota?: OcrQuotaSnapshot
}

export interface OcrQuota {
  monthlyQuota: number
  monthlyUsed: number
  monthlyRemaining: number
  purchasedRemaining: number
  /** 下次月費額度重置時間（ISO 8601） */
  resetAt: string
}

/**
 * POST /ocr/recognize
 * 多檔視為同一張憑證的不同鏡位 / 分段；後端逐檔辨識後回合併結果 + 衝突清單。
 * 張數 / 單檔大小上限與憑證附件相同（5 張 / 5MB），上傳階段已擋，這裡不重複檢查。
 * 失敗時 throw HttpError，body 為 OcrErrorBody。
 */
export function recognize(
  files: ReadonlyArray<Blob | File>,
  role: OcrRole,
): Promise<OcrRecognizeResponse> {
  const form = new FormData()
  for (const f of files) form.append('files[]', f)
  form.append('role', role)
  return service.post<OcrRecognizeResponse>('/ocr/recognize', form)
}

/**
 * GET /ocr/quota
 * 公司本月剩餘辨識次數；管理員與員工看同一份。
 */
export function getQuota(): Promise<OcrQuota> {
  return service.get<OcrQuota>('/ocr/quota')
}
