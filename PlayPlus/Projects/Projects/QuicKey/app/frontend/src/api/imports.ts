/**
 * Excel 匯入 API — 支出／收入共用（兩者路徑不同、形狀相同）。
 *
 * 對應 docs/資料模型.md §5.4。流程：
 * 1. GET  /{expenses|incomes}/import/template   下載標準範本
 * 2. POST /{expenses|incomes}/import/preview    只解析，不寫入
 * 3. POST /{expenses|incomes}/import            後端重新解析同一檔案後整批寫入（同一交易）
 *
 * preview／import 皆為 multipart：FormData 不經 snake_case 轉換，key 直接寫 snake；
 * response 由 service.ts 轉 camelCase。
 * 錯誤：{ error: CODE, message: 可直接顯示的中文 }；需重新預覽的代碼見 IMPORT_REPREVIEW_CODES。
 */

import type { CollectionStatus, DocumentType, PayoutStatus } from '@/types/domain'
import { service } from './service'

export type ImportKind = 'expense' | 'income'

/** 預覽每筆的狀態：可匯入／補預設值或需留意（照匯入）／不匯入 */
export type ImportRecordStatus = 'ok' | 'warning' | 'skipped'

export interface ImportMessage {
  /** Excel 實際列號（標題列 = 1） */
  row: number
  text: string
}

/** 一筆單據（同單據編號的多列合併為一筆） */
export interface ImportPreviewRecord {
  /** 構成此筆的 Excel 列號；第一個是主檔列 */
  rows: number[]
  status: ImportRecordStatus
  summary: {
    date: string | null
    /** 支出 = 廠商、收入 = 客戶 */
    party: string | null
    /** Excel 上填的類別名稱；空白為 null */
    categoryName: string | null
    /** 這筆實際會用的帳戶名稱；不匯入時為 null */
    accountName: string | null
    /** true = 不計入現金流；帳戶還要使用者對應、或這筆不匯入時為 null */
    outsideCashFlow: boolean | null
    amount: number | null
    itemCount: number
    documentType: DocumentType
    status: PayoutStatus | CollectionStatus
  }
  /** skipped 時為不匯入原因；warning 時為說明 */
  messages: ImportMessage[]
}

/**
 * 需要使用者對應的類別（每個名稱一項）。可選動作：
 * - missing：既有類別 id 或 'create'（預設）
 * - archived（與停用類別同名）：既有類別 id 或 'reactivate'（預設），不可新增
 * - blank（類別空白的列，name 為 ''）：只能選既有類別 id，無預設
 * - discarded（與垃圾桶內的類別同名）：只能選既有類別 id，無預設
 * - creatable = false 的 missing（名稱超過 50 字）：只能選既有類別 id，無預設
 */
export interface ImportCategoryIssue {
  name: string
  rows: number[]
  state: 'missing' | 'archived' | 'blank' | 'discarded'
  /** 可否「新增此類別」；blank、archived、discarded 一律 false */
  creatable: boolean
}

/** 檔內填了但找不到（missing）或在垃圾桶（discarded）的帳戶，每個名稱一項，只能對應既有帳戶、沒有預設 */
export interface ImportAccountIssue {
  name: string
  /** 用到這個名稱的單據第一列 Excel 列號（和 excludedRows 同一種列號） */
  rows: number[]
  state: 'missing' | 'discarded'
}

export interface ImportPreviewResponse {
  /** 資料列數（不含標題列） */
  totalRows: number
  /** importable 已含 warning（= 會建立的筆數） */
  counts: { importable: number; warning: number; skipped: number }
  records: ImportPreviewRecord[]
  categories: ImportCategoryIssue[]
  accounts: ImportAccountIssue[]
}

/** 類別名稱 → 'create'／'reactivate'／既有類別 id；沒帶的名稱走預設 */
export type CategoryMapping = Record<string, string>

/** 檔內帳戶名稱 → 既有帳戶 id */
export type AccountMapping = Record<string, string>

export interface ImportRowNote {
  rows: number[]
  messages: ImportMessage[]
}

export interface ImportResult {
  /** 不含使用者移除的筆數 */
  createdCount: number
  /** 實際移除的筆數（完成畫面「使用者移除 N 筆」） */
  excludedCount: number
  /** 實收／實付日期早於帳戶起始月份、不計入現金流的筆數，含使用者對應帳戶的列 */
  outsideCashFlowCount: number
  createdCategories: { id: string; name: string }[]
  reactivatedCategories: { id: string; name: string }[]
  /** 未匯入的列 + 原因 */
  skipped: ImportRowNote[]
  /** 補了預設值或需要留意的列 + 說明 */
  warnings: ImportRowNote[]
}

const BASE: Record<ImportKind, string> = {
  expense: '/expenses/import',
  income: '/incomes/import',
}

const TEMPLATE_FILENAME: Record<ImportKind, string> = {
  expense: '支出匯入範本.xlsx',
  income: '收入匯入範本.xlsx',
}

export function downloadImportTemplate(kind: ImportKind): Promise<void> {
  return service.downloadFile(`${BASE[kind]}/template`, { filename: TEMPLATE_FILENAME[kind] })
}

export function previewImport(kind: ImportKind, file: File): Promise<ImportPreviewResponse> {
  const body = new FormData()
  body.append('file', file)
  return service.post<ImportPreviewResponse>(`${BASE[kind]}/preview`, body)
}

/**
 * @param excludedRows 預覽時使用者移除的單據（records[].rows[0]）；這些單據不建立，
 *   只被它們用到的類別名稱也不新增、不要求對應
 */
export function runImport(
  kind: ImportKind,
  file: File,
  categoryMapping: CategoryMapping,
  accountMapping: AccountMapping,
  excludedRows: number[] = [],
): Promise<ImportResult> {
  const body = new FormData()
  body.append('file', file)
  // key 是使用者填的類別名稱，不可做 snake_case 轉換
  body.append('category_mapping', JSON.stringify(categoryMapping))
  body.append('account_mapping', JSON.stringify(accountMapping))
  if (excludedRows.length) body.append('excluded_rows', JSON.stringify(excludedRows))
  return service.post<ImportResult>(BASE[kind], body)
}

/**
 * 匯入時回這些代碼表示預覽已過期（後端整次不匯入），需重新預覽：
 * - CATEGORY_CHANGED：對應到的類別已被停用或刪除
 * - INVALID_EXCLUDED_ROWS：移除的列號和檔案內容對不上
 * - ACCOUNT_CHANGED：對應到的帳戶已刪除
 * - INVALID_ACCOUNT_MAPPING：畫面已擋下未選的名稱，後端仍回這個代表預覽後檔內帳戶被刪除，
 *   多出需要對應的名稱，要重新預覽才選得到
 */
export const IMPORT_REPREVIEW_CODES = [
  'CATEGORY_CHANGED',
  'INVALID_EXCLUDED_ROWS',
  'ACCOUNT_CHANGED',
  'INVALID_ACCOUNT_MAPPING',
] as const
