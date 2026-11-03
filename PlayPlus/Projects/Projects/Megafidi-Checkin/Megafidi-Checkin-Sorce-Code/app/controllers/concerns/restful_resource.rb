module RestfulResource

  extend ActiveSupport::Concern

  included do
    helper_method :model_class, :model_class_name, :current_collection, :current_pagy, :pagy_current_collection, :current_object, :params_key, :model_events, :per_page

    def index
      @new = true if @new != false
      @xlsx = false

      respond_to do |format|
        format.xlsx {
          @current_collection = default_scope
          render filename: "#{model_class.model_name.human}.xlsx", xlsx: 'index'
        }
        format.html {

        }
      end
    end

    def new
      _klone_object = default_scope.find_by_id(params[:_klone_id])

      if _klone_object
        _klone_attritubes = _klone_object.as_json(only: _klone_object.klone_attritubes)
        @current_object = default_scope.new( params_permit.merge(_klone_attritubes) )
      else
        @current_object = default_scope.new(params_permit)
      end
    end

    def klone
      redirect_to url_for( {
        action: :new, 
        _klone_id: current_object.id,
        klone_next: params[:klone_next]
      } )
    end

    def create
      @current_object = default_scope.new(params_permit)
      if @current_object.save
        @message = "成功建立#{model_class.model_name.human}"

        after_create
        after_save

        respond_to do |format|
          format.js {

          }
          format.html {
            flash[:success] = @message
            if params[:create_next].present?
              redirect_to url_for(action: :new, create_next: true)
            else
              redirect_to action_after_create            
            end
          }
        end
      else
        @message = @current_object.errors.full_messages.to_sentence

        respond_to do |format|
          format.js {
            render template: "backends/error"
          }
          format.html {
            gon.noty_message << {:text => @message, type: "error"}
            render action: :new
          }
        end
      end
    end

    def show

    end

    def edit
      render action: :new
    end

    def update
      if params_permit.present?
        current_object.update(params_permit)
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
        @message = "成功更新#{model_class.model_name.human}"

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

    def acts_as_list
      case params[:event]
      when "insert_at"
        @priority = params[:priority].to_i
        current_object.save
        if @priority > 0
          current_object.insert_at(@priority) 
          @message = "調整排序到第#{@priority}個"
        else
          @message = "請輸入正確的數字"
        end

      when "move_to_top", "move_to_bottom"
        current_object.save
        current_object.send(params[:event])

        @message = "調整排序"
      else
        @message = "不允許的動作"

        respond_to do |format|
          format.js {
            render template: "backends/error"
          }
          format.html {
            flash[:error] = @message
            redirect_back(fallback_location: root_path)
          }
        end        
        return
      end 

      respond_to do |format|
        format.json {

        }
        format.html {
          flash[:success] = @message
          redirect_to action_after_update
        }
      end

    end

    def sort
      @current_collection = default_scope.where(id: params[:sort])

      @current_collection.each do |object|
        object.update!(priority: params[:sort].index("#{object.id}"))
      end

      @message = "完成."

      render json: 'sort_success'
    end

    def destroy
      if current_object.destroy
        flash[:success] = "成功刪除#{model_class.model_name.human}"

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
    
    def bulk_action
      if self.action_methods.include?(params[:bulk_action])
        send(params[:bulk_action])
      end
    end

    def bulk_delete

      @messages = []
      @count = 0

      current_collection.each do |current_object|
        unless current_object.destroy
          @messages << current_object.errors.full_messages.to_sentence
        else
          @count += 1
        end
      end

      flash[:error] = @messages.join("<br>") if @messages.present?
      flash[:success] = "成功刪除#{@count}筆資料。"

      redirect_to action_after_update
    end

    def bulk_event
      if model_events.include?(params[:bulk_event].to_sym)

        @count = 0

        current_collection.each do |current_object|
          if current_object.send("may_#{params[:bulk_event]}?")
            @count += 1
            current_object.send("#{params[:bulk_event]}!")
          end
        end

        flash[:success] = "成功更改#{@count}筆資料。"

        redirect_to action_after_update

      else
        @message = "不允許的動作"

        respond_to do |format|
          format.js {
            render template: "backends/error"
          }
          format.html {
            flash[:error] = @message
            redirect_back(fallback_location: root_path)
          }
        end        
      end
    end

    private

    def model_events
      begin
        @model_events ||= model_class.aasm(:status).events.map{|i| i.name}
      rescue
        @model_events ||= []
      end
    end

    def model_class_name
      self.class.to_s.demodulize.gsub('Controller', '').singularize
    end

    def model_class
      model_class_name.constantize
    end

    def params_key
      model_class_name.underscore.to_sym
    end

    def default_scope
      @default_scope ||= model_class.v_search(params.permit!.to_h)
    end

    def per_page
      params[:per_page] || 20
    end

    def pagy_execute
      @current_pagy, @pagy_current_collection = pagy(current_collection, items: per_page, page: params[:page])
    end

    def current_pagy
      pagy_execute if @current_pagy.blank?
      @current_pagy
    end

    def pagy_current_collection
      pagy_execute if @current_pagy.blank?
      @pagy_current_collection
    end

    def current_collection
      @current_collection ||= default_scope
    end

    def current_object
      @current_object ||= default_scope.find(params[:id])
    end

    def params_permit
      params.fetch(params_key, {}).permit(*permitted_attributes)
    end

    def permitted_attributes
      @permitted_attributes = model_class.column_names.dup
      @permitted_attributes += model_class.attachment_reflections.keys + model_class.attachment_reflections.keys.map{|i| "remove_#{i}".to_sym}
      @permitted_attributes += [translations_attributes: model_class.translation_class.column_names] if model_class.try(:translation_class)

      model_class.nested_attributes_options.keys.each do |current|
        @permitted_attributes += [
          "#{current}_attributes": current.to_s.classify.constantize.nested_attributes
        ]
      end

      model_class.try(:acts_as_taggable_on).each do |current|
        @permitted_attributes += ["#{current.singularize}_list".to_sym => []]
      end if model_class.try(:acts_as_taggable_on)

      return @permitted_attributes
    end

    def action_after_create
      url_for action: :index
    end

    def action_after_update
      request.referrer || url_for(action: :index)
    end
    
    alias :action_after_destroy :action_after_update

    def after_create
    end

    def after_update
    end

    def after_save
    end

  end

end