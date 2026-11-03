module Ecpay::Aio
  class AtmFormService < BaseFormService
    ATM_ADD_FIELDS = %w[ExpireDate PaymentInfoURL ClientRedirectURL ChooseSubPayment].freeze
    attr_accessor *ATM_ADD_FIELDS.map{|field| field.underscore.to_sym}
    def initialize(attributes={})
      super
      @choose_payment = "ATM"
      @expire_date ||= payments.expire_date
      @payment_info_url ||= ecpay_payment_info_url
      @client_redirect_url ||= ecpay_client_redirect_url
    end

    def fields_for_export
      super + ATM_ADD_FIELDS
    end

  end
end