/**
 * 職級：一家公司 1 名 admin + 最多 10 名 employee。
 */
export type Role = 'employee' | 'admin'

/**
 * 請款記錄的主狀態（6 種）
 */
export type ReimbursementStatus =
  | 'draft' // 草稿
  | 'in_review' // 簽核中
  | 'rejected' // 駁回
  | 'approved' // 已核銷
  | 'paid' // 已發放
  | 'voided' // 已作廢

/**
 * 類別種類：支出或收入；建立後不可切換。
 * - expense：供支出 / 代墊款選擇；預算只綁 expense。
 * - income：供收入選擇。
 */
export type CategoryKind = 'expense' | 'income'

/**
 * 類別（Category）— 見 docs/資料模型.md §3.4。
 *
 * 由後端 API 管理。清單只在真的需要「全部類別」的頁面（類別管理頁、
 * 新增支出/收入/代墊款表單的下拉）才呼叫 /api/categories 取得；一般列表
 * 顯示類別名改由 Expense/Reimbursement/Income 的 `category` 欄位（CategoryRef）直接帶。
 *
 * 新公司建立時 CategorySeeder 塞 13 筆 expense + 4 筆 income 起始資料；
 * 建立後都可改名、停用、刪除（進垃圾桶，PRD 規則 18）；系統保留類別只能改名（PRD 規則 19）。
 */
export interface Category {
  id: string
  kind: CategoryKind
  name: string
  /** 會計科目代碼（可空字串；MVP 允許 admin 不填） */
  accountCode: string
  isArchived: boolean
  sortOrder: number
  /** 軟刪除時間（ISO 8601）；下拉取到的恆為 null */
  deletedAt?: string | null
  /** 系統保留類別的代碼（手續費類別為 transfer_fee），其他為 null */
  systemKey?: string | null
  createdAt: string
  updatedAt: string
}

/**
 * 類別引用（CategoryRef）—— 用於 Expense / Reimbursement / Income 的 `category` 欄位。
 * 後端 serializer 把 category 展開成 {id, name, accountCode}，前端顯示直接讀 .name、
 * 分組對比讀 .id。對齊 PersonRef 的設計。送 payload 時仍傳 categoryId（string）。
 */
export interface CategoryRef {
  id: string
  name: string
  accountCode: string
}

/**
 * 一般支出憑證類型。
 * - invoice：統一發票；發票號碼必填、格式 2 英文碼 + 8 數字碼
 * - receipt：收據 / 手開單據；發票號碼選填、不驗格式
 * 對應 openspec/changes/add-general-expense-module/design.md Decision 13
 */
export type DocumentType = 'invoice' | 'receipt'

/**
 * 一般支出稅率選項。
 * - business_5：營業稅 5%
 * - exempt_0：免稅或收據 0%
 * 對應 openspec/changes/add-general-expense-module/design.md Decision 10
 */
export type TaxRate = 'business_5' | 'exempt_0'

/**
 * 一般支出品項（見 docs/資料模型.md §2.3）。
 * subtotal 由 quantity × unitPrice 計算；MVP 手動維護、後端不驗證加總。
 */
export interface ExpenseItem {
  name: string
  quantity: number
  unitPrice: number
  subtotal: number
}

/**
 * 帳號狀態。
 * MVP 實際只用 `'active'`：
 * - 已加入的員工 / admin 都是 active
 * - `'invited'` 依 `docs/資料模型.md` §3.2 欄位存在，但 users store 內不會出現此值
 *   （未接受的邀請放在 Invitation 記錄，不佔用 User 位置；見 add-employee-invitation-module design Decision 1、9）
 * - `'suspended'` / `'left'` 保留欄位，MVP UI 不觸發
 */
export type UserStatus = 'active' | 'invited' | 'suspended' | 'left'

export interface User {
  id: string
  name: string
  email: string
  /** mock users store 保有密碼可供 PasswordChangeDialog 驗證舊密碼；API 登入的 currentUser 無此欄位 */
  password?: string
  role: Role
  status: UserStatus
  /**
   * 加入時間（成為 active user 的時間點）。ISO 8601。
   * - Admin：公司註冊時；seed data 為手填初始值
   * - Employee：受邀者接受邀請、由 invitations.accept → users.create 建立時
   * 用於「人員管理」表格依加入時間排序（舊 → 新）。
   * 若 API response 未帶（例如登入 endpoint），由呼叫端補 '' 空字串。
   */
  createdAt: string
  /**
   * 新手導覽完成時間（ISO 8601）；null = 未完成。
   * 新註冊 admin / 新加入員工預設 null → 首次進 Dashboard / Home 觸發自動導覽。
   * 「重跑導覽」入口把這欄清回 null。
   */
  onboardingCompletedAt: string | null
}

