module Ecpay::InvoiceV3

	class DataService

		include ActiveModel::Model

		attr_accessor :order, :time_stamp, :relate_number,
		:customer_id, :customer_identifier, :customer_name, :customer_addr, :customer_phone, :customer_email,
		:print, :donation, :love_code, :clearance_mark,
		:carrier_type, :carrier_num, :invoice_remark,
		:tax_type, :special_tax_type, :inv_type, :vat, :sales_amount,
		:items

		def initialize(attributes={})
			super
			@time_stamp = Time.current.to_i.to_s
			@relate_number = SecureRandom.hex(8)

			@invoice = @order.order_invoice

			@customer_identifier = ""
			@customer_name = ""
			@customer_addr = ""
      # 取其一必填
      @customer_phone = ""
      @customer_email = "service@playplus.com.tw"

      # 0：不列印 捐贈註記[Donation]=1(捐贈) 時載具類別[CarrierType] 有值時
      # 1：要列印 統一編號[CustomerIdentifier]有值時
      @print = "1"

      # 0：不捐贈 統一編號[CustomerIdentifier]有值時 | 載具類別[CarrierType] 有值時
      # 1：要捐贈
      @donation = "0"
      @love_code = ""
      # 無載具 => "", 綠界電子發票載具 => 1, 自然人憑證號碼 => 2, 手機條碼載具 => 3
      @carrier_type = ""
      @carrier_num = ""

      @clearance_mark = "1"

      @tax_type = "1"
      @special_tax_type = ""
      @inv_type = "07"
      @vat = "1"

      @sales_amount = @order.price

      @items = []

      order.order_items.each_with_index do |item, index|
      	@items << Ecpay::InvoiceV3::ItemService.new(item_seq: (index + 1),item: item).execute
      end

      @invoice_remark = ""

    end

    def execute
    	#return fields_for_hash
    	require "openssl"
    	require "base64"

    	@urlencode_dot_net = urlencode_dot_net(fields_for_hash.to_s)
    	@aes128_cbc_encrypt = aes128_cbc_encrypt(hash_key, @urlencode_dot_net, hash_iv)
    	@strict_encode64 = strict_encode64(@aes128_cbc_encrypt)
    	return @strict_encode64
    end

    private

    def fields_for_hash
    	Hash[fields_for_export.map{|field| field == "Vat" ? [field.underscore, send(field.underscore)] : [field, send(field.underscore)] }]
    end

    def fields_for_export
    	%w[
    		MerchantID RelateNumber
    		CustomerIdentifier CustomerName CustomerAddr CustomerPhone CustomerEmail
    		Print Donation LoveCode CarrierType CarrierNum ClearanceMark
    		TaxType SalesAmount InvoiceRemark InvType vat Items
    	].freeze
    end

    %w[hash_key hash_iv merchant_id].each do |current|
    	define_method current do
    		ENV["ecpay_#{current}"]
    	end
    end

    def aes128_cbc_encrypt(key, data, iv)
    	aes = OpenSSL::Cipher::AES128.new(:CBC)
    	aes.encrypt
    	aes.key = key
    	aes.iv = iv
    	encrypt_text = aes.update(data) + aes.final
    end

    def aes128_cbc_decrypt(key, data, iv)
    	aes = OpenSSL::Cipher::AES128.new(:CBC)
    	aes.decrypt
    	aes.key = key
    	aes.iv = iv
    	decrypted_plain_text = aes.update(data) + aes.final
    end

    def strict_encode64(bin)
    	[bin].pack("m0")
    end

    def urlencode_dot_net(raw_data)
    	CGI.escape(raw_data).gsub('%21', '!').gsub('%2a', '*').gsub('%28', '(').gsub('%29', ')')
    end


  end

end