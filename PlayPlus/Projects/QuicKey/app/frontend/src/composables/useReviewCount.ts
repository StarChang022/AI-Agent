/**
 * 後台側邊欄「簽核」badge 的待簽核筆數（單例，所有呼叫者共用同一份 count）。
 *
 * AdminLayout 在掛載與換頁時 refresh；核准/駁回/作廢等會改變 in_review 筆數的動作
 * 完成後也呼叫 refresh（見 useReimbursementActions），badge 才不會停在舊值。
 * 這個數字與通知未讀數獨立（admin 可能標已讀但沒處理），兩個不互通。
 */
import { readonly, ref } from 'vue'
import { listAdminReimbursements } from '@/api/reimbursements'

const count = ref(0)

// perPage=1 讓後端只回 1 筆資料 + meta.total；用 meta.total 當 badge 數字
async function refresh() {
  try {
    const res = await listAdminReimbursements({ status: 'in_review', perPage: 1 })
    count.value = res.meta.total
  } catch {
    /* 失敗保留舊值，不打擾使用者 */
  }
}

export function useReviewCount() {
  return { count: readonly(count), refresh }
}
