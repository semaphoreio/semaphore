class ApplicationController < ActionController::Base

  def render404
    if request.format.json?
      render :json => { "error" => "Not found." }, :status => :not_found
    else
      render "errors/not_found", :status => :not_found, :layout => false
    end
  end
end
