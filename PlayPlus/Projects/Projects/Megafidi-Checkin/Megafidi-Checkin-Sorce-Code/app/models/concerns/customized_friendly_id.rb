module CustomizedFriendlyId
	extend ActiveSupport::Concern
	included do

		extend FriendlyId

		def normalize_friendly_id(input)
			input.to_s.to_slug.normalize.to_s
		end

		def to_param
			if EnableFriendly.enabled == true
				super
			else
				id.to_s
			end
		end

	end
end