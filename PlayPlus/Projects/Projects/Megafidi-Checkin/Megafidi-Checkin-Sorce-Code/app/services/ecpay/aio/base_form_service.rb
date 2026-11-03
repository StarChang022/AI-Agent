module Ecpay::Aio
	class BaseFormService
		include ActiveModel::Model
    include Rails.application.routes.url_helpers

    attr_accessor :payment, :merchant_trade_no, :trade_desc, :item_name, :total_amount,
                  :client_back_url, :return_url,
                  :custom_field1, :custom_field2, :custom_field3, :custom_field4,
                  :encrypt_type, :platform_id, :invoice_mark,
                  :need_extra_paid_info, :merchant_trade_date, :payment_type, :remark, :choose_payment

    def initialize(attributes={})
      super
      @encrypt_type ||= 1
      @invoice_mark ||= 'N'
      @need_extra_paid_info ||= 'Y'
      @payment_type ||= 'aio'
      @merchant_trade_date ||= Time.current.strftime('%Y/%m/%d %H:%M:%S')
      @item_name ||= payment.item_name
      @total_amount ||= payment.total_amount
      @merchant_trade_no ||= payment.num
      @trade_desc ||= payment.trade_desc

      @return_url = ecpay_return_url # 付款完成通知回傳網址
      @client_back_url = ecpay_client_back_url # Client 端返回特店的按鈕連結
    end

    # 定義這三個 method，從 Settings Class 取值
    %w[hash_key hash_iv merchant_id].each do |current|
      define_method current do
      	ENV["ecpay_#{current}"]
      end
    end

    def params_without_check_mac_value
      Hash[fields_for_export.map{|field| [field, send(field.underscore)] }]
    end

    def params_with_check_mac_value
      res = params_without_check_mac_value.dup
      res['CheckMacValue'] = check_mac_value(res)
      res
    end

    def fields_for_export
      %w[MerchantTradeNo TotalAmount ItemName MerchantID MerchantTradeDate TradeDesc EncryptType
         PlatformID InvoiceMark PaymentType ChoosePayment NeedExtraPaidInfo ReturnURL].freeze
    end

    private

    def check_mac_value(params)
      query_string = params.transform_keys(&:downcase).to_a.sort_by(&:first).unshift(['HashKey', hash_key]).push(['HashIV', hash_iv]).map do |kav|
        kav.join("=")
      end.join("&")
      raw = urlencode_dot_net(query_string)
      Digest::SHA256.hexdigest(raw).upcase
    end

    def urlencode_dot_net(raw_data)
      CGI.escape(raw_data).downcase.gsub('%21', '!').gsub('%2a', '*').gsub('%28', '(').gsub('%29', ')')
    end

	end
end