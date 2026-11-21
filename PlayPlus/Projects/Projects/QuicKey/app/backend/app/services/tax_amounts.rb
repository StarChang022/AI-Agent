class TaxAmounts
  # 含稅金額推算未稅與稅額，Excel 匯入與固定收支共用：
  # 未稅 = 含稅 ÷ (1 + 稅率) 四捨五入到整數，但不超過含稅；稅額 = 含稅 − 未稅。
  # 免稅時未稅等於含稅（保留小數），稅額為 0。

  RATES = { "business_5" => BigDecimal("0.05"), "exempt_0" => BigDecimal("0") }.freeze

  # 回傳 [未稅, 稅額]。
  def self.from_gross(amount, tax_rate)
    rate = RATES.fetch(tax_rate)
    return [ amount, BigDecimal("0") ] if rate.zero?

    pre_tax = [ (amount / (1 + rate)).round(0, BigDecimal::ROUND_HALF_UP), amount ].min
    [ pre_tax, amount - pre_tax ]
  end
end
