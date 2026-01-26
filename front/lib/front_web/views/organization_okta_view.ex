defmodule FrontWeb.OrganizationOktaView do
  use FrontWeb, :view

  def json_encode(config) do
    Poison.encode!(config)
  end

  def session_expiration_minutes_value(form) do
    case input_value(form, :session_expiration_minutes) do
      # 14 days
      nil -> 20_160
      # 14 days
      "" -> 20_160
      value -> value
    end
  end

  # Maximum allowed session expiration minutes (30 days)
  def session_expiration_minutes_max, do: 43_200
end
