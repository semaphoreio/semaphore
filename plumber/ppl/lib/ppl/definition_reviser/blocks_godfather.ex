defmodule Ppl.DefinitionReviser.BlocksGodfather do
  @moduledoc """
  Module serves to validate that all blocks have unique names and to assign uniqe
  names for blocks which don't have names set by user.
  """

  alias Util.ToTuple

  def name_blocks(definition) do
    with {:ok, definition} <- do_name_blocks(definition, "blocks"),
         {:ok, definition} <- do_name_blocks(definition, "after_pipeline")
    do
      ToTuple.ok(definition)
    end
  end

  defp do_name_blocks(definition, "blocks") do
    with {:ok, blocks}            <- Map.fetch(definition, "blocks"),
         {:ok, {names, blocks}}   <- validate_user_defined_names(blocks),
         {:ok, blocks_with_names} <- set_names_for_nameless_blocks(names, blocks),
    do: {:ok, Map.put(definition, "blocks", blocks_with_names)}
  end

  defp do_name_blocks(definition, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil -> {:ok, definition}
      _ ->
        with {:ok, blocks}            <- Map.fetch(definition, "after_pipeline"),
            {:ok, {names, blocks}}   <- validate_user_defined_names(blocks),
            {:ok, blocks_with_names} <- set_names_for_nameless_blocks(names, blocks),
        do: {:ok, Map.put(definition, "after_pipeline", blocks_with_names)}
    end
  end

  defp validate_user_defined_names(blocks) do
    blocks
    |> Enum.reduce({:ok, {%{}, []}}, fn block, acc ->
        validate_name(acc, block)
    end)
  end

  defp validate_name({:ok, {names, blocks}}, block) do
    case Map.get(block, "name") do
      nil -> {:ok, {names, blocks ++ [block]}}
      name -> name_uniqe?(names, blocks, block, name)
    end
  end
  defp validate_name(error, _block), do: error

  defp name_uniqe?(names, blocks, block, name) do
    {is_taken, names} =
      Map.get_and_update(names, name, fn current_value ->
        {current_value, true}
      end)

    case is_taken do
      true -> {:error, {:malformed, "There are at least two blocks with same name: #{name}"}}
      nil -> {:ok, {names, blocks ++ [block]}}
    end
  end

  defp set_names_for_nameless_blocks(names, blocks)
    when map_size(names) == length(blocks), do: {:ok, blocks}

  defp set_names_for_nameless_blocks(names, blocks) do
    blocks
    |> Enum.reduce({:ok, {names, [], 1}}, fn block, acc ->
        name_set?(acc, block)
    end)
    |> return_only_blocks()
  end

  defp name_set?({:ok, {names, blocks, index}}, block) do
    case Map.get(block, "name") do
      nil -> set_name(names, blocks, block, index)
      _name -> {:ok, {names, blocks ++ [block], index}}
    end
  end
  defp name_set?(error, _block), do: error

  defp set_name(names, blocks, block, index) do
    name = "Nameless block #{index}"

    {is_taken, names} =
      Map.get_and_update(names, name, fn current_value ->
        {current_value, true}
      end)

    case is_taken do
      true -> set_name(names, blocks, block, index + 1)
      nil ->
        block = Map.put(block, "name", name)
        {:ok, {names, blocks ++ [block], index + 1}}
    end
  end

  defp return_only_blocks({:ok, {_names, blocks, _index}}), do: {:ok, blocks}
  defp return_only_blocks(error), do: error

end
