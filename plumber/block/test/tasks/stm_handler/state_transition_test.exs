defmodule Block.Looper.Tasks.StateTransition.Test do
  use ExUnit.Case

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo
  alias Test.Helpers

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    ppl_id = UUID.uuid4()
    args = %{"service" => "local", "repo_name" => "2_basic", "ppl_priority" => 50}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    ppl_commands = ["cd other_project"]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"agent" => agent, "jobs" => jobs_list,
              "ppl_commands" => ppl_commands}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}
    request = %{ppl_id: ppl_id, pple_block_index: 0, request_args: args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    id = blk_req.id
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})

    {:ok, %{block_id: id, blk_req: blk_req}}
  end

  def insert_task(blk_req) do
    event = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:build_request_id, UUID.uuid4())

    %Tasks{} |> Tasks.changeset(event) |> Repo.insert
  end

  @tag :integration
  test "Tasks looper transitions", ctx do
    {:ok, task} = insert_task(ctx.blk_req)
    assert task.state == "pending"

    {:ok, pid} = Block.Tasks.STMHandler.PendingState.start_link()
    args = [task, "running", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    {:ok, pid} = Block.Tasks.STMHandler.RunningState.start_link()
    args = [task, "done", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)
  end

  @tag :integration
  test "Tasks recovery counter is reset on transition out of scheduling", ctx do
    assert {:ok, task} = insert_task(ctx.blk_req)
    assert task.state == "pending"
    assert {:ok, task} = task
      |> Tasks.changeset(%{recovery_count: 1})
      |> Repo.update
    assert task.recovery_count == 1

    {:ok, pid} = Block.Tasks.STMHandler.PendingState.start_link()
    args = [task, "running", pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)
  end

  def check_state?(task, desired_state, looper) do
    :timer.sleep 500
    task = Repo.get(Tasks, task.id)
    check_state_(task.state, task, desired_state, looper)
  end

  defp check_state_(state, task, desired_state, looper) when state == desired_state do
    GenServer.stop(looper)
    assert task.recovery_count == 0
    :pass
  end
  defp check_state_(_, task, desired_state, looper), do: check_state?(task, desired_state, looper)
end
