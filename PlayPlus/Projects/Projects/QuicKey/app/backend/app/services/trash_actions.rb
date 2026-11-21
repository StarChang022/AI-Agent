module TrashActions
  # 垃圾桶還原／永久刪除的共用工具（PRD 第 18 條「批次還原與永久刪除」、docs/dev/trash-batch-api.md）。
  # 單筆 API 與批次 API 都經由 ExpenseTrash / IncomeTrash，規則只寫一份。

  MAX_BATCH = 50

  # 規則不允許時丟出。code 給程式判斷，message 給使用者看；單筆 API 由 ApplicationController 轉成錯誤回應。
  class Refused < StandardError
    attr_reader :code, :status

    def initialize(code, status, message)
      super(message)
      @code   = code
      @status = status
    end

    def as_json(*)
      { error: code, message: message }
    end
  end

  # 批次的 ids 參數：必須是非空陣列、去重後不超過 50 筆，回字串陣列。
  def self.parse_ids(raw)
    ids = raw.is_a?(Array) ? raw.map(&:to_s).map(&:strip).reject(&:empty?).uniq : []
    raise Refused.new("IDS_REQUIRED", :unprocessable_content, "請選擇要處理的紀錄") if ids.empty?
    raise Refused.new("TOO_MANY_IDS", :unprocessable_content, "一次最多處理 #{MAX_BATCH} 筆") if ids.size > MAX_BATCH
    ids
  end

  # 逐筆處理：每筆各自一個交易（由 block 內的單筆邏輯開），一筆失敗不影響其他筆。
  # scope 必須已限定本公司的垃圾桶，不在其中的 id 列為 NOT_FOUND。
  # 回 { succeeded: [id...], failed: [{ id, error, message }] }，順序同 ids。
  def self.run_batch(scope, ids)
    records = scope.where(id: ids).index_by { |r| r.id.to_s }
    succeeded = []
    failed    = []

    ids.each do |id|
      record = records[id]
      if record.nil?
        failed << { id: id, error: "NOT_FOUND", message: "找不到這筆紀錄，可能已還原或永久刪除" }
        next
      end

      begin
        yield record
        succeeded << id
      rescue Refused => e
        failed << { id: id, error: e.code, message: e.message }
      rescue ActiveRecord::RecordInvalid => e
        failed << { id: id, error: "VALIDATION_FAILED", message: e.record.errors.full_messages.join("、") }
      rescue ActiveRecord::ActiveRecordError => e
        Rails.logger.error("[trash-batch] #{record.class.name} #{id}: #{e.class} #{e.message}")
        failed << { id: id, error: "FAILED", message: "處理失敗，請稍後再試" }
      end
    end

    { succeeded: succeeded, failed: failed }
  end
end
