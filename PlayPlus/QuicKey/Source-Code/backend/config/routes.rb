Rails.application.routes.draw do
  # Health check for load balancer / uptime monitor.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    scope :auth do
      post "login",  to: "auth#login"
      post "logout", to: "auth#logout"

      scope :signup do
        post "request",  to: "auth#signup_request"
        get  "verify",   to: "auth#signup_verify"
        post "complete", to: "auth#signup_complete"
      end

      scope :password do
        post "forgot", to: "auth#forgot_password"
        post "reset",  to: "auth#reset_password"
        post "change", to: "auth#change_password"
      end
    end

    get   "company",        to: "companies#show"
    patch "company",        to: "companies#update"
    get   "companies/check", to: "companies#check"

    resources :invitations, only: %i[index create destroy]
    get  "invitations/by-token/:token",        to: "invitations#show_by_token"
    post "invitations/by-token/:token/accept", to: "invitations#accept"

    # /users/me 要先於 resources :users 註冊，避免 "me" 被當成 :id 吃掉。
    patch "users/me",            to: "users#update_me"
    patch "users/me/onboarding", to: "users#update_onboarding"
    resources :users, only: %i[index update] do
      member do
        patch :set_status,     path: "status"
        patch :reset_password, path: "password"
      end
    end

    resources :categories, only: %i[index create update] do
      collection do
        patch :reorder
      end
      member do
        patch :archive
        patch :unarchive
      end
    end

    resources :budgets, only: %i[index create update destroy] do
      collection do
        get :utilization
      end
    end

    resources :reimbursements, only: %i[index show create update destroy] do
      collection do
        get :admin
        get :my_summary, path: "my-summary"
        get :export
      end
      member do
        patch :approve
        patch :reject
        patch :void
        patch :withdraw
        patch :revert_void, path: "revert-void"
      end
    end

    resources :expenses, only: %i[index show create update destroy] do
      collection do
        get :pending_batches, path: "pending-batches"
      end
      member do
        patch :pay
        patch :revert_pay, path: "revert-pay"
        patch :adjust_payout_date, path: "adjust-payout-date"
        patch :restore
        delete :purge
      end
    end

    resources :incomes, only: %i[index show create update destroy] do
      member do
        patch :collect
        patch :revert_collect, path: "revert-collect"
        patch :restore
        delete :purge
      end
    end

    scope "payout-schedule" do
      get   "", to: "payout_schedule#show"
      patch "", to: "payout_schedule#update"
    end

    scope "dashboard" do
      get "summary",             to: "dashboard#summary"
      get "trend",               to: "dashboard#trend"
      get "category-breakdown",  to: "dashboard#category_breakdown"
    end

    scope "reports" do
      get "profit-loss(.:format)", to: "reports#profit_loss", defaults: { format: :json },
                                   constraints: { format: /json|xlsx/ }
      get "cashflow(.:format)",    to: "reports#cashflow",    defaults: { format: :json },
                                   constraints: { format: /json|xlsx/ }
    end

    scope "budget-templates" do
      get    "",       to: "budget_templates#index"
      put    "",       to: "budget_templates#upsert"
      post   "apply",  to: "budget_templates#apply"
      delete ":id",    to: "budget_templates#destroy"
    end

    resources :notifications, only: %i[index] do
      member do
        patch :read
      end
      collection do
        patch :mark_all_read, path: "mark-all-read"
        get   :unread_count, path: "unread-count"
      end
    end

    resources :audit_logs, only: %i[index], path: "audit-logs"

    scope "ocr" do
      post "recognize", to: "ocr#recognize"
      get  "quota",     to: "ocr#quota"
    end
  end
end
