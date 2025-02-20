defmodule Block.Tasks.Termination.Test do
  use ExUnit.Case

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo
  alias Test.Helpers

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    ppl_id = UUID.uuid4()
    args = %{"service" => "local", "repo_name" => "2_basic", "ppl_priority" => 50}
    job_1 = %{"name" => "job1", "commands" => ["sleep 1", "echo fus"]}
    job_2 = %{"name" => "job2", "commands" => ["sleep 2", "echo ro"]}
    job_3 = %{"name" => "job3", "commands" => ["sleep 3", "echo dah"]}
    job_4 = %{"name" => "job4", "commands" => ["sleep 4", "echo fus"]}
    jobs_list = [job_1, job_2, job_3, job_4]
    ppl_commands = ["cd other_project"]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"agent" => agent, "jobs" => jobs_list,
              "ppl_commands" => ppl_commands}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}
    request = %{ppl_id: ppl_id, pple_block_index: 0, request_args: args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})
    {:ok, task} = insert_task(blk_req)

    {:ok, %{task: task}}
  end

  def insert_task(blk_req) do
    event = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:build_request_id, UUID.uuid4())

    %Tasks{} |> Tasks.changeset(event) |> Repo.insert
  end

  test "stop task in pending state", ctx do
    task = Map.get(ctx, :task)
    assert task.state == "pending"

    t_params = %{request: "stop", desc: "API call"}
    handler = Block.Tasks.STMHandler.PendingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(task, t_params, handler, desired_result, 3_000)
  end

  test "cancel task in pending state", ctx do
    task = Map.get(ctx, :task)
    assert task.state == "pending"

    t_params = %{request: "cancel", desc: "API call"}
    handler = Block.Tasks.STMHandler.PendingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(task, t_params, handler, desired_result, 3_000)
  end

  @tag :integration
  test "stop task in running state", ctx do
    task = Map.get(ctx, :task)
    assert task.state == "pending"

    {:ok, pid} = Block.Tasks.STMHandler.PendingState.start_link()
    args = [task, {"running", nil, nil}, pid]

    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 4_000)

    task = Repo.get(Tasks, task.id)
    t_params = %{request: "stop", desc: "API call"}
    handler = Block.Tasks.STMHandler.RunningState
    desired_result = {"stopping", nil, nil}

    assert_terminated(task, t_params, handler, desired_result, 4_000)

    {:ok, pid} = Block.Tasks.STMHandler.StoppingState.start_link()
    args = [task, {"done", "stopped", "user"}, pid]

    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 4_000)
  end

  defp assert_terminated(task, t_params, handler, desired_result, timeout) do
    {:ok, task} = terminate_task(task, t_params.request, t_params.desc)

    {:ok, pid} = Kernel.apply(handler, :start_link, [])
    args = [task, desired_result, pid]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, timeout)
  end

  defp terminate_task(task, t_req, t_desc) do
    task
    |> Tasks.changeset(%{terminate_request: t_req, terminate_request_desc: t_desc})
    |> Repo.update()
  end

  def check_state?(task, desired_state, looper) do
    :timer.sleep 500
    task = Repo.get(Tasks, task.id)
    check_state_({task.state, task.result, task.result_reason}, task, desired_state, looper)
  end

  defp check_state_({state, result, reason}, task, {desired_state, desired_result, desired_reason}, looper)
  when state == desired_state and result == desired_result and reason == desired_reason do
    GenServer.stop(looper)
    assert task.recovery_count == 0
    :pass
  end
  defp check_state_(_, task, desired_result, looper), do: check_state?(task, desired_result, looper)

end
