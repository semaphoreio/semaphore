defmodule Ppl.PplBlocks.STMHandler.WaitingState.Drain.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.Actions
  alias Ppl.DefinitionReviser
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.Beholder
  alias Ppl.PplBlocks.Model.{PplBlockConnections, PplBlocks, PplBlocksQueries}
  alias Ppl.PplBlocks.STMHandler.{Common, InitializingState, WaitingState}
  alias Ppl.PplBlocks.WaitingDrain
  alias Ppl.PplRequests.Model.PplRequestsQueries

  @block_count 5

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "drain_pipeline/1 resolves whole chain of skipped blocks in one call" do
    ppl_id = pipeline_with_skipped_chain(@block_count, "running")

    assert {:ok, @block_count} = WaitingState.drain_pipeline(ppl_id)

    for index <- 0..(@block_count - 1) do
      assert {:ok, blk} = PplBlocksQueries.get_by_id_and_index(ppl_id, index)
      assert {blk.state, blk.result, blk.result_reason} == {"done", "passed", "skipped"}
      refute blk.in_scheduling
    end
  end

  test "drain_pipeline/1 does not touch blocks of other pipelines" do
    ppl_id = pipeline_with_skipped_chain(@block_count, "running")
    other_ppl_id = pipeline_with_skipped_chain(@block_count, "running")

    assert {:ok, @block_count} = WaitingState.drain_pipeline(ppl_id)

    for index <- 0..(@block_count - 1) do
      assert {:ok, %{state: "waiting"}} =
               PplBlocksQueries.get_by_id_and_index(other_ppl_id, index)
    end
  end

  test "drain_pipeline/1 stops at blocks whose dependencies are not done" do
    ppl_id = pipeline_with_skipped_chain(@block_count, "running")

    "update pipeline_blocks set state = 'running' where ppl_id = '#{ppl_id}' and block_index = 2"
    |> Repo.query()

    assert {:ok, 2} = WaitingState.drain_pipeline(ppl_id)

    assert {:ok, %{state: "done"}} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)
    assert {:ok, %{state: "running"}} = PplBlocksQueries.get_by_id_and_index(ppl_id, 2)
    assert {:ok, %{state: "waiting"}} = PplBlocksQueries.get_by_id_and_index(ppl_id, 3)
  end

  test "drain_pipeline/1 does nothing while pipeline is not running" do
    ppl_id = pipeline_with_skipped_chain(@block_count, "queuing")

    assert {:ok, 0} = WaitingState.drain_pipeline(ppl_id)
    assert {:ok, %{state: "waiting"}} = PplBlocksQueries.get_by_id_and_index(ppl_id, 0)
  end

  test "drain_pipeline/1 cancels all waiting blocks of terminated pipeline" do
    ppl_id = pipeline_with_skipped_chain(@block_count, "stopping")

    "update pipeline_blocks set terminate_request = 'stop', terminate_request_desc = 'API call'
     where ppl_id = '#{ppl_id}'"
    |> Repo.query()

    assert {:ok, @block_count} = WaitingState.drain_pipeline(ppl_id)

    for index <- 0..(@block_count - 1) do
      assert {:ok, blk} = PplBlocksQueries.get_by_id_and_index(ppl_id, index)
      assert {blk.state, blk.result, blk.result_reason} == {"done", "canceled", "user"}
    end
  end

  test "drain_pipeline/1 schedules at most batch size blocks in one call" do
    ppl_id = pipeline_with_skipped_chain(@block_count, "running")
    Application.put_env(:ppl, :ppl_blk_waiting_drain_batch_size, 2)
    on_exit(fn -> Application.delete_env(:ppl, :ppl_blk_waiting_drain_batch_size) end)

    assert {:ok, 2} = WaitingState.drain_pipeline(ppl_id)

    assert {:ok, %{state: "done"}} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)
    assert {:ok, %{state: "waiting"}} = PplBlocksQueries.get_by_id_and_index(ppl_id, 2)

    assert {:ok, 2} = WaitingState.drain_pipeline(ppl_id)
    assert {:ok, 1} = WaitingState.drain_pipeline(ppl_id)
  end

  test "drain_pipeline/1 continues with other blocks when one can not be scheduled" do
    ppl_id = pipeline_with_blocks(3, "running", skip: false, chain: false)

    with_mock Block, [:passthrough], schedule: fn _request -> {:error, "block service down"} end do
      assert {:ok, 3} = WaitingState.drain_pipeline(ppl_id)
      assert_called_exactly(Block.schedule(:_), 3)
    end

    # They stay in scheduling until Beholder recovers them
    for index <- 0..2 do
      assert {:ok, %{state: "waiting", in_scheduling: true}} =
               PplBlocksQueries.get_by_id_and_index(ppl_id, index)
    end
  end

  test "pipeline is triggered on every exit from waiting and initializing state" do
    ppl_id = UUID.uuid4()

    exit_state = fn state ->
      {:ok, %{exit_transition: %{ppl_id: ppl_id}, user_exit_function: %{state: state}}}
    end

    with_mock WaitingDrain, [:passthrough], trigger: fn _ppl_id -> :ok end do
      for state <- ~w(waiting running done), do: WaitingState.epilogue_handler(exit_state.(state))
      assert_called_exactly(WaitingDrain.trigger(ppl_id), 3)

      for state <- ~w(waiting done), do: InitializingState.epilogue_handler(exit_state.(state))
      assert_called_exactly(WaitingDrain.trigger(ppl_id), 5)
    end
  end

  test "pipeline is triggered when any of its blocks is done or aborted" do
    ppl_id = UUID.uuid4()

    with_mock WaitingDrain, [:passthrough], trigger: fn _ppl_id -> :ok end do
      # Called on 'done' by all PplBlocks STMs
      Common.notify_ppl_when_done(%{exit_transition: %{ppl_id: ppl_id}})
      assert_called_exactly(WaitingDrain.trigger(ppl_id), 1)

      Beholder.post_proccessing(%{ppl_id: ppl_id, block_id: UUID.uuid4()})
      assert_called_exactly(WaitingDrain.trigger(ppl_id), 2)
    end
  end

  defp pipeline_with_skipped_chain(block_count, ppl_state),
    do: pipeline_with_blocks(block_count, ppl_state, skip: true, chain: true)

  defp pipeline_with_blocks(block_count, ppl_state, opts) do
    request = Test.Helpers.schedule_request_factory(:local)
    assert {:ok, %{ppl_id: ppl_id}} = Actions.schedule(request)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    task = %{"jobs" => [%{"name" => "job1", "commands" => ["echo foo"]}]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}

    blocks =
      0..(block_count - 1)
      |> Enum.map(fn i -> %{"name" => "blk #{i}", "task" => task} end)
      |> Enum.map(&maybe_skip(&1, opts[:skip]))

    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}

    {:ok, definition} = DefinitionReviser.revise_definition(definition, ppl_req)
    {:ok, _ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    "update pipelines set state = '#{ppl_state}' where ppl_id = '#{ppl_id}'" |> Repo.query()

    blocks = Enum.map(0..(block_count - 1), &insert_ppl_blk(ppl_id, &1))

    # Each block depends on the previous one
    if opts[:chain] do
      Enum.each(Enum.zip(tl(blocks), blocks), fn {blk, dependency} ->
        insert_dependency(blk, dependency)
      end)
    end

    ppl_id
  end

  defp maybe_skip(block, true), do: Map.put(block, "skip", %{"when" => true})
  defp maybe_skip(block, _skip), do: block

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{
      ppl_id: ppl_id,
      block_index: block_index,
      name: "blk #{block_index}",
      state: "waiting",
      in_scheduling: false
    }

    assert {:ok, ppl_blk} = %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert()
    ppl_blk
  end

  defp insert_dependency(target, dependency) do
    params = %{target: target.id, dependency: dependency.id}

    assert {:ok, _} =
             %PplBlockConnections{} |> PplBlockConnections.changeset(params) |> Repo.insert()
  end
end
