/**
 * 資料匯出的送出與結果提示（PRD 第 24 條），列表匯出確認視窗與明細單筆匯出共用。
 * 沒有圖檔時當下下載 CSV；有圖檔時在背景產生，提示會寄信通知。
 * 另提供確認視窗用的篩選條件文字。
 */
import { ref } from 'vue'
import { useToast } from 'primevue/usetoast'
import { createDataExport, type CreateDataExportRequest } from '@/api/data-exports'
import { formatDate } from '@/utils/format'
import { userErrorToast } from '@/utils/userFeedback'

/** 匯出確認視窗要顯示的內容：送出的請求、筆數、會套用的篩選條件（「全部」才有） */
export interface DataExportConfirm {
  req: CreateDataExportRequest
  count: number
  filters?: string[]
}

/** 發生日期篩選文字：可只選起日；沒選回 null */
export function exportDateRangeText(range: (Date | null)[] | null | undefined): string | null {
  const [from, to] = range ?? []
  const hasFrom = from instanceof Date
  const hasTo = to instanceof Date
  if (hasFrom && hasTo) return `發生日期 ${formatDate(from)}–${formatDate(to)}`
  if (hasFrom) return `發生日期 ${formatDate(from)} 起`
  if (hasTo) return `發生日期 至 ${formatDate(to)}`
  return null
}

/** 類別篩選文字；名稱取不到時退回類數；沒選回 null */
export function exportCategoryText(ids: string[], categories: { id: string; name: string }[]): string | null {
  if (!ids.length) return null
  const names = ids.map((id) => categories.find((c) => c.id === id)?.name).filter(Boolean)
  return names.length === ids.length ? `類別：${names.join('、')}` : `類別 ${ids.length} 類`
}

export function useDataExport() {
  const toast = useToast()
  const exporting = ref(false)

  /** 成功回 true（已下載或已排入背景），失敗回 false 並顯示原因 */
  async function runExport(req: CreateDataExportRequest): Promise<boolean> {
    if (exporting.value) return false
    exporting.value = true
    try {
      const result = await createDataExport(req)
      if (result.downloaded) {
        toast.add({ severity: 'success', summary: '已下載匯出檔', life: 2500 })
      } else {
        toast.add({
          severity: 'info',
          summary: '匯出完成後會寄信通知',
          detail: '檔案在背景產生，完成後也可從站內通知前往下載。',
          life: 3000,
        })
      }
      return true
    } catch (err) {
      toast.add({ severity: 'error', ...userErrorToast(err, '匯出失敗'), life: 3500 })
      return false
    } finally {
      exporting.value = false
    }
  }

  return { exporting, runExport }
}
