defmodule Block.CommandsFileReader.DefinitionRefiner do
  @moduledoc """
  Module serves to take appropriate elements of block build definition, traverse through
  them and calls Transformer module to replace any occurence of 'cmd_file' filed
  with commands read from file which is stated in that field.
  """

  alias Block.CommandsFileReader.Transformer

  def cmd_files_to_commands(definition, args) do
    definition
    |> Map.get("build", nil)
    |> cmd_files_to_commands_(definition, args)
  end

  defp cmd_files_to_commands_(nil, definition, _args), do: {:ok, definition}

  defp cmd_files_to_commands_(build, definition, args) do
    with {:ok, build}    <- to_commands(build, "jobs", args),
         {:ok, build}    <- to_commands(build, "prologue", args, :global_first),
         epilogue        <- Map.get(build, "epilogue", %{}),
         {:ok, epilogue} <- to_commands(epilogue, "always", args, :local_first),
         {:ok, epilogue} <- to_commands(epilogue, "on_pass", args, :local_first),
         {:ok, epilogue} <- to_commands(epilogue, "on_fail", args, :local_first),
         build           <- Map.put(build, "epilogue", epilogue)
    do
       update_definition(definition, build)
    else
        error  -> error
    end
  end

  defp update_definition(definition, build) do
    definition = %{definition | "build" => build}
    {:ok, definition}
  end

  # this is also called from PplSubInit to fetch commands_file for prologue/epiloge
  # from 'global_job_config' field of yaml definition
  def to_commands(build, key, args, merging_order \\ :none) do
    elements = Map.get(build, key, nil)
    with true          <- elements != nil,
         {:ok, values} <- transform_elements(elements, args, merging_order),
         build         <- Map.put(build, key, values)
    do {:ok, build}
    else
      false -> {:ok, build}
      e = {:error, _message} -> e
    end
  end

  # Prologue and epilogue fields are maps, they go through here
  defp transform_elements(element, args, merging_order) when is_map(element) do
    Transformer.transform(element, args, merging_order)
  end

  # Jobs field is list of maps, it goes through here
  defp transform_elements(list, args, merging_order) do
    list
    |> Enum.map(&(Transformer.transform(&1, args, merging_order)))
    |> check_for_errors()
  end

  defp check_for_errors(result_list) do
    result_list
    |> Enum.find_index(&(elem(&1, 0) == :error))
    |> untuple_list(result_list)
  end

  defp untuple_list(nil, list) do
     list = Enum.map(list, &(elem(&1, 1)))
     {:ok, list}
  end
  defp untuple_list(index, list), do: Enum.at(list, index)

end