/**
 * 員工邀請記錄。對應 `docs/資料模型.md` §3.3、
 * backend/app/controllers/api/invitations_controller.rb#serialize_invitation。
 *
 * token 不在這型別：後端 DB 只存 digest，raw_token 僅於建立當下由 `createInvitation`
 * response 一次性回；之後要重新取需另發 resend endpoint（尚未加）。
 * 撤回採軟刪（設 `revokedAt`），保留記錄以供 Accept 頁能區分「連結無效」與「邀請已撤回」錯誤。
 * 有效邀請：`acceptedAt == null && revokedAt == null && expiresAt > now`。
 */
export interface Invitation {
  id: string
  /** 被邀請人 email；trim + lowercase 後儲存 */
  email: string
  /** 邀請時 admin 填的姓名；Accept 頁唯讀顯示、不可被邀請人修改 */
  name: string
  /** 後端衍生欄位：'valid' | 'accepted' | 'revoked' | 'expired' */
  status: 'valid' | 'accepted' | 'revoked' | 'expired'
  /** ISO 8601；固定 now + 3 天（重新寄送時重算） */
  expiresAt: string
  /** ISO 8601；最後一次寄出邀請信的時間（建立或重新寄送） */
  lastSentAt: string
  /** ISO 8601；未接受為 null */
  acceptedAt: string | null
  /** ISO 8601；未撤回為 null；軟刪除語意 */
  revokedAt: string | null
  /** 誰發的邀請；可能為 null */
  invitedByUserId: string | null
  /** ISO 8601 */
  createdAt: string
}

/**
 * 人員指標（API 回傳 shape）。
 * 後端 serializer 把 FK 展開成 {id, name}；前端顯示直接讀 .name、邏輯比對讀 .id。
 */
export interface PersonRef {
  id: string
  name: string
}

/**
 * 簽核進度中的單一步驟
 */
export interface ApprovalStep {
  order: number
  stageName: string
  candidates: string[] // 有權簽核的 user id
  status: 'pending' | 'approved' | 'rejected'
  reviewedBy: PersonRef | null
  comment: string | null
  reviewedAt: string | null
}

export interface ApprovalProgress {
  currentStep: number
  steps: ApprovalStep[]
}

/** 收支上的帳戶引用；後端 serializer 展開 {id, name}。 */
export interface AccountRef {
  id: string
  name: string
}

/**
 * 公司的收付帳戶（docs/資料模型.md §2.9、docs/dev/accounts-api.md）。
 * 列表與單筆形狀相同。
 */
export interface Account {
  id: string
  name: string
  currency: string
  /** 起始金額，視為 openingMonth 月初的餘額 */
  openingAmount: number
  /** 起始月份，該月第一天（YYYY-MM-DD）；這個月之前不顯示該帳戶 */
  openingMonth: string
  /**
   * 各來源的引用筆數，含垃圾桶內的紀錄。
   * key 會隨功能增加（例如資金移轉），一律逐 key 處理，不要寫死。
   */
  references: Record<string, number>
  /** references 全為 0 時才是 true */
  deletable: boolean
  /** 軟刪除時間（ISO 8601）；null 表示未在垃圾桶 */
  deletedAt: string | null
  deletedBy: PersonRef | null
  createdAt: string
  updatedAt: string
}

/**
 * 代墊款的「對應支出」精簡摘要（Reimbursement.linkedExpense）。
 * 用於顯示付款狀態 chip、組「前往支出」連結、以及預計發放日判斷。
 */
export interface LinkedExpense {
  id: string
  payoutStatus: PayoutStatus
  plannedPayoutDate: string | null
  /** 只有管理員的回應才有；員工看不到帳戶 */
  account?: AccountRef
}

