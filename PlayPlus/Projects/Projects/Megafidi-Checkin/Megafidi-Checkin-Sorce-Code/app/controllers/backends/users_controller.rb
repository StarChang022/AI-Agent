class Backends::UsersController < Backends::ResourcesController 

  def show
    @children = %w[]
  end

  def sign_in
    sign_in(:user, current_object)

    flash[:success] = "已登入#{current_object.email}"

    redirect_to users_path
  end

  def skip_confirmation
    current_object.skip_confirmation!
    current_object.save

    flash[:success] = "驗證Email成功。"

    redirect_back(fallback_location: root_path)
  end

  def update
    if params_permit.present?
      current_object.update_with_password(params_permit)
    end

    @aasm_column = params[:aasm_column] || "status".to_sym
    if current_object.aasm(@aasm_column).events(:permitted => true).map(&:name).include?(params[:event]&.to_sym)
      current_object.send(params[:event])
      current_object.save!
    else

    end if params[:event].present?

    if current_object.errors.any?

      @message = current_object.errors.full_messages.to_sentence

      respond_to do |format|
        format.js {
          render template: "backends/error"
        }
        format.html {
          gon.noty_message << {:text => @message, type: "error"}
          render action: :new
        }
      end

    else
      @message = "編輯成功."

      after_update
      after_save

      respond_to do |format|
        format.js {

        }
        format.html {
          flash[:success] = @message
          redirect_to action_after_update
        }
      end
    end
  end

  def destroy
    if current_object.really_destroy!

      respond_to do |format|
        format.js {

        }
        format.html {
          redirect_to action_after_destroy
        }
      end
    else
      @message = current_object.errors.full_messages.to_sentence

      respond_to do |format|
        format.js {
          render template: "backends/error"
        }
        format.html {
          flash[:error] = @message
          redirect_to action_after_destroy
        }
      end
    end
  end

  private

  def default_scope
    @default_scope ||= model_class.v_search(params.permit!.to_h).order(id: :desc)
  end

  def permitted_attributes
    super
    @permitted_attributes += [:password]
    @permitted_attributes
  end


end
