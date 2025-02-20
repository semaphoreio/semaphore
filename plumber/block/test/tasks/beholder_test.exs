defmodule Block.Tasks.Beholder.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Block.Tasks.Beholder
  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"agent" => agent, "jobs" => jobs_list}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    id = blk_req.id
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})

    {:ok, %{block_id: id, blk_req: blk_req}}
  end

  test "task is terminated when recovery counter reaches threshold", ctx do
    assert {:ok, task} = insert_task(ctx.blk_req)
    assert task.state == "pending"
    assert {:ok, task} = task
      |> Tasks.changeset(%{recovery_count: 5, in_scheduling: true})
      |> Repo.update
    assert task.recovery_count == 5
    assert task.in_scheduling == true

    assert {:ok, pid} = Beholder.start_link()
    args = [task.state, task, pid]
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :transitioned_to_done, args, 5_000)
  end

  def transitioned_to_done(state, task, pid) when state != "done" do
    :timer.sleep(100)
    task = Repo.get(Tasks, task.id)
    transitioned_to_done(task.state, task, pid)
  end
  def transitioned_to_done("done", task, pid) do
    assert task.state == "done"
    assert task.in_scheduling == true
    assert task.recovery_count == 5
    Process.exit(pid, :normal)
  end

  def query_params() do
    %{initial_query: Block.Tasks.Model.Tasks, cooling_time_sec: -2,
      repo: Block.EctoRepo, schema: Block.Tasks.Model.Tasks, returning: [:id, :block_id],
      allowed_states: ~w(pending running stopping done)}
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: task}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, task}
  end

  test "recovery counter is incremented when block build event is recovered from stuck", ctx do
    assert {:ok, looper_pid} = Beholder.start_link()

    assert {:ok, task} = insert_task(ctx.blk_req)
    assert task.state == "pending"
    assert {:ok, task} = to_scheduling("pending")
    assert task.in_scheduling == true

    Test.Helpers.assert_finished_for_less_than(
      __MODULE__, :recovery_count_is_incremented_assert,
      [task.recovery_count, task, looper_pid],
      5_000)
  end

  def insert_task(blk_req) do
    event = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:recovery_count, 0)

    %Tasks{} |> Tasks.changeset(event) |> Repo.insert
  end

  def recovery_count_is_incremented_assert(recovery_count, task, looper_pid)
  when recovery_count == 0 do
    :timer.sleep(100)
    task = Repo.get(Tasks, task.id)

    recovery_count_is_incremented_assert(task.recovery_count, task, looper_pid)
  end
  def recovery_count_is_incremented_assert(_recovery_count, task, looper_pid) do
    assert task.recovery_count > 0
    Process.exit(looper_pid, :normal)
  end

  test "child_spec accepts 1 arg and returns a map" do
    assert Beholder.child_spec([]) |> is_map()
  end

  test "termination is called when running task is aborted", ctx do
    assert {:ok, task} = insert_task(ctx.blk_req)
    assert task.state == "pending"
    assert {:ok, task} = task
      |> Tasks.changeset(%{recovery_count: 5, in_scheduling: true,
                                 state: "running", build_request_id: UUID.uuid4()})
      |> Repo.update
    assert task.recovery_count == 5
    assert task.state == "running"
    assert task.in_scheduling == true

    with_mock TaskApiClient, [terminate: &(mocked_terminate(&1, &2, task))] do
      assert {:ok, pid} = Beholder.start_link()
      :timer.sleep(3_000)
      Beholder.stop(pid)
    end
  end

  def mocked_terminate(build_req_id, _url, task) do
    assert %{build_request_id: id} = task
    assert build_req_id == id
  end
end