export interface Reimbursement {
  id: string
  employee: PersonRef
  /** 草稿可先不填，為 null；送出後一定有值 */
  amount: number | null
  /** 類別引用；後端 serializer 展開，前端顯示用 .name、分組用 .id。草稿可先不填，為 null */
  category: CategoryRef | null
  description: string
  /** 發生日期（核准時成為支出的發生日期），YYYY-MM-DD；草稿可先不填，為 null */
  incurredAt: string | null
  /** 發票日期；文件類型為發票時必填，收據為 null（核准時成為支出的發票日期） */
  invoiceDate: string | null
  /** 憑證；後台列表、my-summary 不帶（員工「我的請款」列表與單筆有） */
  attachments: Attachment[]
  /**
   * 員工在請款表單填入的支出欄位，核准時由後端 approve endpoint 連動寫入
   * 對應 Expense
   */
  documentType: DocumentType
  vendor: string | null
  taxId: string | null
  invoiceNo: string | null
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  /** 品項明細（選填，同支出品項）；只有單筆回應帶，列表不帶。核准時複製成支出的品項 */
  items: ExpenseItem[]
  status: ReimbursementStatus
  approvalProgress: ApprovalProgress | null
  /**
   * 對應支出的 Expense.id。簽核通過時會自動建立對應支出並回填；null 只會出現在尚未核准的請款。
   */
  expenseId: string | null
  /**
   * 對應支出的精簡摘要；給 ReimbursementDetail / useReimbursementPayout 顯示付款狀態
   * 與預計發放日用。未核准（還沒建支出）時為 null。
   */
  linkedExpense: LinkedExpense | null
  /**
   * 實際發放日（yyyy-mm-dd）；未發放為 null。
   * 【原型】後端尚無此欄位，見 Notion 卡片 2（paid_at）。
   */
  paidAt?: string | null
  /** 發放操作人；後端 serializer 吐 {id, name}。 */
  paidBy?: PersonRef | null
  /**
   * 發放方式；由支出端標記已付款時連動寫入。未發放或清空時為 null。
   */
  paymentMethod?: PaymentMethod | null
  /**
   * 處理歷程（依時間先後）。重送後 approvalProgress 會重建，駁回紀錄只留在這裡。
   * 【原型】後端需記錄並回傳，見 Notion 卡片 2；沒有時 Timeline 退回以 approvalProgress 推算。
   */
  history?: ReimbursementEvent[]
  version: number
  createdAt: string
  updatedAt: string
}

export type ReimbursementEventType =
  | 'submit'
  | 'resubmit'
  | 'withdraw'
  | 'approve'
  | 'reject'
  | 'pay'
  | 'void'
  | 'revert_void'

export interface ReimbursementEvent {
  type: ReimbursementEventType
  /** ISO datetime；pay 事件可為 yyyy-mm-dd（發放日） */
  at: string
  /** 操作人；後端 serializer 吐 {id, name}，null 用於無人操作（如系統事件） */
  by: PersonRef | null
  /** 簽核關卡名稱（approve / reject） */
  stage?: string
  comment?: string | null
}

/**
 * 一般支出來源。
 * - general：行政人員直接登錄（採購、廠商發票、訂閱費），不走簽核
 * - reimbursement：由已核准的代墊款轉入的支出（雙向 FK 由 Phase 4 才建立）
 * - transfer_fee：資金移轉手續費自動產生的支出，只能從移轉異動
 * 對應 docs/資料模型.md §2.2
 */
export type ExpenseSource = 'general' | 'reimbursement' | 'transfer_fee'

/**
 * 支出付款狀態（2 態，獨立於 Reimbursement 的 6 狀態機）。
 * 對應 docs/資料模型.md §4.2
 */
export type PayoutStatus = 'pending' | 'paid'

/**
 * 憑證圖檔（支出、收入、資金移轉、代墊款共用）。存成實體檔案，見 docs/資料模型.md §2.4、
 * docs/dev/attachments-api.md。
 */
export interface Attachment {
  /** 圖檔 ID；儲存紀錄時帶暫存檔 id、刪除單張時使用 */
  id: string
  filename: string
  mimeType: string
  byteSize: number
  /** 短效簽章網址（`/api/files/<token>`），顯示前經 fileUrl() 接上 API 網域 */
  url: string
}

/**
 * 一般支出（Expense）。與 Reimbursement 分屬兩個 model：
 * - Expense：公司對外部廠商付款；直接成立、無簽核；狀態機 pending/paid 2 態
 * - Reimbursement：公司對內部員工還錢；6 狀態機、需簽核
 * 對應 docs/資料模型.md §2.2；PRD 雙 model 決策見 §一。
 */
