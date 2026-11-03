# == Schema Information
#
# Table name: posts
#
#  id         :integer          not null, primary key
#  deleted_at :datetime
#  posted_at  :datetime
#  slug       :string
#  status     :integer
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_posts_on_slug  (slug)
#
FactoryBot.define do
  factory :post do
    title { "MyString" }
  end
end
