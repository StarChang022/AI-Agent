module Ecpay::Express
  class MapFormService < BaseService
  	ENDPOINT = "Express/map"

    attr_accessor :logistics_type, :logistics_sub_type, :merchant_trade_no, :extra_data, :is_collection, :device

    def initialize(attributes={})
      super
      @merchant_trade_no ||= Time.current
      @logistics_type = "CVS"
      # B2C => ["FAMI", "UNIMART", "HILIFE"]
			# FAMI：全家
			# UNIMART：7-ELEVEN 超商
			# HILIFE：萊爾富
			# C2C => ["FAMIC2C", "UNIMARTC2C", "HILIFEC2C"]
			# FAMIC2C：全家店到店
			# UNIMARTC2C：7-ELEVEN 超商交貨便
			# HILIFEC2C:萊爾富店到店
      @logistics_sub_type ||= "UNIMARTC2C"

			# N：不代收貨款。
			# Y：代收貨款。
      @is_collection ||= "N"
    end

    def fields_for_export
      %w[
        MerchantID
        MerchantTradeNo LogisticsType LogisticsSubType
        IsCollection ServerReplyURL ExtraData Device
      ].freeze
    end

    def offsite_form_action
      "#{service_domain}#{ENDPOINT}"
    end

    private

    def server_reply_url
      server_reply_ecpay_express_map_url
    end

  end
end