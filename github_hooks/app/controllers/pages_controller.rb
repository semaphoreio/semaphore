class PagesController < ApplicationController

  def alive?
    render :plain => "yes"
  end

end
