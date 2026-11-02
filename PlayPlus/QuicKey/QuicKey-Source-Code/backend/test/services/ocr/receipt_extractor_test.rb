require "test_helper"

# 模型回的欄位只做格式檢查：不通過的欄位不放。
class Ocr::ReceiptExtractorTest < ActiveSupport::TestCase
  VALID_TAX_ID = "04595257".freeze # 通過檢查碼

  def extract(data, role = "expense")
    Ocr::ReceiptExtractor.call(data, role: role, source_index: 0)
  end

  def value(result, key)
    result[:fields].dig(key, :value)
  end

  test "發票字軌 2 碼英文加 8 碼數字才採用" do
    ok = extract("invoice_prefix" => "ab", "invoice_digits" => "12345678")
    assert_equal "AB", value(ok, :invoice_prefix)
    assert_equal "12345678", value(ok, :invoice_digits)
    assert_equal "invoice", value(ok, :document_type)

    [ %w[A 12345678], %w[AB 1234567], %w[ABC 12345678], %w[AB 1234567A] ].each do |prefix, digits|
      bad = extract("invoice_prefix" => prefix, "invoice_digits" => digits)
      assert_nil value(bad, :invoice_prefix), "#{prefix}#{digits}"
      assert_nil value(bad, :invoice_digits)
    end
  end

  test "收據不帶發票號碼" do
    result = extract("document_type" => "receipt", "invoice_prefix" => "AB", "invoice_digits" => "12345678")
    assert_nil value(result, :invoice_prefix)
    assert_equal "receipt", value(result, :document_type)
  end

  test "日期要是西元 YYYY-MM-DD 且在 2000 年到明年之間" do
    assert_equal "2026-10-15", value(extract("incurred_at" => "2026-10-15"), :incurred_at)
    [ "1900-01-01", "1999-12-31", "#{Date.current.year + 2}-01-01", "2026-13-40", "115/10/15", "" ].each do |bad|
      assert_nil value(extract("incurred_at" => bad), :incurred_at), bad
    end
  end

  test "統編要 8 碼數字且通過檢查碼，依 role 放我方 / 對方" do
    expense = extract("seller_tax_id" => VALID_TAX_ID, "buyer_tax_id" => "12345678")
    assert_equal VALID_TAX_ID, value(expense, :counterparty_tax_id)
    assert_nil value(expense, :our_tax_id) # 12345678 檢查碼不過

    income = extract({ "seller_tax_id" => VALID_TAX_ID }, "income")
    assert_equal VALID_TAX_ID, value(income, :our_tax_id)

    [ "0459525", "045952570", "ABCDEFGH" ].each do |bad|
      assert_nil value(extract("seller_tax_id" => bad), :counterparty_tax_id), bad
    end
  end

  test "金額要是正整數，稅額可為 0" do
    result = extract("pre_tax_amt" => 95, "tax_amt" => 5, "amount" => 100)
    assert_equal [ 95, 5, 100 ], result[:fields].values_at(:pre_tax_amt, :tax_amt, :amount).map { |f| f[:value] }
    assert_equal "business_5", value(result, :tax_rate)

    free = extract("pre_tax_amt" => 100, "tax_amt" => 0, "amount" => 100)
    assert_equal 0, value(free, :tax_amt)
    assert_equal "exempt_0", value(free, :tax_rate)

    [ 0, -5, 12.5, "100", 1_000_000_000 ].each do |bad|
      assert_nil value(extract("amount" => bad), :amount), bad.inspect
    end
  end

  test "總計小於未稅是讀錯，未稅與稅額都不用" do
    result = extract("pre_tax_amt" => 200, "tax_amt" => 10, "amount" => 100)
    assert_nil value(result, :pre_tax_amt)
    assert_nil value(result, :tax_amt)
    assert_equal 100, value(result, :amount)
  end

  test "品項單價 × 數量要等於小計，否則略過" do
    result = extract("items" => [
      { "name" => "原子筆", "quantity" => 2, "unit_price" => 15, "subtotal" => 30 },
      { "name" => "對不上", "quantity" => 2, "unit_price" => 15, "subtotal" => 40 },
      { "name" => "", "quantity" => 1, "unit_price" => 5, "subtotal" => 5 }
    ])
    assert_equal [ "原子筆" ], result[:items].map { |i| i[:name] }
  end

  test "模型列為不確定的欄位信心度低，名稱與品項一律低" do
    result = extract("amount" => 100, "incurred_at" => "2026-10-15", "seller_name" => "好店有限公司",
                     "uncertain_fields" => [ "amount" ])
    assert_equal Ocr::ReceiptExtractor::LOW, result[:fields][:amount][:confidence]
    assert_equal Ocr::ReceiptExtractor::HIGH, result[:fields][:incurred_at][:confidence]
    assert_equal Ocr::ReceiptExtractor::LOW, result[:fields][:counterparty_name][:confidence]
  end

  test "空資料或不是 Hash 不報錯" do
    assert_equal({}, extract(nil)[:fields])
    assert_equal({}, extract("items" => "x")[:fields])
  end

  test "日期字串過長或格式不對只丟掉該欄位，其他欄位照常" do
    result = extract("incurred_at" => "2026-10-15" + "x" * 200, "amount" => 100)
    assert_nil value(result, :incurred_at)
    assert_equal 100, value(result, :amount)

    [ "20261015", "2026-288", "2026-W42-4", [ "2026-10-15" ], 20_261_015 ].each do |bad|
      assert_nil value(extract("incurred_at" => bad), :incurred_at), bad.inspect
    end
  end

  test "名稱與品名不是字串就捨棄，控制字元清掉，過長捨棄" do
    result = extract("seller_name" => [ "福華" ], "buyer_name" => { "a" => 1 })
    assert_nil value(result, :counterparty_name)
    assert_nil value(result, :our_name)

    clean = extract("seller_name" => "福華\u0000商行\u0007", "items" => [
      { "name" => "原子\u0000筆", "quantity" => 1, "unit_price" => 10, "subtotal" => 10 },
      { "name" => [ "筆" ], "quantity" => 1, "unit_price" => 10, "subtotal" => 10 },
      { "name" => "長" * 101, "quantity" => 1, "unit_price" => 10, "subtotal" => 10 }
    ])
    assert_equal "福華 商行", value(clean, :counterparty_name)
    assert_equal [ "原子 筆" ], clean[:items].map { |i| i[:name] }
    assert_nil value(extract("seller_name" => "長" * 101), :counterparty_name)
  end
end
