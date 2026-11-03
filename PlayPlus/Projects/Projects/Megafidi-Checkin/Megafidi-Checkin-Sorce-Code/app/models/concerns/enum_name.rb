module EnumName
	extend ActiveSupport::Concern
	included do
		defined_enums.keys.each do |key|
			class_eval %Q{
				def #{key}_human
					self.#{key}.present? ? self.class.human_attribute_name(self.#{key}) : ""
				end
			}
		end

	end
end
