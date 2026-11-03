module Ecpay::Express
	class BaseService
		include ActiveModel::Model
    include Rails.application.routes.url_helpers

    def initialize(attributes={})
      super
    end

    def service_domain
      if ENV['ecpay_express_env'] == "production"
        @service_domain = 'https://logistics.ecpay.com.tw/'
      else
        @service_domain = 'https://logistics-stage.ecpay.com.tw/'
      end
    end

    # 定義這三個 method，從 Settings Class 取值
    %w[hash_key hash_iv merchant_id].each do |current|
      define_method current do
      	ENV["ecpay_express_#{current}"]
      end
    end

    def params_without_check_mac_value
      Hash[fields_for_export.map{|field| [field, send(field.underscore)] if send(field.underscore).present?}]
    end

    def params_with_check_mac_value
      res = params_without_check_mac_value.dup
      res['CheckMacValue'] = check_mac_value(res)
      res
    end

    def fields_for_export
      %w[].freeze
    end

    private

    def merchant_trade_date
      @merchant_trade_date ||= Time.current.strftime('%Y/%m/%d %H:%M:%S')
    end

    def check_mac_value(params)
      query_string = params.transform_keys(&:downcase).to_a.sort_by(&:first).unshift(['HashKey', hash_key]).push(['HashIV', hash_iv]).map do |kav|
        kav.join("=")
      end.join("&")

      #query_string = "HashKey=XBERn1YOvpM9nfZc&GoodsAmount=1000&IsCollection=N&LogisticsSubType=FAMIC2C&LogisticsType=CVS&MerchantID=2000933&MerchantTradeDate=2013/03/12 15:30:23&MerchantTradeNo=A20130312153023&ReceiverName=收件者姓名&ReceiverStoreID=001779&SenderName=寄件者姓名&ServerReplyURL=https://www.ecpay.com.tw/ServerReplyURL&HashIV=h1ONHk4P4yqbl5LK"

      raw = urlencode_dot_net(query_string.downcase)
      Digest::MD5.hexdigest(raw).upcase
    end

    def urlencode_dot_net(raw_data)
      CGI.escape(raw_data).downcase.gsub('%21', '!').gsub('%2a', '*').gsub('%28', '(').gsub('%29', ')')
    end

  end
end