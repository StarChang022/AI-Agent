# == Schema Information
#
# Table name: images
#
#  id         :integer          not null, primary key
#  deleted_at :datetime
#  item_type  :string
#  name       :string
#  priority   :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  item_id    :integer
#
# Indexes
#
#  index_images_on_item_id    (item_id)
#  index_images_on_item_type  (item_type)
#
class Image < ApplicationRecord

  belongs_to :item, polymorphic: true, optional: true

  has_one_attached :file
  include CustomizedActiveStorage

  def self.nested_attributes
    @nested_attributes = column_names.dup
    @nested_attributes.push("_destroy", "image", "remove_image")
  end
  
end
