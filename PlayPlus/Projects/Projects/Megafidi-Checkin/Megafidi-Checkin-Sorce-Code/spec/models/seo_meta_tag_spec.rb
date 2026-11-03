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
require 'rails_helper'

RSpec.describe SeoMetaTag, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
