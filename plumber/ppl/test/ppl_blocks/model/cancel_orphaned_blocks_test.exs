defmodule Ppl.PplBlocks.Model.PplBlocksQueries.CancelOrphanedBlocks.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Actions
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  @tag :integration
  test "cancels blocks orphaned under a 'done' pipeline and leaves the rest untouched" do
    # 'done' pipeline with a block stuck in 'waiting' (the orphan we want to fix)
    done_ppl = schedule_ppl_in_state("done")
    {:ok, _orphan} = insert_block(done_ppl, 0, "waiting")

    # already finished block under the same 'done' pipeline - must not be modified
    {:ok, _finished} = insert_block(done_ppl, 1, "done", result: "passed")

    # 'running' pipeline with a legitimately waiting block - must not be touched
    running_ppl = schedule_ppl_in_state("running")
    {:ok, _live} = insert_block(running_ppl, 0, "waiting")

    assert {:ok, 1} = PplBlocksQueries.cancel_orphaned_blocks()

    # orphan moved to done/canceled/internal
    assert {:ok, orphan} = PplBlocksQueries.get_by_id_and_index(done_ppl, 0)
    assert orphan.state == "done"
    assert orphan.result == "canceled"
    assert orphan.result_reason == "internal"

    # already-done block under the done pipeline is unchanged
    assert {:ok, finished} = PplBlocksQueries.get_by_id_and_index(done_ppl, 1)
    assert finished.state == "done"
    assert finished.result == "passed"

    # block of the running pipeline is left waiting
    assert {:ok, live} = PplBlocksQueries.get_by_id_and_index(running_ppl, 0)
    assert live.state == "waiting"
  end

  @tag :integration
  test "dry run reports the count without changing anything" do
    done_ppl = schedule_ppl_in_state("done")
    {:ok, _orphan} = insert_block(done_ppl, 0, "waiting")

    assert {:ok, 1} = PplBlocksQueries.cancel_orphaned_blocks(true)

    assert {:ok, blk} = PplBlocksQueries.get_by_id_and_index(done_ppl, 0)
    assert blk.state == "waiting"
  end

  defp schedule_ppl_in_state(state) do
    {:ok, %{ppl_id: ppl_id}} =
      Test.Helpers.schedule_request_factory(:local) |> Actions.schedule()

    {:ok, _} = Repo.query("update pipelines set state = '#{state}' where ppl_id = '#{ppl_id}'")
    ppl_id
  end

  defp insert_block(ppl_id, index, state, opts \\ []) do
    params =
      %{ppl_id: ppl_id, block_index: index, state: state, in_scheduling: false, name: "Blk #{index}"}
      |> Map.merge(Map.new(opts))

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert()
  end
end
