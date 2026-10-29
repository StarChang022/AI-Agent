module Api
  # 公司資訊 endpoints：
  # - GET /api/company          所有登入 user 可讀
  # - PATCH /api/company        僅管理員可改 name / tax_id（company_type 階段內不開放改）
  # - GET /api/companies/check  public；註冊頁用來查統編是否已有公司
  class CompaniesController < ApplicationController
    skip_before_action :authenticate!, only: :check
    before_action :require_admin, only: :update

    # GET /api/company
    # 回當前登入 user 的公司資訊 + 名額限制。
    # 前端 UsersView 讀 memberLimit 作為「使用中名額 N / X」顯示與邀請按鈕 disabled 判斷。
    def show
      render json: serialize(current_user.company)
    end

    # GET /api/companies/check?tax_id=xxx
    # 註冊時用來提示使用者「相同統編已有公司」。純 UX 檢查、不做唯一性約束。
    # 回 { exists, matched_name }；tax_id 空字串或格式非 8 碼時一律回 exists: false。
    def check
      tax_id = params[:tax_id].to_s.strip
      if tax_id.match?(/\A\d{8}\z/)
        company = Company.where(tax_id: tax_id).first
        render json: { exists: company.present?, matched_name: company&.name }
      else
        render json: { exists: false, matched_name: nil }
      end
    end

    # PATCH /api/company   body: { name, tax_id }
    # tax_id 可傳空字串或 null 表示清空；Company#normalize_tax_id 會轉成 nil。
    def update
      company = current_user.company
      if company.update(company_params)
        render json: serialize(company)
      else
        render json: validation_error(company), status: :unprocessable_content
      end
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def company_params
      params.permit(:name, :tax_id)
    end

    def serialize(company)
      {
        id:            company.id,
        name:          company.name,
        company_type:  company.company_type,
        tax_id:        company.tax_id,
        plan:          company.plan,
        member_limit:  Company::MEMBER_LIMIT,
        members_used:  company.members_used
      }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end
  end
end
