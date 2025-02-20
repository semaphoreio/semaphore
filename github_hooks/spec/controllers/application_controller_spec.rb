require "spec_helper"

RSpec.describe ApplicationController, :type => :controller do

  # Creates anonymous controller with ApplicationController as Base
  controller(ApplicationController) do

    def index
      render :text => "Hello from anonymous class"
    end
  end

end
