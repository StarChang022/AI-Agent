require "test_helper"

# 登入註冊修正（2026-11-09 定案）：
# - 註冊時 Email 已存在直接告知
# - 停用帳號不能登入、手上的 token 立即失效、不寄重設密碼信
# - 重設密碼連結只有最新一封有效
class AuthAccessTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company, email: "ming@example.com")
  end

  # ---- 註冊重複 Email ----

  test "註冊時 Email 已存在回 409，不寄信也不建註冊連結" do
    assert_no_difference -> { SignupToken.count } do
      post "/api/auth/signup/request", as: :json, params: signup_params("ming@example.com")
    end
    assert_response :conflict
    assert_equal "email_taken", response.parsed_body["error"]
    assert_empty ActionMailer::Base.deliveries
  end

  test "Email 大小寫不同也算已註冊" do
    post "/api/auth/signup/request", as: :json, params: signup_params("  Ming@Example.COM ")
    assert_response :conflict
    assert_equal "email_taken", response.parsed_body["error"]
  end

  test "沒註冊過的 Email 照常寄驗證信" do
    post "/api/auth/signup/request", as: :json, params: signup_params("new@example.com")
    assert_response :accepted
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  # ---- 停用帳號 ----

  test "停用帳號密碼正確登入回 403" do
    @employee.update!(status: "suspended")
    login("ming@example.com", TestDataHelpers::DEFAULT_PASSWORD)
    assert_response :forbidden
    assert_equal "account_suspended", response.parsed_body["error"]
  end

  test "停用帳號密碼錯誤仍回 invalid_credentials，不透露帳號狀態" do
    @employee.update!(status: "suspended")
    login("ming@example.com", "wrong-password")
    assert_response :unauthorized
    assert_equal "invalid_credentials", response.parsed_body["error"]
  end

  test "停用後帶舊 token 呼叫 API 回 401" do
    headers = auth_headers(@employee)
    get "/api/notifications", headers: headers
    assert_response :ok

    @employee.update!(status: "suspended")
    get "/api/notifications", headers: headers
    assert_response :unauthorized
  end

  test "停用後重新啟用可以正常登入" do
    @employee.update!(status: "suspended")
    @employee.update!(status: "active")
    login("ming@example.com", TestDataHelpers::DEFAULT_PASSWORD)
    assert_response :ok
    assert response.parsed_body["token"].present?
  end

  # ---- 忘記密碼 ----

  test "停用帳號申請忘記密碼回 403，不寄信" do
    @employee.update!(status: "suspended")
    assert_no_difference -> { PasswordResetToken.count } do
      post "/api/auth/password/forgot", params: { email: "ming@example.com" }, as: :json
    end
    assert_response :forbidden
    assert_equal "account_suspended", response.parsed_body["error"]
    assert_empty ActionMailer::Base.deliveries
  end

  test "查無帳號申請忘記密碼回 404，不寄信" do
    assert_no_difference -> { PasswordResetToken.count } do
      post "/api/auth/password/forgot", params: { email: "nobody@example.com" }, as: :json
    end
    assert_response :not_found
    assert_equal "email_not_found", response.parsed_body["error"]
    assert_empty ActionMailer::Base.deliveries
  end

  test "忘記密碼 Email 大小寫、前後空白不同也找得到帳號並寄信" do
    post "/api/auth/password/forgot", params: { email: "  Ming@Example.COM " }, as: :json
    assert_response :accepted
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  # ---- 重設密碼連結只有最新一封有效 ----

  test "申請第二次後，第一封的連結失效、第二封可用" do
    first  = request_reset_token
    second = request_reset_token

    reset(first, "newpassword1")
    assert_response :bad_request

    reset(second, "newpassword1")
    assert_response :ok
  end

  test "停用前申請的重設連結，停用後拿來重設回 400，密碼不變、連結作廢" do
    token = request_reset_token
    @employee.update!(status: "suspended")

    reset(token, "newpassword1")
    assert_response :bad_request
    assert_equal "invalid_or_expired_token", response.parsed_body["error"]
    assert_nil response.parsed_body["token"]
    assert @employee.reload.authenticate(TestDataHelpers::DEFAULT_PASSWORD)

    # 重新啟用後，這張連結也不能再用
    @employee.update!(status: "active")
    reset(token, "newpassword1")
    assert_response :bad_request
  end

  test "重設成功後，其他沒用過的連結也失效" do
    _record, other = PasswordResetToken.generate_for(@employee)
    # 直接建一張舊的、沒被作廢的 token，模擬並存的情況
    raw = SecureRandom.urlsafe_base64(32)
    PasswordResetToken.create!(user: @employee, token_digest: Digest::SHA256.hexdigest(raw), expires_at: 30.minutes.from_now)

    reset(raw, "newpassword1")
    assert_response :ok

    reset(other, "newpassword2")
    assert_response :bad_request
  end

  private

  def signup_params(email)
    { email: email, password: "password123", company_type: "limited", company_name: "新公司" }
  end

  def login(email, password)
    post "/api/auth/login", params: { email: email, password: password }, as: :json
  end

  def request_reset_token
    ActionMailer::Base.deliveries.clear
    post "/api/auth/password/forgot", params: { email: "ming@example.com" }, as: :json
    assert_response :accepted
    mail = ActionMailer::Base.deliveries.last
    (mail.text_part || mail).body.decoded[/token=([\w-]+)/, 1]
  end

  def reset(token, new_password)
    post "/api/auth/password/reset", params: { token: token, new_password: new_password }, as: :json
  end
end
