module Ocr
  # 公司 OCR 配額。見 docs/OCR辨識規格.md §5。
  #
  # 兩池次數：月費額度（每月 1 日 00:00 台北時間歸零）+ 加購包（不過期）。
  # 扣除順序：先扣月費額度，用完才扣加購。
  # 重置採 lazy：被呼叫時才檢查 ocr_quota_reset_at 是否已過，不開 cron。
  class Quota
    class Exhausted < StandardError; end

    def initialize(company)
      @company = company
    end

    # 月初已過就歸零月費已用次數，並把重置時間推到下個月 1 日。
    def refresh!
      return unless reset_due?
      @company.with_lock { refresh_in_lock }
    end

    def monthly_remaining
      [ @company.ocr_monthly_quota - @company.ocr_monthly_used, 0 ].max
    end

    def purchased_remaining
      @company.ocr_purchased_remaining
    end

    def remaining
      monthly_remaining + purchased_remaining
    end

    # 呼叫 Document AI 前先擋：至少要夠 count 次（一檔至少 1 頁）。
    def ensure_available!(count = 1)
      refresh!
      raise Exhausted if remaining < count
    end

    # Document AI 成功回傳後按實際頁數扣。先扣月費、再扣加購。
    # 多頁 PDF 的頁數要辨識完才知道，可能超過呼叫前檢查的次數；此時扣到 0 為止，不扣成負數。
    # 回傳實際扣除的次數。
    def consume!(pages)
      return 0 if pages <= 0

      @company.with_lock do
        refresh_in_lock
        from_monthly   = [ pages, monthly_remaining ].min
        from_purchased = [ pages - from_monthly, purchased_remaining ].min
        @company.update!(
          ocr_monthly_used:        @company.ocr_monthly_used + from_monthly,
          ocr_purchased_remaining: @company.ocr_purchased_remaining - from_purchased
        )
        from_monthly + from_purchased
      end
    end

    # /recognize 回應與 429 錯誤附帶的剩餘次數；used 只有辨識成功時帶。
    def snapshot(used: nil)
      { used: used, monthly_remaining: monthly_remaining, purchased_remaining: purchased_remaining }.compact
    end

    # GET /api/ocr/quota
    def as_json(*)
      {
        monthly_quota:       @company.ocr_monthly_quota,
        monthly_used:        @company.ocr_monthly_used,
        monthly_remaining:   monthly_remaining,
        purchased_remaining: purchased_remaining,
        reset_at:            @company.ocr_quota_reset_at.in_time_zone.iso8601
      }
    end

    private

    def reset_due?
      @company.ocr_quota_reset_at <= Time.current
    end

    # with_lock 會重新讀取資料列，所以鎖內要再判斷一次是否該重置。
    def refresh_in_lock
      return unless reset_due?
      @company.update!(ocr_monthly_used: 0, ocr_quota_reset_at: next_reset_at)
    end

    # config.time_zone 為 Asia/Taipei，Time.current 即台北時間。
    def next_reset_at
      Time.current.next_month.beginning_of_month
    end
  end
end
