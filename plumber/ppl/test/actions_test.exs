defmodule Ppl.Actions.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.Actions
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.DeleteRequests.Model.DeleteRequestsQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias InternalApi.Plumber.{ListRequest, ListKeysetRequest}
  alias Google.Protobuf.Timestamp
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.EctoRepo, as: Repo
  alias Util.Proto

  import Mock

  setup do
    Test.Helpers.truncate_db()

    request_args = Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}

    definition = %{"version" => "v3.0", "agent" => %{"machine" =>
                    %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}},
                      "blocks" => [%{"name" => "Block 1", "build" => build},
                        %{"name" => "Block 2", "build" => build}]}
    {:ok, %{request_args: request_args, definition: definition}}
  end

  test "schedule() persists requests with valid args" do
    request_args_local = Test.Helpers.schedule_request_factory(:local)
    request_args_git = Test.Helpers.schedule_request_factory(:github)

    request_args_local |> Actions.schedule() |> assert_schedule_success()
    request_args_git |> Actions.schedule() |> assert_schedule_success()
  end

  test "schedule() persists request from periodic scheduler" do
    request_args = Test.Helpers.schedule_request_factory(:local)
    request_args = request_args |> Map.put(:scheduler_task_id, "1234")

    request_args |> Actions.schedule() |> assert_schedule_success()
  end

  defp assert_schedule_success(response) do
    assert {:ok, %{ppl_id: ppl_id, response_status: %{code: 0}}} = response
    assert {:ok, _result} = UUID.info(ppl_id)
    ppl_id
  end

  test "describe_topology() for after_pipeline returns array of blocks" do
    assert {:ok, topology} = definition_map() |> Actions.describe_topology()
    assert [
      "after_ppl_job_b",
      "after_ppl_job_a"
    ] == topology.after_pipeline.jobs
  end

  test "describe_topology() for after_pipeline returns matrix jobs" do
    assert {:ok, topology} = matrix_definition_map() |> Actions.describe_topology()
    assert [
      "matrix_job - ELIXIR=1.1, ERLANG=1.5, SEMAPHORE=1.0",
      "matrix_job - ELIXIR=1.1, ERLANG=1.5, SEMAPHORE=2.0",
      "matrix_job - ELIXIR=1.1, ERLANG=1.5, SEMAPHORE=3.0",
      "matrix_job - ELIXIR=1.1, ERLANG=1.6, SEMAPHORE=1.0",
      "matrix_job - ELIXIR=1.1, ERLANG=1.6, SEMAPHORE=2.0",
      "matrix_job - ELIXIR=1.1, ERLANG=1.6, SEMAPHORE=3.0",
      "matrix_job - ELIXIR=1.2, ERLANG=1.5, SEMAPHORE=1.0",
      "matrix_job - ELIXIR=1.2, ERLANG=1.5, SEMAPHORE=2.0",
      "matrix_job - ELIXIR=1.2, ERLANG=1.5, SEMAPHORE=3.0",
      "matrix_job - ELIXIR=1.2, ERLANG=1.6, SEMAPHORE=1.0",
      "matrix_job - ELIXIR=1.2, ERLANG=1.6, SEMAPHORE=2.0",
      "matrix_job - ELIXIR=1.2, ERLANG=1.6, SEMAPHORE=3.0"
    ] == topology.after_pipeline.jobs
  end

  test "describe_topology() for after_pipeline returns error if matrix is malformed" do
    matrix1 = %{"env_var" => "ELIXIR", "values" => []}
    job1 = %{"name" => "matrix_job", "matrix" => [matrix1]}
    build1 = %{"jobs" => [job1]}
    after_pipeline = %{"name" => "after_ppl", "build" => build1}
    definition = %{"blocks" => [after_pipeline], "after_pipeline" => [after_pipeline]}

    assert {:error, msg} = Actions.describe_topology(definition)
    assert msg == {:malformed, "List 'values' in job matrix must not be empty."}
  end


  test "describe_topology() returns empty array" do
    assert {:ok, topology} = nil |> Actions.describe_topology()
    assert %{after_pipeline: %{jobs: []}, blocks: []} == topology
  end

  test "describe_topology() returns array of blocks" do
    assert {:ok, topology} = definition_map() |> Actions.describe_topology()
    assert [
      %{name: "block1", jobs: ["job1", "job2"], dependencies: nil},
      %{name: "block2", jobs: ["job3"],  dependencies: nil}
    ] == topology.blocks
  end

  defp definition_map() do
    job1 = %{"name" => "job1", "commands" => ["echo foo"]}
    job2 = %{"name" => "job2", "commands" => ["echo baz"]}
    job3 = %{"name" => "job3", "cmd_file" => "some_file.sh"}

    after_ppl_jobs = [
      %{"name" => "after_ppl_job_b", "commands" => ["echo im after ppl job #b"]},
      %{"name" => "after_ppl_job_a", "commands" => ["echo im after ppl job #a"]}
    ]

    build1 = %{"jobs" => [job1, job2]}
    build2 = %{"jobs" => [job3]}
    block1 = %{"name" => "block1", "build" => build1}
    block2 = %{"name" => "block2", "build" => build2}
    blocks = [block1, block2]

    after_pipeline =  [%{"name" => "after_ppl", "build" => %{"jobs" => after_ppl_jobs}}]

    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    %{"version" => "v3.0", "agent" => agent, "blocks" => blocks, "after_pipeline" => after_pipeline}
  end

  test "describe_topology() returns boosters jobs" do
    assert {:ok, topology} = boosters_definition_map() |> Actions.describe_topology()
    assert [
      %{name: "block1", dependencies: nil, jobs: ["boost rspec1", "boost rspec2", "boost cucumber1"]}
    ] == topology.blocks
  end

  defp boosters_definition_map() do
    booster1 = %{"job_count" => 2, "name" => "boost", "type" => "rspec"}
    booster2 = %{"job_count" => 1, "name" => "boost", "type" => "cucumber"}
    build1 = %{"jobs" => [], "boosters" => [booster1, booster2]}
    block1 = %{"name" => "block1", "build" => build1}
    %{"blocks" => [block1]}
  end

  test "describe_topology() returns matrix jobs" do
    assert {:ok, topology} = matrix_definition_map() |> Actions.describe_topology()
    assert [
      %{name: "block1",
        dependencies: nil,
        jobs: [
          "matrix_job - ELIXIR=1.1, ERLANG=1.5, SEMAPHORE=1.0",
          "matrix_job - ELIXIR=1.1, ERLANG=1.5, SEMAPHORE=2.0",
          "matrix_job - ELIXIR=1.1, ERLANG=1.5, SEMAPHORE=3.0",
          "matrix_job - ELIXIR=1.1, ERLANG=1.6, SEMAPHORE=1.0",
          "matrix_job - ELIXIR=1.1, ERLANG=1.6, SEMAPHORE=2.0",
          "matrix_job - ELIXIR=1.1, ERLANG=1.6, SEMAPHORE=3.0",
          "matrix_job - ELIXIR=1.2, ERLANG=1.5, SEMAPHORE=1.0",
          "matrix_job - ELIXIR=1.2, ERLANG=1.5, SEMAPHORE=2.0",
          "matrix_job - ELIXIR=1.2, ERLANG=1.5, SEMAPHORE=3.0",
          "matrix_job - ELIXIR=1.2, ERLANG=1.6, SEMAPHORE=1.0",
          "matrix_job - ELIXIR=1.2, ERLANG=1.6, SEMAPHORE=2.0",
          "matrix_job - ELIXIR=1.2, ERLANG=1.6, SEMAPHORE=3.0"
        ]}
    ] == topology.blocks
  end

  defp matrix_definition_map() do
    definition = %{}
    matrix1 = %{"env_var" => "ELIXIR", "values" => [1.1, 1.2]}
    matrix2 = %{"env_var" => "ERLANG", "values" => [1.5, 1.6]}
    matrix3 = %{"software" => "SEMAPHORE", "versions" => [1.0, 2.0, 3.0]}
    job1 = %{"name" => "matrix_job", "matrix" => [matrix1, matrix2, matrix3]}
    build1 = %{"jobs" => [job1]}
    block1 = %{"name" => "block1", "build" => build1}

    definition = definition
    |> Map.put("blocks", [block1])

    matrix1 = %{"env_var" => "ELIXIR", "values" => [1.1, 1.2]}
    matrix2 = %{"env_var" => "ERLANG", "values" => [1.5, 1.6]}
    matrix3 = %{"software" => "SEMAPHORE", "versions" => [1.0, 2.0, 3.0]}
    job1 = %{"name" => "matrix_job", "matrix" => [matrix1, matrix2, matrix3]}
    build1 = %{"jobs" => [job1]}
    after_pipeline = %{"name" => "after_pipeline", "build" => build1}

    definition
    |> Map.put("after_pipeline", [after_pipeline])
  end

  test "describe_topology() returns error if matrix is malformed" do
    matrix1 = %{"env_var" => "ELIXIR", "values" => []}
    job1 = %{"name" => "matrix_job", "matrix" => [matrix1]}
    build1 = %{"jobs" => [job1]}
    block1 = %{"name" => "block1", "build" => build1}
    definition = %{"blocks" => [block1]}

    assert {:error, msg} = Actions.describe_topology(definition)
    assert msg == {:malformed, "List 'values' in job matrix must not be empty."}
  end

  test "describe_topology() all types of jobs" do
    assert {:ok, topology} = all_types_definition_map() |> Actions.describe_topology()
    assert [
      %{name: "block1",
        dependencies: nil,
        jobs: [
          "job1",
          "matrix_job - ELIXIR=1.1",
          "matrix_job - ELIXIR=1.2",
          "boost rspec1"
        ]}
    ] == topology.blocks

    assert [
      "job1",
      "matrix_job - ELIXIR=1.1",
      "matrix_job - ELIXIR=1.2",
    ] == topology.after_pipeline.jobs
  end

  defp all_types_definition_map() do
    definition = %{}
    job1 = %{"name" => "job1", "commands" => ["echo foo"]}
    booster1 = %{"job_count" => 1, "name" => "boost", "type" => "rspec"}
    matrix1 = %{"env_var" => "ELIXIR", "values" => [1.1, 1.2]}
    job2 = %{"name" => "matrix_job", "matrix" => [matrix1]}
    build1 = %{"jobs" => [job1, job2], "boosters" => [booster1]}
    block1 = %{"name" => "block1", "build" => build1}

    definition = definition
    |> Map.put("blocks", [block1])

    job1 = %{"name" => "job1", "commands" => ["echo foo"]}
    matrix1 = %{"env_var" => "ELIXIR", "values" => [1.1, 1.2]}
    job2 = %{"name" => "matrix_job", "matrix" => [matrix1]}
    build1 = %{"jobs" => [job1, job2]}
    after_pipeline = %{"name" => "after_ppl", "build" => build1}

    definition
    |> Map.put("after_pipeline", [after_pipeline])
  end

  @tag :integration
  test "schedule() limit exceeded" do
    old_env = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "2")
    args = %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml",
             "project_id" => "123", "branch_id" => "456", "owner" => "psr"}
    #First pipeline
    assert {:ok, %{ppl_id: ppl_id}} =
      args
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

      loopers = start_loopers()
      {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "queuing", 5_000)
      stop_loopers(loopers)

    #Second
    assert {:ok, %{ppl_id: ppl_id}} =
      args
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

      loopers = start_loopers()
      {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "queuing", 5_000)
      stop_loopers(loopers)

    #Third
    assert {:limit, msg} =
      args
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

     assert msg == "Limit of queuing pipelines reached"
     System.put_env("PPL_QUEUE_LIMIT", old_env)
  end


  defp start_loopers() do
    []
    # Ppls loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    # PplSubInits loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn {:ok, pid} -> GenServer.stop(pid) end)
  end

  test "schedule() returns error when request has invalid args" do
    # No request_token field
    invalid_args_1 =
      %{"service" => "local", "repo_name" => "2_basic", "owner" => "rt",
        "label" => "master", "project_id" => "123", "branch_name" => "master"}

    invalid_args_1 |> Actions.schedule() |> assert_schedule_fail()
  end

  test "schedule(request, true, true) is idempotent in regard to request_token ", ctx do
  # Two top level ppl schedule requests with same request_token
  ppl_1_id = ctx.request_args |> Actions.schedule(true, true) |> assert_schedule_success()
  ppl_2_id = ctx.request_args |> Actions.schedule(true, true) |> assert_schedule_success()
  assert(ppl_1_id == ppl_2_id)

  assert {:ok, ppl_req_1} = PplRequestsQueries.get_by_id(ppl_1_id)
  assert {:ok, ppl_req_2} = PplRequestsQueries.get_by_id(ppl_2_id)
  assert ppl_req_1.inserted_at == ppl_req_2.inserted_at

  assert {:ok, ppl_1} = PplsQueries.get_by_id(ppl_1_id)
  assert {:ok, ppl_2} = PplsQueries.get_by_id(ppl_2_id)
  assert ppl_1.inserted_at == ppl_2.inserted_at
  assert ppl_1.id == ppl_2.id

  import Ecto.Query
  alias Ppl.EctoRepo, as: Repo

  assert(
    from(p in Ppls, where: p.ppl_id == ^ppl_1_id)
    |> Repo.all()
    |> Enum.count() == 1
  )
