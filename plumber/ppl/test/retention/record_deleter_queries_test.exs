defmodule Ppl.Retention.RecordDeleterQueriesTest do
  use Ppl.IntegrationCase, async: false

  alias Ppl.Actions
  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.Retention.RecordDeleterQueries

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "delete_expired_batch/1" do
    test "deletes expired records" do
      org_id = UUID.uuid4()
      expired_pipeline = insert_pipeline(org_id, expired_at())
      non_expired_pipeline = insert_pipeline(org_id, nil)

      {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

      assert count == 1
      assert get_pipeline(expired_pipeline.id) == nil
      assert get_pipeline(non_expired_pipeline.id) != nil
    end

    test "respects batch size limit" do
      org_id = UUID.uuid4()

      Enum.each(1..10, fn _ ->
        insert_pipeline(org_id, expired_at())
      end)

      {:ok, count} = RecordDeleterQueries.delete_expired_batch(3)

      assert count == 3
      assert count_all_pipelines() == 7
    end

    test "does not delete records with future expires_at" do
      org_id = UUID.uuid4()
      future_pipeline = insert_pipeline(org_id, future_expires_at())

      {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

      assert count == 0
      assert get_pipeline(future_pipeline.id) != nil
    end

    test "does not delete records with nil expires_at" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, nil)

      {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

      assert count == 0
      assert get_pipeline(pipeline.id) != nil
    end

    test "returns 0 when no expired records exist" do
      {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

      assert count == 0
    end

    test "deletes expired records from multiple organizations" do
      org_1 = UUID.uuid4()
      org_2 = UUID.uuid4()

      expired_1 = insert_pipeline(org_1, expired_at())
      expired_2 = insert_pipeline(org_2, expired_at())
      non_expired = insert_pipeline(org_1, nil)

      {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

      assert count == 2
      assert get_pipeline(expired_1.id) == nil
      assert get_pipeline(expired_2.id) == nil
      assert get_pipeline(non_expired.id) != nil
    end
  end

  defp insert_pipeline(org_id, expires_at) do
    id = UUID.uuid4()
    ppl_id = UUID.uuid4()
    wf_id = UUID.uuid4()

    request_args = %{
      "organization_id" => org_id,
      "project_id" => UUID.uuid4(),
      "service" => "local"
    }

    %PplRequests{
      id: id,
      ppl_artefact_id: ppl_id,
      wf_id: wf_id,
      request_args: request_args,
      request_token: UUID.uuid1(),
      definition: %{"version" => "v1.0", "blocks" => []},
      top_level: true,
      initial_request: true,
      prev_ppl_artefact_ids: [],
      expires_at: expires_at
    }
    |> EctoRepo.insert!()
  end

  defp get_pipeline(id) do
    EctoRepo.get(PplRequests, id)
  end

  defp count_all_pipelines do
    EctoRepo.aggregate(PplRequests, :count)
  end

  defp expired_at do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-3600, :second)
  end

  defp future_expires_at do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(3600, :second)
  end

  @tag :integration
  test "deletes pipeline and all related records from ppl and block databases" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" => "no_cmd_files.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert {:ok, ppl_blk_0} = PplBlocksQueries.get_by_id_and_index(ppl_id, 0)
    assert {:ok, ppl_blk_1} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)

    assert {:ok, _} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:ok, _} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, _} = PplSubInitsQueries.get_by_id(ppl_id)
    assert {:ok, _} = PplTracesQueries.get_by_id(ppl_id)
    assert {:ok, _} = Block.describe(ppl_blk_0.block_id)
    assert {:ok, _} = Block.describe(ppl_blk_1.block_id)

    set_expired(ppl_id)

    {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

    assert count == 1
    assert {:error, _} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:error, _} = Block.describe(ppl_blk_0.block_id)
    assert {:error, _} = Block.describe(ppl_blk_1.block_id)
  end

  defp set_expired(ppl_id) do
    expired_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(-3600, :second)

    EctoRepo.query!(
      "UPDATE pipeline_requests SET expires_at = $1 WHERE id = $2",
      [expired_at, ppl_id]
    )
  end
end
