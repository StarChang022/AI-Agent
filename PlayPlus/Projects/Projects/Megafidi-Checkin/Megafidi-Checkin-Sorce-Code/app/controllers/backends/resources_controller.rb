class Backends::ResourcesController < BackendsController

	before_action :prepare_breadcrumb

  include RestfulResource

  def prepare_breadcrumb
    begin
      breadcrumb model_class.model_name.human, url_for(action: :index)
    rescue

    end

    begin
      breadcrumb current_object.try(:display_name) || current_object.name, url_for(action: :show)
    rescue

    end
  end

end
