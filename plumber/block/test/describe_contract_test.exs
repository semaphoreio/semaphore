defmodule Block.DescribeContract.Test do
  use ExUnit.Case, async: false

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.Blocks
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo
  alias Util.Proto
  alias InternalApi.Task.DescribeResponse

  setup do
    assert {:ok, _} =
      Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    :ok
  end

  # The job-copy partition predicate (ppl app) decides copy-vs-run from
  # Block.describe output. This test drives the real serialization chain a
  # description travels in production - Task API proto response decoded the
  # way TaskApiClient decodes it, persisted into the tasks description jsonb
  # column, read back and reshaped by Block.describe - and pins the exact job
  # shape the predicate consumes. A drift anywhere in that chain fails here
  # instead of silently degrading job-level rerun to whole-block rebuilds.
  test "a passed job survives the proto -> jsonb -> describe round-trip in the predicate's shape", ctx do
    _ = ctx
    job_id = UUID.uuid4()

    describe_response =
      Proto.deep_new!(DescribeResponse, %{
        task: %{
          id: UUID.uuid4(),
          state: :FINISHED,
          result: :PASSED,
          jobs: [
            %{id: job_id, index: 0, name: "job1", state: :FINISHED, result: :PASSED},
            %{id: UUID.uuid4(), index: 1, name: "job2", state: :FINISHED, result: :FAILED}
          ]
        }
      })

    tf_map = %{
      Google.Protobuf.Timestamp => {Block.TaskApiClient.GrpcClient, :timestamp_to_datetime}
    }

    {:ok, description} = Proto.to_map(describe_response, transformations: tf_map)

    {:ok, blk_req} = insert_block_request()
    {:ok, _blk} = insert_block(blk_req.id)
    {:ok, _task} = insert_done_task(blk_req.id, description)

    assert {:ok, %{jobs: [job1, job2]}} = Block.describe(blk_req.id)

    assert %{status: "FINISHED", result: "PASSED", index: 0} = job1
    assert job1.job_id == job_id
    assert is_binary(job1.job_id)

    assert %{status: "FINISHED", result: "FAILED", index: 1} = job2
  end

  defp insert_block_request do
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0,
                request_args: %{"service" => "local"},
                source_args: %{"git_ref_type" => "branch"}, version: "v1.0",
                definition: %{"build" => %{"jobs" => []}}, hook_id: UUID.uuid4()}

    BlockRequestsQueries.insert_request(request)
  end

  defp insert_block(block_id) do
    params = %{block_id: block_id, state: "done", result: "failed",
               result_reason: "test", in_scheduling: false}

    %Blocks{} |> Blocks.changeset(params) |> Repo.insert()
  end

  defp insert_done_task(block_id, description) do
    params = %{block_id: block_id, state: "done", result: "failed",
               result_reason: "test", in_scheduling: false,
               task_id: UUID.uuid4(), description: description}

    %Tasks{} |> Tasks.changeset(params) |> Repo.insert()
  end
end
