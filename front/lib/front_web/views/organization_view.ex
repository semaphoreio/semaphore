defmodule FrontWeb.OrganizationView do
  use FrontWeb, :view

  def domain do
    Application.get_env(:front, :domain)
  end
end
