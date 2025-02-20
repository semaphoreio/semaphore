defmodule Block.Blocks.Model.BlocksQueries.Test do
  use ExUnit.Case
  doctest Block.Blocks.Model.BlocksQueries

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.{Blocks, BlocksQueries}
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
                definition: definition, version: "v3.0", hook_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})

    {:ok, %{blk_req: blk_req, block_id: blk_req.id, request: request}}
  end

  test "insert new block", ctx do
    {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    assert blk.state == "initializing"
    assert blk.in_scheduling == false
    assert blk.recovery_count == 0
    clean_up(blk)
  end

  test "block insert is idempotent operation", ctx do
    assert {:ok, blk_1} = BlocksQueries.insert(ctx.blk_req)
    assert {:ok, blk_2} = BlocksQueries.insert(ctx.blk_req)
    assert blk_1.inserted_at == blk_2.inserted_at
    clean_up(blk_1)
    clean_up(blk_2)
  end

  test "list test", ctx do
    #  ppl_id wrong
    assert {:ok, []} = BlocksQueries.list(UUID.uuid4)

    # ppl_id valid, Tasks not created yet
    assert {:ok, blk_1} = BlocksQueries.insert(ctx.blk_req)

    request = ctx.request |> Map.put(:pple_block_index, 1)
    {:ok, blk_req_2} = BlockRequestsQueries.insert_request(request)
    assert {:ok, blk_2} = BlocksQueries.insert(blk_req_2)

    assert {:ok, [expected_desc(blk_1), expected_desc(blk_2)]}
            == BlocksQueries.list(ctx.blk_req.ppl_id)

    # ppl_id valid, all data available
    assert {:ok, task_1} = insert_task(blk_1.block_id)
    assert {:ok, task_2} = insert_task(blk_2.block_id)
    assert {:ok, [expected_desc(blk_1, task_1), expected_desc(blk_2, task_2)]}
            == BlocksQueries.list(ctx.blk_req.ppl_id)
  end

  defp expected_desc(blk) do
    %{block_id: blk.block_id,
      build_req_id: "",
      error_description: "",
      old_jobs: [],
      new_jobs: []}
  end

  defp expected_desc(blk, task) do
    %{block_id: blk.block_id,
      build_req_id: task.build_request_id,
      error_description: "",
      old_jobs: ["job_1", "job_2"],
      new_jobs: nil}
  end

  def insert_task(block_id) do
    event = %{block_id: block_id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:description, %{build: %{jobs: ["job_1", "job_2"]}})
      |> Map.put(:build_request_id, UUID.uuid4())

    %Tasks{} |> Tasks.changeset(event) |> Repo.insert
  end

  test "duplicate passed blocks", ctx do
    {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    blk = blk |> Ecto.Changeset.change(%{state: "done", result: "passed"}) |> Repo.update!()

    request = %{ctx.request | ppl_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    new_blk_id = blk_req.id

    assert {:ok, duplicate} = BlocksQueries.duplicate(blk.block_id, new_blk_id)
    assert duplicate.id != blk.id
    assert duplicate.block_id == new_blk_id
    different_fields = [:id, :block_id, :inserted_at, :updated_at]
    assert duplicate |> Map.drop(different_fields) == blk |> Map.drop(different_fields)
  end

  test "duplicate returns error when block is not passed", ctx do
    {:ok, blk} = BlocksQueries.insert(ctx.blk_req)

    request = %{ctx.request | ppl_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    new_blk_id = blk_req.id

    assert {:error, message} = BlocksQueries.duplicate(blk.block_id, new_blk_id)
    assert message == "Can not dupplicate block #{blk.block_id} because it's result is not 'passed'."
  end

  test "get block in initializing and move it to scheduling", ctx do
    to_scheduling_from("initializing", ctx)
  end

  test "get block in running and move it to scheduling", ctx do
    to_scheduling_from("running", ctx)
  end

  test "get block in stopping and move it to scheduling", ctx do
    to_scheduling_from("stopping", ctx)
  end

  test "move block from initializing-scheduling to running", ctx do
    from_x_scheduling_to("initializing", "running", ctx)
  end

  test "move block from initializing-scheduling to done", ctx do
    from_x_scheduling_to("initializing", "done", ctx)
  end

  test "move block from running-scheduling to stopping", ctx do
    from_x_scheduling_to("running", "stopping", ctx)
  end

  test "move block from running-scheduling to done", ctx do
    from_x_scheduling_to("running", "done", ctx)
  end

  test "move block from stopping-scheduling to done", ctx do
    from_x_scheduling_to("stopping", "done", ctx)
  end

  test "recover blocks stuck in scheduling", ctx do
    stuck_blk = create_event(ctx, "initializing", true)
    id = stuck_blk.id
    recover_stuck_in_scheduling(stuck_blk)

    change_state_and_test(id, "running")
    change_state_and_test(id, "stopping")
    change_state_and_test(id, "done")
  end

  defp change_state_and_test(id, state) do
    Blocks
    |> Repo.get(id)
    |> Blocks.changeset(%{in_scheduling: :true, state: state})
    |> Repo.update()
    |> elem(1)
    |> recover_stuck_in_scheduling()
  end

  defp beholder_params() do
    %{repo: Block.EctoRepo, query: Block.Blocks.Model.Blocks, threshold_sec: -2, threshold_count: 5,
    terminal_state: "done", result_on_abort: "failed", result_reason_on_abort: "stuck",
    excluded_states: ["done"]}
  end

  # Recover all Blocks stuck in scheduling and check if one of them has passed id value
  defp recover_stuck_in_scheduling(blk) do
    {_, recovered} = beholder_params() |> Looper.Beholder.Query.recover_stuck()

    recovered
    |> Enum.find(fn recovered_blk -> recovered_blk.id == blk.id end)
    |> recover_stuck_in_scheduling_(blk.state)
  end

  # Block in "done" is not recovered
  defp recover_stuck_in_scheduling_(blk, "done"), do: assert blk == nil
  # Blocks in other states are recovered - moved out of scheduling
  defp recover_stuck_in_scheduling_(blk, _state) do
    assert blk.in_scheduling == false
  end

  test "updated_at change on update_all() call", ctx do
    blk_req = ctx.blk_req
    func = fn(blk_req) -> BlocksQueries.insert(blk_req) end
    blk = assert_blk_updated_at_set_properly(func, blk_req)

    func = fn(_) -> to_scheduling("initializing") end
    blk_returned = assert_blk_updated_at_set_properly(func, blk)
    assert blk.id == blk_returned.id

    func = fn(blk) -> to_state(blk, "done") end
    blk_returned = assert_blk_updated_at_set_properly(func, blk_returned)
    assert blk.id == blk_returned.id
  end

  defp assert_blk_updated_at_set_properly(func, args) do
    before_func = DateTime.utc_now |> DateTime.to_naive
    {:ok, blk} = func.(args)
    after_func = DateTime.utc_now |> DateTime.to_naive
    assert NaiveDateTime.compare(before_func, blk.updated_at) == :lt
    assert NaiveDateTime.compare(after_func, blk.updated_at) == :gt
    blk
  end

  def query_params() do
    %{initial_query: Block.Blocks.Model.Blocks, cooling_time_sec: -2,
      repo: Block.EctoRepo, schema: Block.Blocks.Model.Blocks, returning: [:id, :block_id],
      allowed_states: ~w(initializing running stopping done)}
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: blk}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, blk}
  end

  def to_state(blk, state) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(blk, fn _, _ -> {:ok, %{state: state}} end, args)
    BlocksQueries.get_by_id(blk.block_id)
  end

  defp to_scheduling_from(state, ctx) do
    _blk = create_event(ctx, state, false)
    {:ok, blk} = to_scheduling(state)
    assert blk.state == state
    assert blk.in_scheduling == true
    clean_up(blk)
  end

  defp from_x_scheduling_to(from_state, to_state, ctx) do
    blk = create_event(ctx, from_state, true)
    {:ok, blk} = to_state(blk, to_state)
    assert blk.state == to_state
    assert blk.in_scheduling == false
    clean_up(blk)
  end

  defp create_event(ctx, state, in_scheduling) do
    params = event_params(ctx, state, in_scheduling)
    {:ok, blk} = %Blocks{} |> Blocks.changeset(params) |> Repo.insert
    assert blk.state == state
    assert blk.in_scheduling == in_scheduling
    blk
  end

  defp event_params(ctx, state, in_scheduling) do
    Map.merge(ctx, %{state: state, in_scheduling: in_scheduling})
  end

  defp clean_up(blk) do
    blk |> Blocks.changeset(%{state: "done"}) |> Repo.update
  end
end
