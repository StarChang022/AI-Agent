class ErrorsController < HomeController

	layout 'home'

  def unauthorized
    render status: :unauthorized
  end

  def forbidden
    render status: :forbidden
  end

  def not_found
    render status: :not_found
  end

end
