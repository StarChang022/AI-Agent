module Ecpay::Aio
	class CreditFormService < BaseFormService
    CREDIT_ADD_FIELDS = %w[OrderResultURL Redeem UnionPay CreditInstallment].freeze
    attr_accessor *CREDIT_ADD_FIELDS.map{|field| field.underscore.to_sym}

    def initialize(attributes={})
      super
      @choose_payment = "Credit"
      @union_pay ||= 0
      @credit_installment = payment.credit_installment

      @order_result_url = ecpay_order_result_url
    end

    def fields_for_export
      super + CREDIT_ADD_FIELDS
    end

	end
end