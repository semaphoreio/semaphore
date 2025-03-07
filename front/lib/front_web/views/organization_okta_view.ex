defmodule FrontWeb.OrganizationOktaView do
  use FrontWeb, :view

  def json_encode(config) do
    Poison.encode!(config)
  end
end
