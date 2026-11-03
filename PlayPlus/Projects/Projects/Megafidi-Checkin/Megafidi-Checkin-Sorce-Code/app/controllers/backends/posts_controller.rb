class Backends::PostsController < Backends::ResourcesController

  private

  def permitted_attributes
    super 
    @permitted_attributes += [:content]
    return @permitted_attributes
  end

end
