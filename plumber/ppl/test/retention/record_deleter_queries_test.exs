defmodule Ppl.Retention.RecordDeleterQueriesTest do
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

      {:ok, count} = delete_expired_batch_with_ok_publisher(100)

      assert count == 1
      assert get_pipeline(expired_pipeline.id) == nil
      assert get_pipeline(non_expired_pipeline.id) != nil
    end

    test "respects batch size limit" do
      org_id = UUID.uuid4()

      Enum.each(1..10, fn _ ->
        insert_pipeline(org_id, expired_at())
      end)

      {:ok, count} = delete_expired_batch_with_ok_publisher(3)

      assert count == 3
      assert count_all_pipelines() == 7
    end

    test "does not delete records with future expires_at" do
      org_id = UUID.uuid4()
      future_pipeline = insert_pipeline(org_id, future_expires_at())

      {:ok, count} = delete_expired_batch_with_ok_publisher(100)

      assert count == 0
      assert get_pipeline(future_pipeline.id) != nil
    end

    test "does not delete records with nil expires_at" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, nil)

      {:ok, count} = delete_expired_batch_with_ok_publisher(100)

      assert count == 0
      assert get_pipeline(pipeline.id) != nil
    end

    test "returns 0 when no expired records exist" do
      {:ok, count} = delete_expired_batch_with_ok_publisher(100)

      assert count == 0
    end

    test "deletes expired records from multiple organizations" do
      org_1 = UUID.uuid4()
      org_2 = UUID.uuid4()

      expired_1 = insert_pipeline(org_1, expired_at())
      expired_2 = insert_pipeline(org_2, expired_at())
      non_expired = insert_pipeline(org_1, nil)

      {:ok, count} = delete_expired_batch_with_ok_publisher(100)

      assert count == 2
      assert get_pipeline(expired_1.id) == nil
      assert get_pipeline(expired_2.id) == nil
      assert get_pipeline(non_expired.id) != nil
    end

    test "concurrent workers do not process the same records" do
      org_id = UUID.uuid4()

      Enum.each(1..10, fn _ ->
        insert_pipeline(org_id, expired_at())
      end)

      parent = self()

      with_mock Ppl.Retention.EventPublisher,
        publish_pipeline_deleted: fn _ppl_id, _wf_id, _org_id, _project_id, _artifact_store_id ->
          :ok
        end,
        publish_workflow_deleted: fn _wf_id, _org_id, _project_id, _artifact_store_id ->
          :ok
        end do
        tasks =
          Enum.map(1..3, fn _ ->
            Task.async(fn ->
              {:ok, count} = RecordDeleterQueries.delete_expired_batch(10)
              send(parent, {:deleted, count})
              count
            end)
          end)

        results = Enum.map(tasks, &Task.await/1)
        total_deleted = Enum.sum(results)

        assert total_deleted == 10
        assert count_all_pipelines() == 0
      end
    end

    test "publishes pipeline and workflow deleted events when workflow is empty" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, expired_at())
      project_id = pipeline.request_args["project_id"]
      artifact_store_id = pipeline.request_args["artifact_store_id"]

      with_mock Ppl.Retention.EventPublisher,
        publish_pipeline_deleted: fn ppl_id, wf_id, org_id_arg, project_id_arg, artifact_store_id_arg ->
          send(
            self(),
            {:pipeline_deleted, ppl_id, wf_id, org_id_arg, project_id_arg, artifact_store_id_arg}
          )

          :ok
        end,
        publish_workflow_deleted: fn wf_id, org_id_arg, project_id_arg, artifact_store_id_arg ->
          send(self(), {:workflow_deleted, wf_id, org_id_arg, project_id_arg, artifact_store_id_arg})
          :ok
        end do
        {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

        assert count == 1

        assert_received {:pipeline_deleted, ^pipeline.id, ^pipeline.wf_id, ^org_id, ^project_id,
                         ^artifact_store_id}

        assert_received {:workflow_deleted, ^pipeline.wf_id, ^org_id, ^project_id,
                         ^artifact_store_id}
      end
    end

    test "does not publish workflow deleted when workflow still has pipelines" do
      org_id = UUID.uuid4()
      workflow_id = UUID.uuid4()
      expired_pipeline = insert_pipeline(org_id, expired_at(), workflow_id)
      insert_pipeline(org_id, nil, workflow_id)

      with_mock Ppl.Retention.EventPublisher,
        publish_pipeline_deleted: fn ppl_id, wf_id, org_id_arg, project_id_arg, artifact_store_id_arg ->
          send(
            self(),
            {:pipeline_deleted, ppl_id, wf_id, org_id_arg, project_id_arg, artifact_store_id_arg}
          )

          :ok
        end,
        publish_workflow_deleted: fn wf_id, org_id_arg, project_id_arg, artifact_store_id_arg ->
          send(self(), {:workflow_deleted, wf_id, org_id_arg, project_id_arg, artifact_store_id_arg})
          :ok
        end do
        {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)

        assert count == 1
        assert_received {:pipeline_deleted, ^expired_pipeline.id, ^workflow_id, _, _, _}
        refute_received {:workflow_deleted, ^workflow_id, _, _, _}
      end
    end

    test "returns error after deletion when pipeline event publish fails" do
      org_id = UUID.uuid4()
      pipeline = insert_pipeline(org_id, expired_at())

      with_mock Ppl.Retention.EventPublisher,
        publish_pipeline_deleted: fn _ppl_id, _wf_id, _org_id, _project_id, _artifact_store_id ->
          {:error, :failed}
        end,
        publish_workflow_deleted: fn _wf_id, _org_id, _project_id, _artifact_store_id ->
          :ok
        end do
        assert {:error, :failed} = RecordDeleterQueries.delete_expired_batch(100)
      end

      assert get_pipeline(pipeline.id) == nil
    end
  end

  defp insert_pipeline(org_id, expires_at, wf_id \\ UUID.uuid4()) do
    id = UUID.uuid4()
    ppl_id = UUID.uuid4()
    project_id = UUID.uuid4()
    artifact_store_id = UUID.uuid4()

    request_args = %{
      "organization_id" => org_id,
      "project_id" => project_id,
      "artifact_store_id" => artifact_store_id,
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

  defp delete_expired_batch_with_ok_publisher(limit) do
    with_mock Ppl.Retention.EventPublisher,
      publish_pipeline_deleted: fn _ppl_id, _wf_id, _org_id, _project_id, _artifact_store_id ->
        :ok
      end,
      publish_workflow_deleted: fn _wf_id, _org_id, _project_id, _artifact_store_id ->
        :ok
      end do
      RecordDeleterQueries.delete_expired_batch(limit)
    end
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

    with_mock Ppl.Retention.EventPublisher,
      publish_pipeline_deleted: fn _ppl_id, _wf_id, _org_id, _project_id, _artifact_store_id ->
        :ok
      end,
      publish_workflow_deleted: fn _wf_id, _org_id, _project_id, _artifact_store_id ->
        :ok
      end do
      {:ok, count} = RecordDeleterQueries.delete_expired_batch(100)
      assert count == 1
    end
    assert {:error, _} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:error, _} = Block.describe(ppl_blk_0.block_id)
    assert {:error, _} = Block.describe(ppl_blk_1.block_id)
  end

  defp set_expired(ppl_id) do
    expired_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(-3600, :second)
    {:ok, binary_id} = Ecto.UUID.dump(ppl_id)

    EctoRepo.query!(
      "UPDATE pipeline_requests SET expires_at = $1 WHERE id = $2",
      [expired_at, binary_id]
    )
  end
end
