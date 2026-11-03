class CheckinController < HomeController
  layout 'home'

  skip_before_action :authenticate_role
end
