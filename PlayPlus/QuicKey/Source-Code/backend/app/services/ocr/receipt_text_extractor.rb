module Ocr
  # 從單一檔案的 Document AI 全文（Enterprise OCR）用規則抓台灣憑證欄位。見 docs/OCR辨識規格.md §3.1。
  #
  # 回傳：
  #   {
  #     source_index: 0,
  #     page_count:   1,
  #     fields: { incurred_at: { value: "2026-10-15", confidence: 0.9 }, ... },  # 只放抓到的欄位
  #     items:  [ { name:, quantity:, unit_price:, subtotal: }, ... ],
  #     confidence: 0.83   # 本檔直接抓到的欄位信心度平均；推導欄位（documentType / taxRate）不計入
  #   }
  #
  # 原則：
  # - 不依賴文字排列順序（不同 processor 讀出的行序不同），只看「標籤」和緊接在它後面的值。
  # - 抓不到就不放；同一欄位抓到兩個以上不同的值也不放（不猜）。
  # - 信心度用固定值：規則明確的欄位 HIGH，名稱 / 品項這類推測的欄位 LOW。
  #
  # role 決定「我方 / 對方」：expense / reimbursement 我方是買方、對方是賣方；income 反過來。
  class ReceiptTextExtractor
    ROLES = %w[expense reimbursement income].freeze

    HIGH = 0.9
    LOW  = 0.5

    # 2 碼英文字軌 + 8 碼數字，中間可能有 - 或一個空白
    INVOICE_NUMBER = /(?<![A-Za-z])([A-Z]{2})([- ]?)(\d{8})(?!\d)/
    # 號碼前面緊接這些字樣時是單號，不是發票號碼（例如「銷帳編號 ST12345678」）
    NOT_INVOICE_BEFORE = /(?:單號|編號|序號|流水號|訂單|帳號|卡號)[\s:]*\z/
    # 西元 2026-10-19、2026/10/19、2026 10 11；民國 100年12月21日、115/10/15。
    # 電子發票的期別「115年09-10月」沒有「日」，不會被當成日期。
    # 西元也可寫成 2026年10月15日。民國斜線格式前後不能緊接 /、英文字母或數字（避免規格尺寸 100/12/31）。
    DATE_PATTERNS = [
      /(?<!\d)(20\d{2})[\/\-. ](\d{1,2})[\/\-. ](\d{1,2})(?!\d)/,
      /(?<!\d)(\d{2,4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日/,
      /(?<![\/A-Za-z\d])(\d{3})\/(\d{1,2})\/(\d{1,2})(?![\/A-Za-z\d])/
    ].freeze
    # 換算成西元後，年份要在這之後、且不超過今年 + 1 年
    MIN_YEAR = 2000
    # 標籤後面接的 8 碼統編（中間可夾冒號、空白、換行）；「買方統編」「買受人統一編號」也算這種寫法。
    # 歸屬看號碼所在那一行、號碼前面最近的「買方 / 買受人 / 賣方」，見 #tax_ids。
    LABELED_TAX_ID = /(賣方|買方|買受人|統編|(?<![A-Za-z])No)[\s:.]*(?:統編|統一編號)?[\s:.]*(\d{8})(?!\d)/
    PARTY_LABEL    = /買方|買受人|賣方/
    # 判斷統編歸屬時只往前看這麼多字（不隨單行長度變慢）；「買受人 公司名稱 統編 」一般在 40 字內
    PARTY_LOOKBEHIND = 40
    # 統編檢查碼權重（財政部規則：各位數乘權重後，把乘積的十位與個位相加）
    TAX_ID_WEIGHTS = [ 1, 2, 1, 2, 1, 2, 4, 1 ].freeze
    # 「統一編號」與號碼之間可能被印章裡的零星字（例如「行」）隔開。
    # 換行前後只吃「不含換行的空白」、零星字不含空白，三段互不重疊，找不到號碼時才不會回溯爆量。
    UNIFIED_TAX_ID = /統一編號((?:[^\S\n]*\n[^\S\n]*[^\s\d]{1,2})*)[\s:]*(\d{8})(?!\d)/
    # 名稱：公司全名或行號
    COMPANY_NAME = /(股份有限公司|有限公司|企業社|商行|商號)/
    # 名稱前面的標籤、後面的統編字樣都要去掉；No 要看字界，不能把 Nobel 這類英文名砍掉
    NAME_LABEL = /\A(?:營業人|賣方|買受人)(?:名稱|姓名)?[\s:]*/
    BUYER_LABEL = /買受人(?:名稱|姓名)?[\s:]*(.*)\z/
    # 「買受人」後面空白時取下一行當買方名稱，但那一行不能有數字，也不能是表頭欄位
    NOT_BUYER_NEXT_LINE = /\d|\A(?:日期|品名|數量|單價|金額|地址|統一編號)/
    NAME_TAIL  = /\s*(?:(?<![A-Za-z])No(?![A-Za-z])|統編|統一編號)[\s:.]*\d*.*\z/
    # 含電話、地址、6 碼以上連續數字，或店章字樣（「營業人蓋用統一發票專用章」）的行不當名稱
    NOT_NAME   = /TEL|電話|傳真|FAX|地址|專用章|蓋用|\d{6,}|\d{3,4}-\d{4}/i
    # 金額標籤；「合計新臺幣 … 元整」也由「合計」涵蓋
    AMOUNT_LABELS  = %w[總計 合計 實收金額 應收].freeze
    # 「銷售額合計」「稅額合計」是未稅 / 稅額，不是含稅金額
    AMOUNT_EXCLUDES = %w[銷售額 稅額 營業稅 數量合計 件數合計 數量總計 件數總計].freeze
    # 「共 3 項 合計 3」這類是件數，不是金額
    ITEM_COUNT = /共\s*\d+\s*[項件]/
    # 「總計(含營業稅)」的「含營業稅」只是說明，比對標籤前先拿掉，避免被當成稅額標籤或被排除
    TAX_INCLUDED_NOTE = /[(（]\s*含\s*(?:營業)?稅\s*[)）]|含\s*(?:營業)?稅/
    PRE_TAX_LABELS  = %w[銷售額].freeze
    TAX_LABELS      = %w[營業稅額 營業稅 稅額].freeze
    # 同一行金額後面還接著這些標籤時（例如「銷售額 1200 稅額 60」），前面的數字照樣算同一行的值
    MONEY_LABELS    = (AMOUNT_LABELS + PRE_TAX_LABELS + TAX_LABELS).freeze
    # 標籤後面要找金額時，最多往下看幾行（7-11 的金額跟標籤隔了好幾行條碼）
    AMOUNT_LOOKAHEAD = 8
    # 往下找時遇到這些付款相關字樣就停止（後面是客人付的現金、找零，不是應付金額）
    LOOKAHEAD_STOP = /找零|現金|付款|信用卡|刷卡/
    # 金額值：可帶 $ 與千分位，最多 7 位數（更長的是條碼 / 序號）
    MONEY_VALUE = /\A\$?\s*(\d{1,3}(?:,\d{3})+|\d{1,7})\s*(?:元整?|TX)?\z/
    # 標籤同一行：開頭是金額，後面沒東西或接著另一個金額標籤
    LEADING_MONEY_VALUE = /\A\$?\s*(\d{1,3}(?:,\d{3})+|\d{1,7})(?!\d)\s*(?:元整?|TX)?(.*)\z/
    # 往下幾行找到的金額必須前面有「$」或後面接「元」，避免合計欄空白時抓到取餐編號等不相干的數字
    MARKED_MONEY_VALUE = /\A(?:\$\s*(\d{1,3}(?:,\d{3})+|\d{1,7})\s*(?:元整?|TX)?|(\d{1,3}(?:,\d{3})+|\d{1,7})\s*元整?)\z/
    # 固定格式明細：「品名 / $單價 *數量 / $小計」（同一行或分行）
    ITEM_LINE = /([^\n$]*[^\n\d\s$][^\n$]*?)\s*\n?\s*\$?(\d[\d,]*)\s*[*xX×]\s*(\d+)\s*\n?\s*\$?(\d[\d,]*)(?:TX)?(?=\s*(?:\n|\z))/

    ROC_YEAR_OFFSET = 1911
    BUSINESS_TAX    = 0.05
    TAX_TOLERANCE   = 0.005

    def self.call(document, role:, source_index:)
      new(document, role: role, source_index: source_index).call
    end

    # 只照名稱規則抓我方 / 對方名稱（多張發票時按頁抽名稱用，見 §3.2）。回傳 { our_name:, counterparty_name: }，抓不到為 nil。
    def self.party_names(text, role:)
      new({ "text" => text }, role: role, source_index: nil).party_names
    end

    # 每頁的文字：Document AI 的 pages[].layout.textAnchor 記的是全文裡的起訖位置（以字計，起點 0 時省略）。
    # 回傳陣列，順序同 pages；該頁沒有位置資料時為 nil。
    def self.page_texts(document)
      text = document.to_h["text"].to_s
      Array(document.to_h["pages"]).map do |page|
        segments = Array(page.dig("layout", "textAnchor", "textSegments"))
        next nil if segments.empty?
        segments.map { |s| text[s["startIndex"].to_i...s["endIndex"].to_i].to_s }.join
      end
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

    def initialize(document, role:, source_index:)
      @document     = document || {}
      @role         = role
      @source_index = source_index
      @text         = self.class.normalize_text(@document["text"]).to_s.gsub("\u3000", " ")
      @lines        = @text.lines.map(&:strip).reject(&:empty?)
    end

    def call
      fields = {}
      add = ->(key, value, confidence) { fields[key] = { value: value, confidence: confidence } unless value.nil? }

      tax_id = tax_ids
      party  = party_names
      ours, theirs = @role == "income" ? %i[seller buyer] : %i[buyer seller]

      add.call(:incurred_at, incurred_at, HIGH)
      add.call(:our_name, party[:our_name], LOW)
      add.call(:our_tax_id, *tax_id[ours])
      add.call(:counterparty_name, party[:counterparty_name], LOW)
      add.call(:counterparty_tax_id, *tax_id[theirs])

      prefix, digits = invoice_number
      add.call(:invoice_prefix, prefix, HIGH)
      add.call(:invoice_digits, digits, HIGH)

      add.call(:pre_tax_amt, money_after(PRE_TAX_LABELS).first, HIGH)
      add.call(:tax_amt, money_after(TAX_LABELS).first, HIGH)
      add.call(:amount, *money_after(AMOUNT_LABELS))

      items = line_items
      direct_confidences = fields.values.map { |f| f[:confidence] }
      direct_confidences << LOW if items.any?

      document_type = detect_document_type(prefix)
      add.call(:document_type, document_type, HIGH)
      tax_rate = self.class.derive_tax_rate(pre_tax: fields.dig(:pre_tax_amt, :value), tax: fields.dig(:tax_amt, :value),
                                            amount: fields.dig(:amount, :value), document_type: document_type)
      add.call(:tax_rate, tax_rate, HIGH)

      {
        source_index: @source_index,
        page_count:   Array(@document["pages"]).size,
        fields:       fields,
        items:        items,
        confidence:   average(direct_confidences)
      }
    end

    # role 決定買方 / 賣方哪個是我方
    def party_names
      seller, buyer = names
      @role == "income" ? { our_name: seller, counterparty_name: buyer } : { our_name: buyer, counterparty_name: seller }
    end

    private

    # 同一欄位所有候選值去重後只剩一個才採用；零個或兩個以上都回 nil。
    def only(values)
      unique = values.compact.uniq
      unique.size == 1 ? unique.first : nil
    end

    def incurred_at
      dates = DATE_PATTERNS.flat_map do |pattern|
        @text.scan(pattern).map do |year, month, day|
          year = year.to_i
          year += ROC_YEAR_OFFSET if year < ROC_YEAR_OFFSET
          next unless year.between?(MIN_YEAR, Date.current.year + 1)
          Date.new(year, month.to_i, day.to_i).iso8601
        rescue Date::Error
          nil
        end
      end
      only(dates)
    end

    # 全文要出現「發票」才採用；「免用統一發票」本身含「發票」二字，但這種收據不會有發票號碼，一律不抓。
    # 號碼前面緊接「單號 / 編號 / 序號 / 流水號 / 訂單 / 帳號 / 卡號」的不算。
    # 證明聯印的是 AB-12345678：優先採用帶 - 或字軌與數字相連的寫法，找不到時才用中間空白的寫法
    # （避免「TW 20261015」這類跟真號碼打架，或在沒有真號碼時被當成發票號碼）。
    def invoice_number
      return [ nil, nil ] if !@text.include?("發票") || @text.include?("免用統一發票")

      candidates = @text.to_enum(:scan, INVOICE_NUMBER).filter_map do
        match = Regexp.last_match
        next if text_before(match, 0, 10).match?(NOT_INVOICE_BEFORE)
        prefix, separator, digits = match.captures
        { number: [ prefix, digits ], spaced: separator == " " }
      end
      preferred = candidates.reject { |c| c[:spaced] }
      only((preferred.presence || candidates).map { |c| c[:number] }) || [ nil, nil ]
    end

    # 有發票號碼 → 發票；沒有號碼時，寫著「免用統一發票」、或有「收據」但沒有「發票」→ 收據；
    # 都不是 → nil（沒讀到號碼不等於收據；「統一發票 請留存收據」這類不算收據）。
    def detect_document_type(invoice_prefix)
      return "invoice" if invoice_prefix
      "receipt" if @text.include?("免用統一發票") || (@text.include?("收據") && !@text.include?("發票"))
    end

    # 回傳 { seller: [統編, 信心度], buyer: [統編, 信心度] }；沒通過檢查碼的 8 碼數字一律不採用。
    #
    # 歸屬（HIGH）：號碼所在那一行、號碼前面最近的是「買方 / 買受人」→ 買方，「賣方」→ 賣方；
    # 同一行沒有這些字時看標籤：「賣方 / 統編」→ 賣方、「買方 / 買受人」→ 買方。
    # 「統一編號」：印章（「專用章」字樣附近）裡的是賣方；緊接在「買受人」後面、或免用統一發票收據
    # 表頭格子裡的是買方。
    # 推測（LOW）：「No:」標籤，以及不符合上面任何位置、預設當賣方的「統一編號」。
    def tax_ids
      candidates = { seller: [], buyer: [] }

      @text.to_enum(:scan, LABELED_TAX_ID).each do
        match = Regexp.last_match
        label, tax_id = match[1], match[2]
        side = party_before(match, 2)
        if side
          candidates[side] << [ tax_id, HIGH ]
        elsif label == "No"
          candidates[:seller] << [ tax_id, LOW ]
        else
          candidates[%w[買方 買受人].include?(label) ? :buyer : :seller] << [ tax_id, HIGH ]
        end
      end

      receipt_form = @text.include?("免用統一發票收據")
      @text.to_enum(:scan, UNIFIED_TAX_ID).each do
        match = Regexp.last_match
        tax_id = match[2]
        before = text_before(match, 0, 30)
        if (side = party_before(match, 2))
          candidates[side] << [ tax_id, HIGH ]
        elsif before.include?("專用章")
          candidates[:seller] << [ tax_id, HIGH ]
        elsif receipt_form || before.include?("買受人")
          candidates[:buyer] << [ tax_id, HIGH ]
        else
          candidates[:seller] << [ tax_id, LOW ]
        end
      end

      candidates.transform_values do |list|
        list = list.select { |tax_id, _| self.class.valid_tax_id?(tax_id) }
        tax_id = only(list.map(&:first))
        # 同一個號碼被不同規則抓到時，有任一條明確規則（HIGH）就算 HIGH
        tax_id ? [ tax_id, list.select { |id, _| id == tax_id }.map(&:last).max ] : [ nil, nil ]
      end
    end

    # 號碼所在那一行、號碼前面 PARTY_LOOKBEHIND 字內最近的「買方 / 買受人 / 賣方」決定歸屬；沒有就回 nil。
    # 只切固定長度再找換行，避免很長的一行裡每個號碼都從行首重掃一次（平方時間）。
    def party_before(match, group)
      window = text_before(match, group, PARTY_LOOKBEHIND)
      window = window[((window.rindex("\n") || -1) + 1)..]
      label = window.scan(PARTY_LABEL).last
      return nil unless label
      label == "賣方" ? :seller : :buyer
    end

    # 比對位置前面最多 chars 個字。中文字串用「第幾個字」切時，Ruby 每次都要從頭數，長文字會變成平方時間；
    # 所以先用位元組位置切出一小段（一個字最多 4 個位元組），去掉被切斷的半個字，再取最後 chars 個字。
    def text_before(match, group, chars)
      stop  = match.byteoffset(group).first
      start = [ stop - chars * 4, 0 ].max
      @text.byteslice(start, stop - start).scrub("").last(chars)
    end

    # 買方：「買受人」後面的文字；標籤後面空白時，才取緊接的下一行（不能有數字、不能是表頭欄位）。
    # 賣方：含公司 / 行號字樣、或以「賣方 / 營業人」開頭的行；買受人下一行的名稱不算。
    #       都沒有時，取「電子發票證明聯」上一行的店名。
    def names
      buyers = []
      buyer_line_indexes = []
      @lines.each_with_index do |line, i|
        next unless (match = line.match(BUYER_LABEL))
        if match[1].strip.present?
          name = clean_name(match[1])
          buyers << name if name
        elsif (next_line = @lines[i + 1]) && !next_line.match?(NOT_BUYER_NEXT_LINE) && (name = clean_name(next_line))
          buyers << name
          buyer_line_indexes << i + 1
        end
      end

      sellers = @lines.each_with_index.filter_map do |line, i|
        next if buyer_line_indexes.include?(i) || line.include?("買")
        next unless line.match?(COMPANY_NAME) || line.match?(/\A(?:營業人|賣方)/)
        clean_name(line)
      end
      if sellers.empty? && (index = @lines.index { |l| l.include?("電子發票證明聯") })&.positive?
        sellers << clean_name(@lines[index - 1].sub(/\A序:?\s*/, ""))
      end

      [ only(sellers), only(buyers) ]
    end

    def clean_name(text)
      name = text.sub(NAME_LABEL, "").sub(NAME_TAIL, "").strip
      name.presence unless name.match?(NOT_NAME)
    end

    # 各標籤後面的金額，回傳 [金額, 信心度]。
    # - 標籤同一行開頭就是金額時一律採用、不再往下找：後面沒字或接著另一個金額標籤 → HIGH，還有其他字 → LOW。
    # - 同一行沒有金額時，往下 AMOUNT_LOOKAHEAD 行內找第一個「整行只有金額、且帶 $ 或元」的值，
    #   中途遇到付款相關字樣就停止。緊接的下一行 → HIGH（Enterprise OCR 常把標籤和金額拆成兩行），隔兩行以上 → LOW。
    # - 全文有「找零」時，「實收金額」是客人付的現金，不採用。
    # 所有標籤抓到的值要一致；同一個值被多個標籤抓到時取較高的信心度。
    def money_after(labels)
      found = []
      paid_in_cash = @text.include?("找零")
      @lines.each_with_index do |raw_line, i|
        line = raw_line.gsub(TAX_INCLUDED_NOTE, "")
        label = labels.find { |l| line.include?(l) }
        next unless label
        if labels == AMOUNT_LABELS
          next if AMOUNT_EXCLUDES.any? { |e| line.include?(e) } || line.match?(ITEM_COUNT)
          next if label == "實收金額" && paid_in_cash
        end

        rest = line.split(label, 2).last.sub(/\A[\s:]*(?:合計|總計|金額)?[\s:]*(?:新[臺台]幣)?[\s:]*/, "")
        if (same_line = same_line_money(rest))
          found << same_line
        elsif (below = money_below(i))
          found << below
        end
      end

      value = only(found.map(&:first))
      value ? [ value, found.select { |v, _| v == value }.map(&:last).max ] : [ nil, nil ]
    end

    def money_below(index)
      @lines[(index + 1), AMOUNT_LOOKAHEAD].to_a.each_with_index do |line, offset|
        break if line.match?(LOOKAHEAD_STOP)
        value = money_value(line, MARKED_MONEY_VALUE)
        return [ value, offset.zero? ? HIGH : LOW ] if value
      end
      nil
    end

    def same_line_money(rest)
      match = rest.match(LEADING_MONEY_VALUE)
      return nil unless match
      tail = match[2].strip
      clean = tail.empty? || MONEY_LABELS.any? { |l| tail.start_with?(l) }
      [ match[1].delete(",").to_i, clean ? HIGH : LOW ]
    end

    def money_value(text, pattern = MONEY_VALUE)
      match = text.to_s.strip.match(pattern)
      match && match.captures.compact.first.delete(",").to_i
    end

    # 只收「單價 × 數量 = 小計」對得上的固定格式明細；品名前面的商品代碼去掉。格式不固定就回 []。
    def line_items
      @text.scan(ITEM_LINE).filter_map do |name, unit_price, quantity, subtotal|
        unit_price, quantity, subtotal = [ unit_price, quantity, subtotal ].map { |v| v.delete(",").to_i }
        next unless quantity.positive? && unit_price * quantity == subtotal

        name = name.strip.sub(/\A\d{4,}\s+/, "").sub(/[-\s]+\z/, "")
        next if name.empty?

        { name: name, quantity: quantity, unit_price: unit_price, subtotal: subtotal }
      end
    end

    def average(values)
      return nil if values.empty?
      (values.sum / values.size).round(4)
    end
  end
end