end

  defp assert_schedule_fail(response) do
    assert {:error, :ppl_req, %Ecto.Changeset{valid?: false}, _} = response
  end

  # Delete

  test "delete_request is stored" do
    args_1 = %{"project_id" => "1"}  |> Test.Helpers.schedule_request_factory(:local)
    assert {:ok, %{ppl_id: _ppl_id_1}} = Actions.schedule(args_1)

    assert {:ok, message} = Actions.delete({:ok, %{project_id: "1", requester: "user"}})
    assert message == "Pipelines from given project are scheduled for deletion."

    assert {:ok, true} == DeleteRequestsQueries.project_deletion_requested?("1")
  end

  # Terminate

  test "terminate test - initializing pipeline", ctx do
    test_termination_in_state(ctx, "initializing")
  end

  test "terminate test - pending pipeline", ctx do
    test_termination_in_state(ctx, "pending")
  end

  test "terminate test - running pipeline", ctx do
    test_termination_in_state(ctx, "running")
  end

  test "terminate test - stopping pipeline", ctx do
    test_termination_in_state(ctx, "stopping")
  end

  test "terminate test - done pipeline", ctx do
    test_termination_in_state(ctx, "done")
  end

  defp test_termination_in_state(ctx, state) do
    user_id = UUID.uuid4()
    ppl = prepare_ppl_in_state_for_test(ctx, state, user_id)

    assert {:ok, message} = Actions.terminate(%{"ppl_id" => ppl.id, "requester_id" => user_id})
    assert message == "Pipeline termination started."

    assert_event_terminated(ppl.id, user_id, state)
  end

  def ppl_query_params() do
    %{initial_query: Ppl.Ppls.Model.Ppls, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.Ppls.Model.Ppls, returning: [:id, :ppl_id],
      allowed_states: ~w(initializing pending running stopping done)}
  end

  def ppl_to_state(ppl, state, additional \\ %{})
  def ppl_to_state(ppl, "running", additional) do
    args = ppl_query_params()
    assert {:ok, _} = Ppl.Ppls.STMHandler.QueuingState.scheduling_handler(ppl)
    Looper.STM.Impl.exit_scheduling(ppl, fn _, _ -> {:ok, Map.merge(additional, %{state: "running"})} end, args)
    PplsQueries.get_by_id(ppl.ppl_id)
  end
  def ppl_to_state(ppl, state, additional) do
    args = ppl_query_params()
    Looper.STM.Impl.exit_scheduling(ppl, fn _, _ -> {:ok, Map.merge(additional, %{state: state})} end, args)
    PplsQueries.get_by_id(ppl.ppl_id)
  end

  def ppl_blk_query_params() do
    %{initial_query: Ppl.PplBlocks.Model.PplBlocks, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.PplBlocks.Model.PplBlocks, returning: [:id, :ppl_id],
      allowed_states: ~w(waiting running stopping done)}
  end

  def ppl_blk_to_state(ppl_blk, state, additional \\ %{})do
    args = ppl_blk_query_params()
    Looper.STM.Impl.exit_scheduling(ppl_blk, fn _, _ -> {:ok, Map.merge(additional, %{state: state})} end, args)
    PplBlocksQueries.get_by_id_and_index(ppl_blk.ppl_id, ppl_blk.block_index)
  end

  defp prepare_ppl_in_state_for_test(ctx, state, terminated_by) do
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(ctx.request_args)
    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    {:ok, ppl} = ppl |> Ppls.changeset(%{queue_id: "123"}) |> Repo.update()
    to_pending(ppl_req, ppl, ctx, state, terminated_by)
  end

  defp to_pending(ppl_req, _ppl, _ctx, "initializing", _terminated_by), do: ppl_req
  defp to_pending(ppl_req, ppl, ctx, state, terminated_by) do
    assert {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, ctx.definition)
    assert {:ok, ppl} = ppl_to_state(ppl, "pending")
    to_running(ppl_req, ppl, state, terminated_by)
  end

  defp to_running(ppl_req, _ppl, "pending", _terminated_by), do: ppl_req
  defp to_running(ppl_req, ppl, state, terminated_by) do
    assert {:ok, ppl} = ppl_to_state(ppl, "running")
    to_stopping(ppl_req, ppl, state, terminated_by)
  end

  defp to_stopping(ppl_req, _ppl, "running", _terminated_by), do: ppl_req
  defp to_stopping(ppl_req, ppl, state = "done", _terminated_by), do: to_done(ppl_req, ppl, state)
  defp to_stopping(ppl_req, ppl, _state, terminated_by) do
    additional = %{terminate_request: "stop", terminate_request_desc: "API call",
                   terminated_by: terminated_by}
    assert {:ok, _ppl} = ppl_to_state(ppl, "stopping", additional)
    ppl_req
  end

  defp to_done(ppl_req, ppl, _state) do
    assert {:ok, _ppl} = ppl_to_state(ppl, "done")
    ppl_req
  end

  defp assert_event_terminated(ppl_id, _terminated_by, "done") do
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl.state == "done"
    assert ppl.terminated_by == ""
  end
  defp assert_event_terminated(ppl_id, terminated_by, _state) do
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl.terminate_request == "stop"
    assert ppl.terminate_request_desc == "API call"
    assert ppl.terminated_by == terminated_by
  end

  test "list_ppls call with valid params returns {:ok, list_resp_params}" do
    ppls = Range.new(0, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params = %{project_id: "123", branch_name: "master", page: 1, page_size: 5}
    |> ListRequest.new()

    assert {:ok, response} = Actions.list_ppls(params)
    assert  %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 10, total_pages: 2} = response

    excluded = ppls |> Enum.slice(0..4)
    included = ppls |> Enum.slice(5..9)

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)
  end

  test "list_ppls returns total 0 when called with project_id or branch_name without ppls" do
    _ppls = Range.new(0, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params = %{project_id: "123", branch_name: "master", page: 1, page_size: 5}

    [:project_id, :label]
    |> Enum.map(fn field ->
        assert {:ok, response} = params
                                 |> Map.put(field, "wrong-value")
                                 |> ListRequest.new()
                                 |> Actions.list_ppls()

        assert %Scrivener.Page{entries: [], page_number: 1, page_size: 5,
                  total_entries: 0, total_pages: 1} == response
      end)
  end

  test "list_ppls returns error when called without project_id or wf_id" do
    params = %{branch_name: "master", page: 1, page_size: 5}

    assert {:error, message} = params |> ListRequest.new() |> Actions.list_ppls()
    assert message == "Either 'project_id' or 'wf_id' parameters are required."
  end

  test "list_ppls sets default values for page and page_size if they are omitted" do
    _ppls = Range.new(0, 34) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params = %{project_id: "123", branch_name: "master", page: 2, page_size: 5}

    assert {:ok, response} =
       params |> Map.delete(:page) |> ListRequest.new() |> Actions.list_ppls()

    assert  %{entries: _ppls, page_number: 1, page_size: 5,
                            total_entries: 35, total_pages: 7} = response

    assert {:ok, response} =
       params |> Map.delete(:page_size) |> ListRequest.new() |> Actions.list_ppls()

    assert  %{entries: _ppls, page_number: 2, page_size: 30,
                            total_entries: 35, total_pages: 2} = response
  end

  test "list_ppls uses optimized queries only when it is possible" do
    ppls = Range.new(0, 4) |> Enum.map(fn index -> insert_new_ppl(index) end)

    timestamp = DateTime.utc_now()

    ppls2 = Range.new(5, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)
    ppls = ppls ++ ppls2

    ppls3 = Range.new(10, 12) |> Enum.map(fn index -> insert_new_ppl(index, true) end)
    ppls = ppls ++ ppls3

    timestamp2 = DateTime.utc_now()

    ppls4 = Range.new(13, 14) |> Enum.map(fn index -> insert_new_ppl(index, true) end)
    ppls = ppls ++ ppls4

    with_mock PplsQueries, [:passthrough], [list_ppls: &(mocked_list(&1, &2, &3))] do
      # use unoptimized list when necessarry

      params = %{project_id: "123", git_ref_types: [0], page: 1, page_size: 5}
      |> ListRequest.new()

      assert {:error, "Using unoptimized list ppls query."}
              = Actions.list_ppls(params)

      # only project_id

      params = %{project_id: "123", page: 1, page_size: 5}
      |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 15, total_pages: 3}} = Actions.list_ppls(params)

      excluded = ppls |> Enum.slice(0..9)
      included = ppls |> Enum.slice(10..14)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id and branch_name

      params = %{project_id: "123", branch_name: "master", page: 1, page_size: 5}
      |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 10, total_pages: 2}} = Actions.list_ppls(params)

      excluded = Enum.slice(ppls, 0..4) ++ Enum.slice(ppls, 10..14)
      included = ppls |> Enum.slice(5..9)
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, branch_name and yml_file_path

      params =
        %{project_id: "123", branch_name: "master", page: 1, page_size: 5,
           yml_file_path: ".semaphore/semaphore.yml"}
          |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 10, total_pages: 2}} = Actions.list_ppls(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, branch_name and yml_file_path, created_before

      params =
        %{project_id: "123", branch_name: "master", page: 1, page_size: 3,
           yml_file_path: ".semaphore/semaphore.yml", created_before: timestamp}
          |> Proto.deep_new!(
              ListRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 3,
              total_entries: 5, total_pages: 2}} = Actions.list_ppls(params)

      excluded = Enum.slice(ppls, 0..1) ++ Enum.slice(ppls, 5..9)
      included = ppls |> Enum.slice(2..4)
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, branch_name and yml_file_path, created_after

      params =
        %{project_id: "123", branch_name: "master", page: 1, page_size: 3,
           yml_file_path: ".semaphore/semaphore.yml", created_after: timestamp}
          |> Proto.deep_new!(
              ListRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 3,
              total_entries: 5, total_pages: 2}} = Actions.list_ppls(params)

      excluded = ppls |> Enum.slice(0..6)
      included = ppls |> Enum.slice(7..9)
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id and pr_target_branch

      params = %{project_id: "123", pr_target_branch: "pr_base", page: 1, page_size: 5}
      |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 5, total_pages: 1}} = Actions.list_ppls(params)

      excluded = Enum.slice(ppls, 0..9)
      included = ppls |> Enum.slice(10..14)
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id and pr_head_branch

      params = %{project_id: "123", pr_head_branch: "pr_head", page: 1, page_size: 5}
      |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 5, total_pages: 1}} = Actions.list_ppls(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_target_branch, and yml_file_path

      params = %{project_id: "123", pr_target_branch: "pr_base", page: 1, page_size: 5,
                 yml_file_path: ".semaphore/semaphore.yml"}
                |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
              total_entries: 2, total_pages: 1}} = Actions.list_ppls(params)

      excluded = Enum.slice(ppls, 0..9) ++ [Enum.at(ppls, 10), Enum.at(ppls, 12), Enum.at(ppls, 14)]
      included = [Enum.at(ppls, 11), Enum.at(ppls, 13)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_head_branch, and yml_file_path

      params = %{project_id: "123", pr_head_branch: "pr_head", page: 1, page_size: 5,
      yml_file_path: ".semaphore/semaphore.yml"}
     |> ListRequest.new()

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 5,
        total_entries: 2, total_pages: 1}} = Actions.list_ppls(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_target_branch, yml_file_path, and created_before

      params =
        %{project_id: "123", pr_target_branch: "pr_base", page: 1, page_size: 3,
           yml_file_path: ".semaphore/semaphore.yml", created_before: timestamp2}
          |> Proto.deep_new!(
              ListRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 3,
              total_entries: 1, total_pages: 1}} = Actions.list_ppls(params)

      excluded = Enum.slice(ppls, 0..10) ++ Enum.slice(ppls, 12..14)
      included = [Enum.at(ppls, 11)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_head_branch, yml_file_path, and created_before

      params =
        %{project_id: "123", pr_head_branch: "pr_head", page: 1, page_size: 3,
           yml_file_path: ".semaphore/semaphore.yml", created_before: timestamp2}
          |> Proto.deep_new!(
              ListRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 3,
              total_entries: 1, total_pages: 1}} = Actions.list_ppls(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_target_branch, yml_file_path, and created_after

      params =
        %{project_id: "123", pr_target_branch: "pr_base", page: 1, page_size: 3,
           yml_file_path: ".semaphore/semaphore.yml", created_after: timestamp2}
          |> Proto.deep_new!(
              ListRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 3,
              total_entries: 1, total_pages: 1}} = Actions.list_ppls(params)

      excluded =  Enum.slice(ppls, 0..12) ++ [Enum.at(ppls, 14)]
      included = [Enum.at(ppls, 13)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_head_branch, yml_file_path, and created_after

      params =
        %{project_id: "123", pr_head_branch: "pr_head", page: 1, page_size: 3,
           yml_file_path: ".semaphore/semaphore.yml", created_after: timestamp2}
          |> Proto.deep_new!(
              ListRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{entries: pipelines, page_number: 1, page_size: 3,
              total_entries: 1, total_pages: 1}} = Actions.list_ppls(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)
    end
  end

  test "list_keyset uses optimized queries only when it is possible" do
    ppls = Range.new(0, 2) |> Enum.map(fn index -> insert_new_ppl(index, true) end)

    timestamp = DateTime.utc_now()

    ppls2 = Range.new(3, 12) |> Enum.map(fn index -> insert_new_ppl(index, true) end)
    ppls = ppls ++ ppls2

    timestamp2 = DateTime.utc_now()

    ppls3 = Range.new(13, 14) |> Enum.map(fn index -> insert_new_ppl(index, true) end)
    ppls = ppls ++ ppls3

    with_mock PplsQueries, [:passthrough], [list_keyset: &(mocked_list(&1, &2))] do
      # use unoptimized list when necessarry

      params = %{project_id: "123", git_ref_types: [0, 1], page_token: "", page_size: 5}
      |> ListKeysetRequest.new()

      assert {:error, "Using unoptimized list_keyset ppls query."}
              = Actions.list_keyset(params)

      # only project_id

      params = %{project_id: "123", page_token: "", page_size: 5}
      |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = ppls |> Enum.slice(0..9)
      included = ppls |> Enum.slice(10..14)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, label and single git_ref_type value

      params = %{project_id: "123", label: "master", page_token: "", page_size: 10,
                 git_ref_types: [0]} |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      included = Enum.slice(ppls, 0..4)
      excluded = Enum.slice(ppls, 5..14)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, label, single git_ref_type value and yml_file_path

      params = %{project_id: "123", label: "master", page_token: "", page_size: 10,
                 git_ref_types: [0], yml_file_path: ".semaphore/deploy.yml"}
                 |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      included = [Enum.at(ppls, 0), Enum.at(ppls, 2), Enum.at(ppls, 4)]
      excluded = [Enum.at(ppls, 1), Enum.at(ppls, 3)] ++ Enum.slice(ppls, 5..14)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, label, single git_ref_type value, yml_file_path and created_before

      params =
        %{project_id: "123", label: "master", page_token: "", page_size: 10,
          git_ref_types: [0], yml_file_path: ".semaphore/deploy.yml",
          created_before: timestamp}
          |> Proto.deep_new!(
              ListKeysetRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = Enum.slice(ppls, 0..1) ++ Enum.slice(ppls, 3..14)
      included = [Enum.at(ppls, 2)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, label, single git_ref_type value, yml_file_path and created_after

      params =
        %{project_id: "123", label: "master", page_token: "", page_size: 10,
          git_ref_types: [0], yml_file_path: ".semaphore/deploy.yml",
          created_after: timestamp}
          |> Proto.deep_new!(
              ListKeysetRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = Enum.slice(ppls, 0..3) ++ Enum.slice(ppls, 5..14)
      included = [Enum.at(ppls, 4)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id and pr_target_branch

      params =
        %{project_id: "123", pr_target_branch: "pr_base", page_token: "", page_size: 10}
        |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = Enum.slice(ppls, 0..9)
      included = Enum.slice(ppls, 10..14)
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id and pr_head_branch

      params =
        %{project_id: "123", pr_head_branch: "pr_head", page_token: "", page_size: 10}
        |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_target_branch, and yml_file_path

      params =
        %{project_id: "123", pr_target_branch: "pr_base", page_token: "", page_size: 10,
          yml_file_path: ".semaphore/deploy.yml"}
        |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = Enum.slice(ppls, 0..9) ++ [Enum.at(ppls, 11), Enum.at(ppls, 13)]
      included = [Enum.at(ppls, 10), Enum.at(ppls, 12), Enum.at(ppls, 14)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_head_branch, and yml_file_path

      params =
        %{project_id: "123", pr_head_branch: "pr_head", page_token: "", page_size: 10,
          yml_file_path: ".semaphore/deploy.yml"}
        |> ListKeysetRequest.new()

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_target_branch, yml_file_path, and created_before

      params =
        %{project_id: "123", pr_target_branch: "pr_base", page_token: "", page_size: 10,
          yml_file_path: ".semaphore/deploy.yml", created_before: timestamp2}
          |> Proto.deep_new!(
              ListKeysetRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = Enum.slice(ppls, 0..9) ++ [Enum.at(ppls, 11), Enum.at(ppls, 13), Enum.at(ppls, 14)]
      included = [Enum.at(ppls, 10), Enum.at(ppls, 12)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_head_branch, yml_file_path, and created_before

      params =
        %{project_id: "123", pr_head_branch: "pr_head", page_token: "", page_size: 10,
          yml_file_path: ".semaphore/deploy.yml", created_before: timestamp2}
          |> Proto.deep_new!(
              ListKeysetRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_target_branch, yml_file_path, and created_after

      params =
        %{project_id: "123", pr_target_branch: "pr_base", page_token: "", page_size: 10,
          yml_file_path: ".semaphore/deploy.yml", created_after: timestamp2}
          |> Proto.deep_new!(
              ListKeysetRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      excluded = Enum.slice(ppls, 0..13)
      included = [Enum.at(ppls, 14)]
      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

      # project_id, pr_head_branch, yml_file_path, and created_after

      params =
        %{project_id: "123", pr_head_branch: "pr_head", page_token: "", page_size: 10,
          yml_file_path: ".semaphore/deploy.yml", created_after: timestamp2}
          |> Proto.deep_new!(
              ListKeysetRequest,
              transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
            )

      assert  {:ok, %{pipelines: pipelines, next_page_token: _n_token,
                      previous_page_token: ""}} = Actions.list_keyset(params)

      assert list_result_contains?(pipelines, included)
      refute list_result_contains?(pipelines, excluded)

    end
  end

  def mocked_list(_, _), do: {:error, "Using unoptimized list_keyset ppls query."}
  def mocked_list(_, _, _), do: {:error, "Using unoptimized list ppls query."}

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}
  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  defp insert_new_ppl(index, diff_refs \\ false) do
    request_args =
      %{
        "branch_name" => (if diff_refs, do: branch_name(index), else: "master"),
        "commit_sha" => "sha" <> Integer.to_string(index),
        "project_id" => "123",
        "label" => (if diff_refs, do: label(index), else: "master"),
        "organization_id" => "abc",
        "file_name" => (if diff_refs, do: file_name(index), else: "semaphore.yml"),
        "working_dir" => ".semaphore",
      }
      |> Test.Helpers.schedule_request_factory(:local)

    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)

    source_args =
      %{
        git_ref_type: ref_type(index),
        pr_branch_name: pr_branch_name(index),
        branch_name: source_branch(index)
      }
      |> Test.Helpers.source_request_factory()

    assert {:ok, ppl_req} = PplRequestsQueries.insert_source(ppl_req, source_args)

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)
    ppl
  end

  defp label(ind) when ind < 5, do: "master"
  defp label(ind) when ind < 10, do: "v1.0.2"
  defp label(_ind), do: "123"

  defp branch_name(ind) when ind < 5, do: "master"
  defp branch_name(ind) when ind < 10, do: "refs/tags/v1.0.2"
  defp branch_name(_ind), do: "pull-request-123"

  defp file_name(ind) when rem(ind, 2) == 1, do: "semaphore.yml"
  defp file_name(_ind), do: "deploy.yml"

  defp ref_type(ind) when ind < 5, do: "branch"
  defp ref_type(ind) when ind < 10, do: "tag"
  defp ref_type(_ind), do: "pr"

  defp source_branch(ind) when ind < 10, do: "master"
  defp source_branch(_ind), do: "pr_base"

  defp pr_branch_name(ind) when ind < 10, do: ""
  defp pr_branch_name(_ind), do: "pr_head"

  defp list_result_contains?(results, ppls) do
    Enum.reduce(ppls, true, fn ppl, acc ->
        case acc do
          false -> false
          true -> ppl_id_in_results?(ppl.ppl_id, results)
        end
      end)
  end

  defp ppl_id_in_results?(ppl_id, results) do
    Enum.find(results, nil, fn ppl ->
      assert_all_fields_are_filled(ppl)
      ppl.ppl_id == ppl_id
    end) != nil
  end

  defp assert_all_fields_are_filled(ppl) do
    assert {:ok, _} = UUID.info(ppl.ppl_id)
    assert ppl.name != ""
    assert ppl.project_id == "123"
    assert ppl.branch_name in ["master", "refs/tags/v1.0.2", "pull-request-123"]
    assert ppl.commit_sha |> String.starts_with?("sha")
    assert is_date_time(ppl.created_at) or is_nil(ppl.created_at)
    assert is_date_time(ppl.pending_at) or is_nil(ppl.pending_at)
    assert is_date_time(ppl.queuing_at) or is_nil(ppl.queuing_at)
    assert is_date_time(ppl.running_at) or is_nil(ppl.running_at)
    assert is_date_time(ppl.stopping_at) or is_nil(ppl.stopping_at)
    assert is_date_time(ppl.done_at) or is_nil(ppl.done_at)
    assert ppl.state in ~w(initializing pending queueing running stopping done)
    assert is_nil(ppl.result) or ppl.result in ~w(passed failed stopped canceled)
    assert is_nil(ppl.result_reason)
           or ppl.result_reason in  ~w(test malformed stuck user internal strategy fast_failing deleted)
    assert ppl.terminate_request == ""
    assert {:ok, _} = UUID.info(ppl.hook_id)
    assert {:ok, _} = UUID.info(ppl.branch_id)
  end

  defp is_date_time(%DateTime{}), do: true
  defp is_date_time(_), do: false


  @tag :integration
  test "describe call for existing ppl in all states", ctx do

    # Initializing state

    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(ctx.request_args)
    assert {:ok, ppl = %Ppls{state: "initializing"}} = PplsQueries.insert(ppl_req)
    assert {:ok, _trace} = PplTracesQueries.insert(ppl)

    %{ppl_id: ppl_req.id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "Pipeline", "initializing")

    # Done-failed - no PplBlocks

    assert {:ok, _ppl_trace} = PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
    assert {:ok, ppl} = ppl_to_state(ppl, "done", %{result: "failed", result_reason: "malformed"})


    %{ppl_id: ppl_req.id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "Pipeline", "done", "failed", "malformed")

    # Pending state

    ppl_id = :local
             |> Test.Helpers.schedule_request_factory()
             |> Actions.schedule()
             |> assert_schedule_success()

    loopers = []
              |> Test.Helpers.start_sub_init_loopers()
              |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])

    {:ok, _ppl_desc} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 5_000)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    %{ppl_id: ppl_id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "basic test", "pending")

    # Queuing state

    loopers = loopers |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])

    {:ok, _ppl_desc} = Test.Helpers.wait_for_ppl_state(ppl_id, "queuing", 5_000)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    %{ppl_id: ppl_id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "basic test", "queuing")

    # Running state
    loopers = loopers
            |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
            |> Test.Helpers.start_ppl_block_loopers()
            |> Test.Helpers.start_block_loopers()

    {:ok, _ppl_desc} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 5_000)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    :timer.sleep(3_000)

    %{ppl_id: ppl_id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "basic test", "running")

    # Stopping state
    assert {:ok, _} = %{"ppl_id" => ppl_id, "requester_id" => "user1"} |> Actions.terminate()

    loopers = loopers |> Enum.concat([Ppl.Ppls.STMHandler.RunningState.start_link()])

    {:ok, _ppl_desc} = Test.Helpers.wait_for_ppl_state(ppl_id, "stopping", 5_000)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    %{ppl_id: ppl_id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "basic test", "stopping", nil, nil, "stop")

    # Done state with blocks desc
    loopers = loopers |> Enum.concat([Ppl.Ppls.STMHandler.StoppingState.start_link()])

    {:ok, _ppl_desc} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 5_000)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    %{ppl_id: ppl_id, detailed: true}
    |> Actions.describe()
    |> assert_describe_result(ppl, "basic test", "done", "stopped", "user", "stop")

    Test.Helpers.stop_all_loopers(loopers)
  end

  defp assert_describe_result(response, ppl, name, state, result \\ nil, reason \\ nil, terminate_request \\ "") do
    ppl_desc = ppl_description(ppl, name, state, result, reason, terminate_request)

    assert {:ok, resp_ppl, resp_blocks} = response
    assert Map.take(resp_ppl, Map.keys(ppl_desc)) == ppl_desc
    assert_blocks_desc_valid(resp_blocks, state, reason)
  end

  defp ppl_description(ppl, name, state, result, reason, terminate_request) do
    %{
      ppl_id: ppl.ppl_id,
      name: name,
      project_id: ppl.project_id,
      branch_name: ppl.branch_name,
      commit_sha: ppl.commit_sha,
      state: state,
      result: result,
      result_reason: reason,
      terminate_request: terminate_request
    }
  end

  defp assert_blocks_desc_valid(block_desc, "initializing", _) do
    assert [] == block_desc
  end
  defp assert_blocks_desc_valid(block_desc, "done", "malformed"), do: assert [] == block_desc
  defp assert_blocks_desc_valid(block_desc, state, _)  when state in ["pending", "queuing"] do
    assert [%{block_id: "", build_req_id: "", jobs: [], name: "Nameless block 1",
            result: nil, result_reason: nil, state: "initializing",
            error_description: ""}] == block_desc
  end
  defp assert_blocks_desc_valid(block_desc, state, _) when state in ["running", "stopping", "done"] do
    assert [%{block_id: b_id, build_req_id: br_id, jobs: jobs, name: "Nameless block 1",
              result: "passed", result_reason: nil, state: "done",
              error_description: ""}] = block_desc
    assert {:ok, _} = UUID.info(b_id)
    assert {:ok, _} = UUID.info(br_id)
    assert [%{index: 0, job_id: j_id, name: "Nameless 1",
              result: "PASSED", status: "FINISHED"}] = jobs
    assert {:ok, _} = UUID.info(j_id)
  end
end
