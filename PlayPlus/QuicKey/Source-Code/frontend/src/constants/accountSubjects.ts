/**
 * 會計科目清單：經濟部「商業會計項目表（112 年度及以後適用版本）」6 營業費用 6111–6134。
 *
 * 類別管理用下拉選單挑科目（選填，之後可補），多個類別可以對應同一個科目
 * （例如交通費、差旅費都記 6114 旅費）。依商業會計法第 27 條，公司可視需要增減項目，
 * 實際使用的科目表仍以公司記帳士為準；接後端後改由 API 提供公司自己的科目表。
 */
export interface AccountSubject {
  code: string
  name: string
}

export const ACCOUNT_SUBJECTS: AccountSubject[] = [
  { code: '6111', name: '薪資支出' },
  { code: '6112', name: '租金支出' },
  { code: '6113', name: '文具用品' },
  { code: '6114', name: '旅費' },
  { code: '6115', name: '運費' },
  { code: '6116', name: '郵電費' },
  { code: '6117', name: '修繕費' },
  { code: '6118', name: '廣告費' },
  { code: '6119', name: '水電瓦斯費' },
  { code: '6120', name: '保險費' },
  { code: '6121', name: '交際費' },
  { code: '6122', name: '捐贈' },
  { code: '6123', name: '稅捐' },
  { code: '6124', name: '呆帳損失' },
  { code: '6125', name: '折舊' },
  { code: '6126', name: '各項耗竭及攤提' },
  { code: '6127', name: '外銷損失' },
  { code: '6128', name: '伙食費' },
  { code: '6129', name: '職工福利' },
  { code: '6130', name: '研究發展費用' },
  { code: '6131', name: '佣金支出' },
  { code: '6132', name: '訓練費' },
  { code: '6133', name: '勞務費' },
  { code: '6134', name: '其他營業費用' },
]

/** 顯示用：「6114 旅費」；清單外的舊代碼只顯示代碼，未設定回空字串 */
export function accountSubjectLabel(code: string | null | undefined): string {
  if (!code) return ''
  const s = ACCOUNT_SUBJECTS.find((x) => x.code === code)
  return s ? `${s.code} ${s.name}` : code
}
