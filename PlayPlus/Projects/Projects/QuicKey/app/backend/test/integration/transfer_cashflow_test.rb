require "test_helper"

# 現金流報表的資金移轉（PRD 第 19 條）：所有帳戶相抵，單一帳戶多一欄，期初＋淨現金流＝期末。
class TransferCashflowTest < ActionDispatch::IntegrationTest
  YEAR = { from: "2026-01-01", to: "2026-12-31" }.freeze

  setup do
    travel_to Time.zone.local(2026, 11, 10, 12)
    @company = create_company
    @admin   = create_user(company: @company, role: "admin")
    @bank    = create_account(company: @company, name: "永豐", opening_amount: 10_000, opening_month: Date.new(2026, 1, 1))
    @petty   = create_account(company: @company, name: "零用金", opening_amount: 500, opening_month: Date.new(2026, 1, 1))
  end

  test "所有帳戶：移轉相抵，不顯示，收付與淨現金流不變，只有手續費算付款" do
    transfer("2026-03-10", amount: 3_000, fee: 15)

    body = cashflow
    march = body["rows"][2]

    assert_not march.key?("transfer")
    assert_not body["total"].key?("transfer")
    assert_equal 0.0, march["cash_in"]
    assert_equal 15.0, march["cash_out"]
    assert_equal(-15.0, march["net"])
    assert_equal 10_485.0, body.dig("total", "closing_cash")
  end

  test "單一帳戶：轉出為負、轉入為正，收付維持真實收支，期初＋淨現金流＝期末" do
    transfer("2026-03-10", amount: 3_000, fee: 15)

    bank = cashflow(account_id: @bank.id)
    march, april = bank["rows"].values_at(2, 3)
    assert_equal(-3_000.0, march["transfer"])
    assert_equal 1, march["transfer_count"]
    assert_equal 0.0, march["cash_in"]
    assert_equal 15.0, march["cash_out"]
    assert_equal(-3_015.0, march["net"])
    assert_equal 10_000.0, march["opening_cash"]
    assert_equal 6_985.0, march["closing_cash"]
    assert_equal 6_985.0, april["opening_cash"]
    assert_equal 0.0, april["transfer"]
    assert_equal 0, april["transfer_count"]
    assert_equal(-3_000.0, bank.dig("total", "transfer"))
    assert_equal 1, bank.dig("total", "transfer_count")
    assert_equal(-3_015.0, bank.dig("total", "net"))
    assert_equal 6_985.0, bank.dig("total", "closing_cash")

    petty = cashflow(account_id: @petty.id)
    assert_equal 3_000.0, petty["rows"][2]["transfer"]
    assert_equal 0.0, petty["rows"][2]["cash_out"]
    assert_equal 3_500.0, petty.dig("total", "closing_cash")

    assert_equal cashflow.dig("total", "closing_cash"),
                 bank.dig("total", "closing_cash") + petty.dig("total", "closing_cash")
  end

  test "同一期轉入轉出相抵：淨額 0，筆數 2" do
    transfer("2026-03-10", amount: 1_000)
    transfer("2026-03-20", amount: 1_000, from: @petty, to: @bank)

    march = cashflow(account_id: @bank.id)["rows"][2]
    assert_equal 0.0, march["transfer"]
    assert_equal 2, march["transfer_count"]
  end

  test "期間之前的移轉併入期初" do
    @bank.update!(opening_month: Date.new(2025, 12, 1))
    @petty.update!(opening_month: Date.new(2025, 12, 1))
    transfer("2025-12-20", amount: 3_000)

    assert_equal 7_000.0, cashflow(account_id: @bank.id)["rows"].first["opening_cash"]
    assert_equal 3_500.0, cashflow(account_id: @petty.id)["rows"].first["opening_cash"]
  end

  test "季彙總：移轉歸入該季" do
    transfer("2026-05-10", amount: 3_000)

    rows = cashflow(account_id: @bank.id, bucket: "quarter")["rows"]
    assert_equal [ 0.0, -3_000.0, 0.0, 0.0 ], rows.map { |r| r["transfer"] }
  end

  test "垃圾桶內的移轉不計入，還原後計入" do
    id = transfer("2026-03-10", amount: 3_000, fee: 15)
    delete "/api/transfers/#{id}", headers: auth_headers(@admin)

    assert_equal 0.0, cashflow(account_id: @bank.id).dig("total", "transfer")
    assert_equal 0.0, cashflow(account_id: @bank.id).dig("total", "cash_out")
    assert_equal 10_000.0, cashflow(account_id: @bank.id).dig("total", "closing_cash")

    patch "/api/transfers/#{id}/restore", headers: auth_headers(@admin)
    assert_equal 6_985.0, cashflow(account_id: @bank.id).dig("total", "closing_cash")
  end

  test "公司隔離：別家的移轉不計入" do
    other = create_company(name: "別家公司")
    other_admin = create_user(company: other, role: "admin")
    bank  = create_account(company: other, name: "甲", opening_month: Date.new(2026, 1, 1))
    petty = create_account(company: other, name: "乙", opening_month: Date.new(2026, 1, 1))
    other.transfers.create!(from_account: bank, to_account: petty, amount: 100, transfer_date: "2026-03-10", created_by: other_admin)

    get "/api/reports/cashflow", params: YEAR.merge(account_id: bank.id), headers: auth_headers(@admin)
    assert_equal "ACCOUNT_NOT_FOUND", response.parsed_body["error"]
    assert_equal 0.0, cashflow(account_id: @bank.id).dig("total", "transfer")
  end

  test "Excel：單一帳戶多一欄資金移轉，所有帳戶沒有" do
    transfer("2026-03-10", amount: 3_000)

    assert_equal %w[期間 期初 收款 付款 資金移轉 淨流 期末], xlsx_rows(account_id: @bank.id)[3]
    assert_equal [ "合計", 10_000.0, 0.0, 0.0, -3_000.0, -3_000.0, 7_000.0 ], xlsx_rows(account_id: @bank.id).last
    assert_equal %w[期間 期初 收款 付款 淨流 期末], xlsx_rows[3]
  end

  private

  def transfer(date, amount:, fee: 0, from: @bank, to: @petty)
    post "/api/transfers", params: { from_account_id: from.id, to_account_id: to.id, amount: amount, fee: fee, transfer_date: date },
                           headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body["id"]
  end

  def cashflow(**query)
    get "/api/reports/cashflow", params: YEAR.merge(query), headers: auth_headers(@admin)
    assert_response :ok
    response.parsed_body
  end

  # 第一個工作表（現金流）的列。
  def xlsx_rows(**query)
    get "/api/reports/cashflow.xlsx", params: YEAR.merge(query), headers: auth_headers(@admin)
    assert_response :ok
    Tempfile.create([ "cashflow", ".xlsx" ]) do |file|
      file.binmode
      file.write(response.body)
      file.flush
      sheet = Roo::Excelx.new(file.path).sheet(0)
      sheet.to_a
    end
  end
end
