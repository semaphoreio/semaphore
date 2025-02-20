defmodule Ppl.DefinitionReviser.ImplicitDependency  do
  @moduledoc """
  This module converts implicit dependencies into explicit and adds the deps list into appropriate block definition
  """

  def convert_to_explicit(definition) do
    if implicit_dependencies?(definition) do
      bl_deps = block_deps(definition)
      add_deps(definition, bl_deps)
    else
      {:ok, definition}
    end

  end

  defp add_deps(definition, bl_deps) do
    %{"blocks" => blcs} = definition
     blcs_list = Enum.map(blcs, &add_blc_deps(&1, bl_deps))
     blcs_map = %{"blocks" => blcs_list}
     {:ok, Map.merge(definition, blcs_map)}
  end

  defp add_blc_deps(blc, bl_deps) do
    name = Map.get(blc, "name")
    deps = get_dependencies(name, bl_deps)
    Map.put(blc, "dependencies", deps)
  end

  defp get_dependencies(block_name, bl_deps) do
    bl_deps
     |> Enum.find(fn {name, _deps} -> name == block_name end)
     |> elem(1)

  end

  defp implicit_dependencies?(definition) do
    block_deps_with_index(definition)
     |> Enum.any?(fn {{_name, deps}, _index} -> deps == nil end)
  end


  defp block_deps(definition) do
    block_deps_with_index = block_deps_with_index(definition)

    block_deps_with_index
    |> Enum.map(fn
      {{name, nil},  0} -> {name, []}
      {{name, nil},  i} -> {name, previous_block(block_deps_with_index, i)}
    end)
  end

  defp block_deps_with_index(definition) do
   definition
    |> Map.get("blocks")
    |> Enum.map(fn block -> {block["name"], block["dependencies"]} end)
    |> Enum.with_index()
  end

  defp previous_block(block_deps_with_index, i) do
    {{dep_name, _}, _} = Enum.at(block_deps_with_index, i - 1)
    [dep_name]
  end

end
