defmodule FrontWeb.OrganizationOktaView do
  use FrontWeb, :view

  def json_encode(config) do
    Poison.encode!(config)
  end

  def session_expiration_days_value(form) do
    case input_value(form, :session_expiration_minutes) do
      nil -> Front.Okta.SessionExpiration.default_days()
      "" -> Front.Okta.SessionExpiration.default_days()
      value -> session_expiration_days_from_minutes(value)
    end
  end

  def session_expiration_days_max, do: Front.Okta.SessionExpiration.max_days()

  def session_expiration_days_from_minutes(nil), do: Front.Okta.SessionExpiration.default_days()

  def session_expiration_days_from_minutes(value),
    do: Front.Okta.SessionExpiration.minutes_to_days(value)
end
