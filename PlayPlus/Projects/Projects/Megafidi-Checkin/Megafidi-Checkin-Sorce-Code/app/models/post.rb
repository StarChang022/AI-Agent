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
class Post < ApplicationRecord

  by_star_field :posted_at
  default_value_for :posted_at, -> { Time.current }

  has_rich_text :content

  include ToggleDisplayedStatus

  has_one_attached :image
  include CustomizedActiveStorage

  include CustomizedFriendlyId
  friendly_id :title, use: :slugged

  def slug_candidates
    [
      :title,
      [:title, :posted_at]
    ]
  end

  def should_generate_new_friendly_id?
    slug.blank? || title_changed?
  end

  acts_as_taggable

end
