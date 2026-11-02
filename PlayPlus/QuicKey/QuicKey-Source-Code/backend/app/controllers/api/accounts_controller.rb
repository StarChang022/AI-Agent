module Api
  # 帳戶設定（PRD 規則 18、20、21）。全部要求 JWT + role=admin，並限定於呼叫者所屬 company。
  # 合約見 docs/dev/accounts-api.md。
  class AccountsController < ApplicationController
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    before_action :require_admin
    before_action :set_account, only: %i[update destroy opening_month_impact]
    before_action :set_discarded_account, only: %i[restore purge]

    # GET /api/accounts?discarded=&page=&per_page=
    # 帳戶設定頁列表；discarded=true → 垃圾桶。下拉選單走 options。
    def index
      discarded = ActiveModel::Type::Boolean.new.cast(params[:discarded]) == true
      scope = current_user.company.accounts
      scope = discarded ? scope.discarded.order(deleted_at: :desc) : scope.kept.order(:created_at)

      page      = [ params[:page].to_i, 1 ].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [ page_size, MAX_PAGE_SIZE ].min
      total     = scope.count

      records  = scope.limit(page_size).offset((page - 1) * page_size).to_a
      ids      = records.map(&:id)
      counts   = Account.reference_counts(ids)
      deleters = discarded ? AuditLog.deleted_by_map(current_user.company, "account", ids) : {}

      render json: {
        data: records.map { |a| serialize(a, references: counts[a.id], deleted_by: deleters[a.id]) },
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # GET /api/accounts/options
    # 收支表單、核准代墊款的帳戶下拉：全部未刪除的帳戶，附上一次使用的帳戶。
    def options
      accounts = current_user.company.accounts.kept.order(:created_at)
      render json: {
        data: accounts.map { |a|
          { id: a.id.to_s, name: a.name, account_type: a.account_type, opening_month: a.opening_month.iso8601 }
        },
        last_used_account_id: current_user.last_used_account&.id&.to_s
      }
    end

    # GET /api/accounts/:id/opening-month-impact?opening_month=2026-08
    # 起始月份改成指定月份時，有幾筆已收款、已付款會不計入現金流，以及有幾筆移轉會擋下調整。
    # 只查詢，不寫入。
    def opening_month_impact
      month = parse_opening_month
      return if performed?

      counts = @account.outside_cash_flow_counts(month)
      blocking = @account.blocking_transfers(month)
      render json: {
        opening_month: month.iso8601, outside_cash_flow_count: counts.values.sum, outside_cash_flow: counts,
        blocking_transfer_count: blocking[:count], earliest_transfer_date: blocking[:earliest]&.iso8601
      }
    end

    # POST /api/accounts  body: { name, account_type, opening_amount, opening_month? }
    # 沒帶 opening_month 時為當月。
    def create
      name = parse_name
      return if performed?
      return render_error("INVALID_ACCOUNT_TYPE", "請選擇帳戶類型", :unprocessable_content) unless Account::ACCOUNT_TYPES.include?(params[:account_type])
      amount = parse_opening_amount
      return if performed?
      month = parse_opening_month if params.key?(:opening_month)
      return if performed?
      return if render_duplicate_name(name)

      account = Account.build_with_opening(company: current_user.company, name: name,
        account_type: params[:account_type], opening_amount: amount, opening_month: month)

      ActiveRecord::Base.transaction do
        account.save!
        AuditLog.record!(account, action: "create", by: current_user, after: account.audit_snapshot)
      end

      render json: serialize(account), status: :created
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_name(name)
    end

    # PATCH /api/accounts/:id  body: { name?, opening_amount?, opening_month? }
    # 類型建立後不可改。有變動的欄位才寫稽核。
    # 起始月份不可調到移轉日期之後。先鎖帳戶再查移轉，和移轉存檔時對帳戶的鎖互斥。
    def update
      name = params.key?(:name) ? parse_name : @account.name
      return if performed?
      amount = params.key?(:opening_amount) ? parse_opening_amount : @account.opening_amount
      return if performed?
      month = params.key?(:opening_month) ? parse_opening_month : @account.opening_month
      return if performed?
      return if name != @account.name && render_duplicate_name(name, except: @account)

      fields = %i[name opening_amount opening_month]

      ActiveRecord::Base.transaction do
        @account.lock!
        before = @account.audit_snapshot.slice(*fields)
        @account.assign_attributes(name: name, opening_amount: amount, opening_month: month)
        next if @account.opening_month_changed? && render_blocked_by_transfers(month)

        @account.save!
        after = @account.audit_snapshot.slice(*fields)
        changed = fields.select { |key| before[key] != after[key] }
        if changed.any?
          AuditLog.record!(@account, action: "update", by: current_user,
            before: before.slice(*changed), after: after.slice(*changed))
        end
        render json: serialize(@account)
      end
    rescue ActiveRecord::RecordNotUnique
      render_duplicate_name(name, except: @account)
    end

    # DELETE /api/accounts/:id
    # 進垃圾桶；被任一收支引用（含垃圾桶內的紀錄）就拒絕。先鎖帳戶再查引用，
    # 和收支驗證帳戶未刪除時的鎖互斥（AccountLedgerEntry#account_not_deleted）。
    # 鎖定後才確認狀態：重複送出時第二次等到鎖已在垃圾桶，不再寫稽核。
    def destroy
      ActiveRecord::Base.transaction do
        @account.lock!
        next render json: {}, status: :ok if @account.discarded?
        next if render_in_use

        @account.discard!
        AuditLog.record!(@account, action: "delete", by: current_user,
          before: { deleted_at: nil },
          after:  { deleted_at: @account.deleted_at&.iso8601 })
        render json: {}, status: :ok
      end
    end

    # PATCH /api/accounts/:id/restore
    # 垃圾桶內的名稱仍佔用，還原不會撞名。
    def restore
      prev_deleted_at = @account.deleted_at&.iso8601
      ActiveRecord::Base.transaction do
        @account.restore_from_trash!
        AuditLog.record!(@account, action: "restore", by: current_user,
          before: { deleted_at: prev_deleted_at },
          after:  { deleted_at: nil })
      end
      render json: serialize(@account)
    end

    # DELETE /api/accounts/:id/purge
    # 永久刪除。audit log 必須在 destroy! 前寫入，否則 target.company 撈不到。
    # 鎖定後重新確認還在垃圾桶，剛被還原的帳戶不刪。
    def purge
      ActiveRecord::Base.transaction do
        @account.lock!
        next render json: { error: "not_found" }, status: :not_found unless @account.discarded?
        next if render_in_use

        AuditLog.record!(@account, action: "purge", by: current_user, before: @account.audit_snapshot)
        @account.destroy!
        render json: {}, status: :ok
      end
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def set_account
      @account = current_user.company.accounts.kept.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @account.nil?
    end

    def set_discarded_account
      @account = current_user.company.accounts.discarded.find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @account.nil?
    end

    def parse_name
      name = params[:name].to_s.strip
      return name if name.present? && name.length <= Account::NAME_MAX
      render_error("INVALID_NAME", "請填寫帳戶名稱，最多 #{Account::NAME_MAX} 字", :unprocessable_content)
      nil
    end

    def parse_opening_amount
      amount = BigDecimal(params[:opening_amount].to_s)
      return amount if amount.between?(0, Account::MAX_AMOUNT)
      render_invalid_opening_amount
    rescue ArgumentError
      render_invalid_opening_amount
    end

    # 接受 YYYY-MM 或 YYYY-MM-DD，一律轉成該月第一天。範圍 2000 年 1 月至當月。
    def parse_opening_month
      match = params[:opening_month].to_s.match(/\A(\d{4})-(\d{2})(?:-\d{2})?\z/)
      month = Date.new(match[1].to_i, match[2].to_i, 1) if match
      return month if month && Account.opening_month_in_range?(month)
      render_invalid_opening_month
    rescue Date::Error
      render_invalid_opening_month
    end

    def render_invalid_opening_month
      render_error("INVALID_OPENING_MONTH", "請選擇起始月份，範圍為 2000 年 1 月至當月", :unprocessable_content)
      nil
    end

    def render_invalid_opening_amount
      render_error("INVALID_OPENING_AMOUNT", "請填寫起始金額，需為 0 以上的數字", :unprocessable_content)
      nil
    end

    # 名稱重複（不分大小寫，含垃圾桶內的帳戶）時 render 409 並回 true。
    def render_duplicate_name(name, except: nil)
      scope = current_user.company.accounts.where("LOWER(name) = ?", name.downcase)
      scope = scope.where.not(id: except.id) if except
      existing = scope.first
      return false if existing.nil?

      message = existing.discarded? ?
        "垃圾桶內已有同名帳戶，請還原或永久刪除後再試" : "已有同名帳戶，請換一個名稱"
      render json: { error: "DUPLICATE_NAME", message: message, account: serialize(existing) }, status: :conflict
      true
    end

    # 有移轉日期早於 month 時 render 409 並回 true。
    def render_blocked_by_transfers(month)
      blocking = @account.blocking_transfers(month)
      return false if blocking[:count].zero?

      render json: {
        error: "OPENING_MONTH_AFTER_TRANSFER",
        message: "有 #{blocking[:count]} 筆資金移轉的日期早於這個起始月份，最早為 #{blocking[:earliest].iso8601}，請先修改移轉日期或刪除移轉",
        transfer_count: blocking[:count],
        earliest_transfer_date: blocking[:earliest].iso8601
      }, status: :conflict
      true
    end

    # 帳戶仍被引用時 render 409 並回 true。
    def render_in_use
      counts = @account.reference_counts
      return false if counts.values.all?(&:zero?)

      render json: {
        error: "ACCOUNT_IN_USE",
        message: "此帳戶已有 #{Account.describe_references(counts)}使用（含垃圾桶內的紀錄），不能刪除",
        references: counts
      }, status: :conflict
      true
    end

    def serialize(a, references: a.reference_counts, deleted_by: nil)
      {
        id:             a.id.to_s,
        name:           a.name,
        account_type:   a.account_type,
        currency:       a.currency,
        opening_amount: a.opening_amount.to_f,
        opening_month:  a.opening_month.iso8601,
        references:     references,
        deletable:      references.values.all?(&:zero?),
        deleted_at:     a.deleted_at&.iso8601,
        deleted_by:     deleted_by && { id: deleted_by.id.to_s, name: deleted_by.name },
        created_at:     a.created_at.iso8601,
        updated_at:     a.updated_at.iso8601
      }
    end

    def render_error(code, message, status)
      render json: { error: code, message: message }, status: status
    end
  end
end
