# == Schema Information
#
# Table name: seo_meta_tags
#
#  id          :integer          not null, primary key
#  deleted_at  :datetime
#  description :text
#  item_type   :string
#  keywords    :string
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  item_id     :integer
#
# Indexes
#
#  index_seo_meta_tags_on_item_id    (item_id)
#  index_seo_meta_tags_on_item_type  (item_type)
#
class SeoMetaTag < ApplicationRecord

  belongs_to :item, polymorphic: true, optional: true

  has_one_attached :image
  include CustomizedActiveStorage

  def self.nested_attributes
    @nested_attributes = column_names.dup
    @nested_attributes.push("_destroy", "image", "remove_image")
  end

end
