// 各頁面的 SEO 描述（以路由 name 對應）。標題沿用路由 meta.title。
// 文字需與頁面實際內容一致，避免描述與內容不符。
export interface PageSeo {
  description: string
  /** 不建立索引（例如 404） */
  noindex?: boolean
  /** 是否在 sitemap.xml 列出（預設 true） */
  inSitemap?: boolean
}

export const pageSeo: Record<string, PageSeo> = {
  home: {
    description: 'QUICKEY 是中小企業收支管理工具，把收支登錄、員工請款與預算管理放在同一個地方，讓老闆與行政都能快速掌握公司狀況。',
  },
  about: {
    description: '認識 QUICKEY 的理念與團隊，我們想讓中小企業的收支紀錄更簡單，財務管理更輕鬆。',
  },
  pricing: {
    description: '依公司需求選擇 QUICKEY 方案：基礎、進階與企業方案，提供 30 天免費試用，可依需求客製。',
  },
  faq: {
    description: 'QUICKEY 常見問題：產品介紹、免費試用與方案差異、員工請款流程、資料安全等問題的說明。',
  },
  blog: {
    description: '收支管理、請款流程、預算規劃與帳務整理的實用文章，幫助中小企業把每一筆錢記得清楚。',
  },
  contact: {
    description: '聯絡 QUICKEY：產品諮詢、功能建議與合作洽談，歡迎與我們聯絡。',
  },
  privacy: {
    description: '說明 QUICKEY 如何收集、使用與保護你的資料。',
  },
  terms: {
    description: '使用 QUICKEY 服務前，請先閱讀服務條款。',
  },
  'not-found': {
    description: '找不到這個頁面。',
    noindex: true,
    inSitemap: false,
  },
}
