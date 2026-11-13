require "test_helper"

# GET /api/reimbursements/:id 的讀取權限：本人、同公司管理員可看；其他一律 404。
class ReimbursementShowAccessTest < ActionDispatch::IntegrationTest
  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
    @coworker = create_user(company: @company)

    @other_company = create_company(name: "別家公司")
    @other_admin   = create_user(company: @other_company, role: "admin")
  end

  test "員工可以看自己的請款（含草稿）" do
    [ create_reimbursement(employee: @employee), create_reimbursement(employee: @employee, status: "draft") ].each do |r|
      get "/api/reimbursements/#{r.id}", headers: auth_headers(@employee)
      assert_response :ok
      assert_equal r.id, response.parsed_body["id"]
    end
  end

  test "管理員可以看本公司員工的請款" do
    r = create_reimbursement(employee: @employee)
    get "/api/reimbursements/#{r.id}", headers: auth_headers(@admin)
    assert_response :ok
    assert_equal r.id, response.parsed_body["id"]
  end

  test "管理員看不到員工的草稿" do
    r = create_reimbursement(employee: @employee, status: "draft")
    get "/api/reimbursements/#{r.id}", headers: auth_headers(@admin)
    assert_response :not_found
  end

  test "員工看同公司其他人的請款回 404" do
    r = create_reimbursement(employee: @coworker)
    get "/api/reimbursements/#{r.id}", headers: auth_headers(@employee)
    assert_response :not_found
  end

  test "別家公司的管理員看不到本公司的請款" do
    r = create_reimbursement(employee: @employee)
    get "/api/reimbursements/#{r.id}", headers: auth_headers(@other_admin)
    assert_response :not_found
  end

  test "管理員不能修改或刪除員工的請款" do
    r = create_reimbursement(employee: @employee, status: "draft")
    patch "/api/reimbursements/#{r.id}", params: { description: "改掉" }, headers: auth_headers(@admin), as: :json
    assert_response :not_found
    delete "/api/reimbursements/#{r.id}", headers: auth_headers(@admin)
    assert_response :not_found
    assert Reimbursement.exists?(r.id)
  end
end
