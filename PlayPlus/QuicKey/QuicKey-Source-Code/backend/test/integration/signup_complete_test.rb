require "test_helper"

# 新公司註冊完成（docs/QA_list/QA_註冊公司帳號.md）：管理員姓名先留空，到歡迎設定頁才補。
# 姓名空白期間不能被擋下其他操作；邀請來的員工與之後改名仍要有姓名。
class SignupCompleteTest < ActionDispatch::IntegrationTest
  EMAIL    = "new@example.com".freeze
  PASSWORD = "password123".freeze

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "從註冊申請走到完成：建立公司與姓名空白的管理員，回登入資料" do
    post "/api/auth/signup/request", as: :json, params: {
      email: EMAIL, password: PASSWORD, company_type: "limited", company_name: "新公司"
    }
    assert_response :accepted

    assert_difference [ -> { Company.count }, -> { User.count } ], 1 do
      post "/api/auth/signup/complete", params: { token: emailed_token }, as: :json
    end
    assert_response :created

    body = response.parsed_body
    assert_equal "", body.dig("user", "name")
    assert_equal "admin", body.dig("user", "role")
    assert_equal "新公司", body.dig("company", "name")
    assert body["token"].present?
    assert_equal "新公司", User.find_by!(email: EMAIL).company.name
  end

  test "同一個連結不能註冊兩次" do
    token = signup_token
    post "/api/auth/signup/complete", params: { token: token }, as: :json
    assert_response :created

    assert_no_difference -> { Company.count } do
      post "/api/auth/signup/complete", params: { token: token }, as: :json
    end
    assert_response :bad_request
  end

  test "公司資料無效時整個註冊不留下資料" do
    _record, raw = SignupToken.generate_for(email: EMAIL, password: PASSWORD, company_type: "limited", company_name: "")

    assert_no_difference [ -> { Company.count }, -> { User.count } ] do
      post "/api/auth/signup/complete", params: { token: raw }, as: :json
    end
    assert_response :unprocessable_content
  end

  test "姓名空白的管理員可以登入、補姓名，補完後不能再清空" do
    admin = signed_up_admin

    post "/api/auth/login", params: { email: EMAIL, password: PASSWORD }, as: :json
    assert_response :ok
    assert_equal "", response.parsed_body.dig("user", "name")

    patch "/api/users/me", params: { name: "" }, headers: auth_headers(admin), as: :json
    assert_response :unprocessable_content
    assert_equal "INVALID_NAME", response.parsed_body["error"]

    patch "/api/users/me", params: { name: " 王管理 " }, headers: auth_headers(admin), as: :json
    assert_response :ok
    assert_equal "王管理", admin.reload.name

    assert_not admin.update(name: "")
    assert admin.errors.key?(:name)
  end

  test "姓名空白時其他更新不受影響：完成導覽、修改密碼、重設密碼" do
    admin = signed_up_admin

    patch "/api/users/me/onboarding", params: { completed: true }, headers: auth_headers(admin), as: :json
    assert_response :ok

    post "/api/auth/password/change", headers: auth_headers(admin), as: :json,
      params: { old_password: PASSWORD, new_password: "newpassword123" }
    assert_response :no_content

    raw = PasswordResetToken.generate_for(admin).last
    post "/api/auth/password/reset", params: { token: raw, new_password: "another123456" }, as: :json
    assert_response :ok
    assert admin.reload.authenticate("another123456")
  end

  test "姓名空白時忘記密碼信以 Email 稱呼" do
    signed_up_admin

    post "/api/auth/password/forgot", params: { email: EMAIL }, as: :json
    assert_response :accepted

    mail = ActionMailer::Base.deliveries.last
    [ mail.html_part, mail.text_part ].compact.each { |part| assert_includes part.body.decoded, "Hi #{EMAIL}," }
  end

  test "有姓名時忘記密碼信照舊以姓名稱呼" do
    admin = signed_up_admin
    admin.update!(name: "王管理")

    post "/api/auth/password/forgot", params: { email: EMAIL }, as: :json
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.decoded, "Hi 王管理,"
  end

  test "邀請員工仍要有姓名，接受邀請後帶入" do
    company = create_company
    admin   = create_user(company: company, role: "admin")

    assert_not company.invitations.new(email: "e@example.com", name: "", expires_at: 1.day.from_now, token_digest: "x").valid?

    _invitation, raw = Invitation.generate_for(company: company, email: "e@example.com", name: "陳小明", invited_by: admin)
    post "/api/invitations/by-token/#{raw}/accept", params: { password: PASSWORD }, as: :json
    assert_response :created
    assert_equal "陳小明", User.find_by!(email: "e@example.com").name
  end

  test "管理員改員工姓名不能留空" do
    company  = create_company
    admin    = create_user(company: company, role: "admin")
    employee = create_user(company: company)

    patch "/api/users/#{employee.id}", params: { name: "" }, headers: auth_headers(admin), as: :json
    assert_response :unprocessable_content
  end

  private

  def signup_token
    SignupToken.generate_for(email: EMAIL, password: PASSWORD, company_type: "limited", company_name: "新公司").last
  end

  def signed_up_admin
    post "/api/auth/signup/complete", params: { token: signup_token }, as: :json
    assert_response :created
    User.find_by!(email: EMAIL)
  end

  def emailed_token
    mail = ActionMailer::Base.deliveries.last
    (mail.text_part || mail).body.decoded[/token=([\w-]+)/, 1]
  end
end
