# == Schema Information
#
# Table name: categories
#
#  id         :integer          not null, primary key
#  deleted_at :datetime
#  depth      :integer
#  lft        :integer
#  name       :string
#  priority   :integer          default(0)
#  rgt        :integer
#  status     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :integer
#
# Indexes
#
#  index_categories_on_parent_id  (parent_id)
#
require 'rails_helper'

RSpec.describe Category, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
