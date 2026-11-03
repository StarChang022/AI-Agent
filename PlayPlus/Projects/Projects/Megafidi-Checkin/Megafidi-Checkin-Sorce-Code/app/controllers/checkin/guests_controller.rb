# frozen_string_literal: true

module Checkin
  class GuestsController < ResourcesController
    layout 'checkin', except: %i[index]

    helper_method :activity

    def index
      if params[:phone_keyword].blank? && params[:certificate_num].blank?
        @current_collection = default_scope.none
      else
        unless current_collection.exists?
          gon.noty_message << { text: '您輸入的資料查無結果，請重新輸入。', type: 'error' }
        end
      end
      render layout: 'home'
    end

    def cancel
      params[:event] = 'cancel'
      update
    end

    def update
      if params_permit.present?
        current_object.update(params_permit)
      end

      @aasm_column = params[:aasm_column] || 'status'.to_sym
      if params[:event].present? && current_object.aasm(@aasm_column).events(permitted: true).map(&:name).include?(params[:event]&.to_sym)
        current_object.send(params[:event])
        current_object.save!
        @message = current_object.registrated? ? '報到成功' : '取消報到成功'
      end

      if current_object.errors.any?

        @message = current_object.errors.full_messages.to_sentence

        flash[:error] = @message
        redirect_back(fallback_location: root_path)

      else
        flash[:success] = @message.presence || '更新成功'
        if current_object.registrated? && @message
          redirect_to url_for(action: :show)
        else
          redirect_to url_for(action: :edit)
        end
      end
    end

    private

    def activity
      @activity = Activity.find(params[:activity_id])
    end
  end
end
