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
  test "cancels only orphaned blocks (no external work) and leaves everything else untouched" do
    done_ppl = schedule_ppl_in_state("done")

    # orphans: never scheduled to the block service (no block_id), stuck under a
    # 'done' pipeline - these must be cleaned.
    {:ok, init_orphan} = insert_block(done_ppl, 0, "initializing")
    {:ok, wait_orphan} = insert_block(done_ppl, 1, "waiting")

    # blocks holding live external work (have a block_id) - must NOT be touched,
    # completing them here would abandon the running Block/jobs in zebra.
    {:ok, _running} = insert_block(done_ppl, 2, "running", block_id: Ecto.UUID.generate())
    {:ok, _stopping} = insert_block(done_ppl, 3, "stopping", block_id: Ecto.UUID.generate())

    # already finished block under the same 'done' pipeline - must not be modified.
    {:ok, _finished} = insert_block(done_ppl, 4, "done", result: "passed")

    # legitimately waiting block under a 'running' pipeline - must not be touched.
    running_ppl = schedule_ppl_in_state("running")
    {:ok, _live} = insert_block(running_ppl, 0, "waiting")

    assert {:ok, affected} = PplBlocksQueries.cancel_orphaned_blocks()

    # the audit list contains exactly the two orphans
    assert Enum.sort_by(affected, & &1.block_index) == [
             %{id: init_orphan.id, ppl_id: done_ppl, block_index: 0},
             %{id: wait_orphan.id, ppl_id: done_ppl, block_index: 1}
           ]

    # orphans moved to done/canceled/internal
    for index <- [0, 1] do
      assert {:ok, blk} = PplBlocksQueries.get_by_id_and_index(done_ppl, index)
      assert blk.state == "done"
      assert blk.result == "canceled"
      assert blk.result_reason == "internal"
    end

    # blocks with live external work are left as-is
    assert {:ok, running} = PplBlocksQueries.get_by_id_and_index(done_ppl, 2)
    assert running.state == "running"
    assert {:ok, stopping} = PplBlocksQueries.get_by_id_and_index(done_ppl, 3)
    assert stopping.state == "stopping"

    # already-done block under the done pipeline is unchanged
    assert {:ok, finished} = PplBlocksQueries.get_by_id_and_index(done_ppl, 4)
    assert finished.state == "done"
    assert finished.result == "passed"

    # block of the running pipeline is left waiting
    assert {:ok, live} = PplBlocksQueries.get_by_id_and_index(running_ppl, 0)
    assert live.state == "waiting"
  end

  @tag :integration
  test "dry run reports the matching orphans without changing anything" do
    done_ppl = schedule_ppl_in_state("done")
    {:ok, orphan} = insert_block(done_ppl, 0, "waiting")

    assert {:ok, [%{id: id, ppl_id: ppl_id, block_index: 0}]} =
             PplBlocksQueries.cancel_orphaned_blocks(true)

    assert id == orphan.id
    assert ppl_id == done_ppl

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
