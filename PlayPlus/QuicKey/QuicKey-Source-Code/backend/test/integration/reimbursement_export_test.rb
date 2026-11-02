require "test_helper"
require "csv"

# 請款記錄 CSV 匯出：以 = + - @ 或 Tab、換行開頭的文字前面加 '，避免 Excel 當成公式執行。
class ReimbursementExportTest < ActionDispatch::IntegrationTest
  setup do
    @company  = create_company
    @admin    = create_user(company: @company, role: "admin")
    @employee = create_user(company: @company)
  end

  test "CSV 匯出跳脫公式開頭的文字，一般文字與金額不變" do
    descriptions = [ "=HYPERLINK(\"http://x\")", "+886", "-5", "@SUM(A1)", "\tA", "\rB", "計程車 =1" ]
    descriptions.each do |d|
      create_reimbursement(employee: @employee).update!(description: d)
    end

    get "/api/reimbursements/export", params: { format: "csv" }, headers: auth_headers(@admin)
    assert_response :ok
    rows = CSV.parse(response.body.force_encoding("UTF-8").delete_prefix("﻿"), headers: true)

    assert_equal [ "'=HYPERLINK(\"http://x\")", "'+886", "'-5", "'@SUM(A1)", "'\tA", "'\rB", "計程車 =1" ].sort,
      rows.map { |r| r["說明"] }.sort
    assert rows.all? { |r| r["金額"] == "100.0" }
  end
end
