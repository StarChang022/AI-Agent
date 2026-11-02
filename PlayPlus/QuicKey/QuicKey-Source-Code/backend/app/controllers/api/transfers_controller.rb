module Api
  # 資金移轉（PRD 第 19 條）。全部要求 JWT + role=admin，並限定於呼叫者所屬 company。
  # 合約見 docs/dev/transfers-api.md。驗證錯誤的 type 就是 API 的錯誤代碼。
  class TransfersController < ApplicationController
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    AUDITED_UPDATE_FIELDS = %w[from_account_id to_account_id amount fee transfer_date note attachments].freeze

    before_action :require_admin
    before_action :set_any_transfer, only: :show
    before_action :set_transfer, only: %i[update destroy]
    before_action :set_discarded_transfer, only: %i[restore purge]

    # GET /api/transfers?discarded=&date_from=&date_to=&from_account_id=&to_account_id=&page=&per_page=
    # 預設只回未刪；discarded=true → 垃圾桶。未刪依移轉日期新到舊，垃圾桶依刪除時間新到舊。
    def index
      discarded = ActiveModel::Type::Boolean.new.cast(params[:discarded]) == true
      scope = current_user.company.transfers.includes(:from_account, :to_account, :created_by)
      scope = discarded ? scope.discarded : scope.kept

      date_from = parse_date(params[:date_from])
      date_to   = parse_date(params[:date_to])
      scope = scope.where(transfer_date: date_from..)       if date_from
      scope = scope.where(transfer_date: ..date_to)         if date_to
      scope = scope.where(from_account_id: params[:from_account_id]) if params[:from_account_id].present?
      scope = scope.where(to_account_id:   params[:to_account_id])   if params[:to_account_id].present?
      scope = discarded ? scope.order(deleted_at: :desc) : scope.order(transfer_date: :desc, created_at: :desc)

      page      = [ params[:page].to_i, 1 ].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [ page_size, MAX_PAGE_SIZE ].min
      total     = scope.count

      records  = scope.limit(page_size).offset((page - 1) * page_size).to_a
      deleters = discarded ? deleted_by_map(records.map(&:id)) : {}

      render json: {
        data: records.map { |t| list_serialize(t, deleted_by: deleters[t.id]) },
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # GET /api/transfers/:id
    # 垃圾桶內的也查得到，支出詳情會連過來。
    def show
      deleted_by = deleted_by_map([ @transfer.id ])[@transfer.id] if @transfer.discarded?
      render json: serialize(@transfer, deleted_by: deleted_by)
    end

    # POST /api/transfers
    # 手續費大於 0 時同時產生手續費支出。
    def create
      transfer = current_user.company.transfers.new(created_by: current_user)
      assign_fields(transfer)

      saved = false
      ActiveRecord::Base.transaction do
        saved = transfer.save
        next unless saved

        AuditLog.record!(transfer, action: "create", by: current_user, after: transfer.audit_snapshot)
        TransferFeeExpense.sync!(transfer, by: current_user)
      end
      return render_invalid(transfer, :unprocessable_content) unless saved

      render json: serialize(transfer), status: :created
    end

    # PATCH /api/transfers/:id
    # 同步手續費支出的金額、日期、帳戶。鎖定後才確認狀態：剛被刪除的移轉不能再改。
    def update
      ActiveRecord::Base.transaction do
        @transfer.lock!
        next render json: { error: "not_found" }, status: :not_found if @transfer.discarded?

        assign_fields(@transfer)
        next render_invalid(@transfer, :unprocessable_content) unless @transfer.save

        audit_update_change!
        TransferFeeExpense.sync!(@transfer, by: current_user)
        render json: serialize(@transfer)
      end
    end

    # DELETE /api/transfers/:id
    # 進垃圾桶，任何時候都可以；已付款的手續費支出一併移入。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已在垃圾桶，不再寫稽核。
    def destroy
      ActiveRecord::Base.transaction do
        @transfer.lock!
        next if @transfer.discarded?

        @transfer.discard!
        AuditLog.record!(@transfer, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @transfer.deleted_at&.iso8601 })
        TransferFeeExpense.discard!(@transfer, by: current_user)
      end
      render json: {}, status: :ok
    end

    # PATCH /api/transfers/:id/restore
    # 移轉日期早於任一帳戶起始月份時不可還原。手續費支出一併還原。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已還原，不再寫稽核。
    def restore
      ActiveRecord::Base.transaction do
        @transfer.lock!
        next render json: serialize(@transfer) unless @transfer.discarded?

        prev_deleted_at = @transfer.deleted_at&.iso8601
        next render_invalid(@transfer, :conflict) unless @transfer.restore_from_trash

        AuditLog.record!(@transfer, action: "restore", by: current_user,
          before: { deleted_at: prev_deleted_at },
          after:  { deleted_at: nil })
        TransferFeeExpense.restore!(@transfer, by: current_user)
        render json: serialize(@transfer)
      end
    end

    # DELETE /api/transfers/:id/purge
    # 永久刪除，指向它的支出一併刪除。audit log 必須在 destroy! 前寫入，否則 target.company 撈不到。
    # 鎖定後重新確認還在垃圾桶，剛被還原的移轉不刪。
    def purge
      ActiveRecord::Base.transaction do
        @transfer.lock!
        next render json: { error: "not_found" }, status: :not_found unless @transfer.discarded?

        AuditLog.record!(@transfer, action: "purge", by: current_user, before: @transfer.audit_snapshot)
        TransferFeeExpense.purge!(@transfer, by: current_user)
        @transfer.destroy!
        render json: {}, status: :ok
      end
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_any_transfer
      @transfer = current_user.company.transfers.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @transfer.nil?
    end

    def set_transfer
      @transfer = current_user.company.transfers.kept.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @transfer.nil?
    end

    def set_discarded_transfer
      @transfer = current_user.company.transfers.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @transfer.nil?
    end

    # 只處理 client 有帶的 key（create 會全帶、update 為 partial）。
    def assign_fields(transfer)
      transfer.assign_attributes(params.permit(:from_account_id, :to_account_id, :amount, :fee, :transfer_date, :note))
      transfer.attachments = json_array(params[:attachments]) if params.key?(:attachments)
    end

    # 把巢狀 JSON 陣列（ActionController::Parameters）轉成純 hash 供 jsonb 儲存。
    def json_array(raw)
      return [] if raw.blank?
      Array(raw).map { |el| el.respond_to?(:to_unsafe_h) ? el.to_unsafe_h : el }
    end

    def parse_date(raw)
      return nil if raw.blank?
      Date.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def deleted_by_map(ids)
      AuditLog.deleted_by_map(current_user.company, "transfer", ids)
    end

    def audit_update_change!
      diff = @transfer.saved_changes.slice(*AUDITED_UPDATE_FIELDS)
      return if diff.empty?
      before, after = AuditLog.update_payload(diff)
      AuditLog.record!(@transfer, action: "update", by: current_user, before: before, after: after)
    end

    def serialize(t, deleted_by: nil)
      {
        id:             t.id.to_s,
        from_account:   account_ref(t.from_account),
        to_account:     account_ref(t.to_account),
        amount:         t.amount.to_f,
        fee:            t.fee.to_f,
        transfer_date:  t.transfer_date.iso8601,
        note:           t.note,
        attachments:    t.attachments,
        fee_expense_id: t.fee_expense_id&.to_s,
        created_by:     person_ref(t.created_by),
        deleted_at:     t.deleted_at&.iso8601,
        deleted_by:     person_ref(deleted_by),
        created_at:     t.created_at.iso8601,
        updated_at:     t.updated_at.iso8601
      }
    end

    def list_serialize(t, deleted_by: nil)
      serialize(t, deleted_by: deleted_by).except(:attachments)
    end

    def account_ref(account)
      { id: account.id.to_s, name: account.name }
    end

    def person_ref(user)
      user && { id: user.id.to_s, name: user.name }
    end

    # 驗證錯誤的 type 就是錯誤代碼，一次回第一個錯誤；憑證的訊息來自共用驗證，代碼另外給。
    def render_invalid(transfer, status)
      error = transfer.errors.first
      code  = error.attribute == :attachments ? "INVALID_ATTACHMENTS" : error.type.to_s
      render json: { error: code, message: error.message, sides: error.details[:sides] }.compact, status: status
    end
  end
end
