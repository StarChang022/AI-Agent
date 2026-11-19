import type {
  CollectionStatus,
  DocumentType,
  ExpenseItem,
  IncomeItem,
  PayoutStatus,
  TaxRate,
} from './domain'

/**
 * 表單裡的一張憑證圖檔（useAttachmentUploads 管理）。
 * 選檔後立即上傳成暫存檔：上傳中 id、url 為 null，圖片先用本機預覽；完成後補上 id 與 url。
 * 編輯時從紀錄載入的為已儲存（saved），儲存時只帶新的暫存檔 id（代墊款例外，帶完整清單）。
 */
export interface FormAttachment {
  /** v-for 用的前端 key */
  key: string
  /** 圖檔 id；上傳中為 null */
  id: string | null
  filename: string
  mimeType: string
  /** 讀取網址（後端簽章網址）；上傳中為 null */
  url: string | null
  /** 這次上傳的圖片的本機預覽；上傳完成後仍沿用（不必再下載），元件卸載時釋放 */
  localUrl: string | null
  /** 已存在紀錄上；false 為這次上傳、尚未儲存的暫存檔 */
  saved: boolean
  uploading: boolean
}

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
  /** 發生日期 */
  incurredAt: Date | null
  /** 發票日期；收據為 null */
  invoiceDate: Date | null
  /** 應付日期；null = 載入這筆時帶預設值 */
  plannedDate: Date | null
  /** 發生日期不再從發票日期自動帶入（見 useRecordDates） */
  occurredLocked: boolean
  /** 最後一次填好的發票日期（清空後仍保留，改發票日期時比對用）；省略時用 invoiceDate */
  lastInvoiceDate?: Date | null
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
  /** 已付款時的實付日期；待付款時忽略 */
  paidAt?: Date | null
  note: string
  /**
   * 這一筆自己的憑證。批次匯入憑證時每筆只帶自己那一頁（切不出來時為空，請使用者自行補）；
   * 換頁時表單的憑證區跟著換，建立時只送這一筆的憑證。
   */
  attachments: FormAttachment[]
}

/**
 * 新增收入表單的一筆「進行中草稿」；用途與 FormPageData 相同，
 * 經 `stagedIncomePages` 帶進 IncomeFormView。
 */
export interface IncomeFormPageData {
  documentType: DocumentType
  /** 發生日期 */
  incomeDate: Date | null
  /** 發票日期；收據為 null */
  invoiceDate: Date | null
  /** 應收日期；null = 載入這筆時帶預設值 */
  plannedDate: Date | null
  /** 規則同 FormPageData.occurredLocked */
  occurredLocked: boolean
  /** 規則同 FormPageData.lastInvoiceDate */
  lastInvoiceDate?: Date | null
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
  /** 已收款時的實收日期；待收款時忽略 */
  collectedAt: Date | null
  note: string
  /** 這一筆自己的憑證，規則同 FormPageData.attachments */
  attachments: FormAttachment[]
}
