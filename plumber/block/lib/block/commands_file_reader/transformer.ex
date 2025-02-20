defmodule Block.CommandsFileReader.Transformer do
  @moduledoc """
  Module accepts map in which it replaces any occurence of 'commands_file' filed
  with commands read from file which is stated in that 'commands_file' field.
  """

  alias Block.CodeRepo

  def transform(element, args, merging_order) when is_map(element) do
    with file when file != nil <- Map.get(element, "commands_file", nil),
         {:ok, commands}       <- read_commands_from_file(file, args)
    do insert_commands(element, commands, merging_order)
    else
        nil               ->  {:ok, element}
        e = {:error, {:malformed, _msg}} -> e
        {:error, message} ->  return_error(element, message)
    end
  end
  def transform(element, _args, _merge_with_commands?),
    do: {:error, "Expected map, got: #{element}"}

  defp read_commands_from_file(file, args) when is_binary(file) do
    args
    |> Map.put("file_name", file)
    |> CodeRepo.get_file()
    |> get_commands_from_lines()
  end

  def get_commands_from_lines({:ok, lines}) do
    lines
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(fn line -> String.trim(line) end)
    |> return_ok_tuple()
  end
  def get_commands_from_lines({:error, message}), do: {:error, message}

  defp insert_commands(element, commands, _merging_order = :none) do
    element
    |> Map.put("commands", commands)
    |> Map.delete("commands_file")
    |> return_ok_tuple()
  end
  defp insert_commands(element, commands, merging_order) do
    existing_commands = Map.get(element, "commands", [])
    element
    |> Map.put("commands", merge_commands(existing_commands, commands, merging_order))
    |> Map.delete("commands_file")
    |> return_ok_tuple()
  end

  defp merge_commands(existing_commands, commands, :global_first),
   do: existing_commands ++ commands
 defp merge_commands(existing_commands, commands, :local_first),
   do:  commands ++ existing_commands

  defp return_error(element, message) do
    "Error in #{inspect element} - #{inspect message}"
    |> return_error_tuple()
  end

  defp return_ok_tuple(element), do: {:ok, element}
  defp return_error_tuple(message), do: {:error, message}
end
