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
require 'rails_helper'

RSpec.describe ContentImage, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