export interface Expense {
  id: string
  source: ExpenseSource
  sourceRefId: string | null // 若 source='reimbursement' 則指回 Reimbursement.id
  /** 來源代墊款目前的狀態；一般支出為 null。刪除時決定要不要詢問連帶作廢。 */
  sourceReimbursementStatus: ReimbursementStatus | null
  /** 產生這筆的固定收支範本；範本永久刪除後為 null，recurringPeriod 仍保留 */
  recurringTemplateId: string | null
  /** 固定收支產生時的期數（YYYY-MM）；有值就顯示「固定」，source 不新增值 */
  recurringPeriod: string | null
  /** 手續費支出指回的移轉；其他支出為 null */
  transferId: string | null
  /** 垃圾桶內可不可以還原；手續費支出一律 false */
  restorable: boolean
  /** 垃圾桶內可不可以永久刪除；移轉目前對應的手續費支出為 false */
  purgeable: boolean
  /**
   * 憑證類型（發票 / 收據）。決定發票號碼是否必填 / 是否驗格式。
   * 對應 design.md Decision 13
   */
  documentType: DocumentType
  vendor: string | null // 廠商名稱（一般支出通常填；代墊款轉入時可填員工名）
  taxId: string | null // 統一編號
  invoiceNo: string | null // 發票號碼
  /**
   * 稅率選項（決定 preTaxAmt ↔ amount 之間的計算比例）。
   * 對應 design.md Decision 10
   */
  taxRate: TaxRate
  preTaxAmt: number | null // 稅前金額
  taxAmt: number | null // 稅額
  amount: number // 總金額（含稅）
  /** 類別引用；後端 serializer 展開 {id, name, accountCode}。 */
  category: CategoryRef
  /** 付款帳戶引用；後端 serializer 展開 {id, name}。 */
  account: AccountRef
  /** 發生日期（損益歸屬），YYYY-MM-DD */
  date: string
  /** 發票日期；文件類型為發票時必填，收據為 null（PRD 第 23 條） */
  invoiceDate: string | null
  note: string | null
  attachments: Attachment[]
  /**
   * 品項明細列表（見 docs/資料模型.md §2.3）。可為空陣列。
   * 對應 design.md Decision 11
   */
  items: ExpenseItem[]
  payoutStatus: PayoutStatus
  /**
   * 應付日期（yyyy-mm-dd，必填）。建立 / 核准當下從當天往後找最近的付款日寫入；
   * 公司關閉付款日時為發生日期。之後公司改付款日不會覆寫。見 docs/資料模型.md §2.2、§3.1。
   */
  plannedPayoutDate: string
  /** 應付日期是否和自動值不同（手動調整過）；true 時可「改回自動排程」 */
  plannedPayoutManual: boolean
  /**
   * 登錄 / 核准當下依付款日算出的自動值，寫入後不變；「改回自動排程」還原成這個值。
   * null = 建立時公司已關閉付款日，自動值就是發生日期。
   */
  autoPlannedPayoutDate: string | null
  /** 實付日期（yyyy-mm-dd）；改回待付款時保留原值 */
  paidAt: string | null
  /** 標記已付款的操作人；後端 serializer 吐 {id, name}。 */
  paidBy?: PersonRef | null
  /** 建立者；後端 serializer 吐 {id, name}。 */
  createdBy: PersonRef
  /**
   * 軟刪除時間（ISO 8601）。null 表示未在垃圾桶；非 null 表示已被丟進垃圾桶。
   * 列表 API（/expenses）僅回未刪；垃圾桶 API（/expenses/trash）才回有值的。
   */
  deletedAt: string | null
  createdAt: string
  updatedAt: string
}

/**
 * 收入收款狀態（2 態，鏡像 Expense 的 PayoutStatus）。
 * 對應 docs/資料模型.md §2.6
 */
export type CollectionStatus = 'uncollected' | 'collected'

/**
 * 收入品項明細（見 docs/資料模型.md §2.6.1）。欄位與 ExpenseItem 相同；
 * subtotal 由 quantity × unitPrice 計算，MVP 手動維護、後端不驗加總。
 */
export interface IncomeItem {
  name: string
  quantity: number
  unitPrice: number
  subtotal: number
}

/**
 * 資金移轉：帳戶之間搬移資金，只影響帳戶餘額，不計入收入、支出與損益。
 * 憑證共用支出的結構。對應 docs/資料模型.md §2.10、docs/dev/transfers-api.md。
 */
