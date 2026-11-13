module Ocr
  # 把 Gemini 回的欄位 JSON 整理成 ResultMerger 用的內部物件，並做格式檢查。見 docs/OCR辨識規格.md §3.1。
  #
  # 回傳：
  #   {
  #     source_index: 0,
  #     fields: { incurred_at: { value: "2026-10-15", confidence: 0.9 }, ... },  # 只放通過檢查的欄位
  #     items:  [ { name:, quantity:, unit_price:, subtotal: }, ... ],
  #     confidence: 0.83   # 本檔直接取得的欄位信心度平均；推導欄位（documentType / taxRate）不計入
  #   }
  #
  # 原則：
  # - 模型可能編造內容，所以只做格式檢查，不通過的欄位不放（不猜）。檢查規則見 OCR辨識規格 §3.1。
  # - 信心度：模型沒有逐欄分數，改讓它列出 uncertain_fields；列入的欄位 LOW，其餘 HIGH。
  #   名稱與品項是自由文字、最容易編造，一律 LOW。
  #
  # role 決定「我方 / 對方」：expense / reimbursement 我方是買方、對方是賣方；income 反過來。
  class ReceiptExtractor
    ROLES = %w[expense reimbursement income].freeze

    HIGH = 0.9
    LOW  = 0.5

    DOCUMENT_TYPES = %w[invoice receipt].freeze
    ISO_DATE       = /\A\d{4}-\d{2}-\d{2}\z/
    INVOICE_PREFIX = /\A[A-Z]{2}\z/
    INVOICE_DIGITS = /\A\d{8}\z/
    TAX_ID         = /\A\d{8}\z/
    # 日期換算成西元後，年份要在這之後、且不超過今年 + 1 年
    MIN_YEAR = 2000
    ROC_YEAR_OFFSET = 1911
    # 單筆金額上限（擋掉模型把條碼、序號讀成金額）
    MAX_AMOUNT = 99_999_999
    MAX_NAME_LENGTH = 100
    MAX_ITEMS = 50
    # 統編檢查碼權重（財政部規則：各位數乘權重後，把乘積的十位與個位相加）
    TAX_ID_WEIGHTS = [ 1, 2, 1, 2, 1, 2, 4, 1 ].freeze

    BUSINESS_TAX  = 0.05
    TAX_TOLERANCE = 0.005

    def self.call(data, role:, source_index:)
      new(data, role: role, source_index: source_index).call
    end

    # 字串比較前的正規化：去頭尾空白（含全形空白）、全形英數字與常見符號轉半形。不做相似度比對。
    def self.normalize_text(value)
      return nil if value.nil?
      text = value.to_s.tr("０-９Ａ-Ｚａ-ｚ：／－＄，", "0-9A-Za-z:/\\-$,").gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
      text.presence
    end

    # 統編檢查碼：各位數乘權重、乘積的十位與個位相加，總和能被 5 整除；
    # 第 7 碼為 7 時，總和或總和 + 1 能被 5 整除即可。
    def self.valid_tax_id?(tax_id)
      sum = tax_id.chars.zip(TAX_ID_WEIGHTS).sum do |digit, weight|
        product = digit.to_i * weight
        product / 10 + product % 10
      end
      sum % 5 == 0 || (tax_id[6] == "7" && (sum + 1) % 5 == 0)
    end

    # 規格 §4 稅率推導：稅額 / 未稅 ≈ 5%（±0.5%）→ business_5；沒有稅額時改用（含稅 − 未稅）/ 未稅；
    # 稅額為 0 或收據 → exempt_0；其他（含 documentType 為 nil）→ nil。
    def self.derive_tax_rate(pre_tax:, tax:, amount:, document_type:)
      # 推算出來的稅額只用來判斷 5%；「稅額為 0 → 免稅」只看憑證上有印的稅額
      tax_for_rate = tax || (amount - pre_tax if pre_tax && amount)

      if tax_for_rate && pre_tax.to_i.positive? && ((tax_for_rate.to_f / pre_tax) - BUSINESS_TAX).abs <= TAX_TOLERANCE
        "business_5"
      elsif tax == 0 || document_type == "receipt"
        "exempt_0"
      end
    end

    def initialize(data, role:, source_index:)
      @data         = data.is_a?(Hash) ? data : {}
      @role         = role
      @source_index = source_index
      @uncertain    = Array(@data["uncertain_fields"]).map(&:to_s)
    end

    def call
      fields = {}
      add = ->(key, value, confidence) { fields[key] = { value: value, confidence: confidence } unless value.nil? }

      seller_id = tax_id("seller_tax_id")
      buyer_id  = tax_id("buyer_tax_id")
      party     = party_names
      our_id, their_id = @role == "income" ? [ seller_id, buyer_id ] : [ buyer_id, seller_id ]
      our_key, their_key = @role == "income" ? %w[seller_tax_id buyer_tax_id] : %w[buyer_tax_id seller_tax_id]

      add.call(:incurred_at, incurred_at, confidence_of("incurred_at"))
      add.call(:our_name, party[:our_name], LOW)
      add.call(:our_tax_id, our_id, confidence_of(our_key))
      add.call(:counterparty_name, party[:counterparty_name], LOW)
      add.call(:counterparty_tax_id, their_id, confidence_of(their_key))

      prefix, digits = invoice_number
      add.call(:invoice_prefix, prefix, confidence_of("invoice_prefix", "invoice_digits"))
      add.call(:invoice_digits, digits, confidence_of("invoice_prefix", "invoice_digits"))

      pre_tax, tax, amount = amounts
      add.call(:pre_tax_amt, pre_tax, confidence_of("pre_tax_amt"))
      add.call(:tax_amt, tax, confidence_of("tax_amt"))
      add.call(:amount, amount, confidence_of("amount"))

      items = line_items
      direct_confidences = fields.values.map { |f| f[:confidence] }
      direct_confidences << LOW if items.any?

      document_type = document_type(prefix)
      add.call(:document_type, document_type, HIGH)
      tax_rate = self.class.derive_tax_rate(pre_tax: pre_tax, tax: tax, amount: amount, document_type: document_type)
      add.call(:tax_rate, tax_rate, HIGH)

      {
        source_index: @source_index,
        fields:       fields,
        items:        items,
        confidence:   average(direct_confidences)
      }
    end

    # role 決定買方 / 賣方哪個是我方。電子發票 QR 沒有名稱，InvoiceQr 用它補名稱。
    def party_names
      seller, buyer = name("seller_name"), name("buyer_name")
      @role == "income" ? { our_name: seller, counterparty_name: buyer } : { our_name: buyer, counterparty_name: seller }
    end

    private

    def confidence_of(*keys)
      keys.any? { |key| @uncertain.include?(key) } ? LOW : HIGH
    end

    def incurred_at
      text = @data["incurred_at"]
      return nil unless text.is_a?(String) && text.match?(ISO_DATE)
      date = Date.strptime(text, "%Y-%m-%d")
      date.year.between?(MIN_YEAR, Date.current.year + 1) ? date.iso8601 : nil
    rescue ArgumentError # Date::Error 是它的子類別
      nil
    end

    # 字軌 2 碼英文 + 號碼 8 碼數字，兩個都通過才採用；免用統一發票收據不會有發票號碼。
    def invoice_number
      prefix = text_value(@data["invoice_prefix"])&.upcase&.delete("-")
      digits = text_value(@data["invoice_digits"])
      return [ nil, nil ] if @data["document_type"] == "receipt"
      return [ nil, nil ] unless prefix&.match?(INVOICE_PREFIX) && digits&.match?(INVOICE_DIGITS)
      [ prefix, digits ]
    end

    # 有發票號碼 → 發票；沒有號碼時依模型判斷收據（沒讀到號碼不等於收據）。
    def document_type(invoice_prefix)
      return "invoice" if invoice_prefix
      "receipt" if @data["document_type"] == "receipt"
    end

    # 8 碼數字且通過統編檢查碼才採用。
    def tax_id(key)
      value = text_value(@data[key])
      value if value&.match?(TAX_ID) && self.class.valid_tax_id?(value)
    end

    def name(key)
      text_value(@data[key])
    end

    # 模型回的文字是不可信輸入：不是字串就捨棄；控制字元（含 \u0000，PostgreSQL 存不了）換成空白；
    # 長度超過上限的捨棄。
    def text_value(value)
      return nil unless value.is_a?(String)
      text = self.class.normalize_text(value.gsub(/[[:cntrl:]]/, " "))
      text if text && text.length <= MAX_NAME_LENGTH
    end

    # 未稅、含稅要是正整數；稅額可為 0（免稅）。總計比未稅小是讀錯，未稅與稅額都不用。
    def amounts
      pre_tax = integer(@data["pre_tax_amt"], min: 1)
      tax     = integer(@data["tax_amt"], min: 0)
      amount  = integer(@data["amount"], min: 1)
      pre_tax, tax = nil, nil if pre_tax && amount && amount < pre_tax
      [ pre_tax, tax, amount ]
    end

    # 只收「單價 × 數量 = 小計」對得上的明細；對不上或欄位缺漏的略過。
    def line_items
      Array(@data["items"]).first(MAX_ITEMS).filter_map do |raw|
        next unless raw.is_a?(Hash)
        name = text_value(raw["name"])
        quantity, unit_price, subtotal = integer(raw["quantity"], min: 1), integer(raw["unit_price"], min: 0), integer(raw["subtotal"], min: 0)
        next unless name && quantity && unit_price && subtotal
        next unless unit_price * quantity == subtotal

        { name: name, quantity: quantity, unit_price: unit_price, subtotal: subtotal }
      end
    end

    # 整數且在範圍內才回傳；字串、小數、負數、超大值都回 nil。
    def integer(value, min:)
      return nil unless value.is_a?(Numeric) && value == value.to_i
      value = value.to_i
      value if value.between?(min, MAX_AMOUNT)
    end

    def average(values)
      return nil if values.empty?
      (values.sum / values.size).round(4)
    end
  end
end
