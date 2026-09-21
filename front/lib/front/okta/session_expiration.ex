defmodule Front.Okta.SessionExpiration do
  @moduledoc false

  @default_minutes 20_160
  @max_minutes 43_200
  @minutes_per_day 1_440

  def default_minutes do
    Application.get_env(:front, :okta_session_expiration_default_minutes, @default_minutes)
  end

  def max_minutes do
    Application.get_env(:front, :okta_session_expiration_max_minutes, @max_minutes)
  end

  def default_days, do: minutes_to_days(default_minutes())
  def max_days, do: minutes_to_days(max_minutes())

  def minutes_to_days(nil), do: minutes_to_days(default_minutes())

  def minutes_to_days(value) when is_integer(value) do
    max(div(value + @minutes_per_day - 1, @minutes_per_day), 1)
  end

  def minutes_to_days(value) when is_binary(value) do
    case Integer.parse(value) do
      {minutes, _} -> minutes_to_days(minutes)
      :error -> 1
    end
  end

  def minutes_to_days(_), do: 1

  def days_to_minutes(value) when is_integer(value) and value > 0 do
    value * @minutes_per_day
  end

  def days_to_minutes(value) when is_binary(value) do
    case Integer.parse(value) do
      {days, _} -> days_to_minutes(days)
      :error -> nil
    end
  end

  def days_to_minutes(_), do: nil
end
