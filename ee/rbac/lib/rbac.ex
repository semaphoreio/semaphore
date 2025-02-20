defmodule Rbac do
  @doc """
  Checks if application is running on-prem environment
  """
  def on_prem?, do: Application.get_env(:rbac, :on_prem)
end
