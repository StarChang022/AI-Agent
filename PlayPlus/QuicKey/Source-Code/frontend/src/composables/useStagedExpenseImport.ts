import { ref } from 'vue'
import type { FormPageData } from '@/types/expense-form'

/**
 * 批次匯入 → 新增支出頁的一次性資料中繼站。
 *
 * BatchImportDialog 於「開始辨識」完成時呼叫 `stageImportedPages(pages)`
 * 把 N 筆假預覽 stage 起來；ExpenseFormView `onMounted` 時呼叫
 * `takeImportedPages()` 取回並清空。
 *
 * 模組級 ref（Vue 應用生命週期內共用），不寫入 localStorage —
 * 重整頁面 = 放棄匯入，使用者需重新走一次 Dialog。
 */
const stagedImports = ref<FormPageData[] | null>(null)

export function stageImportedPages(pages: FormPageData[]): void {
  stagedImports.value = pages.length > 0 ? pages : null
}

export function takeImportedPages(): FormPageData[] | null {
  const v = stagedImports.value
  stagedImports.value = null
  return v
}
