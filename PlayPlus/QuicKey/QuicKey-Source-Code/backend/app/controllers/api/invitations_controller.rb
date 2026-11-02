module Api
  # 員工邀請 endpoints。
  #
  # admin 操作（index / create / destroy）需 JWT + role=admin；
  # public 操作（show_by_token / accept）無需 auth，供邀請信 landing 頁使用。
  class InvitationsController < ApplicationController
    skip_before_action :authenticate!, only: %i[show_by_token accept]
    before_action :require_admin, only: %i[index create destroy]

    # GET /api/invitations?include_inactive=true|false
    def index
      scope = current_user.company.invitations
      scope = scope.active unless include_inactive?

      render json: scope.order(created_at: :desc).map { |inv| serialize_invitation(inv) }
    end

    # POST /api/invitations
    # body: { email, name }
    def create
      email = normalize_email(params[:email])
      name  = params[:name].to_s.strip

      return render_error("INVALID_EMAIL", :unprocessable_content) unless valid_email?(email)
      return render_error("INVALID_NAME",  :unprocessable_content) if name.blank?

      company = current_user.company

      return render_error("AT_LIMIT",      :conflict) if company.members_at_limit?
      return render_error("EMAIL_IN_USE",  :conflict) if User.exists?(email: email)
      return render_error("EMAIL_PENDING", :conflict) if company.invitations.active.exists?(email: email)

      invitation, raw_token = Invitation.generate_for(
        company:    company,
        email:      email,
        name:       name,
        invited_by: current_user
      )
      UserMailer.invitation(invitation, raw_token).deliver_now

      render json: serialize_invitation(invitation), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    # DELETE /api/invitations/:id
    def destroy
      invitation = current_user.company.invitations.find_by(id: params[:id])
      return render json: { error: "not_found" }, status: :not_found if invitation.nil?
      return render_error("ALREADY_ACCEPTED", :conflict) if invitation.accepted?

      invitation.update!(revoked_at: Time.current) if invitation.revoked_at.nil?

      render json: {}, status: :ok
    end

    # GET /api/invitations/by-token/:token
    # 對外 landing 頁用；不揭露 revoked_at / accepted_at / invited_by_user_id 等內部欄位。
    def show_by_token
      invitation = Invitation.find_by_raw(params[:token])

      if invitation.nil?
        return render json: { status: "not_found" }, status: :ok
      end

      case invitation.status
      when "accepted"
        render json: { status: "already_used" }, status: :ok
      when "revoked"
        render json: { status: "revoked" }, status: :ok
      when "expired"
        render json: { status: "expired" }, status: :ok
      else
        render json: {
          status:       "valid",
          email:        invitation.email,
          name:         invitation.name,
          company_name: invitation.company.name,
          expires_at:   invitation.expires_at.iso8601
        }, status: :ok
      end
    end

    # POST /api/invitations/by-token/:token/accept
    # body: { password }
    def accept
      invitation = Invitation.find_by_raw(params[:token])
      return render json: { error: "invalid_or_expired_invitation" }, status: :bad_request if invitation.nil?
      return render json: { error: "invalid_or_expired_invitation" }, status: :bad_request unless invitation.active?

      user = nil

      ActiveRecord::Base.transaction do
        user = User.create!(
          email:    invitation.email,
          password: params[:password],
          name:     invitation.name,
          role:     "employee",
          status:   "active",
          company:  invitation.company
        )
        invitation.update!(accepted_at: Time.current)
      end

      record_login!(user)
      render json: {
        user: {
          id:                      user.id,
          email:                   user.email,
          name:                    user.name,
          role:                    user.role,
          status:                  user.status,
          onboarding_completed_at: user.onboarding_completed_at&.iso8601
        },
        auth_token: JwtService.encode(user_id: user.id)
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: validation_error(e.record), status: :unprocessable_content
    end

    private

    def require_admin
      return if current_user&.role_admin?
      render json: { error: "forbidden" }, status: :forbidden
    end

    def include_inactive?
      params[:include_inactive].to_s == "true"
    end

    def normalize_email(raw)
      raw.to_s.downcase.strip
    end

    def valid_email?(email)
      email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def record_login!(user)
      user.update_column(:last_login_at, Time.current)
    end

    def serialize_invitation(invitation)
      {
        id:                 invitation.id,
        email:              invitation.email,
        name:               invitation.name,
        status:             invitation.status,
        expires_at:         invitation.expires_at.iso8601,
        accepted_at:        invitation.accepted_at&.iso8601,
        revoked_at:         invitation.revoked_at&.iso8601,
        invited_by_user_id: invitation.invited_by_id,
        created_at:         invitation.created_at.iso8601
      }
    end

    def validation_error(record)
      { error: "validation_failed", details: record.errors.messages }
    end

    def render_error(code, status)
      render json: { error: code }, status: status
    end
  end
end
