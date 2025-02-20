defmodule Ppl.PplBlocks.Model.WaitingStateSchedulingTest do
  use ExUnit.Case
  doctest Ppl.PplBlocks.Model.WaitingStateScheduling

  alias Ppl.PplBlocks.Model.PplBlockConnections
  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.Model.WaitingStateScheduling
  alias Ppl.PplBlocks.Model.WaitingStateSchedulingTest.StuckPplCounter

  import Ecto.Query

  @pipeline_count 15

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "behavioural test" do
    StuckPplCounter.start_link()
    generate_blocks_from_multiple_pipelines(@pipeline_count)
    do_test(true)

    IO.puts ">>>>>>>>>>>>> Stuck counter: #{StuckPplCounter.get()}"
  end

  defp do_test(_in_progreess=false), do: :end
  defp do_test(_in_progreess=true) do
    get_ready_block()
    |> case do
      {:ok, []} ->
        assert(all_waiting_blocks_have_unfulfilled_dependencies?())
        tranzition_random_block_to_done()
        StuckPplCounter.inc()
      {:ok, [{_, ppl_block}]} ->
        assert(all_dependencies_are_done?(ppl_block.id))
        mark_block_done(ppl_block.id)
    end

    do_test(blocks_in_progress?())
  end

  ################### Generate blocks ###################

  defp generate_blocks_from_multiple_pipelines(ppl_count) do
    for _i <- 1..ppl_count, do: generate_block_from_single_pipeline()
  end

  defp generate_block_from_single_pipeline() do
    schedule_request =
      Test.Helpers.schedule_request_factory(:local)
      |> Map.put("repo_name", "2_basic")
    {:ok, %{ppl_id: ppl_id}} = Ppl.Actions.schedule(schedule_request)

    block_count = Enum.random(5..30)     # Number of blocks in pipeline
    0..(block_count-1)
    |> Enum.map(&insert_ppl_blk(ppl_id, &1))
    |> Enum.map(&insert_block_dependencies(&1))

    "update pipelines set state = 'running';" |> Repo.query()
  end

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{ppl_id: ppl_id, block_index: block_index,
      name: "blk #{inspect block_index}"}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
  end

  defp insert_block_dependencies({:ok, ppl_blk}) do
    # Get all other blocks from the same pipeline
    from(b in PplBlocks,
      where: b.ppl_id == ^UUID.string_to_binary!(ppl_blk.ppl_id),
      where: b.id != ^ppl_blk.id)
    |> Repo.all
    # Select couple of blocks to be dependencies - can be none (0)
    |> Enum.take_random(Enum.random([0, 0, 1, 1, 1, 1, 2, 2, 3]))
    |> Enum.map(&insert_block_dependency(&1, ppl_blk))
  end

  defp insert_block_dependency(dependency, ppl_blk) do
    assert(ppl_blk.id != dependency.id)
    assert(ppl_blk.ppl_id == dependency.ppl_id)

    %PplBlockConnections{}
    |> PplBlockConnections.changeset(
      %{target: ppl_blk.id, dependency: dependency.id})
    |> Repo.insert
  end

  ################### Test invariants ###################

  defp get_ready_block, do: WaitingStateScheduling.get_ready_block()

  defp all_dependencies_are_done?(block_id) do
    for connection <- get_block_connections(block_id) do
      block = connection.dependency |> get_block_by_id()
      assert(block.state == "done")
    end
    true
  end

  defp get_block_connections(block_id) do
    from(b in PplBlockConnections, where: b.target == ^block_id)
    |> Repo.all
  end

  defp mark_block_done(block_id) do
    block_id
    |> get_block_by_id()
    |> PplBlocks.changeset(%{state: "done"})
    |> Repo.update()
  end

  defp get_block_by_id(id) do
    from(b in PplBlocks, where: b.id == ^id) |> Repo.one()
  end

  defp blocks_in_progress? do
    from(b in PplBlocks, where: b.state != "done")
    |> Repo.all()
    |> Enum.empty?()
    |> Kernel.not
  end

  defp all_waiting_blocks_have_unfulfilled_dependencies? do
    for b <- from(b in PplBlocks, where: b.state == "waiting") |> Repo.all() do
      assert(waiting_block_has_unfulfilled_dependencies?(b))
    end
    true
  end

  defp waiting_block_has_unfulfilled_dependencies?(block) do
    get_block_connections(block.id)
    |> Enum.map(fn connection -> get_block_by_id(connection.dependency) end)
    |> Enum.map(fn dependency -> dependency.state end)
    |> Enum.any?(fn state -> state != "done" end)
  end

  defp tranzition_random_block_to_done do
    from(b in PplBlocks, where: b.state == "waiting", limit: 1)
    |> Repo.one()
    |> PplBlocks.changeset(%{state: "done"})
    |> Repo.update()
  end

  defmodule StuckPplCounter do
    def start_link, do: {:ok, _} = Agent.start_link(fn -> 0 end, name: __MODULE__)

    def inc, do: Agent.update(__MODULE__, fn count -> count + 1 end)

    def get, do: Agent.get(__MODULE__, fn count -> count end)
  end
end
