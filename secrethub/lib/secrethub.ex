defmodule Secrethub do
  @doc """
  Returns true if the application is running on-prem environment.
  """
  def on_prem?, do: Application.get_env(:secrethub, :on_prem?)
end
