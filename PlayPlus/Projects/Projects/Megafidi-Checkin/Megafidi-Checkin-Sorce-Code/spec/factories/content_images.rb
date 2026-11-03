# == Schema Information
#
# Table name: content_images
#
#  id         :integer          not null, primary key
#  deleted_at :datetime
#  file       :string
#  item_type  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  item_id    :integer
#
# Indexes
#
#  index_content_images_on_item_id    (item_id)
#  index_content_images_on_item_type  (item_type)
#
FactoryBot.define do
  factory :content_image do
    
  end
end
