class Backends::CategoriesController < Backends::ResourcesController

  helper_method :current_parent_options

  def index
    @current_collection = default_scope.roots
    @initialize_object = default_scope.new
  end

  def show
    @initialize_object = default_scope.new(parent_id: current_object.id)
    @current_collection = current_object.children
    render action: :index
  end

  private

  def current_parent_options
    @current_parent_options ||= default_scope.roots.map{|i| [i.name, i.id]}
  end

  def action_after_create
    if current_object.parent.present?
      url_for action: :show, id: current_object.parent_id
    else
      url_for action: :index
    end
  end


end
