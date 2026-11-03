module Ecpay::Aio
	class CheckOut

		attr_accessor :aio_params#, :url

		include Rails.application.routes.url_helpers

		def initialize(params = {})
			@params = params.symbolize_keys
			@merchant_id = "2000132"
			@key = "5294y06JbISpM5x9"
			@iv = "v77hoKGq4kWxNNIS"
			@aio_params
		end

		def execute
			@aio_params = @params.reverse_merge(required_params).reverse_merge(url_params).reverse_merge(sub_params)
			@aio_params = @aio_params.reverse_merge(credit_params) if @aio_params[:ChoosePayment] == "Credit"
			@aio_params = @aio_params.reverse_merge(atm_params) if @aio_params[:ChoosePayment] == "ATM"
			@aio_params = @aio_params.reverse_merge(cvs_params) if @aio_params[:ChoosePayment] == "CVS"
			@aio_params["CheckMacValue"] = compute_check_mac_value(@aio_params)
			@aio_params
			#compute_check_mac_value(v)
		end

		def url
			# "https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5"
			"https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5"
		end

		private

		def required_params
			{
				MerchantID: @merchant_id, # 特店編號
				MerchantTradeNo: "", # 訂單編號
    		MerchantTradeDate: "", # yyyy/MM/dd HH:mm:ss
    		PaymentType: "aio",
    		TotalAmount: "", # 訂單金額
    		TradeDesc: "", # 交易描述 => UrlEncode
    		ItemName: "", # 商品名稱 joins("#")
    		ChoosePayment: "Credit", # All/Credit/
    		EncryptType: "1",
    	}
    end

    def url_params
    	{
    		ReturnURL: ecpay_return_url, # 付款完成通知回傳網址
    		ClientBackURL: ecpay_client_back_url, # Client 端返回特店的按鈕連結
    		OrderResultURL: ecpay_order_result_url,
    	}
    end

    def sub_params
    	{
    		ItemURL: "", # 商品銷售網址
    		Remark: "", # 備註
    		ChooseSubPayment: "",
    		NeedExtraPaidInfo: "Y",
    		DeviceSource: "",
    		IgnorePayment: "",
    		PlatformID: "",
    		InvoiceMark: "N",
    		CustomField1: "",
    		CustomField2: "",
    		CustomField3: "",
    		CustomField4: "",
    		Language: "",
    	}
    end

    def credit_params
    	{
    		Redeem: "", # 紅利折抵
    		UnionPay: "0", # 銀聯卡
    	}
    end

    def atm_params
    	{
    		ExpireDate: "",
    		PaymentInfoURL: ecpay_payment_info_url,
    		ClientRedirectURL: ecpay_client_redirect_url,
    	}
    end

    def invoice_params
    	{
    		RelateNumber: "", # 訂單編號
    		CustomerID: "",
    		CustomerIdentifier: "", # 統一編號
    		CustomerName: "", # UrlEncode
    		CustomerAddr: "", # UrlEncode
    		CustomerPhone: "",
    		CustomerEmail: "", # UrlEncode

    		ClearanceMark: "2",
    		TaxType: "1",
    		DelayDay: "7", # 0 - 15
    		InvType: "07",

    		CarruerType: "", #載具類別
    		CarruerNum: "", # 載具編號

    		Print: "1", # 要列印嗎？ 0代表不要 1代表要
    		Donation: "0", # 要捐嗎？ 0代表不要 1代表要
    		LoveCode: "", # 要捐給誰，一個7字元的愛心碼

    		InvoiceItemName: "", # joins("|") => UrlEncode
    		InvoiceItemCount: "", # joins("|")
    		InvoiceItemWord: "", # joins("|") => UrlEncode
    		InvoiceItemPrice: "", # joins("|")
    		InvoiceItemTaxType: "", # joins("|") if TaxType == 9

    		InvoiceRemark: "", # UrlEncode
    	}
    end

    def cvs_params
    	{
    		StoreExpireDate: "",
    		Desc_1: "",
    		Desc_2: "",
    		Desc_3: "",
    		Desc_4: "",
    		PaymentInfoURL: ecpay_payment_info_url,
    		ClientRedirectURL: ecpay_client_redirect_url,
    	}
    end

    def compute_check_mac_value(params)
      # 先將參數備份
      params = params.dup

      # 某些參數需要先進行 url encode
      %w[TradeDesc CustomerName CustomerAddr CustomerEmail InvoiceItemName InvoiceItemWord InvoiceRemark].each do |key|
      	next if params[key].nil?
      	params[key] = urlencode_dot_net(params[key])
      end

      # 某些參數不需要參與 CheckMacValue 的計算
      # exclude_keys = %w[InvoiceRemark ItemName ItemWord ItemRemark]
      # params = params.reject do |k, _v|
      # 	exclude_keys.include? k
      # end

      # 轉成 query_string
      query_string = to_query_string(params)
      # 加上 HashKey 和 HashIV
      query_string = "HashKey=#{@key}&#{query_string}&HashIV=#{@iv}"
      # 進行 url encode
      raw = urlencode_dot_net(query_string)
      # 套用 MD5 後轉大寫
      Digest::SHA256.hexdigest(raw).upcase
    end

    def urlencode_dot_net(raw_data)
      # url encode 後轉小寫
      encoded_data = CGI.escape(raw_data).downcase
      # 調整成跟 ASP.NET 一樣的結果
      encoded_data.gsub!('%21', '!')
      encoded_data.gsub!('%2a', '*')
      encoded_data.gsub!('%28', '(')
      encoded_data.gsub!('%29', ')')
      encoded_data
    end

    def to_query_string(params)
      # 對小寫的 key 排序
      params = params.sort_by do |key, _val|
      	key.downcase
      end

      # 組成 query_string
      params = params.map do |key, val|
      	"#{key}=#{val}"
      end
      params.join('&')
    end

  end

end