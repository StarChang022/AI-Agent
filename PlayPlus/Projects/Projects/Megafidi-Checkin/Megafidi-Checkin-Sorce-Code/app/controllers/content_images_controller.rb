class ContentImagesController < ApplicationController

  skip_before_action :verify_authenticity_token

  def tinymce
    @content_image = ContentImage.create(file: params[:file])
    render json: {location: @content_image.file.url}
  end

end
