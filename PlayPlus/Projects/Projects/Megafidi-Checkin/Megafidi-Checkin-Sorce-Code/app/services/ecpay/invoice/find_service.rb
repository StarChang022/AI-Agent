require 'net/http'

module Ecpay::Invoice
  class FindService < BaseService

    attr_accessor :order, :time_stamp, :relate_number, :response

    def initialize(attributes={})
      super
      @time_stamp = Time.current.to_i.to_s
      @relate_number = "#{order.num}"
    end

    def execute
      @response = find(params_with_check_mac_value).deep_transform_keys(&:underscore)
    end

    private

    def url
      if merchant_id == "2000132"
        'https://einvoice-stage.ecpay.com.tw/Query/Issue'
      else
        'https://einvoice.ecpay.com.tw/Query/Issue'
      end
    end

    def fields_for_export
      %w[TimeStamp MerchantID RelateNumber].freeze
    end

    def find(params)
      uri = URI(url)
      response = Net::HTTP.post_form(uri, params)
      body = response.body.force_encoding('UTF-8')
      CGI.parse(body).transform_values(&:first)
    end

  end
end