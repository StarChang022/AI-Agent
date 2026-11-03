class Backends::BlogsController < Backends::ResourcesController

  private

  def permitted_attributes
    super
    @permitted_attributes += [:content]
    return @permitted_attributes
  end

  def current_object
    @current_object ||= default_scope.friendly.find(params[:id])
  end

end
