defmodule Front do
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
  Check if it's specifically the on-prem edition
  """
  @spec onprem?() :: boolean()
  def onprem? do
    Application.get_env(:front, :edition) == "onprem"
  end

  @doc """
  Check if it's OS edition
  """
  @spec os?() :: boolean()
  def os? do
    ee?() || ce?()
  end

  @doc """
  Check if we're running on saas or not
  """
  @spec saas?() :: boolean()
  def saas? do
    !os?() && !onprem?()
  end

  @doc """
  Whether a service account's projects are held to its owner's access.

  Mirrors the same switch in the service that applies the rule, so the UI says a
  create is blocked only where it really is.
  """
  @spec enforce_service_account_owner?() :: boolean()
  def enforce_service_account_owner? do
    Application.get_env(:front, :enforce_service_account_owner?, false)
  end
end
