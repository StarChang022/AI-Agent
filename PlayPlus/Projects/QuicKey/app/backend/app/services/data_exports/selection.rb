module DataExports
  # 一次匯出要包含哪些紀錄（docs/dev/data-export-api.md 第 1 節）。發起時用來算筆數、判斷
  # 有沒有圖檔；背景產生時再依同一份條件重查，所以這段期間進垃圾桶的紀錄不會匯出。
  # 一次只有一個列表；一律限本公司。支出、收入排除垃圾桶，代墊款同「全部紀錄」列表排除草稿。
  class Selection
    BATCH_SIZE = 500

    # type 給 CSV 欄位與檔名用，model 給查圖檔用；relation 不排序，
    # 依 cursor／order 分批讀（排序同列表：新到舊）。
    Section = Data.define(:type, :model, :relation, :cursor, :order) do
      # 分批讀取，不一次把整家公司的紀錄載進記憶體。with_attachments：每批一起載入圖檔。
      def each_record(with_attachments: false, &block)
        scope = with_attachments ? relation.with_attached_attachments : relation
        scope.find_each(cursor: cursor, order: order, batch_size: BATCH_SIZE, &block)
      end
    end

    RECORD_CURSOR = { cursor: %i[date created_at id], order: %i[desc desc desc] }.freeze

    def initialize(data_export)
      @export  = data_export
      @company = data_export.company
    end

    def section
      @section ||=
        case @export.kind
        when "expense"
          scope = narrow(@company.expenses.kept.includes(:category, :account)) { |s, f| RecordFilters.expenses(s, f) }
          Section.new(type: "expense", model: Expense, relation: scope, **RECORD_CURSOR)
        when "income"
          scope = narrow(@company.incomes.kept.includes(:category, :account)) { |s, f| RecordFilters.incomes(s, f) }
          Section.new(type: "income", model: Income, relation: scope, **RECORD_CURSOR)
        when "reimbursement"
          scope = narrow(@company.reimbursements.visible.includes(:category, :employee)) { |s, f| RecordFilters.reimbursements(s, f) }
          Section.new(type: "reimbursement", model: Reimbursement, relation: scope,
                      cursor: %i[created_at id], order: %i[desc desc])
        end
    end

    def record_count
      section.relation.count
    end

    def any_attachments?
      ActiveStorage::Attachment.where(record_type: section.model.name, name: AttachmentFiles::NAME,
                                      record_id: section.relation.select(:id)).exists?
    end

    private

    # 單筆／勾選：指定的 id；filtered：列表的篩選條件（RecordFilters），發生日期區間選填。
    def narrow(scope)
      criteria = @export.criteria
      case @export.scope
      when "single", "selected" then scope.where(id: Array(criteria["ids"]))
      else
        yield scope, (criteria["filters"] || {}).merge(criteria.slice("date_from", "date_to"))
      end
    end
  end
end
