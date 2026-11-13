require "test_helper"

# 新註冊公司不自動建立帳戶，由新手導覽結束後引導管理員建立第一個帳戶（PRD 規則 20、22）。
class SignupNoAccountTest < ActionDispatch::IntegrationTest
  EMAIL = "new@example.com".freeze

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "註冊完成：公司沒有帳戶，帳戶下拉是空的" do
    assert_no_difference -> { Account.count } do
      complete_signup
    end
    assert_response :created

    assert_empty User.find_by!(email: EMAIL).company.accounts

    get "/api/accounts/options", headers: { "Authorization" => "Bearer #{response.parsed_body['token']}" }
    assert_response :ok
    assert_empty response.parsed_body["data"]
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
