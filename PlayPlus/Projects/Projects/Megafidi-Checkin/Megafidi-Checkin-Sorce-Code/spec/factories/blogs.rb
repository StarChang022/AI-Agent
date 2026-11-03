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
FactoryBot.define do
  factory :blog do
    
  end
end
