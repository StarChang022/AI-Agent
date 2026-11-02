class CategorySeeder
  # 新公司建立時塞起始類別。對齊 docs/資料模型.md §3.4，皆取自經濟部
  # 「商業會計項目表（112 年度及以後適用）」：
  # - expense 14 筆：營業費用 6111–6134，與 frontend/src/constants/accountSubjects.ts 一致。
  # - income 4 筆：營業收入 41xx / 42xx 與營業外收入 71xx / 74xx。
  # 僅為起始值，之後可全部改名／停用；建立後與使用者自建類別一視同仁。手續費除外，它是系統保留類別。
  TRANSFER_FEE = { name: "手續費", account_code: "6131", system_key: Category::TRANSFER_FEE_KEY }.freeze

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
    { name: "其他費用",   account_code: "6134" },
    TRANSFER_FEE
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

  # 公司的手續費類別。類別在公司建立後才種，種失敗時會缺這筆，這裡補上，不寫稽核。
  # 規則同既有公司的 migration：有同名支出類別就沿用，停用中或在垃圾桶的恢復為使用中，沒有則新增。
  # 同時補上時由 system_key 的唯一索引擋下後到的那筆；在子交易內才不會弄壞呼叫端的交易。
  def self.ensure_transfer_fee!(company)
    key = Category::TRANSFER_FEE_KEY
    company.categories.find_by(system_key: key) ||
      Category.transaction(requires_new: true) { claim_transfer_fee!(company) || create_transfer_fee!(company) }
  rescue ActiveRecord::RecordNotUnique
    company.categories.find_by!(system_key: key)
  end

  def self.claim_transfer_fee!(company)
    category = company.categories.of_kind("expense").where("LOWER(name) = LOWER(?)", TRANSFER_FEE[:name])
      .order(Arel.sql("deleted_at IS NOT NULL"), :is_archived, :created_at).first
    category&.tap do |c|
      c.update_columns(system_key: TRANSFER_FEE[:system_key], is_archived: false, deleted_at: nil, updated_at: Time.current)
    end
  end
  private_class_method :claim_transfer_fee!

  # 名稱的唯一性驗證沒有資料庫索引擋，同時補上時可能先報驗證錯誤，所以跳過驗證，交給 system_key 的索引。
  def self.create_transfer_fee!(company)
    sort_order = (company.categories.of_kind("expense").maximum(:sort_order) || -1) + 1
    company.categories.new(TRANSFER_FEE.merge(kind: "expense", sort_order: sort_order)).tap { |c| c.save!(validate: false) }
  end
  private_class_method :create_transfer_fee!

  def self.seed_kind!(company, kind, defaults)
    defaults.each_with_index do |attrs, i|
      company.categories.find_or_create_by!(kind: kind, name: attrs[:name]) do |c|
        c.account_code = attrs[:account_code]
        c.sort_order   = i
        c.is_archived  = false
        c.system_key   = attrs[:system_key]
      end
    end
  end
end
