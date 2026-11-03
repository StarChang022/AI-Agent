Rails.application.routes.draw do
  require 'sidekiq/web'
  authenticate :admin do
    mount Sidekiq::Web => '/backends/sidekiqz'
  end

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    confirmations: 'users/confirmations',
    passwords: 'users/passwords',
    sessions: 'users/sessions',
    omniauth_callbacks: 'users/omniauth_callbacks',
    unlocks: 'users/unlocks',
  }

  devise_for :admins, controllers: {
    registrations: 'admins/registrations',
    confirmations: 'admins/confirmations',
    passwords: 'admins/passwords',
    sessions: 'admins/sessions',
  }

  root to: 'checkin/activities#index'

  post 'content_images/tinymce', to: 'content_images#tinymce'

  resources :posts

  def resources_routes
    collection do
      post :sort
      match :build, action: :new, via: %w[get post]
      match :bulk_action, via: %w[put patch post]
    end
    member do
      post :acts_as_list
      post :klone
    end
  end

  namespace :backends do
    resources :system_settings, only: %w[edit update]
    resources :resources, :admins, :categories, :contacts, :posts, :blogs do
      resources_routes
    end

    resources :blogs do
      resources_routes
      member do
        get :contentbuilder
      end
    end

    resources :users do
      resources_routes
      member do
        post :sign_in
        patch :skip_confirmation
      end
    end
  end
  resources :backends

  namespace :home do
    resources :users, controller: 'home/users'
  end

  namespace :checkin do
    resources :activities, only: %w[index] do
      resources :guests, only: %w[index show edit update] do
        member do
          match :cancel, via: %w[put patch post]
        end
      end
    end
  end

  namespace :home do
    resources :admins, :activities, :guests do
      resources_routes
    end
  end
  resources :home

  # 暫時跳過身份驗證
  # resource :users, only: %i[show]

  # 暫時設定路由
  # get '/guests/edit', to: 'home/guests#show'
  # get '/users_edit', to: 'home/users#show'

  get '401', to: 'errors#unauthorized', as: :unauthorized
  get '403', to: 'errors#forbidden', as: :forbidden
  get '404', to: 'errors#not_found', as: :not_found
end
