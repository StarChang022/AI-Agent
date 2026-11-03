class Backends::SystemSettingsController < Backends::ResourcesController

  private

  def current_object
    @current_objcet ||= current_system_setting
  end

end
