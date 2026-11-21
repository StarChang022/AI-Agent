/**
 * Payout schedule API — 公司付款日設定 endpoints。
 *
 * 命名慣例：型別為 camelCase；wire format 為 snake_case，
 * 由 `api/service.ts` 於 request/response 邊界自動雙向轉換。
 * 對應 docs/資料模型.md §3.1、backend/app/controllers/api/payout_schedule_controller.rb。
 */

import type { PayoutDay } from '@/utils/payoutSchedule'
import { service } from './service'

export interface PayoutScheduleResponse {
  /** 每月付款日 1–31，31 等同月底；null 代表關閉自動付款批次 */
  day: PayoutDay | null
}

/** GET /payout-schedule */
export function getPayoutSchedule(): Promise<PayoutScheduleResponse> {
  return service.get<PayoutScheduleResponse>('/payout-schedule')
}

/**
 * PATCH /payout-schedule — day: 1–31 或 null（關閉自動付款批次）。
 * 不會動到任何已登錄支出；新規則只套用到之後新登錄 / 核准的支出。
 */
export function updatePayoutSchedule(day: PayoutDay | null): Promise<PayoutScheduleResponse> {
  return service.patch<PayoutScheduleResponse>('/payout-schedule', { day })
}
