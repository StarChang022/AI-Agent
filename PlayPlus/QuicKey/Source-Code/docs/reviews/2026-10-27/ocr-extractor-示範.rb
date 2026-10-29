# 後端技術審查示範（只示範寫法，沒有改 app/ 裡的程式）。
# 執行：ruby docs/reviews/2026-10-27/ocr-extractor-示範.rb   （不需要 Bundler / DB / Google）
require "benchmark"

# ── 1. UNIFIED_TAX_ID 的 ReDoS ─────────────────────────────
# 原本（receipt_text_extractor.rb:40）：\s* 和 [^\n\d] 都能吃空白，同一段空白有無數種切法，
# 找不到 8 碼數字時會把每一種切法都試一遍 → 指數時間。
OLD = /統一編號((?:\s*\n\s*[^\n\d]{1,2})*)[\s:]*(\d{8})(?!\d)/
# 修正：換行前後只吃「不含換行的空白」，格子字元不含空白，三者不重疊 → 線性時間。
NEW = /統一編號((?:[^\S\n]*\n[^\S\n]*[^\s\d]{1,2})*)[\s:]*(\d{8})(?!\d)/

Regexp.timeout = 3
bad  = "統一編號\n" + ("元\n\n" * 25) + "總計 100\n"
bad2 = "統一編號\n" + ("  個\n" * 30) + "總計 100\n"
[ [ "原本", OLD ], [ "修正", NEW ] ].each do |label, re|
  [ bad, bad2 ].each_with_index do |text, i|
    sec = Benchmark.realtime { text.match(re) rescue print "(逾時) " }
    puts format("%s 樣本%d：%.3fs", label, i + 1, sec)
  end
end

# 行為要一致：印章裡夾零星字、號碼在下一行
samples = [
  "統一編號\n行\n87654321",
  "統一編號 : 87654321",
  "統一編號\n12345678",
  "統一編號\n專\n用\n87654321"
]
samples.each { |s| puts "同結果：#{OLD.match(s)&.[](2) == NEW.match(s)&.[](2)}  #{s.inspect}" }

# ── 2. 統一編號檢查碼（財政部 2023 年起：總和能被 5 整除） ───────
# 用來擋掉「8 碼但不是統編」的數字（單號 No.00123456、訂單號、手寫收據流水號）。
def valid_tax_id?(id)
  return false unless id.match?(/\A\d{8}\z/)
  sum = id.chars.map(&:to_i).zip([ 1, 2, 1, 2, 1, 2, 4, 1 ]).sum do |d, w|
    p = d * w
    p / 10 + p % 10
  end
  sum % 5 == 0 || (id[6] == "7" && (sum + 1) % 5 == 0)
end
{ "22555003" => "統一超商", "00123456" => "收據流水號", "12345678" => "常見假號" }.each do |id, note|
  puts "#{id} (#{note}): #{valid_tax_id?(id)}"
end
