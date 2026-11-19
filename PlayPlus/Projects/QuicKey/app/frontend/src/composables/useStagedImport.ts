import type { FormPageData, IncomeFormPageData } from '@/types/expense-form'

/**
 * 批次匯入 → 新增支出／收入頁的一次性資料中繼站。
 *
 * 批次匯入憑證（BatchReceiptImportDialog，docs/資料模型.md §5.5）確認扣次後呼叫 `stage(pages)`
 * 把 N 筆 stage 起來；新增頁 `onMounted` 時呼叫 `take()` 取回並清空。Excel 匯入走整批建立，不經此處。
 *
 * 模組級變數（Vue 應用生命週期內共用），不寫入 localStorage —
 * 重整頁面 = 放棄匯入，使用者需重新走一次 Dialog。
 */
function stagedPages<T>() {
  let staged: T[] | null = null
  return {
    stage(pages: T[]): void {
      staged = pages.length > 0 ? pages : null
    },
    take(): T[] | null {
      const v = staged
      staged = null
      return v
    },
  }
}

export const stagedExpensePages = stagedPages<FormPageData>()
export const stagedIncomePages = stagedPages<IncomeFormPageData>()
