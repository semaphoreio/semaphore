defmodule Block.Test do
  use ExUnit.Case

  alias Block.Tasks.Model.Tasks
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.BlocksQueries
  alias Block.Tasks.Model.TasksQueries
  alias Block.EctoRepo, as: Repo

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    request_args = %{"service" => "local", "repo_name" => "2_basic", "ppl_priority" => 50}
    source_args = %{"git_ref_type" => "branch"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"jobs" => jobs_list, "ppl_commands" => [], "agent" => agent}
    definition_v1 = %{"name" => "Block 1", "build" => build}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition_v3 = Map.put(definition_v1, "includes", includes)
    {:ok, %{request_args: request_args, definition_v1: definition_v1,
            definition_v3: definition_v3, source_args: source_args}}
  end

  # Schedule

  test "valid request for v1 pipeline's block", ctx do
    [UUID.uuid4(), 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    |> form_request()
    |> schedule_block_run_with_params_success()
  end

  test "valid request for v3 pipeline's block", ctx do
    [UUID.uuid4(), 0, ctx, UUID.uuid4(), "v3.0", ctx.definition_v3]
    |> form_request()
    |> schedule_block_run_with_params_success()
  end

  defp schedule_block_run_with_params_success(params) do
    assert {:ok, block_id} = apply(Block, :schedule, params)
    assert {:ok, _} = UUID.info(block_id)
    [request] = params
    assert {:ok, _blk_req} = BlockRequestsQueries.get_by_ppl_data(request.ppl_id, request.pple_block_index)
    assert {:ok, _blk} = BlocksQueries.get_by_id(block_id)
    block_id
  end

  defp form_request([ppl_id, pple_block_index, ctx, hook_id, version, definition]) do
    request = %{ppl_id: ppl_id, pple_block_index: pple_block_index, version: version,
                hook_id: hook_id, request_args: ctx[:request_args],
                source_args: ctx[:source_args], definition: definition}
    [request]
  end

  test "schedule call is idempotent", ctx do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()

    [request] = form_request([ppl_id, 0, ctx, hook_id, "v3.0", ctx.definition_v3])
    assert {:ok, _message} = Block.schedule(request)
    assert {:ok, blk_req_1} = BlockRequestsQueries.get_by_ppl_data(ppl_id, 0)

    assert {:ok, _message} = Block.schedule(request)
    assert {:ok, blk_req_2} = BlockRequestsQueries.get_by_ppl_data(ppl_id, 0)

    assert blk_req_1.inserted_at == blk_req_2.inserted_at
  end

  test "invalid requests for v1 pipeline block - one of params is nil", ctx do
    params = [UUID.uuid4(), 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]

    Enum.map(0..5, fn(x) -> schedule_block_run_with_params_fail(nil_param_at(params, x)) end)
  end

  test "invalid requests for v3 pipeline block - one of params is nil", ctx do
    params = [UUID.uuid4(), 0, ctx, UUID.uuid4(), "v3.0", ctx.definition_v3]

    Enum.map(0..5, fn(x) -> schedule_block_run_with_params_fail(nil_param_at(params, x)) end)
  end

  defp schedule_block_run_with_params_fail(params) do
    [request] = form_request(params)
    assert {:error, _message} = apply(Block, :schedule, [request])
  end

  defp nil_param_at(list, 2), do: List.replace_at(list, 2, %{})
  defp nil_param_at(list, index), do: List.replace_at(list, index, nil)


  # Duplicate

  test "duplicate succedes for passed block", ctx do
    old_block_id = prepare_passed_block(ctx)

    new_ppl_id = UUID.uuid4()
    assert {:ok, new_block_id} = Block.duplicate(old_block_id, new_ppl_id)
    assert {:ok, blk_req} = BlockRequestsQueries.get_by_ppl_data(new_ppl_id, 0)
    assert blk_req.id == new_block_id
    assert {:ok, _blk} = BlocksQueries.get_by_id(new_block_id)
    assert {:ok, _task} = TasksQueries.get_by_id(new_block_id)
  end

  defp prepare_passed_block(ctx) do
    definition = Map.get(ctx, :definition_v3)
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: ctx[:request_args],
                definition: definition, version: "v3.0", hook_id: UUID.uuid4(),
                source_args: ctx[:source_args]}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: definition |> Map.get("build")})

    {:ok, blk} = BlocksQueries.insert(blk_req)
    blk |> Ecto.Changeset.change(%{state: "done", result: "passed"}) |> Repo.update!()

    {:ok, _task} = insert_task(blk_req)

    blk_req.id
  end

  def insert_task(blk_req) do
    params = %{block_id: blk_req.id}
      |> Map.put(:state, "done")
      |> Map.put(:result, "passed")
      |> Map.put(:in_scheduling, "false")

    %Tasks{} |> Tasks.changeset(params) |> Repo.insert()
  end

  # Delete

  @tag :integration
  test "delete_blocks_from_ppl() is idempotent", ctx do
    ppl_id = UUID.uuid4()
    params = [ppl_id, 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_id_1} = apply(Block, :schedule, [request])

    assert {:ok, message} = Block.delete_blocks_from_ppl(ppl_id)
    assert message == "Deleted 1 blocks successfully."

    assert {:error, {:block_not_found, block_id_1}} == Block.describe(block_id_1)

    assert {:ok, message} = Block.delete_blocks_from_ppl(ppl_id)
    assert message == "Deleted 0 blocks successfully."
  end

  @tag :integration
  test "delete_blocks_from_ppl() deletes all blocks of given ppl from DB and only them", ctx do
    ppl_id = UUID.uuid4()
    params = [ppl_id, 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_id_1} = apply(Block, :schedule, [request])

    params = [ppl_id, 1, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_id_2} = apply(Block, :schedule, [request])

    ppl_id_2 = UUID.uuid4()
    params = [ppl_id_2, 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_id_3} = apply(Block, :schedule, [request])

    loopers = Test.Helpers.start_loopers()

    Test.Helpers.assert_finished_for_less_than(__MODULE__, :block_finished?, [block_id_1], 10_000)
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :block_finished?, [block_id_2], 10_000)
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :block_finished?, [block_id_3], 10_000)

    Test.Helpers.stop_loopers(loopers)

    assert {:ok, %{block_id: ^block_id_1, error_description: "", build_req_id: build_req_id}}
                    = Block.describe(block_id_1)
    assert {:ok, _} = UUID.info(build_req_id)

    assert {:ok, %{block_id: ^block_id_2, error_description: "", build_req_id: build_req_id}}
                    = Block.describe(block_id_2)
    assert {:ok, _} = UUID.info(build_req_id)

    assert {:ok, %{block_id: ^block_id_3, error_description: "", build_req_id: build_req_id}}
                    = Block.describe(block_id_3)
    assert {:ok, _} = UUID.info(build_req_id)

    assert {:ok, message} = Block.delete_blocks_from_ppl(ppl_id)
    assert message == "Deleted 2 blocks successfully."

    assert {:error, {:block_not_found, block_id_1}} == Block.describe(block_id_1)
    assert {:error, {:block_not_found, block_id_2}} == Block.describe(block_id_2)

    assert {:ok, %{block_id: ^block_id_3, error_description: "", build_req_id: build_req_id}}
                    = Block.describe(block_id_3)
    assert {:ok, _} = UUID.info(build_req_id)
  end

  def block_finished?(block_id) do
    :timer.sleep(500)

    {:ok, %{state: state}} = Block.status(block_id)
    if state == "done", do: :finish, else: block_finished?(block_id)
  end

  # List

  @tag :integration
  test "list() returns valid responses both when blocks are found and when they are not", ctx do
    ppl_id = UUID.uuid4()

    assert {:ok, []} == Block.list(ppl_id)

    params = [ppl_id, 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_1_id} = apply(Block, :schedule, [request])

    params = [ppl_id, 1, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_2_id} = apply(Block, :schedule, [request])

    assert {:ok, blk_1} = BlocksQueries.get_by_id(block_1_id)
    assert {:ok, blk_2} = BlocksQueries.get_by_id(block_2_id)
    assert {:ok, [expected_desc(blk_1), expected_desc(blk_2)]} == Block.list(ppl_id)


    loopers = Test.Helpers.start_loopers()

    Test.Helpers.wait_for_block_state(block_1_id, "done", 10_000)
    Test.Helpers.wait_for_block_state(block_2_id, "done", 10_000)

    assert {:ok, task_1} = TasksQueries.get_by_id(block_1_id)
    assert {:ok, task_2} = TasksQueries.get_by_id(block_2_id)


    assert {:ok, [block_1_desc, block_2_desc]} =  Block.list(ppl_id)

    assert_valid_block_desc(block_1_desc, blk_1.block_id, task_1.build_request_id)
    assert_valid_block_desc(block_2_desc, blk_2.block_id, task_2.build_request_id)

    Test.Helpers.stop_loopers(loopers)
  end

  defp expected_desc(blk) do
    %{block_id: blk.block_id,
      build_req_id: "",
      error_description: "",
      jobs: []}
  end

  defp assert_valid_block_desc(block_desc, block_id, build_request_id) do
    assert %{block_id: ^block_id, build_req_id: ^build_request_id,
             error_description: "", jobs: [job_1, job_2]} = block_desc
    assert %{index: 0, job_id: job_1_id, name: "job1",
             result: "PASSED", status: "FINISHED"} = job_1
    assert {:ok, _} = UUID.info(job_1_id)
    assert %{index: 1, job_id: job_2_id, name: "job2",
             result: "PASSED", status: "FINISHED"} = job_2
    assert {:ok, _} = UUID.info(job_2_id)
  end

  # Describe

  test "valid request for v1 block description", ctx do
    ppl_id = UUID.uuid4()
    params = [ppl_id, 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_id} = apply(Block, :schedule, [request])

    # Test description value before build event is created
    assert {:ok, %{block_id: block_id, error_description: "", build_req_id: ""}}
                    == Block.describe(block_id)

    assert {:ok, blk} = BlocksQueries.get_by_id(block_id)
    assert {:ok, _blk} = to_state(blk, "running")

    # Test description value when build event exists
    assert {:ok, %{block_id: ^block_id, error_description: "", build_req_id: build_req_id}}
                    = Block.describe(block_id)
    assert {:ok, _} = UUID.info(build_req_id)
  end

  test "valid describe request for block which failed initialization", ctx do
    ppl_id = UUID.uuid4()

    invalid_jobs = [%{"name" => "job1", "commands" => ["echo foo"],
                      "matrix" => "this should be list of envs and their values"}]

    definition = ctx.definition_v1
                 |> put_in(["build", "jobs"], invalid_jobs)

    params = [ppl_id, 0, ctx, UUID.uuid4(), "v1.0", definition]
    [request] = form_request(params)
    assert {:ok, block_id} = apply(Block, :schedule, [request])

    {:ok, pid} = Block.Blocks.STMHandler.InitializingState.start_link()
    :timer.sleep(3_000)

    assert {:ok, block} = BlocksQueries.get_by_id(block_id)
    assert block.state == "done"

    # Test description value when block failed to initialize
    assert {:ok, %{block_id: ^block_id, error_description: error_desc, build_req_id: ""}}
                    = Block.describe(block_id)
    assert error_desc == "Error: \"'matrix' must be non-empty List.\""

    GenServer.stop(pid)
  end

  test "invalid request for v1 block description - unknown block_id", ctx do
    params = [UUID.uuid4(), 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, _block_id} = apply(Block, :schedule, [request])

    not_existing_block_id = UUID.uuid4()
    assert {:error, {:block_not_found, not_existing_block_id}} == Block.describe(not_existing_block_id)
  end

  test "valid request for v1 block status", ctx do
    ppl_id = UUID.uuid4()
    params = [ppl_id, 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, block_id} = apply(Block, :schedule, [request])
    assert {:ok, block} = BlocksQueries.get_by_id(block_id)

    assert {:ok, %{state: "initializing", result: nil, result_reason: nil,
                   inserted_at: block.inserted_at |> DateTime.from_naive!("Etc/UTC"),
                   updated_at: block.updated_at |> DateTime.from_naive!("Etc/UTC")}}
               == Block.status(block_id)
  end

  test "invalid request for v1 block status - unknown block_id", ctx do
    params = [UUID.uuid4(), 0, ctx, UUID.uuid4(), "v1.0", ctx.definition_v1]
    [request] = form_request(params)
    assert {:ok, _block_id} = apply(Block, :schedule, [request])

    not_existing_block_id = UUID.uuid4()
    assert {:error, {:block_not_found, not_existing_block_id}} == Block.status(not_existing_block_id)
  end

  test "terminate test - initializing block", ctx do
    terminate_test("v1.0", ctx.definition_v1, ctx, "initializing")
    terminate_test("v3.0", ctx.definition_v3, ctx, "initializing")
  end

  test "terminate test - running pipeline", ctx do
    terminate_test("v1.0", ctx.definition_v1, ctx, "running")
    terminate_test("v3.0", ctx.definition_v3, ctx, "running")
  end

  test "terminate test - stopping pipeline", ctx do
    terminate_test("v1.0", ctx.definition_v1, ctx, "stopping")
    terminate_test("v3.0", ctx.definition_v3, ctx, "stopping")
  end

  test "terminate test - done pipeline", ctx do
    terminate_test("v1.0", ctx.definition_v1, ctx, "done")
    terminate_test("v3.0", ctx.definition_v3, ctx, "done")
  end

  defp terminate_test(version, definition, ctx, state) do
    [UUID.uuid4(), 0, ctx, UUID.uuid4(), version, definition]
    |> form_request()
    |> schedule_block_run_with_params_success()
    |> transition_to_state(state)
    |> terminate_block()
    |> assert_block_terminated(state)
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

  def to_state(blk, state, additional \\ %{})
  def to_state(blk, "running", additional) do
    args = query_params()
    assert {:ok, _} = Block.Blocks.STMHandler.InitializingState.scheduling_handler(blk)
    Looper.STM.Impl.exit_scheduling(blk, fn _, _ -> {:ok, Map.merge(additional, %{state: "running"})} end, args)
    BlocksQueries.get_by_id(blk.block_id)
  end
  def to_state(blk, state, additional) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(blk, fn _, _ -> {:ok, Map.merge(additional, %{state: state})} end, args)
    BlocksQueries.get_by_id(blk.block_id)
  end

  defp transition_to_state(block_id, state) do
    assert {:ok, blk} = BlocksQueries.get_by_id(block_id)
    to_running(blk, state)
  end

  defp to_running(blk, "initializing"), do: blk.block_id
  defp to_running(blk, state) do
    assert {:ok, blk} = to_state(blk, "running")
    to_stopping(blk, state)
  end

  defp to_stopping(blk, "running"), do: blk.block_id
  defp to_stopping(blk, state = "done"), do: to_done(blk, state)
  defp to_stopping(blk, state) do
    assert {:ok, blk} = to_state(blk, "stopping", %{terminate_request: "stop", terminate_request_desc: "API call"})
    to_done(blk, state)
  end

  defp to_done(blk, "running"), do: blk.block_id
  defp to_done(blk, "stopping"), do: blk.block_id
  defp to_done(blk, _state) do
    assert {:ok, blk} = to_state(blk, "done")
    blk.block_id
  end

  defp terminate_block(block_id) do
    assert {:ok, message} = Block.terminate(block_id)
    assert message == "Block termination started."
    block_id
  end

  defp assert_block_terminated(block_id, "done") do
    assert {:ok, blk} = BlocksQueries.get_by_id(block_id)
    assert blk.state == "done"
  end
  defp assert_block_terminated(block_id, _state) do
    assert {:ok, blk} = BlocksQueries.get_by_id(block_id)
    assert blk.terminate_request == "stop"
    assert blk.terminate_request_desc == "API call"
  end
end
