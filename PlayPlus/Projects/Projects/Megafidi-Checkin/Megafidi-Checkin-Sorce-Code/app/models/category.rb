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
class Category < ApplicationRecord

  default_scope {order(priority: :asc)}

  acts_as_list column: :priority, scope: [:parent_id, deleted_at: nil]

  include ToggleDisplayedStatus
  include EnumAttributeLocalizable

  acts_as_nested_set
  delegate :name, to: :parent, prefix: true, allow_nil: true

  validates :name, presence: true, uniqueness: {scope: :parent_id}

end
