# == Schema Information
#
# Table name: activities
#
#  id         :integer          not null, primary key
#  date       :date
#  deleted_at :datetime
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Activity < ApplicationRecord
  has_many :guests

  def guests_count
    guests.count
  end
end
