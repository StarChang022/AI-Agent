// 方案價格資料（單一來源：三張方案卡片）
// 規格來源：docs/後續擴充規格.md §1、§2、§4、§5、§6（草稿，2026-10-19）
// ⚠️ 價格為「示意價格」（2026-10-20 指示先放假價格，正式價格確認後替換）。
//    月費正式確認前，請勿以此數字作為正式對外價格。替換位置：下方 plans 的 price。
export type PlanId = 'basic' | 'advanced' | 'enterprise'

export interface Plan {
  id: PlanId
  name: string
  audience: string
  seats: string
  recognitions: string
  storage: string
  /** 示意月費（NT$）；企業方案為客製方案，null */
  price: number | null
  recommended?: boolean
  cta:
    | { label: string; kind: 'trial'; variant: 'primary' | 'ghost' }
    | { label: string; kind: 'contact'; to: string }
}

export const plans: Plan[] = [
  {
    id: 'basic',
    name: '基礎方案',
    audience: '適合個人工作室、小型團隊與基本收支管理需求。',
    seats: '3 人',
    recognitions: '20 次',
    storage: '3 GB',
    price: 390,
    cta: { label: '免費試用30天', kind: 'trial', variant: 'ghost' },
  },
  {
    id: 'advanced',
    name: '進階方案',
    audience: '適合需要更多額度或者多人協作的成長型團隊。',
    seats: '15 人',
    recognitions: '100 次',
    storage: '10 GB',
    price: 890,
    recommended: true,
    cta: { label: '免費試用30天', kind: 'trial', variant: 'primary' },
  },
  {
    id: 'enterprise',
    name: '企業方案',
    audience: '適合人數較多、需要更大使用額度或更完整管理功能的企業團隊。',
    seats: '客製方案',
    recognitions: '客製方案',
    storage: '客製方案',
    price: null,
    cta: { label: '聯繫我們', kind: 'contact', to: '/contact' },
  },
]

/** 所有方案皆包含的核心功能（規格：所有方案都有全部功能，差別只在人數、辨識次數與儲存空間） */
// 功能名稱依後台實際模組（導覽列與 docs/sitemap.md）：支出管理、收入管理、請款、簽核、預算管理、報表、類別管理、人員管理
export const sharedFeatures = [
  '支出管理與收入管理',
  '請款與簽核',
  '預算管理（依類別設定月或年預算）',
  '損益報表與現金流報表',
  '類別管理與人員管理',
]

/** 訂閱與試用說明（規格已確認的內容） */
export const subscriptionNotes: { text: string }[] = [
  { text: 'QUICKEY 提供 30 天免費試用，試用期間使用進階版功能，註冊時不需綁卡。' },
  { text: '試用結束前，需綁定信用卡並開通定期定額，才能繼續使用。' },
  { text: '付款成功後立即生效，服務期間從當天算起。' },
  { text: '升級於付款成功後立即生效；降級於當期結束時生效，若超過降級後方案的人數或儲存空間上限，需先處理後才能降級。' },
  { text: '取消訂閱於當期結束時生效，當期結束前可以恢復。' },
  { text: '到期後資料保留 12 個月，期滿後刪除。到期後無法匯出，請於到期前自行備份。' },
]

/** 尚未確認、正式上線前需替換或確認的項目 */
export const pendingItems: string[] = [
  '月費：目前為示意價格（基礎 NT$ 390、進階 NT$ 890），正式價格確認後替換 plans 的 price',
  '計費週期（月繳或年繳），目前頁面顯示「每月」',
  '點數單價（規格列為 10 或 11 元），目前頁面不顯示',
  '升級差額的計算方式（依剩餘天數，金額待定價時確定）',
  '到期後可用範圍：規格草稿 §5 為「唯讀」，與確認原則「停止使用平台功能」字句不同，頁面未寫入，待確認',
]
