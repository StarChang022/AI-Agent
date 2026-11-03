class BuilderContentService

  include ActiveModel::Model
  attr_accessor :builder_content

  def initialize(attributes={})
    super
    @builder_content = builder_content
  end


  def run
    require 'nokogiri'
    require 'open-uri'

    @nokogiri_html = Nokogiri::HTML(@builder_content)
    @images = @nokogiri_html.css("img")

    @images.each do |image|
      src = image['src']
      original_filename = image['data-filename']

      begin
        regex = src.match(/data:(image\/[a-zA-Z]*);base64,([^\"]*)/)
  
        if regex.present?
          content_type, data = regex.captures

          content_image = ContentImage.new
          content_image.original_filename = original_filename
          content_image.content_type = content_type
          content_image.file_data = data
          content_image.save

          image.attributes["src"].value = content_image.file.url
          image.set_attribute("content_image", "#{content_image.id}")
        end
        
        image.remove_attribute('onload')

      rescue
        regex = nil

        image.remove

      end
      
    end

    @builder_content = @nokogiri_html.css("body").inner_html

  end

  private

end