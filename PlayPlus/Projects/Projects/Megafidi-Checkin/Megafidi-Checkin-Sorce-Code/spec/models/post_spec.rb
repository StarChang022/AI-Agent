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
require 'rails_helper'

RSpec.describe Post, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
