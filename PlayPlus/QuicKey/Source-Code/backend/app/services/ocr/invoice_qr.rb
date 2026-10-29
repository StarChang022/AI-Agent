module Ocr
  # 把 QrScanner 解出的 QR 內容整理成電子發票。見 docs/OCR辨識規格.md §3.2。
  #
  # 回傳：[ { invoice_prefix:, invoice_digits:, incurred_at:, pre_tax_amt:, tax_amt:, amount:,
  #           buyer_tax_id:, seller_tax_id:, page:, items: [...] }, ... ]
  #       依左邊 QR 在檔案裡的順序（頁序、由上到下、由左到右）；號碼相同的只留第一張。page 是左邊 QR 所在頁（從 0 開始）。
  #       items 只有筆數對得上才有值，否則為 []；pre_tax_amt / tax_amt / buyer_tax_id 可能為 nil。
  #
  # 左邊 QR（財政部〈電子發票證明聯一維及二維條碼規格說明〉）：
  #   發票號碼 10 + 民國日期 7 + 隨機碼 4 + 銷售額 16 進位 8 + 總計 16 進位 8 + 買方統編 8 + 賣方統編 8 + 加密驗證 24，
  #   之後以「:」分隔：營業人自用區 : 左右 QR 合計記載的品項筆數 : 發票總品項筆數 : 中文編碼 : 品名 : 數量 : 單價 : …
  # 右邊 QR 以「**」開頭，接續左邊放不下的品項。
  # 號碼、日期、賣方統編、金額（總計 > 0 且 ≥ 銷售額）任一項檢查不通過，整個 QR 不採用。
  # 銷售額 = 總計時分不出是免稅還是收銀機填錯，跟 00000000 一樣不填未稅 / 稅額（稅率因此也不推導）。
  # 買方統編沒通過檢查碼時只丟掉買方統編。品項區出任何錯只讓 items 為 []，不影響表頭欄位。
  class InvoiceQr
    LEFT = /\A([A-Z]{2})(\d{8})(\d{3})(\d{2})(\d{2})\d{4}(\h{8})(\h{8})(\d{8})(\d{8})[A-Za-z0-9+\/=]{24}/n
    RIGHT_PREFIX = "**".b
    NO_BUYER     = "00000000"
    NO_PRE_TAX   = "00000000"
    # 中文編碼參數：0 = Big5、1 = UTF-8、2 = Base64、3 = 境外電商 UTF-8；Base64 的品名不解，不用 QR 的品項。
    # Big5 用 CP950（微軟碼表，台灣 POS 多半用這個），無法轉換的字比 Ruby 的 Big5 少很多。
    ENCODINGS = { "0" => Encoding::CP950, "1" => Encoding::UTF_8, "3" => Encoding::UTF_8 }.freeze
    # 數量 / 單價：最多 9 位整數、4 位小數（擋掉幾百位數的異常值）
    NUMBER = /\A\d{1,9}(?:\.\d{1,4})?\z/

    # QR 有的欄位：以 QR 為準，蓋掉 ReceiptTextExtractor 從全文抽到的值（QR 沒有的值也不留全文的）
    FIELDS = %i[invoice_prefix invoice_digits incurred_at pre_tax_amt tax_amt amount
                our_tax_id counterparty_tax_id document_type tax_rate].freeze
    # QR 沒有名稱；多張發票時改從發票所在那一頁的文字抽，放進每張發票的 fields
    NAME_FIELDS = %i[our_name counterparty_name].freeze

    def self.call(codes)
      new(codes).call
    end

    # 把這個檔案解出的發票套進 ReceiptTextExtractor 的結果（result 為 nil 時從空結果開始）。
    # - 每張發票整理成 { source_index:, invoice_index:, fields: { 欄位: 值 }, items: } 放進 result[:invoices]，
    #   給 ResultMerger 判斷要不要回 conflicts.invoices。fields 除了 QR 的欄位，還有按頁抽到的名稱（見 names_by_page）。
    # - 只有 1 張：FIELDS 改用 QR 的值（信心度 HIGH）；QR 品項齊全時取代全文抽到的品項。名稱照全文抽到的。
    # - 2 張以上：這個檔案的 FIELDS 和品項都清掉，交給使用者整張挑一張。
    def self.apply(result, invoices, role:, source_index:, document:)
      result ||= { source_index: source_index, page_count: 0, fields: {}, items: [], confidence: nil }
      return result if invoices.empty?

      names = names_by_page(document, invoices, role)
      entries = invoices.each_with_index.map do |invoice, i|
        fields = fields_for(invoice, role).merge(NAME_FIELDS.index_with(nil)).merge(names[invoice[:page]].to_h)
        { source_index: source_index, invoice_index: i + 1, fields: fields, items: invoice[:items] }
      end
      fields = result[:fields].except(*FIELDS)
      items  = []
      if entries.one?
        entry = entries.first
        entry[:fields].slice(*FIELDS).compact.each { |key, value| fields[key] = { value: value, confidence: ReceiptTextExtractor::HIGH } }
        items = entry[:items].presence || result[:items]
      end

      direct = fields.except(:document_type, :tax_rate).values.map { |f| f[:confidence] }
      direct << (items.equal?(result[:items]) ? ReceiptTextExtractor::LOW : ReceiptTextExtractor::HIGH) if items.any?
      result.merge(fields: fields, items: items, invoices: entries,
                   confidence: direct.empty? ? nil : (direct.sum / direct.size).round(4))
    end

    def self.fields_for(invoice, role)
      ours, theirs = role == "income" ? invoice.values_at(:seller_tax_id, :buyer_tax_id) : invoice.values_at(:buyer_tax_id, :seller_tax_id)
      fields = invoice.slice(:invoice_prefix, :invoice_digits, :incurred_at, :pre_tax_amt, :tax_amt, :amount)
                      .merge(our_tax_id: ours, counterparty_tax_id: theirs, document_type: "invoice")
      fields.merge(tax_rate: ReceiptTextExtractor.derive_tax_rate(pre_tax: fields[:pre_tax_amt], tax: fields[:tax_amt],
                                                                  amount: fields[:amount], document_type: "invoice"))
    end
    private_class_method :fields_for

    # 每頁的名稱：{ 頁: { our_name:, counterparty_name: } }。只從發票所在那一頁的文字照 §3.1 抽（規則推測，信心度低）。
    # 同一頁有 2 張以上發票時分不出名稱屬於哪張，那一頁不填（寧可空白，不帶錯的店名）。
    # 名稱是加分項，出任何錯都當作抽不到。
    def self.names_by_page(document, invoices, role)
      texts = ReceiptTextExtractor.page_texts(document)
      invoices.group_by { |invoice| invoice[:page] }.to_h do |page, same_page|
        text = texts[page]
        [ page, same_page.one? && text.present? ? ReceiptTextExtractor.party_names(text, role: role) : {} ]
      end
    rescue StandardError => e
      Rails.logger.info("[ocr] page names skipped: #{e.class}")
      {}
    end
    private_class_method :names_by_page

    def initialize(codes)
      @codes = codes
    end

    def call
      lefts  = @codes.filter_map { |code| parse_left(code) }
      rights = right_by_left(lefts)
      invoices = lefts.map { |left| left[:invoice].merge(items: safe_items(left, rights[left])) }
      invoices.uniq { |inv| inv.values_at(:invoice_prefix, :invoice_digits) }
    end

    private

    def parse_left(code)
      data  = code[:data].b
      match = data.match(LEFT)
      return nil unless match

      # 比對出來的字串是 ASCII-8BIT；轉成 UTF-8，之後存 DB 或接中文字串才不會出錯
      prefix, digits, year, month, day, pre_tax_hex, total_hex, buyer, seller =
        match.captures.map { |value| value.dup.force_encoding(Encoding::UTF_8) }
      incurred_at = roc_date(year, month, day)
      pre_tax     = pre_tax_hex == NO_PRE_TAX ? nil : pre_tax_hex.to_i(16)
      amount      = total_hex.to_i(16)
      return nil unless incurred_at && ReceiptTextExtractor.valid_tax_id?(seller) &&
                        amount.positive? && amount >= pre_tax.to_i
      pre_tax = nil if pre_tax == amount

      segments = data.byteslice(match.end(0)..).split(":".b, -1).drop(1)
      {
        code:    code,
        counts:  segments[1..2].to_a.map { |s| s.match?(/\A\d+\z/n) ? s.to_i : nil },
        encoding: ENCODINGS[segments[3]],
        segments: segments.drop(4),
        invoice: {
          invoice_prefix: prefix,
          invoice_digits: digits,
          incurred_at:    incurred_at,
          pre_tax_amt:    pre_tax,
          tax_amt:        pre_tax && amount - pre_tax,
          amount:         amount,
          buyer_tax_id:   buyer != NO_BUYER && ReceiptTextExtractor.valid_tax_id?(buyer) ? buyer : nil,
          seller_tax_id:  seller,
          page:           code[:page]
        }
      }
    end

    def roc_date(year, month, day)
      date = Date.new(year.to_i + ReceiptTextExtractor::ROC_YEAR_OFFSET, month.to_i, day.to_i)
      date.iso8601 if date.year.between?(ReceiptTextExtractor::MIN_YEAR, Date.current.year + 1)
    rescue Date::Error
      nil
    end

    # 每個右邊 QR 配給同一頁、距離最近的左邊 QR（一頁通常只有一張發票）；一個左邊 QR 只配一個右邊 QR
    def right_by_left(lefts)
      pairs = {}.compare_by_identity
      @codes.select { |code| code[:data].b.start_with?(RIGHT_PREFIX) }.each do |right|
        left = lefts.select { |l| l[:code][:page] == right[:page] }
                    .min_by { |l| (l[:code][:x] - right[:x])**2 + (l[:code][:y] - right[:y])**2 }
        pairs[left] ||= right if left
      end
      pairs
    end

    # 品項是加分項：品項區任何錯（例如超長數字、編碼問題）都只讓 items 為 []
    def safe_items(left, right)
      items(left, right)
    rescue StandardError => e
      Rails.logger.info("[ocr] qr items skipped: #{e.class}")
      []
    end

    # 「左右 QR 合計記載的品項筆數」=「發票總品項筆數」，而且實際解出的筆數也一樣，才用 QR 的品項。
    # 每 3 段一筆「品名:數量:單價」，遇到湊不成一筆的段落（補充說明）就停。
    def items(left, right)
      listed, total = left[:counts]
      encoding = left[:encoding]
      return [] unless encoding && listed&.positive? && listed == total

      segments = triplets(left[:segments], encoding)
      segments += triplets(right[:data].b.delete_prefix(RIGHT_PREFIX).delete_prefix(":".b).split(":".b, -1), encoding) if right
      return [] unless segments.size == listed

      segments.map do |name, quantity, unit_price|
        { name: name, quantity: quantity, unit_price: unit_price, subtotal: (quantity * unit_price).round }
      end
    end

    def triplets(segments, encoding)
      segments.each_slice(3).take_while do |name, quantity, unit_price|
        quantity.to_s.match?(NUMBER) && unit_price.to_s.match?(NUMBER) && text(name, encoding).present?
      end.map do |name, quantity, unit_price|
        [ text(name, encoding), number(quantity), number(unit_price) ]
      end
    end

    def text(bytes, encoding)
      value = bytes.to_s.dup.force_encoding(encoding)
      return nil unless value.valid_encoding?
      ReceiptTextExtractor.normalize_text(value.encode(Encoding::UTF_8, undef: :replace, replace: "").gsub("　", " "))
    end

    def number(value)
      value.include?(".") ? value.to_f : value.to_i
    end
  end
end
