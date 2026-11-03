module Ecpay::InvoiceV3
  class CreateService

    include ActiveModel::Model

    attr_accessor :order, :merchant_id, :rq_header, :data

    def initialize(attributes={})
      super
      @rq_header = {
        Timestamp: Time.current.to_i.to_s,
        RqID: SecureRandom.hex(16),
        Revision: "3.0.0"
      }

      @data = Ecpay::InvoiceV3::DataService.new(order: order).execute
    end

    def execute
      fields_for_hash
      create(fields_for_hash)
    end

    def url
      "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue"
      #'https://einvoice-stage.ecpay.com.tw/Invoice/Issue'
    end

    # 定義這三個 method，從 Settings Class 取值
    %w[hash_key hash_iv merchant_id].each do |current|
      define_method current do
        ENV["ecpay_#{current}"]
      end
    end


    private

    def fields_for_hash
      Hash[fields_for_export.map{|field| [field, send(field.underscore)] }]
    end

    def fields_for_export
      %w[MerchantID RqHeader Data].freeze
    end


    def create(params)
      uri = URI(url)
      response = Net::HTTP.post_form(uri, params)
      response.body.force_encoding('UTF-8')
    end


  end


end