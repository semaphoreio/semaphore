defmodule TaskApiReferent.Validation.Command do
  @moduledoc """
  Contains validation methods for Commands
  """

  @doc "Validates structure of Command List"
  def validate_all(commands) when is_list(commands) do
    with {:ok, _} <- empty?(commands),
         {:ok, _} <- valid?(commands)
    do
      {:ok, "All Commands are valid."}
    else
      e = {:error, _} -> e
    end
  end
  def validate_all(_), do: {:error, "'commands' parameter is of invalid type, must be of type List."}

  # Check if 'commands' List is empty and return appropriate response we can handle later
  defp empty?(commands) do
    if Enum.empty?(commands) do
      {:error, "'commands' List must have atleast one Command."}
    else
      {:ok, "'commands' List contains atleast one Command."}
    end
  end

  # Check if every Command within 'commands' List is valid
  defp valid?(commands) do
    with result <- Enum.map(commands, &(validate(&1))),
         false <- Enum.member?(result, :error)
    do
      {:ok, "All Commands are valid."}
    else
      true ->
        {:error, "One or more Commands in the 'commands' List is invalid."}
    end
  end

  # Validates structure of a single Command
  def validate(command) when is_binary(command), do: {:ok, "Command is valid."}
  def validate(_), do: :error

end
