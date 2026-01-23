defmodule FrontWeb.OrganizationOktaView do
  use FrontWeb, :view

  def json_encode(config) do
    Poison.encode!(config)
  end

  def session_expiration_minutes_value(form) do
    case input_value(form, :session_expiration_minutes) do
      nil -> 4320
      "" -> 4320
      value -> value
    end
  end
end
