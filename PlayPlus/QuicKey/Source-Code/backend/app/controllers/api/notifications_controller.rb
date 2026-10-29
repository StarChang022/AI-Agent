module Api
  # 站內通知 endpoints（docs/通知提醒.md）。收件人隔離：一律只能看見 / 操作自己的通知，
  # 不分 admin / employee（兩種角色都會收到不同事件）。read_at 存於後端，實現跨裝置同步。
  class NotificationsController < ApplicationController
    before_action :set_notification, only: %i[read]

    # 分頁預設；對齊前端 ROWS_OPTIONS 第一個選項 (10)，上限 100 防誤傳巨值。
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE     = 100

    # GET /api/notifications?read=all|unread|read&page=&per_page=
    # 回收件人全部通知，新到舊。read filter 預設 all；分頁信封對齊公司慣例
    # { data, meta: { total, page, pageSize } }。
    def index
      scope = Notification.for_user(current_user)
      case params[:read].to_s
      when "unread" then scope = scope.unread
      when "read"   then scope = scope.where.not(read_at: nil)
      end
      scope = scope.order(created_at: :desc)

      page      = [ params[:page].to_i, 1 ].max
      page_size = params[:per_page].to_i
      page_size = DEFAULT_PAGE_SIZE if page_size <= 0
      page_size = [ page_size, MAX_PAGE_SIZE ].min
      total     = scope.count

      records = scope.limit(page_size).offset((page - 1) * page_size)
      render json: {
        data: records.map { |n| serialize(n) },
        meta: { total: total, page: page, page_size: page_size }
      }
    end

    # GET /api/notifications/unread-count
    # 鈴鐺紅點用；輕量，不走分頁。
    def unread_count
      render json: { unread_count: Notification.for_user(current_user).unread.count }
    end

    # PATCH /api/notifications/:id/read
    # 標記單筆為已讀；重複呼叫為 no-op（保留第一次已讀時間）。
    def read
      @notification.update!(read_at: Time.current) if @notification.read_at.nil?
      render json: serialize(@notification)
    end

    # PATCH /api/notifications/mark-all-read
    # 批次標記全部未讀為已讀；回傳本次標了幾筆。
    def mark_all_read
      count = Notification.for_user(current_user).unread.update_all(read_at: Time.current, updated_at: Time.current)
      render json: { updated: count }
    end

    private

    def set_notification
      @notification = Notification.for_user(current_user).find_by(id: params[:id])
      render json: { error: "not_found" }, status: :not_found if @notification.nil?
    end

    def serialize(n)
      {
        id:         n.id.to_s,
        kind:       n.kind,
        payload:    n.payload,
        read_at:    n.read_at&.iso8601,
        created_at: n.created_at.iso8601
      }
    end
  end
end
