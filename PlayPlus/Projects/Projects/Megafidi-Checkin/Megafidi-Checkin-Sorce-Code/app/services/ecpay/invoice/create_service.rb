# https://github.com/chagn/ecpay_invoice_demo
require 'net/http'

module Ecpay::Invoice
  class CreateService < BaseService

    include ActiveModel::Model

    attr_accessor :order, :invoice, :time_stamp, :relate_number,
    :customer_id, :customer_identifier, :customer_name, :customer_addr, :customer_phone, :customer_email,
    :clearance_mark, :print, :donation, :love_code,
    :carruer_type, :carruer_num,
    :tax_type, :special_tax_type, :inv_type, :vat,
    :sales_amount, :item_name, :item_count, :item_word, :item_price, :item_tax_type, :item_amount, :item_remark,
    :invoice_remark, :response

    def initialize(attributes={})
      super
      @time_stamp = Time.current.to_i.to_s
      @relate_number = "#{order.num}"

      @invoice = order.order_invoice
      @items = order.order_items

      @customer_id = ""
      case @invoice.invoice_type
      when "duplex"
        case @invoice.carruer_type
        when "without_carrier"
          @print = "1"
        when "ecpay_carrier"
          @print = "0"
          @carruer_type = 1
          @carruer_num = @invoice.carruer_num
        when "human_certificate"
          @print = "0"
          @carruer_type = 2
          @carruer_num = @invoice.carruer_num
        when "phone_barcode"
          @print = "0"
          @carruer_type = 3
          @carruer_num = @invoice.carruer_num
        end
      when "triple"
        @print = "1"
        @customer_identifier = @invoice.num
        @customer_name = @invoice.title
      when "donation"
        @print = "0"
        @donation = "1"
        @love_code = @invoice.love_code_code
      end

      @customer_name ||= order.purchaser_name
      @customer_addr = order.full_address
      @customer_phone = order.purchaser_phone
      @customer_email = order.purchaser_email

      @clearance_mark = ""

      # 0：不捐贈 統一編號[CustomerIdentifier]有值時 | 載具類別[CarrierType] 有值時
      # 1：要捐贈
      @donation ||= "0"
      @love_code ||= ""

      # 無載具 => "", 綠界電子發票載具 => 1, 自然人憑證號碼 => 2, 手機條碼載具 => 3
      @carruer_type ||= ""
      @carruer_num ||= ""

      @tax_type = "1"
      @special_tax_type = ""
      @inv_type = "07"
      @vat = "1"

      @invoice_remark = ""

      @sales_amount = order.price


      @item_name = @items.map(&:item_name).join("|")
      @item_count = @items.map(&:quantity).join("|")
      @item_word = @items.map(&:unit).join("|")
      @item_price = @items.map(&:price).join("|")
      @item_tax_type = @items.map{|i| 1}.join("|")
      @item_amount = @items.map(&:total_price).join("|")
      @item_remark = ""

    end

    def execute
      @response = create(params_with_check_mac_value).deep_transform_keys(&:underscore)
    end

    def params_without_check_mac_value
      Hash[fields_for_export.map{|field| field == "Vat" ? [field.underscore, send(field.underscore)] : [field, send(field.underscore)] }].select{|k, v| v.present?}
    end

    private

    def fields_for_export
      %w[TimeStamp MerchantID RelateNumber CustomerIdentifier CustomerName CustomerAddr CustomerPhone CustomerEmail Print Donation LoveCode CarruerType CarruerNum TaxType SalesAmount InvoiceRemark ItemName ItemCount ItemWord ItemPrice ItemTaxType ItemAmount ItemRemark InvType vat].freeze
    end

    def url
      if merchant_id == "2000132"
        'https://einvoice-stage.ecpay.com.tw/Invoice/Issue'
      else
        'https://einvoice.ecpay.com.tw/Invoice/Issue'
      end
    end

    def create(params)
      uri = URI(url)
      response = Net::HTTP.post_form(uri, params)
      body = response.body.force_encoding('UTF-8')
      CGI.parse(body).transform_values(&:first)
    end

  end
end