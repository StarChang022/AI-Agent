// 部落格文章資料（草稿標題與摘要，尚未發布）
export interface Post {
  slug: string
  title: string
  summary: string
  category: string
  tone: 1 | 2 | 3
  // 排序示意用的假資料：publishedAt（YYYY-MM-DD）與 views（瀏覽數），後端接上後改由資料庫提供
  publishedAt: string
  views: number
}

export const postCategories = ['收支管理', '請款流程', '預算規劃', '帳務與報稅'] as const

export const posts: Post[] = [
  { slug: 'monthly-close', title: '收支記得清楚，月底對帳就不痛苦：用三個固定步驟整理每筆支出、請款與現金流，讓結帳不再手忙腳亂', summary: '把每筆收支當天記下，月底就不必再翻找收據，對帳會輕鬆很多。', category: '收支管理', publishedAt: '2026-10-20', views: 40, tone: 1 },
  { slug: 'start-with-category', title: '不懂會計科目？先從「類別」開始', summary: '不需要先學會計科目，用公司自己看得懂的類別記帳，一樣能掌握錢的去向。', category: '收支管理', publishedAt: '2026-10-17', views: 413, tone: 2 },
  { slug: 'reimbursement-flow', title: '員工請款怎麼做，才不會卡在半路：從拍照送出、主管審核到撥款與併入正式支出的完整流程說明', summary: '從拍照送出到撥款，把每一步講清楚，員工與主管都能少一點等待與來回。', category: '請款流程', publishedAt: '2026-10-14', views: 786, tone: 3 },
  { slug: 'transparent-advance', title: '代墊款的審核與撥款，可以更透明', summary: '每筆請款的狀態都看得到，撥款前後的紀錄也會保留，查帳時有依據。', category: '請款流程', publishedAt: '2026-10-11', views: 259, tone: 1 },
  { slug: 'budget-rhythm', title: '每月預算怎麼設，才看得出花費節奏', summary: '與其等到超支才發現，不如定期看預算使用率，及早調整花費的步調。', category: '預算規劃', publishedAt: '2026-10-08', views: 632, tone: 2 },
  { slug: 'prepare-tax-ledger', title: '報稅之前，先把內帳整理好', summary: '平時把收支記清楚，報稅前交給會計師或記帳士時，準備工作會快很多。', category: '帳務與報稅', publishedAt: '2026-10-05', views: 105, tone: 3 },
  { slug: 'sample-01', title: '小店老闆的每日記帳三步驟', summary: '固定時間記帳，比月底補記更不容易漏掉。', category: '收支管理', publishedAt: '2026-10-02', views: 478, tone: 2 },
  { slug: 'sample-02', title: '零用金怎麼管，才不會越用越亂', summary: '設定額度與補充時點，讓小額支出有跡可循。', category: '收支管理', publishedAt: '2026-09-29', views: 851, tone: 3 },
  { slug: 'sample-03', title: '信用卡帳單對不上？先從這三件事查起', summary: '比對消費日期、金額與分期，快速找出差異。', category: '收支管理', publishedAt: '2026-09-26', views: 324, tone: 1 },
  { slug: 'sample-04', title: '訂閱服務越來越多，怎麼一次看清楚', summary: '把月費與年費集中記錄，避免重複付費。', category: '收支管理', publishedAt: '2026-09-23', views: 697, tone: 2 },
  { slug: 'sample-05', title: '現金收入怎麼記，才好對帳', summary: '每日結算現金與收據，讓帳面與實際金額一致。', category: '收支管理', publishedAt: '2026-09-20', views: 170, tone: 3 },
  { slug: 'sample-06', title: '採購與報價單的記帳重點', summary: '記下廠商、單價與數量，日後比價與追蹤都方便。', category: '收支管理', publishedAt: '2026-09-17', views: 543, tone: 1 },
  { slug: 'sample-07', title: '一人公司也需要收支表嗎？', summary: '即使只有一個人，固定記錄收支也能看清楚獲利狀況。', category: '收支管理', publishedAt: '2026-09-14', views: 916, tone: 2 },
  { slug: 'sample-08', title: '季節性支出怎麼提前規劃', summary: '把年節、旺季的花費列入預期，避免現金流突然吃緊。', category: '收支管理', publishedAt: '2026-09-11', views: 389, tone: 3 },
  { slug: 'sample-09', title: '請款單要填什麼，主管一看就懂', summary: '用標準欄位描述用途與金額，減少來回確認。', category: '請款流程', publishedAt: '2026-09-08', views: 762, tone: 1 },
]
