defmodule FrontWeb.OrganizationOktaView do
  use FrontWeb, :view

  def json_encode(config) do
    Poison.encode!(config)
  end

  def session_expiration_days_value(form) do
    case input_value(form, :session_expiration_minutes) do
      # 14 days
      nil -> 14
      # 14 days
      "" -> 14
      value -> session_expiration_days_from_minutes(value)
    end
  end

  # Maximum allowed session expiration days (30 days)
  def session_expiration_days_max, do: 30

  def session_expiration_days_from_minutes(nil), do: 14
  def session_expiration_days_from_minutes(value), do: minutes_to_days(value)

  defp minutes_to_days(value) when is_integer(value) do
    max(div(value + 1_439, 1_440), 1)
  end

  defp minutes_to_days(value) when is_binary(value) do
    case Integer.parse(value) do
      {minutes, _} -> minutes_to_days(minutes)
      :error -> 1
    end
  end
end
