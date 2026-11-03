module Ecpay::Aio
  class PeriodFormService < BaseFormService
    PERIOD_ADD_FIELDS = %w[PeriodAmount PeriodType Frequency ExecTimes PeriodReturnURL OrderResultURL].freeze
    attr_accessor *PERIOD_ADD_FIELDS.map{|field| field.underscore.to_sym}
    def initialize(attributes={})
      super
      @choose_payment = "Credit"

      @period_amount ||= payment.period_amount || 20
      @period_type ||= payment.period_type || "M"
      @frequency ||= payment.frequency || 1
      @exec_times ||= payment.exec_times || 1

      @period_return_url ||= ecpay_period_return_url
      @order_result_url = ecpay_order_result_url

    end

    def fields_for_export
      super + PERIOD_ADD_FIELDS
    end

  end
end