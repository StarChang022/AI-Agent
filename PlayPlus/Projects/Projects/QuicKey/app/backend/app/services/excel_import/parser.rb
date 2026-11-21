module ExcelImport
  # Excel 匯入解析（docs/資料模型.md §5.4）。分五段：讀表（SheetReader）→ 欄位對應
  # （ColumnMapper）→ 值轉換（ValueParser）→ 檢查（本類別）→ 產生紀錄（Importer）。
  # 本類別只解析不寫入，preview 與 import 共用；import 會重新解析同一檔案。
  #
  # 每筆單據（Record）的狀態：
  # - ok       可匯入
  # - warning  可匯入，但補了預設值或需要留意（messages 為說明）
  # - skipped  不匯入（messages 為原因）
  class Parser
    Message = Data.define(:row, :text)

    Record = Struct.new(:rows, :status, :attrs, :items, :category_name, :category, :account_name, :account,
                        :outside_cash_flow, :messages, keyword_init: true) do
      def importable? = status != "skipped"
    end

    # 需要使用者對應的類別：state 為 missing（找不到）、archived（同名類別已停用）、
    # discarded（同名類別在垃圾桶）、blank（未填類別）。key 為比對用的小寫名稱，name 為第一次出現的寫法。
    # creatable：可否選「新增此類別」（只有找不到且名稱不超過上限的才可以）。
    CategoryEntry = Struct.new(:key, :name, :rows, :state, :archived_category, :creatable, keyword_init: true)

    # 需要使用者對應的帳戶：state 為 missing（找不到）或 discarded（在垃圾桶）。
    # 只能對應到既有帳戶，不提供新增。key 為比對用的小寫名稱，name 為第一次出現的寫法。
    AccountEntry = Struct.new(:key, :name, :rows, :state, keyword_init: true)

    Result = Data.define(:total_rows, :records, :categories, :accounts) do
      def importable = records.select(&:importable?)
    end

    # 同 Category 的名稱長度上限；超過的名稱不能新增，只能對應既有類別。
    CATEGORY_NAME_MAX = 50

    TAX_RATE_WORDS = {
      "應稅" => "business_5", "應稅5%" => "business_5", "5%" => "business_5", "0.05" => "business_5",
      "免稅" => "exempt_0", "0%" => "exempt_0", "0" => "exempt_0"
    }.freeze
    DOCUMENT_TYPE_WORDS = { "發票" => "invoice", "收據" => "receipt" }.freeze

    def initialize(schema:, user:)
      @schema  = schema
      @user    = user
      @company = user.company
    end

    def parse(upload, column_mapping: nil)
      @accounts = @company.accounts.kept.index_by { |a| a.name.downcase }
      raise Error.new("NO_ACCOUNTS", Account::NO_ACCOUNTS_MESSAGE) if @accounts.empty?

      sheet = SheetReader.read(upload)
      @index = ColumnMapper.map(sheet.headers, @schema, column_mapping)
      raise Error.new("NO_DATA_ROWS", "檔案沒有任何資料列") if sheet.rows.empty?

      @last_used_account = @user.last_used_account
      records = group(sheet.rows).map { |rows| build_record(rows) }
      categories = resolve_categories(records)
      accounts = resolve_accounts(records)
      Result.new(total_rows: sheet.rows.size, records: records, categories: categories, accounts: accounts)
    end

    private

    # 單據編號相同的列合併成一筆（不需相鄰）；空白的列自成一筆。依第一次出現的順序。
    def group(rows)
      groups = {}
      rows.each do |number, cells|
        ref = ValueParser.text(cell(cells, :doc_ref))
        (groups[ref ? "ref:#{ref}" : "row:#{number}"] ||= []) << [ number, cells ]
      end
      groups.values
    end

    def cell(cells, key)
      position = @index[key]
      position && cells[position]
    end

    def header(key)
      @schema.header(key)
    end

    def build_record(rows)
      @skips = []
      @warns = []
      first_no, first = rows.first

      check_conflicting_master(rows)

      document_type = parse_document_type(first_no, first)
      invoice_date = parse_invoice_date(first_no, first, document_type)
      date = parse_date(first_no, first, document_type, invoice_date)
      planned_date = parse_planned_date(first_no, first)
      party = parse_party(first_no, first)
      account = parse_account(first_no, first)
      tax_id = parse_tax_id(first_no, first, document_type)
      invoice_no = parse_invoice_no(first_no, first, document_type)
      tax_rate = parse_tax_rate(first_no, first, document_type)
      pre_tax_amt, tax_amt, amount = parse_amounts(first_no, first, tax_rate)
      items = rows.filter_map { |no, cells| build_item(no, cells) }
      check_items_total(first_no, pre_tax_amt, amount, items)
      status = parse_status(first_no, first)
      settled_at = parse_settled_at(first_no, first, status, date)
      outside_cash_flow = check_opening_month(first_no, account, settled_at)

      Record.new(
        rows: rows.map(&:first),
        status: @skips.any? ? "skipped" : (@warns.any? ? "warning" : "ok"),
        attrs: {
          date: date, invoice_date: invoice_date, planned_date: planned_date, party: party,
          amount: amount, tax_rate: tax_rate,
          pre_tax_amt: pre_tax_amt, tax_amt: tax_amt, tax_id: tax_id, invoice_no: invoice_no,
          document_type: document_type, status: status, settled_at: settled_at,
          note: ValueParser.text(cell(first, :note))
        },
        items: items,
        category_name: ValueParser.text(cell(first, :category)),
        account_name: ValueParser.text(cell(first, :account)),
        account: account,
        outside_cash_flow: outside_cash_flow,
        messages: (@skips.any? ? @skips : @warns).each_with_index.sort_by { |m, i| [ m.row, i ] }.map(&:first)
      )
    end

    def skip(row, text) = @skips << Message.new(row: row, text: text)
    def warn(row, text) = @warns << Message.new(row: row, text: text)

    # 主檔欄位以第一列為準；後面的列有填且不同時列出。
    def check_conflicting_master(rows)
      first_no, first = rows.first
      rows.drop(1).each do |no, cells|
        Schema::MASTER_KEYS.each do |key|
          value = ValueParser.text(cell(cells, key))
          next if value.nil? || value == ValueParser.text(cell(first, key))
          warn(no, "「#{header(key)}」與第 #{first_no} 列不同，以第 #{first_no} 列為準")
        end
      end
    end

    # 發生日期：發票空白時帶發票日期（正常用法，不列出）；收據空白或看不懂 → 不匯入。
    # 文件類型看不懂時已經不匯入，空白不再多列一則。
    def parse_date(no, cells, document_type, invoice_date)
      raw = cell(cells, :date)
      if ValueParser.blank?(raw)
        return invoice_date if document_type == "invoice" && invoice_date
        skip(no, "#{header(:date)}未填") if document_type == "receipt"
        return nil
      end

      date = ValueParser.date(raw)
      skip(no, "#{header(:date)}「#{ValueParser.text(raw)}」無法判讀") if date.nil?
      date
    end

    # 發票日期：發票必填，空白或看不懂 → 不匯入。收據不帶入，有填則列出。
    def parse_invoice_date(no, cells, document_type)
      raw = cell(cells, :invoice_date)
      if document_type != "invoice"
        warn(no, "收據沒有#{header(:invoice_date)}，未帶入") if document_type && !ValueParser.blank?(raw)
        return nil
      end

      date = ValueParser.date(raw)
      if ValueParser.blank?(raw)
        skip(no, "發票的#{header(:invoice_date)}未填")
      elsif date.nil?
        skip(no, "#{header(:invoice_date)}「#{ValueParser.text(raw)}」無法判讀")
      end
      date
    end

    # 應付／應收日期：空白依預設規則（由 Importer 照手動新增計算）；看不懂 → 依預設規則並列出。
    def parse_planned_date(no, cells)
      raw = cell(cells, :planned_date)
      return nil if ValueParser.blank?(raw)

      date = ValueParser.date(raw)
      warn(no, "#{header(:planned_date)}「#{ValueParser.text(raw)}」無法判讀，依預設規則帶入") if date.nil?
      date
    end

    def parse_document_type(no, cells)
      raw = ValueParser.text(cell(cells, :document_type))
      type = raw && DOCUMENT_TYPE_WORDS[raw.delete(" ")]
      if raw.nil?
        skip(no, "#{header(:document_type)}未填")
      elsif type.nil?
        skip(no, "#{header(:document_type)}「#{raw}」無法判讀，請填發票或收據")
      end
      type
    end

    def parse_party(no, cells)
      party = ValueParser.text(cell(cells, :party))
      skip(no, "#{header(:party)}未填") if party.nil?
      party
    end

    # 帳戶：有填就比對本公司未刪除的帳戶，找不到的名稱之後由使用者對應（resolve_accounts）；
    # 空白帶上一次使用的帳戶。
    def parse_account(no, cells)
      name = ValueParser.text(cell(cells, :account))
      return @accounts[name.downcase] if name

      skip(no, "#{header(:account)}未填，且沒有上一次使用的帳戶") if @last_used_account.nil?
      @last_used_account
    end

    # 收付款日早於帳戶起始月份照常匯入，列出提醒，回傳是否不計入現金流。要使用者對應帳戶的
    # 單據，預覽時還不知道帳戶，回 nil，由 Importer 算進完成畫面的筆數。
    def check_opening_month(no, account, settled_at)
      return nil if account.nil?
      return false unless settled_at && settled_at < account.opening_month

      warn(no, "#{header(:settled_at)}早於帳戶「#{account.name}」的起始月份，不計入現金流")
      true
    end

    # 品項：品項欄全空 = 沒有品項。數量空白視為 1；小計空白 = 數量 × 單價；
    # 只有小計時單價 = 小計 ÷ 數量。品名空白、數量看不懂或 ≤ 0、算不出小計或
    # 小計超過上限的品項不匯入並列出。
    def build_item(no, cells)
      raws = Schema::ITEM_KEYS.index_with { |key| cell(cells, key) }
      return nil if raws.values.all? { |v| ValueParser.blank?(v) }

      name = ValueParser.text(raws[:item_name])
      if name.nil?
        warn(no, "品項的#{header(:item_name)}空白，此品項未匯入")
        return nil
      end

      quantity = BigDecimal("1")
      unless ValueParser.blank?(raws[:item_quantity])
        quantity = ValueParser.decimal(raws[:item_quantity])
        if quantity.nil?
          warn(no, "品項「#{name}」的#{header(:item_quantity)}「#{ValueParser.text(raws[:item_quantity])}」無法判讀，此品項未匯入")
          return nil
        elsif quantity <= 0
          warn(no, "品項「#{name}」的#{header(:item_quantity)}需大於 0，此品項未匯入")
          return nil
        end
      end

      unit_price = item_amount(no, raws[:item_unit_price], :item_unit_price)
      subtotal   = item_amount(no, raws[:item_subtotal], :item_subtotal)
      subtotal ||= (quantity * unit_price).round(2) if unit_price
      unit_price ||= (subtotal / quantity).round(2) if subtotal
      if subtotal.nil?
        warn(no, "品項「#{name}」算不出小計，此品項未匯入")
        return nil
      elsif subtotal > ValueParser::MAX_MONEY
        warn(no, "品項「#{name}」的小計超過金額上限，此品項未匯入")
        return nil
      end

      { name: name, quantity: quantity, unit_price: unit_price, subtotal: subtotal }
    end

    # 單價、小計：≥ 0 且不超過金額上限；看不懂視為空白並列出。
    def item_amount(no, raw, key)
      return nil if ValueParser.blank?(raw)
      value = ValueParser.decimal(raw)
      value = nil unless value && value >= 0 && value <= ValueParser::MAX_MONEY
      warn(no, "品項的#{header(key)}「#{ValueParser.text(raw)}」無法判讀") if value.nil?
      value
    end

    # 統一編號：支出發票必填且須通過檢查碼，否則不匯入；支出收據與所有收入選填，無效則不帶入並列出。
    def parse_tax_id(no, cells, document_type)
      raw = cell(cells, :tax_id)
      blank = ValueParser.blank?(raw)
      tax_id = blank ? nil : ValueParser.tax_id(raw)

      if document_type == "invoice" && @schema.kind == "expense"
        if blank
          skip(no, "發票須填#{header(:tax_id)}")
        elsif tax_id.nil?
          skip(no, "#{header(:tax_id)}「#{ValueParser.text(raw)}」格式不正確")
        end
      elsif !blank && tax_id.nil?
        warn(no, "#{header(:tax_id)}「#{ValueParser.text(raw)}」格式不正確，未帶入")
      end
      tax_id
    end

    # 發票號碼：發票必填且格式正確，否則不匯入；收據不帶入（有填則列出）。
    def parse_invoice_no(no, cells, document_type)
      raw = cell(cells, :invoice_no)
      blank = ValueParser.blank?(raw)

      if document_type == "receipt"
        warn(no, "收據不需要#{header(:invoice_no)}，「#{ValueParser.text(raw)}」未帶入") unless blank
        return nil
      end

      invoice_no = blank ? nil : ValueParser.invoice_no(raw)
      if document_type == "invoice"
        if blank
          skip(no, "發票須填#{header(:invoice_no)}")
        elsif invoice_no.nil?
          skip(no, "#{header(:invoice_no)}「#{ValueParser.text(raw)}」格式不正確")
        end
      end
      invoice_no
    end

    # 收據一律免稅（同手動新增）：空白不列出，填了其他稅別改免稅並列出。
    # 發票：空白視為應稅，看不懂以應稅計並列出。
    def parse_tax_rate(no, cells, document_type)
      raw = ValueParser.text(cell(cells, :tax_rate))
      if document_type == "receipt"
        if raw && TAX_RATE_WORDS[raw.delete(" ")] != "exempt_0"
          warn(no, "收據一律免稅，#{header(:tax_rate)}「#{raw}」已改為免稅")
        end
        return "exempt_0"
      end
      return "business_5" if raw.nil?
      rate = TAX_RATE_WORDS[raw.delete(" ")]
      warn(no, "#{header(:tax_rate)}「#{raw}」無法判讀，以應稅計") if rate.nil?
      rate || "business_5"
    end

    # 未稅、含稅金額至少填一個，另一個依稅別推算（算法同手動新增）：
    # - 只填含稅：見 TaxAmounts.from_gross
    # - 只填未稅：稅額 = 未稅 × 稅率 四捨五入到整數，含稅 = 未稅 + 稅額
    # - 兩個都填：照填；應稅的未稅 > 含稅 → 不匯入；應稅的稅額與 未稅 × 稅率 相差超過 1 元
    #   → 照填並列出；免稅（含收據）不相等 → 以含稅為準並列出
    # 稅額欄只用來核對：有填但與推算結果不符 → 以推算為準並列出。
    # 回傳 [未稅, 稅額, 含稅]；不匯入時回 nil。
    def parse_amounts(no, cells, tax_rate)
      pre_raw, amount_raw = cell(cells, :pre_tax_amt), cell(cells, :amount)
      pre_blank, amount_blank = ValueParser.blank?(pre_raw), ValueParser.blank?(amount_raw)
      if pre_blank && amount_blank
        skip(no, "#{header(:pre_tax_amt)}與#{header(:amount)}至少要填一個")
        return [ nil, nil, nil ]
      end
      pre    = money_or_skip(no, pre_raw, :pre_tax_amt)
      amount = money_or_skip(no, amount_raw, :amount)
      return [ nil, nil, nil ] if (!pre_blank && pre.nil?) || (!amount_blank && amount.nil?)

      rate = TaxAmounts::RATES[tax_rate]
      if pre && amount
        if rate.zero? && pre != amount
          warn(no, "免稅的#{header(:pre_tax_amt)}與#{header(:amount)}不相等，以#{header(:amount)} #{format_money(amount)} 為準")
          pre = amount
        elsif pre > amount
          skip(no, "#{header(:pre_tax_amt)}大於#{header(:amount)}")
          return [ nil, nil, nil ]
        elsif !rate.zero? && ((amount - pre) - (pre * rate).round(0, BigDecimal::ROUND_HALF_UP)).abs > 1
          warn(no, "#{header(:pre_tax_amt)}與#{header(:amount)}不符合 5% 稅率，請確認")
        end
      elsif amount
        pre, = TaxAmounts.from_gross(amount, tax_rate)
      else
        amount = pre + (pre * rate).round(0, BigDecimal::ROUND_HALF_UP)
        if amount > ValueParser::MAX_MONEY
          skip(no, "推算出的#{header(:amount)}超過金額上限")
          return [ nil, nil, nil ]
        end
      end
      tax = amount - pre

      tax_raw = cell(cells, :tax_amt)
      unless ValueParser.blank?(tax_raw) || ValueParser.money(tax_raw) == tax
        warn(no, "#{header(:tax_amt)}「#{ValueParser.text(tax_raw)}」與推算結果不符，以 #{format_money(tax)} 為準")
      end
      [ pre, tax, amount ]
    end

    def money_or_skip(no, raw, key)
      return nil if ValueParser.blank?(raw)
      value = ValueParser.money(raw)
      skip(no, "#{header(key)}「#{ValueParser.text(raw)}」無法判讀") if value.nil?
      value
    end

    # 品項不代替金額，只核對：加總等於未稅或含稅任一個即視為一致（發票品項常以未稅列示），
    # 都不相等時列出提醒。
    def check_items_total(no, pre, amount, items)
      return if amount.nil? || items.empty?
      items_sum = items.sum(BigDecimal("0")) { |i| i[:subtotal] }
      return if items_sum == amount || items_sum == pre
      amounts = pre == amount ? "#{header(:amount)} #{format_money(amount)}" :
        "#{header(:pre_tax_amt)} #{format_money(pre)}、#{header(:amount)} #{format_money(amount)}"
      warn(no, "品項小計加總 #{format_money(items_sum)} 與#{amounts} 不一致")
    end

    def parse_status(no, cells)
      raw = ValueParser.text(cell(cells, :status))
      return @schema.default_status if raw.nil?
      status = @schema.status_words[raw.delete(" ")]
      if status.nil?
        warn(no, "#{header(:status)}「#{raw}」無法判讀，以#{@schema.status_label(@schema.default_status)}計")
      end
      status || @schema.default_status
    end

    # 已付款／已收款：空白或看不懂 → 以日期代入並列出。待付款／待收款填了日期 → 不帶入並列出。
    def parse_settled_at(no, cells, status, date)
      raw = cell(cells, :settled_at)
      settled_label = @schema.status_label(@schema.settled_status)

      if status != @schema.settled_status
        unless ValueParser.blank?(raw)
          warn(no, "#{header(:status)}為#{@schema.status_label(status)}，#{header(:settled_at)}未帶入")
        end
        return nil
      end

      if ValueParser.blank?(raw)
        warn(no, "#{settled_label}但#{header(:settled_at)}空白，以#{header(:date)}代入")
        return date
      end
      settled_at = ValueParser.date(raw)
      if settled_at.nil?
        warn(no, "#{header(:settled_at)}「#{ValueParser.text(raw)}」無法判讀，以#{header(:date)}代入")
      end
      settled_at || date
    end

    # 類別依名稱（不分大小寫）比對本公司啟用中的同類型類別；找不到、停用、在垃圾桶或空白的
    # 名稱整理成對應清單（每個名稱一項）。垃圾桶內的類別仍佔用名稱，不能新增也不能重新啟用，
    # 只能對應到既有類別。不匯入的單據不需要對應，不列入。
    def resolve_categories(records)
      categories = @company.categories.of_kind(@schema.kind).to_a
      discarded, kept = categories.partition(&:discarded?)
      active    = kept.reject(&:is_archived).index_by { |c| c.name.downcase }
      archived  = kept.select(&:is_archived).index_by { |c| c.name.downcase }
      discarded = discarded.to_set { |c| c.name.downcase }
      entries   = {}

      records.select(&:importable?).each do |record|
        name = record.category_name
        key  = name.to_s.downcase
        if name && active[key]
          record.category = active[key]
          next
        end

        entry = entries[key] ||= CategoryEntry.new(
          key: key, name: name.to_s, rows: [],
          state: category_state(name, key, archived, discarded),
          archived_category: archived[key],
          creatable: name.present? && archived[key].nil? && !discarded.include?(key) && name.length <= CATEGORY_NAME_MAX
        )
        entry.rows << record.rows.first
      end
      entries.values
    end

    def category_state(name, key, archived, discarded)
      return "blank" if name.nil?
      return "discarded" if discarded.include?(key)
      archived[key] ? "archived" : "missing"
    end

    # 有填但找不到帳戶的名稱整理成對應清單（每個名稱一項）。不匯入的單據不需要對應，不列入。
    def resolve_accounts(records)
      discarded = @company.accounts.discarded.pluck(:name).to_set(&:downcase)
      entries   = {}

      records.select(&:importable?).reject(&:account).each do |record|
        key   = record.account_name.downcase
        entry = entries[key] ||= AccountEntry.new(
          key: key, name: record.account_name, rows: [],
          state: discarded.include?(key) ? "discarded" : "missing"
        )
        entry.rows << record.rows.first
      end
      entries.values
    end

    def format_money(value)
      value.to_s("F").sub(/\.0\z/, "")
    end
  end
end
