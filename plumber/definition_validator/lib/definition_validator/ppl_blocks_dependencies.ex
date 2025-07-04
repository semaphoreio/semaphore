defmodule DefinitionValidator.PplBlocksDependencies do
  @moduledoc """
  Semantic validations for pipeline definition
  """

  alias Util.ToTuple

  def validate_yaml(definition) do
    with {:ok, definition} <- implicit_or_explicit_dependency_definition(definition),
         do: validate_names(definition)
  end

  @doc """
  Verifies that definition contains implicit or explicit dependencies but
  NOT mix of them.
  """
  def implicit_or_explicit_dependency_definition(definition) do
    blocks = Map.get(definition, "blocks")
    block_count = length(blocks)
    blocks_with_deps_count =
      blocks |> Enum.count(fn block -> Map.get(block, "dependencies") end)
    if blocks_with_deps_count == 0 or blocks_with_deps_count == block_count do
      {:ok, definition}
    else
      {:error, {:malformed, deps_mix_error_msg()}}
    end
  end

  defp deps_mix_error_msg() do
    """
    There are blocks with both explicitly and implicitly defined dependencies.
    This is not allowed, please use only one of this formats.
    """
  end

  @doc """
  Validate that all block names stated in dependencies propertis
  are acctually defined as block names in the pipeline.
  """
  def validate_names(definition) do
    block_names = definition["blocks"]
      |> Enum.map(fn block -> block["name"] end)

    definition["blocks"]
    |> Enum.map(fn block -> block["dependencies"] end)
    |> List.flatten
    |> Enum.filter(& !is_nil(&1))
    |> do_validate_names(definition, block_names)
  end

  defp do_validate_names(dep_names, definition, _) when dep_names == [],
    do: definition |> ToTuple.ok()
  defp do_validate_names(dep_names, definition, block_names) do
    Enum.reduce_while(dep_names, ok(definition),
      fn dep, _ -> if dep in block_names, do: ok(definition), else: err(dep) end)
  end

  defp ok(definition), do: {:cont, {:ok, definition}}
  defp err(dep), do: {:halt, {:error, {:malformed, {:unknown_block_name, dep}}}}
end
