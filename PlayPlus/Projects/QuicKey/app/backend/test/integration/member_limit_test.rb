require "test_helper"

# 員工人數上限依方案（docs/資料模型.md §3.1「方案上限」、§3.2 約束）：
# 團隊版 5 人；使用中＋邀請中都算，不含管理員與停用的員工；已達上限不能邀請，
# 超過上限時不停用既有員工。
class MemberLimitTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
  end

  test "團隊版：使用中加邀請中共 4 人時可邀請第 5 人，第 6 人被擋" do
    3.times { create_user(company: @company) }
    invite!("pending@example.com")
    assert_response :created

    invite!("fifth@example.com")
    assert_response :created

    assert_no_difference -> { @company.invitations.count } do
      invite!("sixth@example.com")
    end
    assert_response :conflict
    assert_equal "AT_LIMIT", response.parsed_body["error"]
  end

  test "停用的員工不佔名額" do
    4.times { create_user(company: @company) }
    create_user(company: @company, status: "suspended")

    invite!("fifth@example.com")
    assert_response :created
  end

  test "已超過上限的公司不能邀請，既有員工照常使用" do
    employees = Array.new(7) { create_user(company: @company) }

    invite!("extra@example.com")
    assert_response :conflict
    assert_equal "AT_LIMIT", response.parsed_body["error"]

    assert employees.all? { |u| u.reload.status_active? }
    get "/api/company", headers: auth_headers(employees.last)
    assert_response :ok
  end

  test "名額 5/5 時不能重新啟用停用的員工，有空位時可以" do
    active    = Array.new(5) { create_user(company: @company) }
    suspended = create_user(company: @company, status: "suspended")

    reactivate!(suspended)
    assert_response :conflict
    assert_equal "AT_LIMIT", response.parsed_body["error"]
    assert suspended.reload.status_suspended?

    active.first.update!(status: "suspended")
    reactivate!(suspended)
    assert_response :ok
    assert suspended.reload.status_active?
  end

  test "公司資訊依方案回傳名額上限與方案" do
    2.times { create_user(company: @company) }

    get "/api/company", headers: auth_headers(@admin)
    assert_response :ok
    body = response.parsed_body
    assert_equal "team", body["plan"]
    assert_equal 5, body["member_limit"]
    assert_equal 2, body["members_used"]

    @company.update!(plan: "enterprise")
    get "/api/company", headers: auth_headers(@admin)
    assert_equal 10, response.parsed_body["member_limit"]
  end

  test "方案只能是免費版、團隊版、企業版" do
    @company.plan = "pro"
    assert_not @company.valid?
    assert @company.errors[:plan].any?
  end

  private

  def reactivate!(user)
    patch "/api/users/#{user.id}/status", params: { status: "active" }, headers: auth_headers(@admin), as: :json
  end

  def invite!(email)
    post "/api/invitations", params: { email: email, name: "受邀者" }, headers: auth_headers(@admin), as: :json
  end
end
