defmodule DefinitionValidator.PplBlocksDependencies do
  @moduledoc """
  Semantic validations for pipeline definition
  """

  alias Util.ToTuple

  def validate_yaml(definition) do
    with {:ok, definition} <- implicit_or_explicit_dependency_definition(definition),
         {:ok, definition} <- validate_names(definition),
         do: validate_no_cycles(definition)
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

  @doc """
  Verifies that block dependencies do not form a cycle.

  Mirrors the cycle detection done in the workflow editor (front), so that
  pipelines whose YAML was edited directly (bypassing the editor) are also
  rejected. Implicit dependencies are linear and can never form a cycle, so
  only explicitly defined dependencies produce edges in the graph.
  """
  def validate_no_cycles(definition) do
    graph =
      definition["blocks"]
      |> Enum.reduce(%{}, fn block, acc ->
        Map.put(acc, block["name"], block["dependencies"] || [])
      end)

    case find_cycle(graph) do
      nil -> {:ok, definition}
      cycle -> {:error, {:malformed, cycle_error_msg(cycle)}}
    end
  end

  # Depth-first search over every node. `visited` accumulates nodes whose
  # subtree is fully explored (and proven acyclic); `stack` is the current DFS
  # path. Re-entering a node already on `stack` means we found a cycle.
  defp find_cycle(graph) do
    graph
    |> Map.keys()
    |> Enum.reduce_while(MapSet.new(), fn node, visited ->
      case dfs(node, graph, visited, []) do
        {:cycle, path} -> {:halt, path}
        {:ok, visited} -> {:cont, visited}
      end
    end)
    |> case do
      %MapSet{} -> nil
      cycle_path -> cycle_path
    end
  end

  defp dfs(node, graph, visited, stack) do
    cond do
      node in stack ->
        cycle = stack |> Enum.reverse() |> Enum.drop_while(&(&1 != node))
        {:cycle, cycle ++ [node]}

      MapSet.member?(visited, node) ->
        {:ok, visited}

      true ->
        neighbors = Map.get(graph, node, [])
        new_stack = [node | stack]

        neighbors
        |> Enum.reduce_while({:ok, visited}, fn neighbor, {:ok, vis} ->
          case dfs(neighbor, graph, vis, new_stack) do
            {:cycle, path} -> {:halt, {:cycle, path}}
            {:ok, vis} -> {:cont, {:ok, vis}}
          end
        end)
        |> case do
          {:cycle, path} -> {:cycle, path}
          {:ok, vis} -> {:ok, MapSet.put(vis, node)}
        end
    end
  end

  defp cycle_error_msg(cycle) do
    # Render the cycle in the same direction the UI uses: the dependency first,
    # then the block that depends on it (i.e. "B → A" when A depends on B). The
    # detected path is in "depends-on" order, so reverse it before formatting.
    path =
      cycle
      |> Enum.reverse()
      |> Enum.map_join(" → ", &"'#{&1}'")

    "Circular dependency between blocks detected: #{path}. " <>
      "Blocks cannot depend on each other in a cycle."
  end
end
