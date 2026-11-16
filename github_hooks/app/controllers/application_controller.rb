class ApplicationController < ActionController::API

  def render404
    render :json => { "error" => "Not found." }, :status => :not_found
  end
end
