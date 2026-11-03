module Seo
	extend ActiveSupport::Concern
	included do
		has_one :seo_meta_tag, as: :item, dependent: :destroy
		accepts_nested_attributes_for :seo_meta_tag, allow_destroy: true, reject_if: :all_blank
		after_initialize :building_seo_meta_tag, if: :new_record?


		def building_seo_meta_tag
			self.seo_meta_tag ||= SeoMetaTag.new
		end
	end
end
