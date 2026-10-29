module Ocr
  # 把多張檔案各自 normalize 後的結果合併成單一回應。見 docs/OCR辨識規格.md §4。
  #
  # 輸入：ReceiptTextExtractor 的結果陣列（只放辨識成功、且有內容的檔案）
  # 輸出：{ merged:, conflicts: { fields:, items:, invoices: }, confidence: { overall:, low_fields: }, warnings: }
  #
  # 頂層欄位：只有一張有值或多張值相同 → merged；多張值不同 → conflicts.fields，merged 該欄為 nil。
  # 品項：以「正規化品名 + 單價」分組；只有一張出現或多張數量 / 小計都相同 → merged.items，
  #       否則 → conflicts.items。全部完全比對，不做相似度判斷（寧可多問使用者）。
  # 電子發票（§3.2）：任一檔案解出 2 張以上發票時，列出本次所有發票到 conflicts.invoices（號碼相同只列一次），
  #       讓使用者整張挑一張；這時 QR 有的欄位、名稱和品項都不進 merged / conflicts.fields / conflicts.items
  #       （名稱改放在每張發票的 fields，按頁抽）。
  #       沒有這種檔案時不回 conflicts.invoices。
  class ResultMerger
    FIELDS = %i[
      document_type incurred_at
      our_tax_id our_name counterparty_tax_id counterparty_name
      invoice_prefix invoice_digits
      tax_rate pre_tax_amt tax_amt amount
    ].freeze

    # conflicts.invoices 最多列幾張（異常檔案解出上百張時不全部回給前端）
    MAX_INVOICES = 20

    # 信心度不高於這個值的欄位算「規則推測」，列進 lowFields（docs/OCR辨識規格.md §3.1、§6）
    LOW_CONFIDENCE = ReceiptTextExtractor::LOW

    def self.call(results)
      new(results).call
    end

    def initialize(results)
      @results    = results
      @warnings   = []
      @low_fields = []
    end

    def call
      invoices = invoice_choices
      if invoices
        @results = @results.map { |r| r.merge(fields: r[:fields].except(*InvoiceQr::FIELDS, *InvoiceQr::NAME_FIELDS), items: []) }
        @warnings << "辨識到 #{invoices.size} 張發票，請選擇要帶入哪一張"
      end

      merged = {}
      field_conflicts = []

      FIELDS.each do |key|
        value, conflict = merge_field(key)
        merged[key] = value
        field_conflicts << conflict if conflict
      end

      merged_items, item_conflicts = merge_items
      merged[:items] = merged_items

      conflicts = { fields: field_conflicts, items: item_conflicts }
      conflicts[:invoices] = invoices if invoices
      {
        merged:     merged,
        conflicts:  conflicts,
        confidence: { overall: overall_confidence, low_fields: low_fields(merged) },
        warnings:   @warnings
      }
    end

    private

    def invoice_choices
      return nil unless @results.any? { |r| r[:invoices].to_a.size >= 2 }
      invoices = @results.flat_map { |r| r[:invoices].to_a }.uniq { |inv| inv[:fields].values_at(:invoice_prefix, :invoice_digits) }
      return invoices if invoices.size <= MAX_INVOICES

      @warnings << "發票超過 #{MAX_INVOICES} 張，只列出前 #{MAX_INVOICES} 張"
      invoices.first(MAX_INVOICES)
    end

    # field 名稱是「值」不是 key，前端 service 不會幫忙轉 camelCase，這裡直接輸出 camelCase。
    def merge_field(key)
      candidates = @results.filter_map do |r|
        field = r[:fields][key]
        next unless field
        { value: field[:value], source_index: r[:source_index], confidence: field[:confidence] }
      end

      return [ nil, nil ] if candidates.empty?

      # 同值的候選只留一個（保留第一個來源，信心度取最高），避免彈窗出現重複選項。
      unique = candidates.group_by { |c| c[:value] }.map do |_, same|
        same.first.merge(confidence: same.map { |c| c[:confidence].to_f }.max)
      end
      if unique.size == 1
        # 多張抓到同一個值時，只要有任一張是用推測規則抓到的就列進 lowFields
        @low_fields << key if candidates.any? { |c| c[:confidence].to_f <= LOW_CONFIDENCE }
        return [ unique.first[:value], nil ]
      end

      field_name = key.to_s.camelize(:lower)
      @warnings << "#{field_name} 有多個候選值，請人工確認"
      [ nil, { field: field_name, candidates: unique } ]
    end

    def merge_items
      groups = Hash.new { |h, k| h[k] = [] }
      @results.each do |r|
        r[:items].each do |item|
          key = [ ReceiptTextExtractor.normalize_text(item[:name]), item[:unit_price] ]
          groups[key] << { item: item, source_index: r[:source_index] }
        end
      end

      merged = []
      conflicts = []

      groups.each_value do |entries|
        if entries.map { |e| e[:source_index] }.uniq.size == 1
          merged.concat(entries.map { |e| e[:item] })
          next
        end

        unique = entries.uniq { |e| e[:item].values_at(:quantity, :subtotal) }
        if unique.size == 1
          merged << unique.first[:item]
        else
          conflicts << { candidates: unique }
          @warnings << "品項「#{unique.first[:item][:name]}」有多個候選數量或小計，請人工確認"
        end
      end

      [ merged, conflicts ]
    end

    # 值是欄位名稱，前端不會幫忙轉 camelCase，這裡直接輸出 camelCase；items 為 [] 時不列。
    # 只列 merged 裡有值的欄位（進了 conflicts 的欄位 merged 為 nil，不列）；品項一律算推測。
    def low_fields(merged)
      keys = @low_fields.reject { |key| merged[key].nil? }
      keys << :items if merged[:items].any?
      keys.map { |key| key.to_s.camelize(:lower) }
    end

    # 各檔信心度（直接辨識出的欄位平均，推導欄位不計入）再取平均；都沒有時為 0。
    def overall_confidence
      values = @results.map { |r| r[:confidence] }.compact
      return 0.0 if values.empty?
      (values.sum / values.size).round(4)
    end
  end
end
