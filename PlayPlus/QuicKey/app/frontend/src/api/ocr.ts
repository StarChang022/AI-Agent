/**
 * OCR API — 憑證辨識 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 response 邊界自動轉換（request 為 multipart，欄位名直接寫 snake_case）。
 * 對應 docs/OCR辨識規格.md §1、§2、§5。
 */

import type { Attachment, DocumentType, TaxRate } from '@/types/domain'
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
  /** 剩餘次數不足以辨識本次所有頁數；不辨識、不扣次 */
  | 'quota_insufficient'
  | 'ocr_unavailable'
  /** 要辨識的圖檔找不到（暫存檔已清除或已刪除） */
  | 'attachment_not_found'

/** 錯誤 payload（`quota` 僅 422、429 時附上） */
export interface OcrErrorBody {
  code: OcrErrorCode
  message: string
  quota?: OcrQuotaSnapshot
  /** 本次需要的次數（總頁數）；僅 quota_insufficient 時附上 */
  required?: number
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
 * 多張視為同一張憑證的不同鏡位 / 分段；後端逐張辨識後回合併結果 + 衝突清單。
 * 帶已上傳的圖檔 id（1～5 個；暫存檔或這筆紀錄已存的圖檔），不再重送檔案。
 * 失敗時 throw HttpError，body 為 OcrErrorBody。
 */
export function recognize(
  attachmentIds: ReadonlyArray<string>,
  role: OcrRole,
): Promise<OcrRecognizeResponse> {
  return service.post<OcrRecognizeResponse>('/ocr/recognize', { role, attachmentIds })
}

/**
 * GET /ocr/quota
 * 公司本月剩餘辨識次數；管理員與員工看同一份。
 */
export function getQuota(): Promise<OcrQuota> {
  return service.get<OcrQuota>('/ocr/quota')
}

// ─── 批次辨識（docs/資料模型.md §5.5）─────────────────────────────
// 先找張數、確認後才逐張辨識並扣次：上傳後只回每頁張數，確認才辨識內容、扣次並回內容；取消不扣次。

/** 批次匯入的一頁；receiptCount 為 0 的頁（空白、找不到憑證或整批逾時 90 秒）不扣次，原因在 warnings */
export interface OcrBatchPage {
  pageId: string
  /** 對應送出時 files[] 的索引（0 起算）；讀不出頁數的檔案不會出現在 pages，只在 warnings */
  fileIndex: number
  filename: string
  /** 該檔案內的頁碼（1 起算；圖片固定 1） */
  pageNumber: number
  receiptCount: number
}

export interface OcrBatchResponse {
  /** 確認／取消時用；暫存 30 分鐘 */
  token: string
  expiresAt: string
  /** 全部頁面找到的憑證張數合計（= 全選時最多扣的次數；辨識不出內容的不扣） */
  receiptCount: number
  pages: OcrBatchPage[]
  warnings: string[]
  quota: OcrQuotaSnapshot
}

/**
 * 確認後帶出的一張憑證（只含辨識出內容的；辨識不出或逾時的不列、不扣次）。
 * result 與 /ocr/recognize 成功回應同結構（不含 quota）。附件用 pageId 對到 pages
 */
export interface OcrBatchReceipt {
  pageId: string
  pageNumber: number
  filename: string
  result: Omit<OcrRecognizeResponse, 'quota'>
}

/**
 * 所選頁的檔案，每頁只回一次，已是暫存檔（有 id）。同一頁拆出的多張憑證共用同一個 id，
 * 各自建立時都帶這個 id。PDF 為單頁 PDF、HEIC／WEBP 轉 JPEG。
 * 單頁超過 5MB 時 attachment 為 null，warnings 會提醒，需使用者自行補憑證
 */
export interface OcrBatchPageAttachment {
  pageId: string
  attachment: Attachment | null
}

export interface OcrBatchConfirmResponse {
  receipts: OcrBatchReceipt[]
  pages: OcrBatchPageAttachment[]
  warnings: string[]
  quota: OcrQuotaSnapshot
}

export type OcrBatchErrorCode =
  | 'invalid_file_type'
  | 'too_many_files'
  | 'file_too_large'
  | 'too_many_pages'
  | 'quota_exhausted'
  | 'quota_insufficient'
  | 'ocr_unavailable'
  | 'ocr_no_result'
  | 'batch_expired'
  /** 同公司上一批還在辨識（409） */
  | 'batch_in_progress'
  /** confirm：page_ids 空白、有不存在的頁，或所選頁都沒有憑證 */
  | 'invalid_page_ids'

/**
 * POST /ocr/batch
 * 上傳後找出每頁有幾張憑證，還不辨識內容、不扣次。上限：5 個檔案、單檔 20MB、合計 5 頁（頁數由後端擋）。
 * 失敗時 throw HttpError，body 為 { code: OcrBatchErrorCode, message, quota?, required? }。
 */
export function batchRecognize(files: ReadonlyArray<File>, role: OcrRole): Promise<OcrBatchResponse> {
  const form = new FormData()
  for (const f of files) form.append('files[]', f)
  form.append('role', role)
  return service.post<OcrBatchResponse>('/ocr/batch', form)
}

/**
 * POST /ocr/batch/:token/confirm — 逐張辨識勾選的頁，辨識出內容的一張扣一次並帶出內容（最多約 90 秒）。
 * 503 ocr_unavailable 時不扣次、暫存保留，可用同一個 token 再確認。
 */
export function confirmBatch(token: string, pageIds: string[]): Promise<OcrBatchConfirmResponse> {
  return service.post<OcrBatchConfirmResponse>(`/ocr/batch/${encodeURIComponent(token)}/confirm`, { pageIds })
}

/** DELETE /ocr/batch/:token — 取消，不扣次 */
export function cancelBatch(token: string): Promise<void> {
  return service.delete<void>(`/ocr/batch/${encodeURIComponent(token)}`)
}
