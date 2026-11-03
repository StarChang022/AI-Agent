module EnableFriendly
  thread_mattr_accessor :enabled
end

class ApplicationController < ActionController::Base
  before_action :store_user_location!, if: :storable_location?

  before_action :prepare_meta_tags
  before_action :prepare_noty
  before_action :enable_friendly

  before_action do
    ActiveStorage::Current.url_options = { protocol: request.protocol, host: request.host, port: request.port }
  end

  helper_method :current_system_setting

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::InvalidAuthenticityToken, with: :without_token

  # routing error
  unless Rails.application.config.consider_all_requests_local
    rescue_from ActionController::RoutingError, with: -> { render_404  }
  end

  include Pagy::Backend

  protected

  def enable_friendly
    # 要使用 friendly 的 controller 再複寫成 true
    EnableFriendly.enabled = false
  end

  def current_system_setting
    @current_system_setting ||= SystemSetting.first || SystemSetting.new
  end

  def prepare_noty
    gon.noty_message ||= []
    gon.noty_message << { text: flash[:success], type: 'success' } if flash[:success]
    gon.noty_message << { text: flash[:error], type: 'error' } if flash[:error]
    gon.noty_message << { text: flash[:notice], type: 'success' } if flash[:notice]
    gon.noty_message << { text: flash[:alert], type: 'error' } if flash[:alert]
  end

  def current_seo_meta_tag
    @current_seo_meta_tag ||= current_system_setting&.seo_meta_tag || SeoMetaTag.new
  end

  def meta_tags_i18n_scope(current)
    # namespace = controller_path.split('/').first
    # config/locales/meta_tags.zh-TW.yml
    # 可針對 controller#action 去做設定
    ['meta_tags', controller_name, action_name, current].compact.join('.')
  end

  def prepare_meta_tags(options = {})
    site_name = current_system_setting.name

    title = I18n.t(meta_tags_i18n_scope('title'), default: current_seo_meta_tag.title)
    description = I18n.t(meta_tags_i18n_scope('description'), default: current_seo_meta_tag.description)
    keywords = I18n.t(meta_tags_i18n_scope('keywords'), default: current_seo_meta_tag.keywords)

    # title = current_seo_meta_tag.title
    # description = current_seo_meta_tag.description
    # keywords = current_seo_meta_tag.keywords

    image = rails_blob_url(current_seo_meta_tag.image) if current_seo_meta_tag.image.attached?
    current_url = request.url

    defaults = {
      site: site_name,
      title: title,
      description: description,
      keywords: keywords,
      og: {
        image: image,
        url: current_url,
        site_name: site_name,
        title: title,
        description: description,
        type: 'website',
      },
      reverse: true,
    }

    options.reverse_merge!(defaults)

    set_meta_tags options
  end

  def not_found(e)
    @message = e
    respond_to do |format|
      format.html do
        render template: '/errors/not_found'
      end
      format.js do
        render template: '/backends/error'
      end
    end
    return
  end

  def without_token(e)
    @message = e
    respond_to do |format|
      format.html do
        flash[:error] = @message
        redirect_back(fallback_location: root_path)
      end
      format.js do
        render template: '/backends/error'
      end
    end
    return
  end

  def customization_authenticate_user!
    unless current_user
      respond_to do |format|
        format.html do
          authenticate_user!
        end
        format.js do
          @message = '請先登入！'
          render template: '/backends/error'
        end
      end
    end
  end

  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
  end

  def store_user_location!
    # :user is the scope we are authenticating
    store_location_for(:user, request.fullpath)
  end
end
