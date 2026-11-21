require "test_helper"

# 邀請重新寄送與過期（docs/資料模型.md §3.3「重新寄送與過期」、§5.3，2026-11-10）。
class InvitationResendTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "重新寄送換新 token、重算期限並再寄信；舊連結失效" do
    invitation, old_token = invite("new@example.com")
    travel 2.days

    assert_emails(1) { resend!(invitation) }
    assert_response :ok
    new_token = emailed_token

    assert_not_equal old_token, new_token
    assert_equal "valid", response.parsed_body["status"]
    invitation.reload
    assert_in_delta Time.current + Invitation::TTL, invitation.expires_at, 1
    assert_in_delta Time.current, invitation.last_sent_at, 1

    get "/api/invitations/by-token/#{old_token}"
    assert_equal "not_found", response.parsed_body["status"]
    get "/api/invitations/by-token/#{new_token}"
    assert_equal "valid", response.parsed_body["status"]
  end

  test "距上次寄出不到 60 秒不能重寄" do
    invitation, = invite("new@example.com")
    travel 30.seconds

    assert_no_emails { resend!(invitation) }
    assert_response :too_many_requests
    assert_equal "RESEND_TOO_SOON", response.parsed_body["error"]
    assert_includes 30..31, response.parsed_body["retry_after"]

    travel 31.seconds
    resend!(invitation)
    assert_response :ok
  end

  test "已過期的邀請可以重寄；名額已滿時被擋" do
    invitation, = invite("late@example.com")
    travel Invitation::TTL + 1.hour

    5.times { create_user(company: @company) }
    assert_no_emails { resend!(invitation) }
    assert_response :conflict
    assert_equal "AT_LIMIT", response.parsed_body["error"]
    assert invitation.reload.expired?

    @company.users.role_employee.first.update!(status: "suspended")
    resend!(invitation)
    assert_response :ok
    assert invitation.reload.active?
  end

  test "已接受、已撤回的邀請不能重寄" do
    accepted, = invite("a@example.com")
    accepted.update!(accepted_at: Time.current)
    revoked, = invite("r@example.com")
    revoked.update!(revoked_at: Time.current)
    travel 2.minutes

    resend!(accepted)
    assert_response :conflict
    assert_equal "ALREADY_ACCEPTED", response.parsed_body["error"]
    resend!(revoked)
    assert_response :conflict
    assert_equal "ALREADY_REVOKED", response.parsed_body["error"]
  end

  test "員工不能重寄" do
    invitation, = invite("new@example.com")
    employee = create_user(company: @company)
    travel 2.minutes

    post "/api/invitations/#{invitation.id}/resend", headers: auth_headers(employee)
    assert_response :forbidden
  end

  test "列表有已過期的邀請，過期的不佔名額" do
    expired, = invite("old@example.com")
    travel Invitation::TTL + 1.hour
    valid, = invite("new@example.com")

    get "/api/invitations", headers: auth_headers(@admin)
    assert_response :ok
    statuses = response.parsed_body.to_h { |i| [ i["id"], i["status"] ] }
    assert_equal({ expired.id => "expired", valid.id => "valid" }, statuses)

    get "/api/company", headers: auth_headers(@admin)
    assert_equal 1, response.parsed_body["members_used"]
  end

  test "對同一個 Email 發新邀請時，舊的過期邀請被作廢" do
    old, = invite("same@example.com")
    travel Invitation::TTL + 1.hour

    post "/api/invitations", params: { email: "same@example.com", name: "受邀者" }, headers: auth_headers(@admin), as: :json
    assert_response :created
    assert old.reload.revoked?

    get "/api/invitations", headers: auth_headers(@admin)
    assert_equal [ "same@example.com" ], response.parsed_body.map { |i| i["email"] }
  end

  private

  def invite(email)
    Invitation.generate_for(company: @company, email: email, name: "受邀者", invited_by: @admin)
  end

  def resend!(invitation)
    post "/api/invitations/#{invitation.id}/resend", headers: auth_headers(@admin), as: :json
  end

  def emailed_token
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/token=([\w-]+)/, 1]
  end
end
