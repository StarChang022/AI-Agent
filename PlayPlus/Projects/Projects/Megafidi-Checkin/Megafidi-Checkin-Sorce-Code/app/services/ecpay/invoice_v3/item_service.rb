module Ecpay::InvoiceV3

	class ItemService

		include ActiveModel::Model

    attr_accessor :item, :item_seq, :item_name, :item_count, :item_word, :item_price, :item_tax_type, :item_amount, :item_remark

		def initialize(attributes={})
			super
			@item_seq ||= ""
			@item_name ||= item.item_name
			@item_count ||= item.quantity
			@item_word ||= "單位"
			@item_price ||= item.price

			@item_tax_type ||= "1"
			@item_amount = @item_count * @item_price

			@item_remark ||= ""
		end

		def execute
			return Hash[fields_for_export.map{|field| [field, send(field.underscore)] }]
		end

		private

    def fields_for_export
      %w[ItemSeq ItemName ItemCount ItemWord ItemPrice ItemTaxType ItemAmount ItemRemark].freeze
    end

	end

end