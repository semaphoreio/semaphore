defmodule Ppl.Retention.Deleter.QueriesTest do
  use Ppl.IntegrationCase, async: false

  import Mock

  alias Ppl.Actions
  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.Retention.Deleter.Queries

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  describe "delete_expired_batch/1" do
    test "deletes expired records" do
      org_id = UUID.uuid4()
      expired = insert_pipeline(org_id, expired_at())
      non_expired = insert_pipeline(org_id, nil)

      {:ok, count} = delete_with_mock(100)

      assert count == 1
      assert get_pipeline(expired.id) == nil
      assert get_pipeline(non_expired.id) != nil
    end

    test "respects batch size limit" do
      org_id = UUID.uuid4()
      Enum.each(1..10, fn _ -> insert_pipeline(org_id, expired_at()) end)

      {:ok, count} = delete_with_mock(3)

      assert count == 3
      assert count_pipelines() == 7
    end

    test "skips records with future expires_at" do
      org_id = UUID.uuid4()
      future = insert_pipeline(org_id, future_expires_at())

      {:ok, count} = delete_with_mock(100)

      assert count == 0
      assert get_pipeline(future.id) != nil
    end

    test "skips records with nil expires_at" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, nil)

      {:ok, count} = delete_with_mock(100)

      assert count == 0
      assert get_pipeline(pipeline.id) != nil
    end

    test "returns 0 when no expired records" do
      {:ok, count} = delete_with_mock(100)
      assert count == 0
    end

    test "deletes from multiple organizations" do
      expired_1 = insert_pipeline(UUID.uuid4(), expired_at())
      expired_2 = insert_pipeline(UUID.uuid4(), expired_at())
      non_expired = insert_pipeline(UUID.uuid4(), nil)

      {:ok, count} = delete_with_mock(100)

      assert count == 2
      assert get_pipeline(expired_1.id) == nil
      assert get_pipeline(expired_2.id) == nil
      assert get_pipeline(non_expired.id) != nil
    end

    test "concurrent workers do not process the same records" do
      org_id = UUID.uuid4()
      Enum.each(1..10, fn _ -> insert_pipeline(org_id, expired_at()) end)

      with_mock Ppl.Retention.Events,
        publish_pipeline_deleted: fn _, _, _, _, _ -> :ok end,
        publish_workflow_deleted: fn _, _, _, _ -> :ok end do
        tasks = Enum.map(1..3, fn _ ->
          Task.async(fn -> Queries.delete_expired_batch(10) end)
        end)

        results = Enum.map(tasks, &Task.await/1)
        total = Enum.sum(Enum.map(results, fn {:ok, n} -> n end))

        assert total == 10
        assert count_pipelines() == 0
      end
    end
  end

  describe "event publishing" do
    test "publishes pipeline and workflow events when workflow is empty" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, expired_at())
      project_id = pipeline.request_args["project_id"]
      artifact_store_id = pipeline.request_args["artifact_store_id"]

      test_pid = self()

      with_mock Ppl.Retention.Events,
        publish_pipeline_deleted: fn ppl_id, wf_id, org, proj, art ->
          send(test_pid, {:pipeline_deleted, ppl_id, wf_id, org, proj, art})
          :ok
        end,
        publish_workflow_deleted: fn wf_id, org, proj, art ->
          send(test_pid, {:workflow_deleted, wf_id, org, proj, art})
          :ok
        end do
        {:ok, 1} = Queries.delete_expired_batch(100)

        assert_received {:pipeline_deleted, ppl_id, wf_id, ^org_id, ^project_id, ^artifact_store_id}
        assert ppl_id == pipeline.id
        assert wf_id == pipeline.wf_id

        assert_received {:workflow_deleted, wf_id, ^org_id, ^project_id, ^artifact_store_id}
        assert wf_id == pipeline.wf_id
      end
    end

    test "does not publish workflow event when workflow still has pipelines" do
      org_id = UUID.uuid4()
      wf_id = UUID.uuid4()
      expired = insert_pipeline(org_id, expired_at(), wf_id)
      _non_expired = insert_pipeline(org_id, nil, wf_id)

      test_pid = self()

      with_mock Ppl.Retention.Events,
        publish_pipeline_deleted: fn ppl_id, _, _, _, _ ->
          send(test_pid, {:pipeline_deleted, ppl_id})
          :ok
        end,
        publish_workflow_deleted: fn wf_id, _, _, _ ->
          send(test_pid, {:workflow_deleted, wf_id})
          :ok
        end do
        {:ok, 1} = Queries.delete_expired_batch(100)

        assert_received {:pipeline_deleted, ppl_id}
        assert ppl_id == expired.id

        refute_received {:workflow_deleted, _}
      end
    end

    test "publishing failures do not block deletion" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, expired_at())

      with_mock Ppl.Retention.Events,
        publish_pipeline_deleted: fn _, _, _, _, _ -> {:error, :failed} end,
        publish_workflow_deleted: fn _, _, _, _ -> {:error, :failed} end do
        {:ok, 1} = Queries.delete_expired_batch(100)
      end

      assert get_pipeline(pipeline.id) == nil
    end
  end

  @tag :integration
  test "deletes pipeline and all related records" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" => "no_cmd_files.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    {:ok, ppl_blk_0} = PplBlocksQueries.get_by_id_and_index(ppl_id, 0)
    {:ok, ppl_blk_1} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)

    assert {:ok, _} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:ok, _} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, _} = PplSubInitsQueries.get_by_id(ppl_id)
    assert {:ok, _} = PplTracesQueries.get_by_id(ppl_id)
    assert {:ok, _} = Block.describe(ppl_blk_0.block_id)
    assert {:ok, _} = Block.describe(ppl_blk_1.block_id)

    set_expired(ppl_id)

    with_mock Ppl.Retention.Events,
      publish_pipeline_deleted: fn _, _, _, _, _ -> :ok end,
      publish_workflow_deleted: fn _, _, _, _ -> :ok end do
      {:ok, 1} = Queries.delete_expired_batch(100)
    end

    assert {:error, _} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:error, _} = Block.describe(ppl_blk_0.block_id)
    assert {:error, _} = Block.describe(ppl_blk_1.block_id)
  end

  # Helpers

  defp insert_pipeline(org_id, expires_at, wf_id \\ UUID.uuid4()) do
    %PplRequests{
      id: UUID.uuid4(),
      ppl_artefact_id: UUID.uuid4(),
      wf_id: wf_id,
      request_args: %{
        "organization_id" => org_id,
        "project_id" => UUID.uuid4(),
        "artifact_store_id" => UUID.uuid4(),
        "service" => "local"
      },
      request_token: UUID.uuid1(),
      definition: %{"version" => "v1.0", "blocks" => []},
      top_level: true,
      initial_request: true,
      prev_ppl_artefact_ids: [],
      expires_at: expires_at
    }
    |> EctoRepo.insert!()
  end

  defp get_pipeline(id), do: EctoRepo.get(PplRequests, id)

  defp count_pipelines, do: EctoRepo.aggregate(PplRequests, :count)

  defp delete_with_mock(limit) do
    with_mock Ppl.Retention.Events,
      publish_pipeline_deleted: fn _, _, _, _, _ -> :ok end,
      publish_workflow_deleted: fn _, _, _, _ -> :ok end do
      Queries.delete_expired_batch(limit)
    end
  end

  defp expired_at do
    NaiveDateTime.utc_now() |> NaiveDateTime.add(-3600, :second)
  end

  defp future_expires_at do
    NaiveDateTime.utc_now() |> NaiveDateTime.add(3600, :second)
  end

  defp set_expired(ppl_id) do
    {:ok, binary_id} = Ecto.UUID.dump(ppl_id)
    EctoRepo.query!(
      "UPDATE pipeline_requests SET expires_at = $1 WHERE id = $2",
      [expired_at(), binary_id]
    )
  end
end
