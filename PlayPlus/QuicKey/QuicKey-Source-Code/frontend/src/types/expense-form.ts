import type {
  CollectionStatus,
  DocumentType,
  ExpenseAttachment,
  ExpenseItem,
  IncomeAttachment,
  IncomeItem,
  PayoutStatus,
  TaxRate,
} from './domain'

/**
 * 新增支出表單的一筆「進行中草稿」資料形狀。
 *
 * `ExpenseFormView.vue` 內部維護 `pages: FormPageData[]` 陣列以支援批次匯入
 * 帶入多筆一次建立；批次匯入憑證（BatchReceiptImportDialog，docs/資料模型.md §5.5）確認後以
 * 此型別經 `stagedExpensePages` stage，之後由 ExpenseFormView
 * `onMounted` 呼叫 `take()` 取用。Excel 匯入整批建立，不經此處。
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
  /** OCR 不含帳戶：批次匯入進來時為 null，由使用者在核對時選擇 */
  accountId: string | null
  payoutStatus: PayoutStatus | null
  /** 已付款時的付款日；待付款時忽略 */
  paidAt?: Date | null
  note: string
  /**
   * 這一筆自己的憑證。批次匯入憑證時每筆只帶自己那一頁（切不出來時為空，請使用者自行補）；
   * 換頁時表單的憑證區跟著換，建立時只送這一筆的憑證。
   */
  attachments: ExpenseAttachment[]
}

/**
 * 新增收入表單的一筆「進行中草稿」；用途與 FormPageData 相同，
 * 經 `stagedIncomePages` 帶進 IncomeFormView。
 */
export interface IncomeFormPageData {
  documentType: DocumentType
  incomeDate: Date | null
  taxId: string
  customer: string
  invoiceNo: string
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  amount: number | null
  items: IncomeItem[]
  categoryId: string | null
  /** 規則同 FormPageData.accountId */
  accountId: string | null
  collectionStatus: CollectionStatus
  /** 已收款時的收款日；待收款時忽略 */
  collectedAt: Date | null
  note: string
  /** 這一筆自己的憑證，規則同 FormPageData.attachments */
  attachments: IncomeAttachment[]
}
