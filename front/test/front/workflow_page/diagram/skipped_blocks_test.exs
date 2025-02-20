defmodule Front.WorkflowPage.Diagram.SkippedBlocksTest do
  use ExUnit.Case
  use ExUnitProperties

  @max_blocks 100

  describe "when graph omits skipped blocks" do
    test "renders proper graph with omitted skipped blocks" do
      blocks = [
        %{number: 1, skipped?: false, deps: []},
        %{number: 2, skipped?: true, deps: []},
        %{number: 3, skipped?: true, deps: [1]},
        %{number: 4, skipped?: false, deps: [3]},
        %{number: 5, skipped?: false, deps: [1]},
        %{number: 6, skipped?: false, deps: [2]},
        %{number: 7, skipped?: true, deps: [3]},
        %{number: 8, skipped?: false, deps: [4, 7]},
        %{number: 9, skipped?: false, deps: [6, 7]},
        %{number: 10, skipped?: true, deps: [8]}
      ]

      pipeline = %{blocks: blocks |> Enum.map(&stringify_block/1) |> Enum.shuffle()}
      new_pipeline = Front.WorkflowPage.Diagram.SkippedBlocks.fold_dependencies(pipeline)

      indirect_deps =
        Enum.into(new_pipeline.blocks, %{}, fn block ->
          {block.number,
           Enum.map(block.indirect_dependencies, &(String.split(&1) |> List.last()))}
        end)

      assert indirect_deps == %{
               1 => [],
               2 => [],
               3 => [],
               4 => ["1"],
               5 => ["1"],
               6 => [],
               7 => [],
               8 => ["1", "4"],
               9 => ["1", "6"],
               10 => []
             }
    end

    property "all edges are adjacent to non-skipped blocks" do
      check all(blocks <- gen_pipeline_blocks()) do
        pipeline = %{blocks: blocks |> Enum.map(&stringify_block/1) |> Enum.shuffle()}
        new_pipeline = Front.WorkflowPage.Diagram.SkippedBlocks.fold_dependencies(pipeline)

        non_skipped_blocks =
          pipeline.blocks |> Enum.reject(& &1.skipped?) |> MapSet.new(& &1.name)

        indirect_dependency_blocks =
          new_pipeline.blocks
          |> Enum.flat_map(& &1.indirect_dependencies)
          |> MapSet.new()

        assert MapSet.subset?(indirect_dependency_blocks, non_skipped_blocks)
      end
    end

    property "for every edge in the reduced graph " <>
               "there is a path in the original graph " <>
               "that doesn't have non-skipped blocks in the middle" do
      check all(blocks <- gen_pipeline_blocks()) do
        pipeline = %{blocks: blocks |> Enum.map(&stringify_block/1) |> Enum.shuffle()}

        expected_pipeline = %{blocks: indirect_dependencies(pipeline)}
        expected = Map.new(expected_pipeline.blocks, &{&1.number, &1.indirect_dependencies})

        actual_pipeline = Front.WorkflowPage.Diagram.SkippedBlocks.fold_dependencies(pipeline)
        actual = Map.new(actual_pipeline.blocks, &{&1.number, &1.indirect_dependencies})

        assert expected == actual
      end
    end
  end

  # Helpers

  defp stringify_block(block) do
    dependencies = Enum.map(block.deps, &"Block #{&1}")

    block
    |> Map.put(:name, "Block #{block.number}")
    |> Map.put(:dependencies, dependencies)
  end

  defp indirect_dependencies(%{blocks: blocks}) do
    blocks
    |> Enum.sort(&(&1.number <= &2.number))
    |> Enum.reduce(%{}, &indirect_dependencies/2)
    |> Enum.map(&(elem(&1, 1) |> Map.drop([:indirect_deps])))
  end

  defp indirect_dependencies(block, acc) do
    {skipped_deps, non_skipped_deps} = Enum.split_with(block.deps, &acc[&1].skipped?)

    indirect_deps =
      skipped_deps
      |> Enum.flat_map(&Enum.to_list(acc[&1].indirect_deps))
      |> Enum.concat(non_skipped_deps)

    result =
      if block.skipped?,
        do: MapSet.new(),
        else: MapSet.new(indirect_deps, &"Block #{&1}")

    new_block =
      block
      |> Map.put(:indirect_deps, MapSet.new(indirect_deps))
      |> Map.put(:indirect_dependencies, result)

    Map.put(acc, block.number, new_block)
  end

  # Generators

  def gen_pipeline_blocks do
    ExUnitProperties.gen all(
                           num_vertices <- StreamData.integer(1..@max_blocks),
                           skipped <- gen_skipped(num_vertices),
                           deps <- gen_dependencies(num_vertices)
                         ) do
      block_gen = &%{number: &1, skipped?: skipped[&1], deps: Map.get(deps, &1, [])}
      Enum.map(1..num_vertices, block_gen)
    end
  end

  def gen_skipped(num_vertices) do
    StreamData.boolean()
    |> StreamData.list_of(length: num_vertices)
    |> StreamData.map(&Enum.with_index(&1, 1))
    |> StreamData.map(&Enum.into(&1, %{}, fn {v, i} -> {i, v} end))
  end

  def gen_dependencies(num_vertices) do
    max_edges = div(num_vertices * (num_vertices - 1), 2)
    deps_grouper = fn edges -> Enum.group_by(edges, &elem(&1, 1), &elem(&1, 0)) end

    gen_edge(num_vertices)
    |> StreamData.list_of(max_length: max_edges)
    |> StreamData.map(&MapSet.new/1)
    |> StreamData.map(deps_grouper)
  end

  def gen_edge(num_vertices) do
    gen_vertex_from(num_vertices)
    |> StreamData.bind(fn from ->
      gen_vertex_to(from, num_vertices)
      |> StreamData.bind(fn to ->
        StreamData.constant({from, to})
      end)
    end)
  end

  def gen_vertex_from(num_vertices) do
    StreamData.integer(1..(num_vertices - 1))
  end

  def gen_vertex_to(from, num_vertices) do
    StreamData.integer((from + 1)..num_vertices)
  end
end