export interface Transfer {
  id: string
  fromAccount: AccountRef
  toAccount: AccountRef
  amount: number
  /** 手續費；大於 0 時自動產生一筆支出 */
  fee: number
  transferDate: string
  note: string | null
  attachments: Attachment[]
  /** 手續費目前對應的支出；手續費為 0 時為 null */
  feeExpenseId: string | null
  createdBy: PersonRef
  deletedAt: string | null
  deletedBy: PersonRef | null
  createdAt: string
  updatedAt: string
}

/**
 * 收入（Income）。欄位與 Expense 對應（docs/資料模型.md §2.6），差異：
 * - customer 必填（對應 Expense.vendor）
 * - 收款狀態為 collectionStatus / collectedAt（對應 payoutStatus / paidAt）
 * - 無 source / sourceRefId（代墊款只會轉成支出）
 * - 無 paidBy 類人員欄位（§2.6 未定義 receivedBy）
 * - 應收日期為 plannedCollectionDate（預設發生日期，不看公司付款日，沒有手動旗標）
 */
export interface Income {
  id: string
  /** 產生這筆的固定收支範本；範本永久刪除後為 null，recurringPeriod 仍保留 */
  recurringTemplateId: string | null
  /** 固定收支產生時的期數（YYYY-MM）；有值就顯示「固定」 */
  recurringPeriod: string | null
  documentType: DocumentType
  customer: string
  taxId: string | null
  invoiceNo: string | null
  taxRate: TaxRate
  preTaxAmt: number | null
  taxAmt: number | null
  amount: number
  category: CategoryRef
  /** 收款帳戶引用；後端 serializer 展開 {id, name}。 */
  account: AccountRef
  /** 發生日期（損益歸屬），YYYY-MM-DD */
  date: string
  /** 發票日期；規則同 Expense.invoiceDate */
  invoiceDate: string | null
  /** 應收日期（必填），預設為發生日期；用於待收款分組與逾期判斷 */
  plannedCollectionDate: string
  note: string | null
  attachments: Attachment[]
  items: IncomeItem[]
  collectionStatus: CollectionStatus
  /** 實收日期（YYYY-MM-DD）；待收款時可能為 null，revert 後**保留**原值 */
  collectedAt: string | null
  createdBy: PersonRef
  /** 軟刪除時間（ISO 8601）；null 表示未在垃圾桶 */
  deletedAt: string | null
  createdAt: string
  updatedAt: string
}

export type RecurringDirection = 'income' | 'expense'
export type RecurringFrequency = 'monthly' | 'yearly'
/** 進行中：還有下一期可產生；歷史：沒有下一期；垃圾桶：已刪除 */
export type RecurringStatus = 'active' | 'history' | 'trash'

export const RECURRING_DIRECTION_LABELS: Record<RecurringDirection, string> = {
  expense: '固定支出',
  income: '固定收入',
}

/**
 * 固定收支範本（docs/資料模型.md §2.8、docs/dev/recurring-api.md）。
 * 列表與單筆形狀相同。
 */
export interface RecurringTemplate {
  id: string
  direction: RecurringDirection
  name: string
  category: CategoryRef & { isArchived: boolean; deletedAt: string | null }
  account: AccountRef
  documentType: DocumentType
  taxRate: TaxRate
  /** 廠商或客戶；產生紀錄時帶入支出的 vendor、收入的 customer */
  counterparty: string
  taxId: string | null
  /** 每期金額（含稅） */
  amount: number
  frequency: RecurringFrequency
  /** 1–31；月份沒有這一天時落在當月最後一天 */
  dayOfMonth: number
  /** 每年週期才有值，1–12 */
  monthOfYear: number | null
  /** YYYY-MM */
  startMonth: string
  /** YYYY-MM；null 表示持續產生 */
  endMonth: string | null
  status: RecurringStatus
  /** 不含垃圾桶內的紀錄，不要用它判斷開始月份能否改 */
  generatedCount: number
  lastGeneratedPeriod: string | null
  /** 歷史與垃圾桶內的範本為 null */
  nextPeriod: string | null
  nextDate: string | null
  /** 已產生過紀錄時為 true，紀錄全被刪掉也一樣 */
  startMonthLocked: boolean
  /** 類別不在垃圾桶時為 true；只有垃圾桶內的範本才需要看 */
  restorable: boolean
  deletedAt: string | null
  deletedBy: PersonRef | null
  createdBy: PersonRef
  createdAt: string
  updatedAt: string
}

