class UsersController < HomeController

  before_action :store_user_location!, if: :storable_location?

  before_action :customization_authenticate_user!

  helper_method :resource_name, :resource, :devise_mapping

  def show
    render template: "/users/registrations/edit"
  end

  private

  def resource_name
    :user
  end

  def resource
    @resource ||= current_user
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end

  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end  

end
