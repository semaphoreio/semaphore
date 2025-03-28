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

  @doc """
  Check if it's CE edition
  """
  @spec ce?() :: boolean()
  def ce? do
    Application.get_env(:front, :edition) == "ce"
  end

  @doc """
  Check if it's EE edition
  """
  @spec ee?() :: boolean()
  def ee? do
    Application.get_env(:front, :edition) == "ee"
  end

  @doc """
  Check if it's OS edition
  """
  @spec os?() :: boolean()
  def os? do
    ee?() || ce?()
  end
end
