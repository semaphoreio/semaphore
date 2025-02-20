defmodule PipelinesAPI.Util.Config do
  @moduledoc """
  Runtime configuration
  """

  @doc """
  Update application environment from system environment
  """
  def sys2app_env(app, sys_env_var, app_env_var)
      when is_binary(sys_env_var) and is_atom(app) and is_atom(app_env_var) do
    value = System.get_env(sys_env_var)
    Application.put_env(app, app_env_var, value)
    app
  end

  @doc """
  Stop and start again specified application
  """
  def restart_app(_app = nil), do: nil

  def restart_app(app) when is_atom(app) do
    :ok = Application.stop(app)
    {:ok, _} = Application.ensure_all_started(app, :permanent)
  end

  def set_watchman_prefix(sys_env_var, app) when is_binary(sys_env_var),
    do: sys_env_var |> System.get_env() |> set_watchman_prefix_(app)

  defp set_watchman_prefix_(_app_env = nil, _app), do: nil
  defp set_watchman_prefix_(app_env, app), do: put_env(:watchman, :prefix, "#{app}.#{app_env}")

  defp put_env(_app, _key, _value = nil), do: nil

  defp put_env(app, key, value) do
    Application.put_env(app, key, value)
    app
  end
end
