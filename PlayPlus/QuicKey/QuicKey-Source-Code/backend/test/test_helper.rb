ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

# integration test 共用：直接建資料，不走 fixtures（公司建立時會自動種預設類別）。
module TestDataHelpers
  DEFAULT_PASSWORD = "password123".freeze

  def create_company(name: "測試公司")
    Company.create!(name: name, company_type: "limited")
  end

  def create_user(company:, role: "employee", status: "active", email: nil)
    email ||= "#{role}-#{SecureRandom.hex(4)}@example.com"
    company.users.create!(email: email, name: email.split("@").first, role: role, status: status,
                          password: DEFAULT_PASSWORD)
  end

  def create_reimbursement(employee:, status: "in_review")
    employee.company.reimbursements.create!(
      employee: employee, status: status, amount: 100, incurred_at: Date.current,
      category: employee.company.categories.first, description: "測試請款",
      document_type: "receipt", tax_rate: "exempt_0"
    )
  end

  def create_account(company:, name: nil, account_type: "bank", opening_amount: 0, opening_month: nil)
    Account.build_with_opening(company: company, name: name || "帳戶-#{SecureRandom.hex(4)}", account_type: account_type,
                               opening_amount: opening_amount, opening_month: opening_month).tap(&:save!)
  end

  # 測試共用的帳戶：既有測試不關心是哪個帳戶時用這個。
  def account_for(company)
    company.accounts.kept.first || create_account(company: company)
  end

  def create_recurring_template(company:, created_by:, **attrs)
    direction = attrs.fetch(:direction, "expense")
    company.recurring_templates.create!({
      direction: direction, name: "辦公室租金", created_by: created_by,
      category: company.categories.of_kind(direction).active.first, account: account_for(company),
      document_type: "receipt", tax_rate: "exempt_0", counterparty: "大樓管理公司", amount: 1000,
      frequency: "monthly", day_of_month: 5, start_month: Date.current.strftime("%Y-%m")
    }.merge(attrs))
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{JwtService.encode(user_id: user.id)}" }
  end
end

class ActionDispatch::IntegrationTest
  include TestDataHelpers
end

# 測試用：讓 Ocr::GeminiClient.from_env 回傳假 client（不打 Google）。
module Ocr
  class GeminiClient
    def self.stub_from_env(client)
      singleton_class.alias_method(:__real_from_env, :from_env)
      singleton_class.define_method(:from_env) { client }
      yield
    ensure
      singleton_class.alias_method(:from_env, :__real_from_env)
      singleton_class.remove_method(:__real_from_env)
    end
  end
end

# 測試用：模擬另一個請求先拿到鎖、改完才放開。hook 只跑一次，在 lock! 重新讀取之前執行。
module BeforeLock
  mattr_accessor :hook

  def lock!(...)
    hook, BeforeLock.hook = BeforeLock.hook, nil
    hook&.call
    super
  end
end

# 測試用：攔截逾期通知，拿到實際要通知的支出。
module Notifications
  def self.stub_notify_overdue(fake)
    singleton_class.alias_method(:__real_notify_overdue_payouts, :notify_overdue_payouts)
    singleton_class.define_method(:notify_overdue_payouts) { |*args, **kw| fake.call(*args, **kw) }
    yield
  ensure
    singleton_class.alias_method(:notify_overdue_payouts, :__real_notify_overdue_payouts)
    singleton_class.remove_method(:__real_notify_overdue_payouts)
  end
end
