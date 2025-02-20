defmodule Front do
  @doc """
  Checks if application is running on-prem environment
  """
  @spec on_prem?() :: boolean()
  def on_prem? do
    Application.get_env(:front, :on_prem?)
  end

  @spec ce_roles?() :: boolean()
  def ce_roles? do
    Application.get_env(:front, :ce_roles)
  end
end
