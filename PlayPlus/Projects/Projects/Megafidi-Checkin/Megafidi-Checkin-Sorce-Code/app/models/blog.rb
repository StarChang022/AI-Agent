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
class Blog < ApplicationRecord

  by_star_field :posted_at
  default_value_for :posted_at, -> { Time.current }

  include CustomizedFriendlyId
  friendly_id :name, use: :slugged

  def slug_candidates
    [
      :name,
      [:name, :posted_at]
    ]
  end

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  acts_as_taggable


  has_one_attached :image

  include CustomizedActiveStorage

  include ToggleDisplayedStatus

  include Seo

  validates_presence_of :name

  # 編輯器選項

  # tinymce
  # tinymce_content

  # trix
  has_rich_text :content

  # contentbuilder
  after_commit :process_builder_content
  def process_builder_content
    service = BuilderContentService.new(builder_content: builder_content)
    service.run
    
    self.builder_content = service.builder_content
  end

end
