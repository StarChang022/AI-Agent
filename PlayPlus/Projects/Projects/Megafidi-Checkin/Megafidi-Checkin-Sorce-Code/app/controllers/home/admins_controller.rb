# frozen_string_literal: true

module Home
  class AdminsController < ResourcesController
    def destroy
      if current_object.really_destroy!

        respond_to do |format|
          format.js do
          end
          format.html do
            redirect_to action_after_destroy
          end
        end
      else
        @message = current_object.errors.full_messages.to_sentence

        respond_to do |format|
          format.js do
            render template: 'backends/error'
          end
          format.html do
            flash[:error] = @message
            redirect_to action_after_destroy
          end
        end
      end
    end

    private

    def params_permit
      @params_permit = params.fetch(params_key, {}).permit(*permitted_attributes)
      if @params_permit[:password].blank?
        @params_permit = @params_permit.to_h.except(:password, :password_confirmation)
      end
      @params_permit
    end

    def permitted_attributes
      super
      @permitted_attributes += %i[password password_confirmation]
    end

    def action_after_update
      request.referrer || url_for(action: :edit)
    end
  end
end
