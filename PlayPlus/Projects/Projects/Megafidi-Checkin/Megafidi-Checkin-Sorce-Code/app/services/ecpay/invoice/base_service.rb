require 'net/http'

module Ecpay::Invoice
  class BaseService

    include ActiveModel::Model

    def initialize(attributes={})
      super
    end

    private

    def params_without_check_mac_value
      Hash[fields_for_export.map{|field| [field, send(field.underscore)] }]
    end

    def params_with_check_mac_value
      res = params_without_check_mac_value.dup
      res['CheckMacValue'] = compute_check_mac_value(res)
      res
    end

    def fields_for_export
      %w[].freeze
    end

    def url_encode_keys
      %w[CustomerName CustomerAddr CustomerEmail]
    end

    def exclude_keys
      %w[InvoiceRemark ItemName ItemWord ItemRemark]
    end

    def compute_check_mac_value(params)
      # 先將參數備份
      params = params.dup

      # 某些參數需要先進行 url encode
      url_encode_keys.each do |key|
        next if params[key].nil?
        params[key] = urlencode_dot_net(params[key])
      end

      # 某些參數不需要參與 CheckMacValue 的計算
      params = params.except(*exclude_keys)

      query_string = params.to_a.sort_by(&:first).unshift(['HashKey', hash_key]).push(['HashIV', hash_iv]).map do |kav|
        kav.join("=")
      end.join("&")

      # 進行 url encode
      raw = urlencode_dot_net(query_string)
      # 套用 MD5 後轉大寫
      Digest::MD5.hexdigest(raw).upcase
    end

    def urlencode_dot_net(raw_data)
      CGI.escape(raw_data).downcase.gsub('%21', '!').gsub('%2a', '*').gsub('%28', '(').gsub('%29', ')')
    end

    # 定義這三個 method，從 Settings Class 取值
    %w[hash_key hash_iv merchant_id].each do |current|
      define_method current do
        ENV["ecpay_#{current}"]
      end
    end


  end
end