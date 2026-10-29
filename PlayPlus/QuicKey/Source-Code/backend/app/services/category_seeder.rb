class CategorySeeder
  # 新公司建立時塞起始類別。對齊 docs/資料模型.md §3.4，皆取自經濟部
  # 「商業會計項目表（112 年度及以後適用）」：
  # - expense 13 筆：營業費用 6111–6134，與 frontend/src/constants/accountSubjects.ts 一致。
  # - income 4 筆：營業收入 41xx / 42xx 與營業外收入 71xx / 74xx。
  # 僅為起始值，之後可全部改名／停用；建立後與使用者自建類別一視同仁。
  EXPENSE_DEFAULTS = [
    { name: "交通費",     account_code: "6114" },
    { name: "差旅費",     account_code: "6114" },
    { name: "伙食費",     account_code: "6128" },
    { name: "文具用品",   account_code: "6113" },
    { name: "郵電費",     account_code: "6116" },
    { name: "水電瓦斯費", account_code: "6119" },
    { name: "廣告費",     account_code: "6118" },
    { name: "交際費",     account_code: "6121" },
    { name: "修繕費",     account_code: "6117" },
    { name: "教育訓練費", account_code: "6132" },
    { name: "保險費",     account_code: "6120" },
    { name: "租金支出",   account_code: "6112" },
    { name: "其他費用",   account_code: "6134" }
  ].freeze

  INCOME_DEFAULTS = [
    { name: "銷售收入", account_code: "4110" }, # 銷貨收入
    { name: "服務收入", account_code: "4210" }, # 勞務收入
    { name: "利息收入", account_code: "7110" }, # 利息收入（營業外）
    { name: "其他收入", account_code: "7480" }  # 其他收入（營業外）
  ].freeze

  def self.seed!(company)
    seed_kind!(company, "expense", EXPENSE_DEFAULTS)
    seed_kind!(company, "income",  INCOME_DEFAULTS)
  end

  def self.seed_kind!(company, kind, defaults)
    defaults.each_with_index do |attrs, i|
      company.categories.find_or_create_by!(kind: kind, name: attrs[:name]) do |c|
        c.account_code = attrs[:account_code]
        c.sort_order   = i
        c.is_archived  = false
      end
    end
  end
end
