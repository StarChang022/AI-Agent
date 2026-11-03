module Ecpay::Express
  class CvsCreateService < BaseService
  	ENDPOINT = "Express/create"

    attr_accessor :shipment, :system_setting, :merchant_trade_no,
    :logistics_type, :logistics_sub_type,
    :goods_name, :goods_amount, :collection_amount, :is_collection,
    :sender_name, :sender_phone, :sender_cell_phone,
    :receiver_name, :receiver_phone, :receiver_cell_phone, :receiver_email,
    :trade_desc, :remark,
    :platform_id, :receiver_store_id, :return_store_id,
    :status, :response_params

    # B2C => ["FAMI", "UNIMART", "HILIFE"]
    # FAMI：全家
    # UNIMART：7-ELEVEN 超商
    # HILIFE：萊爾富
    # C2C => ["FAMIC2C", "UNIMARTC2C", "HILIFEC2C"]
    # FAMIC2C：全家店到店
    # UNIMARTC2C：7-ELEVEN 超商交貨便
    # HILIFEC2C:萊爾富店到店

    def initialize(attributes={})
      super
      @merchant_trade_no ||= shipment.num

      @logistics_type = "CVS"
      @logistics_sub_type ||= shipment.logistics_sub_type


      @trade_desc ||= shipment.trade_desc
      @remark ||= shipment.remark

      @goods_name ||= shipment.goods_name
      @goods_amount ||= shipment.goods_amount
      @collection_amount ||= shipment.collection_amount
      @is_collection ||= shipment.is_collection

      @receiver_name ||= shipment.receiver_name
      @receiver_phone ||= shipment.receiver_phone
      @receiver_cell_phone ||= shipment.receiver_cell_phone
      @receiver_email ||= shipment.receiver_email
      @receiver_store_id ||= shipment.receiver_store_id

      # 系統設定
      @sender_name ||= system_setting.sender_name
      @sender_phone ||= system_setting.sender_phone
      @sender_cell_phone ||= system_setting.sender_cell_phone
    end

    def run
      @request = Net::HTTP.post_form(uri, params_with_check_mac_value)

      @response = @request.body.force_encoding('UTF-8')
      @response = @response.split("|")

      @status = @response[0]
      if @response[1].present?
        @params = Rack::Utils.parse_query(@response[1])
        @response_params = @params.deep_transform_keys(&:underscore)
      else
        @params = {}
        @response_params = {}
      end

      unless Ecpay::Express::CheckMacService.new(@params).execute
        # 檢查碼不符
      end

      @response_params = @response_params.merge(status: @status)
      return @response_params
    end

    private

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

    def uri
      URI("#{service_domain}#{ENDPOINT}")
    end

    def server_reply_url
      server_reply_ecpay_express_cvs_url
    end

    def client_reply_url
      #client_reply_ecpay_express_cvs_url
    end

    def logistics_c2_c_reply_url
      logistics_reply_ecpay_express_cvs_url
    end

  end
end