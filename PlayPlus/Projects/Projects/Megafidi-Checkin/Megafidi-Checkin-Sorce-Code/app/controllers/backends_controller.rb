class BackendsController < ApplicationController

	before_action :authenticate_admin!

	before_action do
		prepare_meta_tags(title: I18n.t("backends.index"))
	end

	breadcrumb "#{I18n.t("backends.index")}", :backends_path

	def index

	end

  private

  def store_user_location!
    # :user is the scope we are authenticating
    store_location_for(:admin, request.fullpath)
  end

end
