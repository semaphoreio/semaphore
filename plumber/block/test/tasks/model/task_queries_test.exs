defmodule Block.Model.TasksQueries.Test do
  use ExUnit.Case
  doctest Block.Tasks.Model.TasksQueries

  alias Ecto.Multi
  alias Block.Tasks.Model.TasksQueries
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    id = blk_req.id
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})

    {:ok, %{block_id: id, blk_req: blk_req, request: request}}
  end

  test "insert new task", ctx do
    {:ok, task} = insert_task(ctx.blk_req)
    assert task.state == "pending"
    assert task.in_scheduling == false
    assert task.recovery_count == 0
    clean_up(task)
  end

  def insert_task(blk_req) do
    event = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")

    %Tasks{} |> Tasks.changeset(event) |> Repo.insert
  end

  test "duplicate passed task", ctx do
    {:ok, task} = insert_task(ctx.blk_req)
    task = task |> Ecto.Changeset.change(%{state: "done", result: "passed"}) |> Repo.update!()

    request = %{ctx.request | ppl_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    new_blk_id = blk_req.id

    assert {:ok, duplicate} = TasksQueries.duplicate(task.block_id, new_blk_id)
    assert duplicate.id != task.id
    assert duplicate.block_id == new_blk_id
    different_fields = [:id, :block_id, :inserted_at, :updated_at]
    assert duplicate |> Map.drop(different_fields) == task |> Map.drop(different_fields)
  end

  test "duplicate returns error when task is not passed", ctx do
    {:ok, task} = insert_task(ctx.blk_req)

    request = %{ctx.request | ppl_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    new_blk_id = blk_req.id

    assert {:error, message} = TasksQueries.duplicate(task.block_id, new_blk_id)
    assert message == "Can not dupplicate task for block #{task.block_id} because it's result is not 'passed'."
  end

  test "get task in pending and move it to scheduling", ctx do
    to_scheduling_from("pending", ctx)
  end

  test "get task in running and move it to scheduling", ctx do
    to_scheduling_from("running", ctx)
  end

  test "get task in stopping and move it to scheduling", ctx do
    to_scheduling_from("stopping", ctx)
  end

  test "move task from pending-scheduling to running", ctx do
    from_x_scheduling_to("pending", "running", ctx)
  end

  test "move task from pending-scheduling to done", ctx do
    from_x_scheduling_to("pending", "done", ctx)
  end

  test "move task from running-scheduling to stopping", ctx do
    from_x_scheduling_to("running", "stopping", ctx)
  end

  test "move task from running-scheduling to done", ctx do
    from_x_scheduling_to("running", "done", ctx)
  end

  test "move task from stopping-scheduling to done", ctx do
    from_x_scheduling_to("stopping", "done", ctx)
  end

  test "recover tasks stuck in scheduling", ctx do
    stuck_task = create_event(ctx, "pending", true)
    id = stuck_task.id
    recover_stuck_in_scheduling(stuck_task)

    change_state_and_test(id, "running")
    change_state_and_test(id, "stopping")
    change_state_and_test(id, "done")
  end

  defp change_state_and_test(id, state) do
    Tasks
    |> Repo.get(id)
    |> Tasks.changeset(%{in_scheduling: :true, state: state})
    |> Repo.update()
    |> elem(1)
    |> recover_stuck_in_scheduling()
  end

  defp beholder_params() do
    %{repo: Block.EctoRepo, query: Block.Tasks.Model.Tasks, threshold_sec: -2, threshold_count: 5,
    terminal_state: "done", result_on_abort: "failed", result_reason_on_abort: "stuck",
    excluded_states: ["done"]}
  end

  # Recover all Tasks stuck in scheduling and check if one of them has passed id value
  defp recover_stuck_in_scheduling(task) do
    {_, recovered} = beholder_params() |> Looper.Beholder.Query.recover_stuck()

    recovered
    |> Enum.find(fn recovered_task -> recovered_task.id == task.id end)
    |> recover_stuck_in_scheduling_(task.state)
  end

  # Task in "done" is not recovered
  defp recover_stuck_in_scheduling_(task, "done"), do: assert task == nil
  # Tasks in other states are recovered - moved out of scheduling
  defp recover_stuck_in_scheduling_(task, _state) do
    assert task.in_scheduling == false
  end

  test "updated_at change on update_all() call", ctx do
    blk_req = ctx.blk_req
    func = fn(blk_req) -> insert_task(blk_req) end
    task = assert_task_updated_at_set_properly(func, blk_req)

    func = fn(_) -> to_scheduling("pending") end
    task_returned = assert_task_updated_at_set_properly(func, task)
    assert task.id == task_returned.id

    func = fn(task) -> to_state(task, "done") end
    task_returned = assert_task_updated_at_set_properly(func, task_returned)
    assert task.id == task_returned.id
  end

  defp assert_task_updated_at_set_properly(func, args) do
    before_func = DateTime.utc_now |> DateTime.to_naive
    {:ok, task} = func.(args)
    after_func = DateTime.utc_now |> DateTime.to_naive
    assert NaiveDateTime.compare(before_func, task.updated_at) == :lt
    assert NaiveDateTime.compare(after_func, task.updated_at)  == :gt
    task
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

  def to_state(task, state) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(task, fn _, _ -> {:ok, %{state: state}} end, args)
    TasksQueries.get_by_id(task.block_id)
  end

  defp to_scheduling_from(state, ctx) do
    _task = create_event(ctx, state, false)
    {:ok, task} = to_scheduling(state)
    assert task.state == state
    assert task.in_scheduling == true
    clean_up(task)
  end

  defp from_x_scheduling_to(from_state, to_state, ctx) do
    task = create_event(ctx, from_state, true)
    {:ok, task} = to_state(task, to_state)
    assert task.state == to_state
    assert task.in_scheduling == false
    clean_up(task)
  end

  defp create_event(ctx, state, in_scheduling) do
    params = event_params(ctx, state, in_scheduling)
    {:ok, task} = %Tasks{} |> Tasks.changeset(params) |> Repo.insert
    assert task.state == state
    assert task.in_scheduling == in_scheduling
    task
  end

  defp event_params(ctx, state, in_scheduling) do
    Map.merge(ctx, %{state: state, in_scheduling: in_scheduling})
  end

  defp clean_up(task) do
    task |> Tasks.changeset(%{state: "done"}) |> Repo.update
  end

  test "add insert changeset to multi", ctx do
    multi = TasksQueries.multi_insert(Multi.new, ctx.blk_req)

    assert MapSet.member?(Map.get(multi, :names), :task)
    operations = Map.get(multi, :operations)
    assert Keyword.has_key?(operations, :task)

    changeset_tuple = Keyword.get(operations, :task)
    assert elem(changeset_tuple, 0) == :changeset

    changeset = elem(changeset_tuple, 1)
    assert changeset.action == :insert
    assert changeset.valid? == true
    assert changeset.data ==  %Tasks{}

    assert Map.get(changeset.changes, :block_id) == ctx.blk_req.id
    assert Map.get(changeset.changes, :state) == "pending"
    assert Map.get(changeset.changes, :in_scheduling) == false

  end
end
