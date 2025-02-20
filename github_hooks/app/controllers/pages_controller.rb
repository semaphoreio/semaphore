class PagesController < ApplicationController

  def is_alive # rubocop:disable Naming/PredicateName
    render :plain => "yes"
  end

end
