require "test_helper"

# 新註冊公司自動建預設帳戶（PRD 規則 20）：和建公司同一個交易、不寫稽核。
class SignupDefaultAccountTest < ActionDispatch::IntegrationTest
  EMAIL = "new@example.com".freeze

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "註冊完成：公司有預設帳戶，銀行帳戶、起始月份為註冊當月、起始金額 0，不寫稽核" do
    assert_difference -> { Account.count } => 1, -> { AuditLog.count } => 0 do
      complete_signup
    end
    assert_response :created
    assert_equal "", response.parsed_body.dig("user", "name")

    company = User.find_by!(email: EMAIL).company
    account = company.accounts.sole
    assert_empty AuditLog.where(company: company)
    assert_empty AuditLog.where(target_type: "account", target_id: account.id)
    assert_equal "預設帳戶", account.name
    assert_equal "bank", account.account_type
    assert_equal Date.current.beginning_of_month, account.opening_month
    assert_equal 0, account.opening_amount
  end

  test "新註冊的管理員登入後，下拉看得到預設帳戶，還沒有上一次使用的帳戶" do
    complete_signup
    assert_response :created
    token = response.parsed_body["token"]

    get "/api/accounts/options", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :ok
    assert_equal [ "預設帳戶" ], response.parsed_body["data"].map { |a| a["name"] }
    assert_nil response.parsed_body["last_used_account_id"]
  end

  test "建預設帳戶失敗時，公司與使用者都不建立" do
    Account.singleton_class.alias_method(:__real_create_default!, :create_default!)
    Account.define_singleton_method(:create_default!) { |_company| raise ActiveRecord::RecordInvalid, Account.new }
    begin
      assert_no_difference -> { Company.count } do
        complete_signup
      end
    ensure
      Account.singleton_class.alias_method(:create_default!, :__real_create_default!)
      Account.singleton_class.remove_method(:__real_create_default!)
    end

    assert_response :unprocessable_content
    assert_nil User.find_by(email: EMAIL)
  end

  test "建使用者失敗時，公司與預設帳戶都不留下（同一個交易）" do
    User.singleton_class.alias_method(:__real_create!, :create!)
    User.define_singleton_method(:create!) { |_attrs| raise ActiveRecord::RecordInvalid, User.new }
    begin
      assert_no_difference [ -> { Company.count }, -> { Account.count } ] do
        complete_signup
      end
    ensure
      User.singleton_class.alias_method(:create!, :__real_create!)
      User.singleton_class.remove_method(:__real_create!)
    end
    assert_response :unprocessable_content
  end

  private

  # 真實註冊流程：送出申請 → 從驗證信取得連結的 token → 完成註冊。
  def complete_signup
    post "/api/auth/signup/request", as: :json, params: {
      email: EMAIL, password: "password123", company_type: "limited", company_name: "新公司"
    }
    assert_response :accepted

    mail  = ActionMailer::Base.deliveries.last
    token = (mail.text_part || mail).body.decoded[/token=([\w-]+)/, 1]
    post "/api/auth/signup/complete", params: { token: token }, as: :json
  end
end
