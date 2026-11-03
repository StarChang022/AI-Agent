# == Schema Information
#
# Table name: content_images
#
#  id         :integer          not null, primary key
#  deleted_at :datetime
#  file       :string
#  item_type  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  item_id    :integer
#
# Indexes
#
#  index_content_images_on_item_id    (item_id)
#  index_content_images_on_item_type  (item_type)
#
class ContentImage < ApplicationRecord

  attr_accessor :original_filename, :content_type

  mount_uploader :file, ContentImageUploader

  def file_data=(data)
    sio = CarrierStringIO.new(Base64.decode64(data))
    sio.original_filename = original_filename
    sio.content_type = content_type
    self.file = sio
  end

end
