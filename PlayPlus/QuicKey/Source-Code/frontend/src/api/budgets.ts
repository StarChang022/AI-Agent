/**
 * Budget / BudgetTemplate API — 類別預算 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §3.5、backend/app/controllers/api/budgets_controller.rb
 * 與 backend/app/controllers/api/budget_templates_controller.rb。
 */

import type { Budget, BudgetTemplate, BudgetCycle } from '@/types/domain'
import { service } from './service'

export type { Budget, BudgetTemplate }

// ═══════════════════════════════════════════════════════
// Budget（單期預算記錄）
// ═══════════════════════════════════════════════════════

/**
 * POST /budgets
 * 建立單筆預算。後端 MUST：
 * - 驗證 amount > 0（= 0 → 400 提示改走 DELETE；< 0 → 422）
 * - 驗證 (categoryId, cycle, periodStart) 於同一 companyId 內唯一（重複回 409）
 * - 驗證 periodStart / periodEnd 符合 cycle 定義（month 為該月 1 號 ~ 最後一天；
 *   year 為 YYYY-01-01 ~ YYYY-12-31）；否則 422
 */
export interface CreateBudgetRequest {
  categoryId: string
  cycle: BudgetCycle
  amount: number
  periodStart: string
  periodEnd: string
}

/**
 * PATCH /budgets/:id
 * 更新預算金額；MVP 僅允許改 amount。改期間 / 類別走 delete + create 流程。
 */
export interface UpdateBudgetRequest {
  amount: number
}

/**
 * GET /budgets
 * 預算列表查詢；所有 filter 皆為 optional。
 */
export interface ListBudgetsQuery {
  categoryId?: string
  cycle?: BudgetCycle
  /** YYYY-MM-DD */
  periodStart?: string
}

export function listBudgets(query?: ListBudgetsQuery): Promise<Budget[]> {
  return service.get<Budget[]>('/budgets', { query })
}

/**
 * GET /budgets/utilization?period_start=&period_end=
 * 回所有使用中支出類別的實際支出加總（含 actual=0）；
 * 聚合由後端做，避免前端為了算執行率把當期所有 expenses 全撈下來。
 *
 * 回傳 [{ categoryId, categoryName, actual }, ...]（照類別 sort_order）
 *
 * 注意：歸屬到已停用類別的 expenses 不含在這份回應裡——本端點只代表「使用中類別」
 * 的當期支出。若 Dashboard 等需要公司當期總支出，請另外開獨立 endpoint。
 */
export interface BudgetUtilizationQuery {
  periodStart: string
  periodEnd: string
}

export interface BudgetUtilizationRow {
  categoryId: string
  categoryName: string
  actual: number
}

export function getBudgetUtilization(
  query: BudgetUtilizationQuery,
): Promise<BudgetUtilizationRow[]> {
  return service.get<BudgetUtilizationRow[]>('/budgets/utilization', { query })
}

export function createBudget(body: CreateBudgetRequest): Promise<Budget> {
  return service.post<Budget>('/budgets', body)
}

export function updateBudget(
  id: string,
  body: UpdateBudgetRequest,
): Promise<Budget> {
  return service.patch<Budget>(`/budgets/${id}`, body)
}

export function deleteBudget(id: string): Promise<void> {
  return service.delete<void>(`/budgets/${id}`)
}

// ═══════════════════════════════════════════════════════
// BudgetTemplate（基本預算範本）
// ═══════════════════════════════════════════════════════

/**
 * PUT /budget-templates
 * 單一 endpoint 處理建立與更新（因 (categoryId, cycle) 為唯一鍵）。後端 MUST：
 * - 驗證 amount ≥ 0（= 0 → 刪除既有 template；< 0 → 422）
 * - 驗證 cycle ∈ { 'month', 'year' }
 */
export interface UpsertBudgetTemplateRequest {
  categoryId: string
  cycle: BudgetCycle
  amount: number
}

/**
 * GET /budget-templates
 * 範本列表查詢；cycle filter 為 optional。
 */
export interface ListBudgetTemplatesQuery {
  cycle?: BudgetCycle
}

/**
 * POST /budget-templates/apply
 * 套用該 cycle 所有 amount > 0 的 template 到指定期間，覆寫該期間類別既有 Budget。
 * amount = 0 或無 template 的類別跳過。
 */
export interface ApplyBudgetTemplatesRequest {
  cycle: BudgetCycle
  periodStart: string
  periodEnd: string
}

export interface ApplyBudgetTemplatesResponse {
  /** 實際被 upsert 的筆數 */
  appliedCount: number
  /** amount = 0 或無 template 而被跳過的類別數（供 UI 提示） */
  skippedCount: number
}

export function listBudgetTemplates(
  query?: ListBudgetTemplatesQuery,
): Promise<BudgetTemplate[]> {
  return service.get<BudgetTemplate[]>('/budget-templates', { query })
}

/**
 * upsert：amount = 0 時後端刪除既有並回空 body（此處回 null）。
 */
export function upsertBudgetTemplate(
  body: UpsertBudgetTemplateRequest,
): Promise<BudgetTemplate | null> {
  return service.put<BudgetTemplate | null>('/budget-templates', body)
}

export function deleteBudgetTemplate(id: string): Promise<void> {
  return service.delete<void>(`/budget-templates/${id}`)
}

export function applyBudgetTemplates(
  body: ApplyBudgetTemplatesRequest,
): Promise<ApplyBudgetTemplatesResponse> {
  return service.post<ApplyBudgetTemplatesResponse>('/budget-templates/apply', body)
}
