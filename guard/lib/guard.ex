defmodule Guard do
  @moduledoc """
  Documentation for Guard.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Guard.hello
      :world

  """
  def hello do
    :world
  end

  @doc """
  Checks if application is running on-prem environment
  """
  def on_prem?, do: Application.get_env(:guard, :on_prem)
end
