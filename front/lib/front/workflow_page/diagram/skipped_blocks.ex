defmodule Front.WorkflowPage.Diagram.SkippedBlocks do
  def fold_dependencies(pipeline) do
    init_state = %{
      skipped: Map.new(pipeline.blocks, &{&1.name, &1.skipped?}),
      dependencies: Map.new(pipeline.blocks, &{&1.name, &1.dependencies}),
      stack: [],
      result: %{}
    }

    %{result: result} =
      pipeline.blocks
      |> Enum.reject(& &1.skipped?)
      |> Enum.reduce(init_state, &traverse/2)

    blocks =
      pipeline.blocks
      |> Enum.map(fn
        block = %{skipped?: true} -> Map.put(block, :indirect_dependencies, MapSet.new())
        block = %{skipped?: false} -> Map.put(block, :indirect_dependencies, result[block.name])
      end)

    pipeline |> Map.put(:blocks, blocks)
  end

  defp traverse(block, state), do: traverse_dependecies(%{state | stack: [block.name]})

  # if stack is not empty, we need to examine other skipped blocks
  defp traverse_dependecies(state = %{stack: stack = [stack_head | stack_tail]}) do
    {skipped_dependencies, non_skipped_dependencies} =
      Enum.split_with(state.dependencies[stack_head], &state.skipped[&1])

    {visited_dependencies, non_visited_dependencies} =
      Enum.split_with(skipped_dependencies, &Map.has_key?(state.result, &1))

    if Enum.empty?(non_visited_dependencies) do
      # since we have a complete information, we can pop block from stack,
      # mark it as visited and provide it with list of reachable nodes

      new_result =
        visited_dependencies
        |> Enum.flat_map(&(state.result |> Map.get(&1, []) |> Enum.to_list()))
        |> Enum.concat(non_skipped_dependencies)
        |> MapSet.new()

      state
      |> put_in([:stack], stack_tail)
      |> put_in([:result, stack_head], new_result)
      |> traverse_dependecies()
    else
      # there are some skipped dependencies which haven't been visited
      # processing that block is put off and will continue once
      # these dependencies are visited
      new_stack = non_visited_dependencies ++ stack

      state
      |> put_in([:stack], new_stack)
      |> traverse_dependecies()
    end
  end

  # we terminate recursion while stack is empty
  defp traverse_dependecies(state = %{stack: []}), do: state
end
