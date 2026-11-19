// 各頁面的 SEO 描述（以路由 name 對應）。標題沿用路由 meta.title。
// 文字需與頁面實際內容一致，避免描述與內容不符。
export interface PageSeo {
  description: string
  /** 不建立索引（例如 404、上線前未開放的頁面） */
  noindex?: boolean
  /** 是否在 sitemap.xml 列出（預設 true） */
  inSitemap?: boolean
}

export const pageSeo: Record<string, PageSeo> = {
  home: {
    description: 'QUICKEY 快記是中小企業收支管理工具，協助記錄收支、員工請款與預算管理。即將上線，歡迎先聯絡領取封測資訊。',
  },
  about: {
    description: '認識 QUICKEY 快記的理念與團隊，我們希望讓中小企業的收支紀錄更簡單，財務管理更輕鬆。',
  },
  // 以下頁面上線前暫不開放：不建立索引、不列入 sitemap；開放時移除 noindex 與 inSitemap 即可
  pricing: {
    description: '查看 QUICKEY 快記的方案內容與價格。',
    noindex: true,
    inSitemap: false,
  },
  faq: {
    description: 'QUICKEY 快記常見問題：產品介紹、功能說明與使用方式。',
    noindex: true,
    inSitemap: false,
  },
  blog: {
    description: '收支管理、請款流程、預算規劃與帳務整理的實用文章。',
    noindex: true,
    inSitemap: false,
  },
  'blog-post': {
    description: '',
    noindex: true,
    inSitemap: false,
  },
  contact: {
    description: '聯絡 QUICKEY 快記：產品諮詢、功能建議與合作洽談，可透過 LINE 或 Email 與我們聯繫。',
  },
  privacy: {
    description: '說明 QUICKEY 快記官方網站如何蒐集、使用與保護個人資料。',
  },
  terms: {
    description: '瀏覽 QUICKEY 快記官方網站前，請先閱讀網站使用條款。',
  },
  'not-found': {
    description: '找不到這個頁面。',
    noindex: true,
    inSitemap: false,
  },
}
