/**
 * Category API — 費用類別 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §3.4、backend/app/controllers/api/categories_controller.rb。
 */

import type { Category, CategoryKind, PersonRef } from '@/types/domain'
import type { Paginated } from './expenses'
import { service } from './service'

export type { Category }

/**
 * POST /categories
 * 新增類別。kind 必填，建立後不可改。後端 MUST 檢查 (companyId, kind, name)
 * 於 case-insensitive 內唯一；重複時回 409 並回傳既有 Category 於 body。
 */
export interface CreateCategoryRequest {
  kind: CategoryKind
  name: string
  accountCode?: string
  sortOrder?: number
}

/**
 * PATCH /categories/:id
 * 更新類別欄位；所有欄位皆為 optional。後端 MUST 只覆寫 client 傳來的欄位。
 * MUST NOT 用此 endpoint 改 isArchived（走 /archive 與 /unarchive）、
 * MUST NOT 改 kind（建立後固定）。
 */
export interface UpdateCategoryRequest {
  name?: string
  accountCode?: string
  sortOrder?: number
}

/**
 * GET /categories?kind=&archived=&include_usage=
 * 類別列表查詢。
 * - kind 必填：'expense' 或 'income'
 * - 未帶 archived → 回傳該 kind 的未停用類別（新增下拉來源的預設）
 * - archived=true → 只回傳該 kind 已停用類別（CategoriesView「已停用」tab 使用）
 * - include_usage=true → 每筆附帶 usageCount 與可否刪除的資訊（CategoriesView 用；下拉不用）
 * 兩者都不含垃圾桶內的類別。
 */
export interface ListCategoriesQuery {
  kind: CategoryKind
  /** 預設 undefined（= 未停用）；true 時只回已停用類別 */
  archived?: boolean
  /** 預設 undefined（= 不含 usageCount）；true 時每筆附帶 usageCount */
  includeUsage?: boolean
}

/** 類別 + 使用情形（CategoriesView 使用）；未帶 includeUsage 時以下欄位皆為 undefined。 */
export interface CategoryWithUsage extends Category {
  usageCount?: number
  /** 各來源的引用筆數，含垃圾桶內的紀錄；key 會隨功能增加，一律逐 key 處理 */
  references?: Record<string, number>
  /** 不能刪除、停用時為 false，原因見 blockedReason */
  deletable?: boolean
  archivable?: boolean
  /** references 全為 0 時才是 true；垃圾桶內的類別才用得到 */
  purgeable?: boolean
  blockedReason?: string | null
}

export interface TrashedCategory extends CategoryWithUsage {
  deletedAt: string
  deletedBy: PersonRef | null
}

export function listCategories(
  query: ListCategoriesQuery,
): Promise<CategoryWithUsage[]> {
  return service.get<CategoryWithUsage[]>('/categories', { query })
}

export function createCategory(body: CreateCategoryRequest): Promise<Category> {
  return service.post<Category>('/categories', body)
}

export function updateCategory(
  id: string,
  body: UpdateCategoryRequest,
): Promise<Category> {
  return service.patch<Category>(`/categories/${id}`, body)
}

/**
 * PATCH /categories/reorder
 * body: { ids: ["uuid1", "uuid2", ...] }
 * ids 內所有類別必須同一 kind；回傳僅該 kind 的使用中類別。
 */
export function reorderCategories(ids: string[]): Promise<Category[]> {
  return service.patch<Category[]>('/categories/reorder', { ids })
}

export function archiveCategory(id: string): Promise<Category> {
  return service.patch<Category>(`/categories/${id}/archive`)
}

export function unarchiveCategory(id: string): Promise<Category> {
  return service.patch<Category>(`/categories/${id}/unarchive`)
}

/** 進垃圾桶。進行中範本使用時回 409 CATEGORY_IN_USE_BY_TEMPLATE。 */
export function deleteCategory(id: string): Promise<void> {
  return service.delete<void>(`/categories/${id}`)
}

export interface ListTrashedCategoriesQuery {
  kind: CategoryKind
  page?: number
  perPage?: number
}

/** GET /categories/trash 依刪除時間新到舊。 */
export function listTrashedCategories(query: ListTrashedCategoriesQuery): Promise<Paginated<TrashedCategory>> {
  return service.get<Paginated<TrashedCategory>>('/categories/trash', { query })
}

/** 還原後回到原本的狀態，原本停用的仍為停用。 */
export function restoreCategory(id: string): Promise<Category> {
  return service.patch<Category>(`/categories/${id}/restore`)
}

/** 永久刪除。有任何引用時回 409 CATEGORY_IN_USE。 */
export function purgeCategory(id: string): Promise<void> {
  return service.delete<void>(`/categories/${id}/purge`)
}
