# == Schema Information
#
# Table name: blogs
#
#  id              :integer          not null, primary key
#  builder_content :text
#  deleted_at      :datetime
#  name            :string
#  posted_at       :datetime
#  slug            :string
#  status          :integer
#  tinymce_content :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_blogs_on_slug  (slug)
#
require 'rails_helper'

RSpec.describe Blog, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
