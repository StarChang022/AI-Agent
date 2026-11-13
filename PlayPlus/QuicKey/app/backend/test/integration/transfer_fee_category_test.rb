require "test_helper"
require Rails.root.join("db/migrate/20261102000004_add_system_key_to_categories")

# 系統保留的手續費類別：新公司自動建立、既有公司補上、不可停用或刪除（PRD 第 19 條）。
class TransferFeeCategoryTest < ActionDispatch::IntegrationTest
  setup do
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @fee     = @company.categories.find_by!(system_key: Category::TRANSFER_FEE_KEY)
  end

  test "新公司自動建立手續費類別，科目 6131" do
    assert_equal "手續費", @fee.name
    assert_equal "expense", @fee.kind
    assert_equal "6131", @fee.account_code
  end

  test "不可停用、不可刪除" do
    patch "/api/categories/#{@fee.id}/archive", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "CATEGORY_SYSTEM_RESERVED", response.parsed_body["error"]
    assert response.parsed_body["message"].present?

    delete "/api/categories/#{@fee.id}", headers: auth_headers(@admin)
    assert_response :conflict
    assert_equal "CATEGORY_SYSTEM_RESERVED", response.parsed_body["error"]

    @fee.reload
    assert_equal false, @fee.is_archived
    assert_nil @fee.deleted_at
  end

  test "不可永久刪除" do
    @fee.update_columns(deleted_at: Time.current)

    delete "/api/categories/#{@fee.id}/purge", headers: auth_headers(@admin)

    assert_response :conflict
    assert_equal "CATEGORY_SYSTEM_RESERVED", response.parsed_body["error"]
    assert Category.exists?(@fee.id)
  end

  test "可以改名，手續費支出沿用" do
    patch "/api/categories/#{@fee.id}", params: { name: "銀行手續費" }, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "transfer_fee", response.parsed_body["system_key"]
    assert_equal "銀行手續費", @fee.reload.name

    account = create_account(company: @company, opening_month: Date.current.beginning_of_month)
    other   = create_account(company: @company, opening_month: Date.current.beginning_of_month)
    post "/api/transfers", params: { from_account_id: account.id, to_account_id: other.id, amount: 100, fee: 10,
                                     transfer_date: Date.current }, headers: auth_headers(@admin), as: :json
    assert_response :created
    assert_equal @fee.id, @company.expenses.sole.category_id
  end

  test "缺手續費類別：建立有手續費的移轉時自動補上，不寫稽核" do
    @fee.destroy!
    max = @company.categories.of_kind("expense").maximum(:sort_order)
    accounts = two_accounts

    assert_no_difference -> { AuditLog.where(target_type: "category").count } do
      post_fee_transfer(accounts)
    end

    assert_response :created
    fee = @company.categories.find_by!(system_key: Category::TRANSFER_FEE_KEY)
    assert_equal [ "手續費", "6131", "expense", max + 1 ], [ fee.name, fee.account_code, fee.kind, fee.sort_order ]
    assert_equal fee.id, @company.expenses.sole.category_id
  end

  test "缺手續費類別：沒有手續費的移轉不補" do
    @fee.destroy!

    post_fee_transfer(two_accounts, fee: 0)

    assert_response :created
    assert_nil @company.categories.find_by(system_key: Category::TRANSFER_FEE_KEY)
  end

  test "缺手續費類別：編輯時填手續費也會補上" do
    @fee.destroy!
    post_fee_transfer(two_accounts, fee: 0)

    patch "/api/transfers/#{response.parsed_body["id"]}", params: { fee: 10 }, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "手續費", @company.expenses.sole.category.name
  end

  test "缺手續費類別：停用或在垃圾桶的同名類別恢復為使用中，不新增" do
    @fee.update_columns(system_key: nil, is_archived: true, deleted_at: 1.day.ago, account_code: "9999")
    accounts = two_accounts

    assert_no_difference -> { Category.count } do
      post_fee_transfer(accounts)
    end

    assert_response :created
    @fee.reload
    assert_equal [ "transfer_fee", false, nil, "9999" ], [ @fee.system_key, @fee.is_archived, @fee.deleted_at, @fee.account_code ]
    assert_equal @fee.id, @company.expenses.sole.category_id
  end

  test "缺手續費類別：收入類別同名不算" do
    @fee.destroy!
    income = @company.categories.create!(kind: "income", name: "手續費")
    accounts = two_accounts

    post_fee_transfer(accounts)

    assert_response :created
    assert_nil income.reload.system_key
    assert_equal "expense", @company.expenses.sole.category.kind
  end

  test "別家公司的手續費類別不受影響" do
    other = create_company(name: "別家公司")
    other_fee = other.categories.find_by!(system_key: Category::TRANSFER_FEE_KEY)
    @fee.destroy!
    accounts = two_accounts

    post_fee_transfer(accounts)

    assert_not_equal other_fee.id, @company.expenses.sole.category_id
    assert_equal other.id, other_fee.reload.company_id
  end

  test "include_usage：deletable、archivable、purgeable 為 false，有說明；一般類別不變" do
    get "/api/categories", params: { kind: "expense", include_usage: true }, headers: auth_headers(@admin)

    rows = response.parsed_body.index_by { |c| c["id"] }
    fee  = rows.fetch(@fee.id)
    assert_equal "transfer_fee", fee["system_key"]
    assert_equal false, fee["deletable"]
    assert_equal false, fee["archivable"]
    assert_equal false, fee["purgeable"]
    assert_includes fee["blocked_reason"], "系統保留"

    other = rows.values.find { |c| c["system_key"].nil? }
    assert_equal true, other["deletable"]
    assert_equal true, other["archivable"]
    assert_nil other["blocked_reason"]
  end

  test "既有公司：沒有手續費類別時新增，排在最後" do
    @fee.destroy!
    max = @company.categories.of_kind("expense").maximum(:sort_order)

    backfill

    fee = @company.categories.find_by!(system_key: "transfer_fee")
    assert_equal "手續費", fee.name
    assert_equal "6131", fee.account_code
    assert_equal max + 1, fee.sort_order
    assert_equal false, fee.is_archived
  end

  test "既有公司：同名支出類別沿用，保留科目與排序，不新增" do
    @fee.update_columns(system_key: nil, account_code: "9999", sort_order: 3)

    assert_no_difference -> { Category.count } do
      backfill
    end

    @fee.reload
    assert_equal "transfer_fee", @fee.system_key
    assert_equal "9999", @fee.account_code
    assert_equal 3, @fee.sort_order
  end

  test "既有公司：停用中、垃圾桶內的同名類別恢復為使用中" do
    @fee.update_columns(system_key: nil, is_archived: true, deleted_at: 1.day.ago)

    backfill

    @fee.reload
    assert_equal "transfer_fee", @fee.system_key
    assert_equal false, @fee.is_archived
    assert_nil @fee.deleted_at
  end

  test "既有公司：名稱比對不分大小寫" do
    @fee.destroy!
    fee = @company.categories.create!(kind: "expense", name: "Fee")

    stub_const(AddSystemKeyToCategories, :FEE_NAME, "FEE") { backfill }

    assert_equal "transfer_fee", fee.reload.system_key
    assert_equal "Fee", fee.name
  end

  test "既有公司：同名有多筆時優先用使用中的，收入類別不算" do
    income = @company.categories.create!(kind: "income", name: "手續費")
    @fee.update_columns(system_key: nil)
    trashed = @company.categories.create!(kind: "expense", name: "暫名")
    trashed.update_columns(name: "手續費", deleted_at: 1.day.ago)

    backfill

    assert_equal "transfer_fee", @fee.reload.system_key
    assert_nil trashed.reload.system_key
    assert_nil income.reload.system_key
  end

  test "既有公司：不寫稽核，每家公司一個，重跑不重複" do
    other = create_company(name: "別家公司")
    other.categories.find_by!(system_key: "transfer_fee").destroy!
    @fee.update_columns(system_key: nil)

    assert_no_difference -> { AuditLog.count } do
      backfill
      backfill
    end

    assert_equal 1, @company.categories.where(system_key: "transfer_fee").count
    assert_equal 1, other.categories.where(system_key: "transfer_fee").count
  end

  private

  def two_accounts
    month = Date.current.beginning_of_month
    [ create_account(company: @company, opening_month: month), create_account(company: @company, opening_month: month) ]
  end

  def post_fee_transfer(accounts, fee: 10)
    post "/api/transfers", params: { from_account_id: accounts.first.id, to_account_id: accounts.last.id, amount: 100,
                                     fee: fee, transfer_date: Date.current }, headers: auth_headers(@admin), as: :json
  end

  def backfill
    migration = AddSystemKeyToCategories.new
    migration.suppress_messages { migration.backfill }
  end
end

# 兩條連線同時補手續費類別，需要真的提交的交易。
class TransferFeeCategoryConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include TestDataHelpers

  test "同時補上：後到的等先到的提交，撞唯一索引後改用同一筆，外層交易不受影響" do
    company = create_company(name: "併發補類別")
    company.categories.find_by!(system_key: Category::TRANSFER_FEE_KEY).destroy!
    created = Queue.new
    release = Queue.new

    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          created << CategorySeeder.ensure_transfer_fee!(Company.find(company.id)).id
          release.pop
        end
      end
    end
    first_id = created.pop

    second = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          category = CategorySeeder.ensure_transfer_fee!(Company.find(company.id))
          [ category.id, Category.where(company_id: company.id, system_key: Category::TRANSFER_FEE_KEY).count ]
        end
      end
    end

    assert_nil second.join(0.5), "第二條連線應該等第一條提交"
    release << true
    first.join

    assert_equal [ first_id, 1 ], second.value
  ensure
    release&.push(true)
    [ first, second ].compact.each(&:join)
    company&.destroy!
  end
end
