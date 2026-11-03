# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController

  layout 'home'

  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  def destroy
    resource.really_destroy!
    Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
    set_flash_message! :notice, :destroyed
    yield resource if block_given?
    respond_with_navigational(resource){ redirect_to after_sign_out_path_for(resource_name) }
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  def configure_sign_up_params
    # 註冊填寫欄位
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name email gender phone county district zipcode address password password_confirmation])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name gender phone county district zipcode address password password_confirmation])
  end

  def update_resource(resource, params)
    if params[:password].blank?
      result = resource.update_without_password(params)
    else
      result = resource.update_with_password(params)
      bypass_sign_in resource, scope: resource_name if result
    end

    if resource.errors.any?
      gon.noty_message << {type: "error", text: resource.errors.full_messages.to_sentence}
    end

    result
  end

  def after_sign_up_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || super(resource_or_scope)
  end
  
  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
