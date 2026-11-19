require "test_helper"

# 邀請的 Email 已有帳號（docs/sitemap.md 員工管理，2026-11-10）：一個 Email 只能屬於一家公司。
# 本公司人員回 EMAIL_IN_USE；其他公司的帳號回 EMAIL_IN_OTHER_COMPANY。兩種都不產生邀請、不寄信。
class InvitationEmailTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "Email 已是本公司人員 → EMAIL_IN_USE" do
    create_user(company: @company, email: "ming@example.com")

    assert_no_invitation_sent { invite!(" Ming@Example.com ") }
    assert_equal "EMAIL_IN_USE", response.parsed_body["error"]
  end

  test "Email 已在其他公司註冊 → EMAIL_IN_OTHER_COMPANY" do
    create_user(company: create_company(name: "他公司"), role: "admin", email: "boss@example.com")

    assert_no_invitation_sent { invite!("BOSS@example.com") }
    assert_equal "EMAIL_IN_OTHER_COMPANY", response.parsed_body["error"]
  end

  private

  def invite!(email)
    post "/api/invitations", params: { email: email, name: "受邀者" }, headers: auth_headers(@admin), as: :json
  end

  def assert_no_invitation_sent(&)
    assert_no_difference(-> { Invitation.count }, &)
    assert_response :conflict
    assert_empty ActionMailer::Base.deliveries
  end
end
