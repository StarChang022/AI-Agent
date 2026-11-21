/**
 * RecurringTemplate API — 固定收支範本 endpoints，僅 admin。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §2.8、docs/dev/recurring-api.md。
 */

import type {
  AccountRef,
  CollectionStatus,
  DocumentType,
  PayoutStatus,
  RecurringDirection,
  RecurringFrequency,
  RecurringStatus,
  RecurringTemplate,
  TaxRate,
} from '@/types/domain'
import type { Paginated, PaginationMeta } from './expenses'
import { service } from './service'

export type { RecurringTemplate }

/** 全部分頁的數量，不受查詢的 direction、tab 影響 */
export type RecurringCounts = Record<RecurringDirection, Record<RecurringStatus, number>>

export interface ListRecurringTemplatesQuery {
  direction: RecurringDirection
  /** 預設 active */
  tab?: RecurringStatus
  page?: number
  perPage?: number
}

export interface RecurringTemplatePage {
  data: RecurringTemplate[]
  meta: PaginationMeta & { counts: RecurringCounts }
}

/** 進行中、歷史依建立時間新到舊，垃圾桶依刪除時間新到舊。 */
export function listRecurringTemplates(query: ListRecurringTemplatesQuery): Promise<RecurringTemplatePage> {
  return service.get<RecurringTemplatePage>('/recurring-templates', { query })
}

/** 垃圾桶內的也查得到。 */
export function getRecurringTemplate(id: string): Promise<RecurringTemplate> {
  return service.get<RecurringTemplate>(`/recurring-templates/${id}`)
}

export interface RecurringSchedule {
  frequency: RecurringFrequency
  dayOfMonth: number
  /** 每年週期才帶 */
  monthOfYear: number | null
  /** YYYY-MM */
  startMonth: string
  /** YYYY-MM；null 表示持續產生 */
  endMonth: string | null
}

export interface RecurringPreview {
  /** 送出後立即補產生的筆數 */
  backfillCount: number
  backfillPeriods: string[]
  /** false 表示開始到結束月份之間一期都沒有，原因見 message */
  hasPeriods: boolean
  nextPeriod: string | null
  nextDate: string | null
  message: string | null
}

export interface RecurringPreviewRequest extends RecurringSchedule {
  /** 編輯時帶，算出這次儲存實際會產生的筆數 */
  templateId?: string
  /** 編輯時帶表單當下的值；歷史範本延長時，類別擋不擋看這個值 */
  categoryId?: string
}

/** POST /recurring-templates/preview 只查詢，不寫入。編輯時沒改到週期相關欄位不需要打。 */
export function previewRecurringTemplate(body: RecurringPreviewRequest): Promise<RecurringPreview> {
  return service.post<RecurringPreview>('/recurring-templates/preview', body)
}

export interface CreateRecurringTemplateRequest extends RecurringSchedule {
  direction: RecurringDirection
  name: string
  categoryId: string
  accountId: string
  documentType: DocumentType
  taxRate: TaxRate
  counterparty: string
  taxId: string | null
  amount: number
}

/** direction 建立後不可改；只帶要改的欄位。 */
export type UpdateRecurringTemplateRequest = Partial<Omit<CreateRecurringTemplateRequest, 'direction'>>

/** 建立、編輯、還原時當場產生了紀錄，會多回 backfilledCount */
export type SavedRecurringTemplate = RecurringTemplate & { backfilledCount?: number }

export function createRecurringTemplate(body: CreateRecurringTemplateRequest): Promise<SavedRecurringTemplate> {
  return service.post<SavedRecurringTemplate>('/recurring-templates', body)
}

export function updateRecurringTemplate(
  id: string,
  body: UpdateRecurringTemplateRequest,
): Promise<SavedRecurringTemplate> {
  return service.patch<SavedRecurringTemplate>(`/recurring-templates/${id}`, body)
}

/** 進垃圾桶，任何時候都可以；已產生的紀錄不受影響。 */
export function deleteRecurringTemplate(id: string): Promise<void> {
  return service.delete<void>(`/recurring-templates/${id}`)
}

/** 類別在垃圾桶時回 409 CATEGORY_IN_TRASH。 */
export function restoreRecurringTemplate(id: string): Promise<SavedRecurringTemplate> {
  return service.patch<SavedRecurringTemplate>(`/recurring-templates/${id}/restore`)
}

/** 永久刪除；已產生的紀錄保留，只是不再連回範本。 */
export function purgeRecurringTemplate(id: string): Promise<void> {
  return service.delete<void>(`/recurring-templates/${id}/purge`)
}

/** 範本產生的一筆紀錄 */
export interface RecurringRecord {
  id: string
  kind: RecurringDirection
  /** YYYY-MM */
  recurringPeriod: string
  date: string
  amount: number
  status: PayoutStatus | CollectionStatus
  /** 實付或實收日期；待付款、待收款時可能有舊值，畫面要隱藏 */
  settledAt: string | null
  invoiceNo: string | null
  account: AccountRef
}

export interface ListRecurringRecordsQuery {
  page?: number
  perPage?: number
}

/** 依期數新到舊，不含垃圾桶內的紀錄。 */
export function listRecurringRecords(id: string, query?: ListRecurringRecordsQuery): Promise<Paginated<RecurringRecord>> {
  return service.get<Paginated<RecurringRecord>>(`/recurring-templates/${id}/records`, { query })
}
