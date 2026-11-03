module Ecpay::Express
  class CheckMacService < BaseService
    attr_accessor :params, :current_check_mac_value

    def initialize(params)
      # 需要剪掉和綠界無關的 params
      @params = params.slice(*params.keys - %w[action controller id].freeze)
      @current_check_mac_value = @params.delete('CheckMacValue')
    end

    def execute
      check_mac_value(params) == current_check_mac_value
    end

    private

  end
end