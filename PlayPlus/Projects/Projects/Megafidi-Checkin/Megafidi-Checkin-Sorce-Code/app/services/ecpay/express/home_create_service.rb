module Ecpay::Express
  class HomeCreateService < BaseService
  	ENDPOINT = "Express/create"

    attr_accessor :shipment, :merchant_trade_no, :logistics_type, :logistics_sub_type,
                  :goods_name, :goods_amount,
                  :sender_name, :sender_phone, :sender_cell_phone,
                  :receiver_name, :receiver_phone, :receiver_cell_phone, :receiver_email,
                  :trade_desc, :remark,
                  :platform_id, :receiver_store_id, :return_store_id

    def initialize(attributes={})
      super
      @merchant_trade_no ||= Time.current.to_i

      @logistics_type = "HOME"
      # B2C => ["FAMI", "UNIMART", "HILIFE"]
			# FAMI：全家
			# UNIMART：7-ELEVEN 超商
			# HILIFE：萊爾富
			# C2C => ["FAMIC2C", "UNIMARTC2C", "HILIFEC2C"]
			# FAMIC2C：全家店到店
			# UNIMARTC2C：7-ELEVEN 超商交貨便
			# HILIFEC2C:萊爾富店到店
      #@logistics_sub_type ||= shipment.logistics_sub_type

			# N：不代收貨款。
			# Y：代收貨款。
      @is_collection ||= "N"

    end

    def run

    end

    def fields_for_export
      %w[
        MerchantID
        MerchantTradeNo MerchantTradeDate LogisticsType LogisticsSubType
        GoodsAmount CollectionAmount IsCollection GoodsName
        SenderName SenderPhone SenderCellPhone
        ReceiverName ReceiverPhone ReceiverCellPhone ReceiverEmail
        TradeDesc Remark
        ServerReplyURL ClientReplyURL LogisticsC2CReplyURL
        PlatformID ReceiverStoreID ReturnStoreID
      ].freeze
    end

    def offsite_form_action
      "#{service_domain}#{ENDPOINT}"
    end

    def server_reply_url

    end

    def client_reply_url

    end

    def logistics_c2_c_reply_url

    end

  end
end