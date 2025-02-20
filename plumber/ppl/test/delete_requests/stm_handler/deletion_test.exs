defmodule Ppl.DeleteRequests.STMHandler.Deletion.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.Actions
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.PplBlocks.Model.PplBlockConectionsQueries
  alias Ppl.Queues.Model.QueuesQueries

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "all related entities in db are deleted when delete request is processed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml", "project_id" => "to-delete"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

      loopers = Test.Helpers.start_all_loopers()
      {:ok, _ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
      Test.Helpers.stop_all_loopers(loopers)

      assert {:ok, ppl_blk_1} = PplBlocksQueries.get_by_id_and_index(ppl_id, 0)
      assert {:ok, ppl_blk_2} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)

      {:ok, %{project_id: "to-delete", requester: "sudo"}} |> Actions.delete()

      delete_loopers =
        []
        |> Enum.concat([Ppl.DeleteRequests.STMHandler.PendingState.start_link()])
        |> Enum.concat([Ppl.DeleteRequests.STMHandler.DeletingState.start_link()])
        |> Enum.concat([Ppl.DeleteRequests.STMHandler.QueueDeletingState.start_link()])

      :timer.sleep(3_000)

      Test.Helpers.stop_all_loopers(delete_loopers)

      assert_everything_deleted(ppl_id, ppl_blk_1, ppl_blk_2)
  end

  defp assert_everything_deleted(ppl_id, ppl_blk_1, ppl_blk_2) do
    assert {:error, _msg} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:error, _msg} = PplsQueries.get_by_id(ppl_id)
    assert {:error, _msg} = PplSubInitsQueries.get_by_id(ppl_id)
    assert {:error, _msg} = PplOriginsQueries.get_by_id(ppl_id)
    assert {:error, _msg} = PplTracesQueries.get_by_id(ppl_id)
    assert {:error, _msg} = PplBlocksQueries.get_all_by_id(ppl_id)
    assert {:error, _msg} = PplBlockConectionsQueries.get_all_by_id(ppl_blk_1.id)
    assert {:error, _msg} = PplBlockConectionsQueries.get_all_by_id(ppl_blk_2.id)

    params = %{org_id: :skip, project_id: "to-delete", type: "all"}
    assert {:ok, %{total_entries: 0}} = QueuesQueries.list_queues(params, 0, 10)

    assert {:error, _msg} = Block.describe(ppl_blk_1.block_id)
    assert {:error, _msg} = Block.describe(ppl_blk_2.block_id)
  end
end
