module Ecpay::Express
	class QueryService < BaseService

		ENDPOINT = "Helper/QueryLogisticsTradeInfo/V2"

		attr_accessor :all_pay_logistics_id, :response_params

		def initialize(attributes={})
			super

		end

		def run
			@request = Net::HTTP.post_form(uri, params_with_check_mac_value)

			@response = @request.body.force_encoding('UTF-8')
			@params = Rack::Utils.parse_query(@response)
			@response_params = @params.deep_transform_keys(&:underscore)

			unless Ecpay::Express::CheckMacService.new(@params).execute
        # 檢查碼不符
      end

      @response_params = @response_params
      return @response_params
    end

    private

    def fields_for_export
    	%w[ MerchantID AllPayLogisticsID TimeStamp ].freeze
    end

    def uri
    	URI("#{service_domain}#{ENDPOINT}")
    end

    def time_stamp
    	@time_stamp ||= Time.current.to_i
    end

  end
end