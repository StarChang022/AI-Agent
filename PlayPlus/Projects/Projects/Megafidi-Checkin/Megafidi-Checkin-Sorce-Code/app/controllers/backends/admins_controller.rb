class Backends::AdminsController < Backends::ResourcesController

  private

  def params_permit
    @params_permit = params.fetch(params_key, {}).permit(*permitted_attributes)
    if @params_permit[:password].blank?
      @params_permit = @params_permit.to_h.except(:password)
    end
    @params_permit
  end

  def permitted_attributes
    super
    @permitted_attributes += [:password, :password_confirmation]
  end

end
