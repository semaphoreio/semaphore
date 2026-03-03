defmodule Rbac.Okta.SessionExpiration do
  @moduledoc false

  @default_minutes 20_160
  @max_minutes 43_200

  def default_minutes do
    Application.get_env(:rbac, :okta_session_expiration_default_minutes, @default_minutes)
  end

  def max_minutes do
    Application.get_env(:rbac, :okta_session_expiration_max_minutes, @max_minutes)
  end
end
