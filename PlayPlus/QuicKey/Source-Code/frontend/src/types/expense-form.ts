import type {
  DocumentType,
  ExpenseItem,
  PayoutStatus,
  TaxRate,
} from './domain'

/**
 * 新增支出表單的一筆「進行中草稿」資料形狀。
 *
 * `ExpenseFormView.vue` 內部維護 `pages: FormPageData[]` 陣列以支援批次匯入
 * 帶入多筆一次建立；批次匯入 Dialog（BatchImportDialog）產生假資料時也以
 * 此型別 stage 到 expense store 的 `stagedImports`，之後由 ExpenseFormView
 * `onMounted` 呼叫 `takeImportedPages()` 取用。
 *
 * 與後端 `Expense`（api/expenses.ts）差異：日期為 `Date | null` 而非 ISO 字串；
 * categoryId / payoutStatus 為 nullable 允許使用者未選；金額為 number | null
 * 對應 PrimeVue InputNumber 清空狀態。
 */
export interface FormPageData {
  documentType: DocumentType
  incurredAt: Date | null
  taxId: string
  vendor: string
  invoiceNo: string
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  amount: number | null
  items: ExpenseItem[]
  categoryId: string | null
  payoutStatus: PayoutStatus | null
  /** 已付款時的付款日；待付款時忽略 */
  paidAt?: Date | null
  note: string
}