/** 發放方式；對齊後端 Expense::PAYMENT_METHODS / Reimbursement::PAYMENT_METHODS。 */
export type PaymentMethod = 'bank_transfer' | 'cash'

/** 中文顯示對應（UI 共用）。 */
export const PAYMENT_METHOD_LABELS: Record<PaymentMethod, string> = {
  bank_transfer: '匯款',
  cash: '現金'
}

/** 代墊款標記已付款時的發放方式選項與預設值（支出列表對話框與編輯頁共用）。 */
export const PAYMENT_METHOD_OPTIONS = (Object.keys(PAYMENT_METHOD_LABELS) as PaymentMethod[]).map((value) => ({
  value,
  label: PAYMENT_METHOD_LABELS[value],
}))
export const DEFAULT_PAYMENT_METHOD: PaymentMethod = 'bank_transfer'

/**
 * 預算週期。見 docs/資料模型.md §3.5。
 * - month：以自然月為期間（YYYY-MM-01 ~ 該月最後一天）
 * - year：以自然年為期間（YYYY-01-01 ~ YYYY-12-31）
 * 同類別可同時存在 month 與 year 兩筆預算、期間互相獨立。
 */
export type BudgetCycle = 'month' | 'year'

/**
 * 類別預算（Budget）— 見 docs/資料模型.md §3.5。
 *
 * 唯一約束：(categoryId, cycle, periodStart)。同類別可月＋年並存，
 * 不同期間為完全獨立記錄。
 *
 * 業務規則：
 * - amount = 0 由 store 層轉為刪除記錄（未設定 = 無此筆），避免 0/0 除法
 * - amount < 0 由 store 層拒絕
 * - 執行率 / 剩餘 / 餘額 於 view 端由 computeUtilization 計算；actual 由
 *   /budgets/utilization 聚合後傳入，不快取
 * - periodStart / periodEnd 為本地時區 YYYY-MM-DD 字串（同 Expense.date 格式），
 *   加總時直接字典序比對 e.date >= periodStart && e.date <= periodEnd
 */
export interface Budget {
  id: string
  /** Category.id；停用類別的 Budget 記錄不會被自動刪除、解除停用後仍可用 */
  categoryId: string
  cycle: BudgetCycle
  /** 預算金額（新台幣元）；> 0；amount = 0 語意上等同刪除記錄 */
  amount: number
  /** 期間起 YYYY-MM-DD（本地時區） */
  periodStart: string
  /** 期間迄 YYYY-MM-DD（本地時區） */
  periodEnd: string
  createdAt: string
  updatedAt: string
}

/**
 * 基本預算範本（BudgetTemplate）— 見 openspec add-category-budget-module design.md Decision 13。
 *
 * 每個 (categoryId, cycle) 組合最多一筆 template；與 Budget 記錄完全獨立存在。
 * 編輯 template **不會**自動改動任何已存在的 Budget；使用者需明確於 BudgetsView
 * 點「套用基本預算」才會將 template 值 upsert 為當前檢視期間的 Budget（覆寫既有）。
 *
 * 業務規則：
 * - amount > 0 → upsertTemplate；amount = 0 → 刪除既有 template（等同未設定）；amount < 0 → 拒絕
 * - 類別停用時 template 記錄不自動刪除；解除停用後 template 仍可用
 * - 「套用」時，amount = 0 或無 template 的類別跳過（見 Decision 14）
 */
export interface BudgetTemplate {
  id: string
  categoryId: string
  cycle: BudgetCycle
  amount: number
  createdAt: string
  updatedAt: string
}

/**
 * 站內通知類型（見 docs/通知提醒.md）。
 * 對齊後端 Notification::KINDS；新增類型時兩端同步擴充。
 */
export type NotificationType =
  | 'reimbursement_submitted'
  | 'reimbursement_approved'
  | 'reimbursement_rejected'
  | 'reimbursement_paid'
  | 'payout_overdue'
  | 'data_export_ready'
  | 'data_export_failed'

/**
 * 站內通知。payload 是後端寫入時的事件快照（employee 姓名、金額、說明等），
 * 讓列表直接顯示免再 join。shape 依 kind 不同，欄位詳見 docs/通知提醒.md。
 */
export interface Notification {
  id: string
  kind: NotificationType
  payload: Record<string, unknown>
  /** 已讀時間；null = 未讀 */
  readAt: string | null
  createdAt: string
}
