defmodule Ppl.Grpc.Server.Test do
  use Ppl.IntegrationCase
  @moduletag capture_log: true
  import Mock
  alias Test.Helpers
  alias Util.{ToTuple, Proto}
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Queues.Model.{Queues, QueuesQueries}
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias InternalApi.Plumber.Pipeline.{State, Result, ResultReason}
  alias Google.Protobuf.Timestamp

  alias InternalApi.Plumber.{
    VersionRequest,
    PipelineService,
    ValidateYamlRequest,
    TerminateRequest,
    DescribeRequest,
    ListRequest,
    GetProjectIdRequest,
    DescribeTopologyRequest,
    ScheduleExtensionRequest,
    DescribeManyRequest,
    PartialRebuildRequest,
    DeleteRequest,
    ListQueuesRequest,
    ListGroupedRequest,
    ListActivityRequest,
    ListKeysetRequest,
    ListRequestersRequest,
    Triggerer
  }

  alias Ppl.Actions
  alias Ppl.Grpc.InFlightCounter
  alias Test.Support.WorkflowBuilder

  setup do
    Test.Helpers.truncate_db()

    urls = %{workflow_service: "localhost:50053", plumber_service: "localhost:50053"}
    start_supervised!({WorkflowBuilder.Impl, urls})
    :ok
  end

  # Version

  test "server availability by calling version() rpc" do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    request = VersionRequest.new()
    response = channel |> PipelineService.Stub.version(request)
    assert {:ok, version_response} = response
    assert Map.get(version_response, :version) == Mix.Project.config()[:version]
  end

  defp code(:ok), do: 0
  defp code(:error), do: 1
  defp code(:limit), do: 2
  defp code(:refused), do: 3

  # ValidateYaml

  test "gRPC validate_yaml() - only valid yaml definition passed" do
    yaml_definition = valid_definition()

    assert {message, _} = assert_validate_yaml(yaml_definition, "", :ok, false)
    assert message == "YAML definition is valid."
  end

  test "gRPC validate_yaml() - only invalid yaml definition passed" do
    yaml_definition = invalid_definition()

    assert {message, _} = assert_validate_yaml(yaml_definition, "", :error, false)
    assert String.contains?(message, "Type mismatch. Expected Object but got Null")
    assert String.contains?(message, "blocks/0/task")
  end

  test "gRPC validate_yaml() -  valid yaml definition, refuse ppls scheduling if project deletion was requested" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "project_id" => "to-delete"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, message} = delete_ppls_from_project("to-delete")
    assert message == "Pipelines from given project are scheduled for deletion."

    yaml_definition = valid_definition()

    assert {message, _} = assert_validate_yaml(yaml_definition, ppl_id, :refused, false)
    assert message == "Project with id to-delete was deleted."
  end

  test "gRPC validate_yaml() - valid yaml definition, ppl scheduled" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    yaml_definition = valid_definition()

    assert {message, _} = assert_validate_yaml(yaml_definition, ppl_id, :ok, true)
    assert message == "YAML definition is valid."
  end

  test "gRPC validate_yaml() - invalid yaml definition, ppl is not scheduled" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    yaml_definition = invalid_definition()

    assert {message, _} = assert_validate_yaml(yaml_definition, ppl_id, :error, false)
    assert String.contains?(message, "Type mismatch. Expected Object but got Null")
    assert String.contains?(message, "blocks/0/task")
  end

  @tag :integration
  test "gRPC validate_yaml() - scheduled pipeline execution passed, origin data saved" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    test_valid_pipeline_description_passes(ppl_id)

    ppl_definition =
      "#{:code.priv_dir(:block)}/repos/5_v1_full/.semaphore/no_cmd_files.yml"
      |> File.read!()

    assert {:ok, ppl_or} = PplOriginsQueries.get_by_id(ppl_id)
    assert ppl_or.initial_request |> is_map()
    assert ppl_or.initial_definition == ppl_definition
  end

  defp valid_definition() do
    """
    version: "v1.0"
    name: basic test
    agent:
      machine:
        type: e1-standard-2
        os_image: ubuntu1804
    blocks:
      - task:
          jobs:
            - commands:
                - echo foo
    """
  end

  defp invalid_definition() do
    """
    version: "v1.0"
    name: basic test
    agent:
      machine:
        type: e1-standard-2
        os_image: ubuntu1804
    blocks:
      - task:
    """
  end

  defp assert_validate_yaml(yaml_definition, ppl_id_req, expected_status, ppl_id_resp_uuid) do
    request =
      %{yaml_definition: yaml_definition, ppl_id: ppl_id_req}
      |> ValidateYamlRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.validate_yaml(request)
    assert {:ok, validate_response} = response
    assert %{response_status: response_status} = validate_response
    assert is_uuid(Map.get(validate_response, :ppl_id)) == ppl_id_resp_uuid
    assert %{code: status_code, message: message} = response_status
    assert code(expected_status) == status_code
    {message, Map.get(validate_response, :ppl_id)}
  end

  defp is_uuid(value) do
    case UUID.info(value) do
      {:ok, _} -> true
      _ -> false
    end
  end

  # DescribeTopology

  @tag :integration
  test "gRPC describe_topology() - parallelism in jobs" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "27_parallelism"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = start_loopers_init()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 7_000)
    request = DescribeTopologyRequest.new(ppl_id: ppl_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    stop_loopers(loopers)

    assert {:ok, describe_topology_response} = response
    assert %{blocks: [%{jobs: jobs}]} = describe_topology_response
    assert ["Job 1 - 1/4", "Job 1 - 2/4", "Job 1 - 3/4", "Job 1 - 4/4"] = jobs

    check_status_code(describe_topology_response)
  end

  @tag :integration
  test "gRPC describe_topology() - with after_pipeline" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "30_after_ppl_test"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = start_loopers_init()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 7_000)
    request = DescribeTopologyRequest.new(ppl_id: ppl_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    stop_loopers(loopers)

    assert {:ok, describe_topology_response} = response

    assert %{after_pipeline: after_pipeline} = describe_topology_response

    assert %{jobs: jobs} = after_pipeline

    assert [
             "Hello",
             "Nameless 1",
             "With parallelism - 1/4",
             "With parallelism - 2/4",
             "With parallelism - 3/4",
             "With parallelism - 4/4",
             "With matrix - FOOS=foo#1, BARS=bar#1",
             "With matrix - FOOS=foo#1, BARS=bar#2",
             "With matrix - FOOS=foo#2, BARS=bar#1",
             "With matrix - FOOS=foo#2, BARS=bar#2",
             "With matrix - FOOS=foo#3, BARS=bar#1",
             "With matrix - FOOS=foo#3, BARS=bar#2"
           ] = jobs

    check_status_code(describe_topology_response)
  end

  @tag :integration
  test "gRPC describe_topology() - implicit dependencies" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = start_loopers_init()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 7_000)
    request = DescribeTopologyRequest.new(ppl_id: ppl_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    stop_loopers(loopers)

    assert {:ok, describe_topology_response} = response

    assert %{:blocks => [%{:dependencies => dl1}, %{:dependencies => dl2}]} =
             describe_topology_response

    check_deps(dl1, [])
    check_deps(dl2, ["Block 1"])
    check_status_code(describe_topology_response)
  end

  @tag :integration
  test "gRPC describe_topology() - explicit dependencies" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = start_loopers_init()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 7_000)

    request = DescribeTopologyRequest.new(ppl_id: ppl_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    stop_loopers(loopers)

    assert {:ok, describe_topology_response} = response

    assert %{
             :blocks => [
               %{:dependencies => dl_a},
               %{:dependencies => dl_b},
               %{:dependencies => dl_c},
               %{:dependencies => dl_d},
               %{:dependencies => dl_e}
             ]
           } = describe_topology_response

    check_deps(dl_a, [])
    check_deps(dl_b, ["A", "D"])
    check_deps(dl_c, ["B"])
    check_deps(dl_d, [])
    check_deps(dl_e, ["B"])
    check_status_code(describe_topology_response)
  end

  @tag :integration
  test "gRPC describe_topology() - malformed pipeline" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "12_failing_deps"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 5_000)

    request = DescribeTopologyRequest.new(ppl_id: ppl_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    Test.Helpers.stop_all_loopers(loopers)

    assert {:ok, describe_topology_response} = response
    assert %{:blocks => blc} = describe_topology_response
    assert List.first(blc) == nil
    check_status_code(describe_topology_response)
  end

  defp check_deps(deps_list, expected_list) do
    for blc <- expected_list, do: assert(Enum.member?(deps_list, blc))
  end

  defp check_status_code(describe_topology_response) do
    %{:status => %{code: status_code}} = describe_topology_response
    assert status_code == 0
  end

  defp start_loopers_init() do
    []
    # Ppls loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    # PplSubInits loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn {:ok, pid} -> GenServer.stop(pid) end)
  end

  test "gRPC describe_topology() - error when forming topology fails" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    matrix1 = %{"env_var" => "ELIXIR", "values" => []}
    job1 = %{"name" => "matrix_job", "matrix" => [matrix1]}
    build1 = %{"jobs" => [job1]}
    block1 = %{"name" => "block1", "build" => build1}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => [block1]}

    assert {:ok, req} = PplRequestsQueries.get_by_id(ppl_id)

    insert_definition(req, definition)

    request = DescribeTopologyRequest.new(ppl_id: ppl_id)
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    assert {:ok, describe_topology_response} = response
    %{:status => %{code: status_code, message: msg}} = describe_topology_response
    assert status_code == 1
    assert msg == "{:malformed, \"List 'values' in job matrix must not be empty.\"}"
  end

  test "gRPC describe_topology()" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, req} = PplRequestsQueries.get_by_id(ppl.ppl_id)

    insert_definition(req, valid_definition_map())

    describe_topology_response = assert_describe_topology(ppl_id, :ok)
    assert %{blocks: blocks, after_pipeline: after_pipeline} = describe_topology_response
    assert [%{jobs: ["job"], name: "block"}] = blocks
    assert %{jobs: []} = after_pipeline
  end

  test "gRPC describe_topology() - ppl_id not found" do
    assert_describe_topology(UUID.uuid4(), :error)
  end

  defp valid_definition_map() do
    job = %{"name" => "job"}
    build = %{"jobs" => [job]}
    block = %{"name" => "block", "build" => build}
    blocks = [block]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    %{"version" => "v3.0", "agent" => agent, "blocks" => blocks}
  end

  defp insert_definition(ppl_req, definition) do
    assert {:ok, _ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)
  end

  defp assert_describe_topology(ppl_id, expected_status) do
    request = %{ppl_id: ppl_id} |> DescribeTopologyRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe_topology(request)

    assert {:ok, describe_topology_response} = response
    assert %{status: status} = describe_topology_response
    assert %{code: status_code, message: _message} = status
    assert code(expected_status) == status_code

    describe_topology_response
  end

  # Delete
  @tag :integration
  test "gRPC delete() - deletes everything when given valid params" do
    {:ok, %{ppl_id: ppl_id_1}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml", "project_id" => "to-delete"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id_1, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert_describe_ppl_status(ppl_id_1, :ok)

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml", "project_id" => "to-delete"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id_2, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert_describe_ppl_status(ppl_id_2, :ok)

    assert {:ok, message} = delete_ppls_from_project("to-delete")
    assert message == "Pipelines from given project are scheduled for deletion."

    delete_loopers =
      []
      |> Enum.concat([Ppl.DeleteRequests.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.DeleteRequests.STMHandler.DeletingState.start_link()])
      |> Enum.concat([Ppl.DeleteRequests.STMHandler.QueueDeletingState.start_link()])

    :timer.sleep(3_000)

    assert_describe_ppl_status(ppl_id_1, :error)
    assert_describe_ppl_status(ppl_id_2, :error)

    Test.Helpers.stop_all_loopers(delete_loopers)
  end

  defp delete_ppls_from_project(project_id) do
    {:ok, request} = Proto.deep_new(DeleteRequest, %{project_id: project_id, requester: "sudo"})

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.delete(request)

    assert {:ok, delete_response} = response
    assert %{status: %{code: :OK, message: message}} = Proto.to_map!(delete_response)
    {:ok, message}
  end

  # Describe

  @tag :integration
  test "gRPC describe() - ppl_id not found" do
    assert_describe_ppl_status("does-not-exist", :error)
  end

  test "gRPC describe() - refuse request when there are to many unfinished ones" do
    old_desc = InFlightCounter.set_limit(:describe, 0)

    assert_describe_ppl_error(UUID.uuid4(), GRPC.Status.resource_exhausted())

    InFlightCounter.set_limit(:describe, old_desc)
  end

  @tag :integration
  test "gRPC describe(), detailed and regular - response_status.code = OK for scheduled ppl" do
    loopers = Test.Helpers.start_all_loopers()

    {:ok, %{ppl_id: v1_ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(v1_ppl_id, "done", 10_000)

    assert {ppl, _} = assert_describe_ppl_status(v1_ppl_id, :ok)
    assert assert_describe_ppl_status(v1_ppl_id, :ok, true)
    assert assert_ppl_triggerer(ppl)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "gRPC describe(), detailed - env vars are correctly mapped" do
    loopers = Test.Helpers.start_all_loopers()

    {:ok, %{ppl_id: v1_ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Map.put("env_vars", [%{"name" => "foo", "value" => "bar"}])
      |> Actions.schedule()

    assert {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(v1_ppl_id, "done", 10_000)

    assert {ppl, blocks} = assert_describe_ppl_status(v1_ppl_id, :ok, true)

    assert assert_ppl_triggerer(ppl)

    assert ppl.env_vars == [%InternalApi.Plumber.EnvVariable{name: "foo", value: "bar"}]

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "v1: gRPC describe() - pipeline execution passed, initial def saved" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    test_valid_pipeline_description_passes(ppl_id)

    assert_initial_definition_saved(ppl_id)
  end

  defp assert_initial_definition_saved(ppl_id) do
    path = "#{:code.priv_dir(:block)}/repos/5_v1_full/.semaphore/no_cmd_files.yml"
    {:ok, yaml_definition} = File.read(path)

    assert {:ok, ppl_or} = PplOriginsQueries.get_by_id(ppl_id)
    assert ppl_or.initial_request |> is_map()
    assert ppl_or.initial_definition == yaml_definition
  end

  defp assert_describe_ppl_error(ppl_id, expected_status, detailed \\ false) do
    request =
      %{ppl_id: ppl_id, detailed: detailed}
      |> DescribeRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    assert {:error, response} = channel |> PipelineService.Stub.describe(request)
    assert %{status: ^expected_status} = response
  end

  defp assert_describe_ppl_status(ppl_id, expected_status, detailed \\ false) do
    %{ppl_id: ppl_id, detailed: detailed}
    |> DescribeRequest.new()
    |> describe_ppl(expected_status)
  end

  defp assert_ppl_triggerer(ppl, is_map? \\ false) do
    cond do
      # describe_many/1, list_grouped/3, list_keyset/2 functions converts responses to map, this is a workaround to pattern match it's result
      is_map? ->
        triggerer_map = %Triggerer{}
        |> Map.drop([:__struct__])

        assert triggerer_map = ppl.triggerer
      true ->
        assert %Triggerer{} = ppl.triggerer
    end
  end

  defp describe_ppl(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.describe(request)

    assert {:ok, describe_response} = response

    assert %{pipeline: ppl, blocks: blocks, response_status: %{code: status_code}} =
             describe_response

    assert code(expected_status) == status_code
    {ppl, blocks}
  end

  defp test_valid_pipeline_description_passes(ppl_id) do
    loopers = Test.Helpers.start_all_loopers()
    args = [ppl_id, loopers]

    Helpers.assert_finished_for_less_than(__MODULE__, :ppl_describe_execution_done?, args, 30_000)
    ppl_id
  end

  def ppl_describe_execution_done?(ppl_id, loopers) do
    :timer.sleep(1_000)

    {ppl, _blocks} = assert_describe_ppl_status(ppl_id, :ok)
    state = ppl.state |> from_proto(:state)
    result = ppl.result |> from_proto(:result)
    ppl_describe_execution_done_(state, result, ppl_id, loopers)
  end

  defp ppl_describe_execution_done_("done", "passed", _ppl_id, loopers) do
    Test.Helpers.stop_all_loopers(loopers)
    :pass
  end

  defp ppl_describe_execution_done_(_state, _, ppl_id, loopers),
    do: ppl_describe_execution_done?(ppl_id, loopers)

  # DescribeMany

  test "describe_many returns error when one of ids is not a valid uuid" do
    {:ok, %{ppl_id: ppl_id_1}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    request = %{ppl_ids: [ppl_id_1, ppl_id_2, "not-an-uuid"]} |> DescribeManyRequest.new()
    assert {:BAD_PARAM, [], message} = describe_many(request)
    assert message == "Pipeline with id: 'not-an-uuid' not found."
  end

  test "describe_many returns error when there is no pipeliene for one or more of given ids" do
    {:ok, %{ppl_id: ppl_id_1}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    wrong_id = UUID.uuid4()
    request = %{ppl_ids: [ppl_id_1, ppl_id_2, wrong_id]} |> DescribeManyRequest.new()
    assert {:BAD_PARAM, [], message} = describe_many(request)
    assert message == "Pipeline with id: #{wrong_id} not found"
  end

  test "gRPC describe_many() - refuse request when there are to many unfinished ones" do
    old_desc = InFlightCounter.set_limit(:describe, 0)

    request = %{ppl_ids: [UUID.uuid4()]} |> DescribeManyRequest.new()
    status = GRPC.Status.resource_exhausted()
    assert %{status: status} == request |> describe_many_error() |> Map.take([:status])

    InFlightCounter.set_limit(:describe, old_desc)
  end

  test "describe_many returns pipeline descriptions when given valid ids" do
    {:ok, %{ppl_id: ppl_id_1}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"repo_name" => "2_bacis"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    request = %{ppl_ids: [ppl_id_1, ppl_id_2]} |> DescribeManyRequest.new()
    assert {:OK, pipelines, ""} = describe_many(request)

    assert length(pipelines) == 2
    assert pipelines |> Enum.at(0) |> Map.get(:ppl_id) == ppl_id_1
    assert pipelines |> Enum.at(1) |> Map.get(:ppl_id) == ppl_id_2

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  defp describe_many_error(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    assert {:error, response} = channel |> PipelineService.Stub.describe_many(request)
    response
  end

  defp describe_many(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    assert {:ok, response} = channel |> PipelineService.Stub.describe_many(request)

    assert {:ok, resp_map} = Proto.to_map(response)
    {resp_map.response_status.code, resp_map.pipelines, resp_map.response_status.message}
  end

  # GetProjectId

  test "gRPC get_project_id() - valid params - success" do
    ppl = insert_new_ppl(0)

    params = %{ppl_id: ppl.ppl_id} |> GetProjectIdRequest.new()

    assert {:ok, project_id} = get_project_id(params, :ok)
    assert project_id == ppl.project_id
  end

  test "gRPC get_project_id() - non-existin ppl_id - fail" do
    ppl_id = UUID.uuid4()

    params = %{ppl_id: ppl_id} |> GetProjectIdRequest.new()

    assert get_project_id(params, :error)
  end

  defp get_project_id(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.get_project_id(request)

    assert {:ok, get_project_id_response} = response

    assert %{project_id: project_id, response_status: %{code: status_code}} =
             get_project_id_response

    assert code(expected_status) == status_code

    project_id |> ToTuple.ok()
  end

  # ListQueues

  test "gRPC list_queues() - invalid params - no 'type' param" do
    request =
      %{project_id: "000", organization_id: "123", page: 2, page_size: 1}
      |> Proto.deep_new!(ListQueuesRequest)

    message = "The 'queue_types' list in request must have at least one elemet."
    assert list_queues(request, :BAD_PARAM, message)
  end

  test "gRPC list_queues() - invalid params - both project_id and organization_id are missing" do
    request =
      %{queue_types: [:IMPLICIT], project_id: "", organization_id: "", page: 2, page_size: 1}
      |> Proto.deep_new!(ListQueuesRequest)

    message = "Either 'project_id' or 'organization_id' parameters are required."
    assert list_queues(request, :BAD_PARAM, message)
  end

  test "gRPC list_queues() - valid params - success" do
    queues =
      1..4
      |> Enum.map(fn ind ->
        params = %{
          name: "production-#{ind}",
          scope: "project",
          project_id: project(ind),
          organization_id: "abc",
          user_generated: true
        }

        assert {:ok, queue} = QueuesQueries.insert_queue(params)
        queue
      end)

    request =
      %{
        queue_types: [:USER_GENERATED],
        project_id: "123",
        organization_id: "",
        page: 2,
        page_size: 1
      }
      |> Proto.deep_new!(ListQueuesRequest)

    assert %{page_number: 2, page_size: 1, total_pages: 2, total_entries: 2, queues: res_list} =
             list_queues(request, :OK)

    included = queues |> Enum.at(1)

    assert list_result_contains?(res_list, [included], :queue_id_in_results?)
  end

  test "gRPC list_queues() - valid params - result is empty list" do
    request =
      %{
        queue_types: [:USER_GENERATED],
        project_id: "123",
        organization_id: "",
        page: 2,
        page_size: 1
      }
      |> Proto.deep_new!(ListQueuesRequest)

    assert %{page_number: 1, page_size: 1, total_pages: 1, total_entries: 0, queues: []} ==
             list_queues(request, :OK)
  end

  defp project(ind) when ind < 3, do: "123"
  defp project(ind) when ind > 2, do: "456"

  defp list_queues(request, expected_status, msg \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list_queues(request)

    assert {:ok, lq_response} = response
    assert {:ok, response} = Proto.to_map(lq_response)
    assert %{response_status: %{code: ^expected_status, message: ^msg}} = response

    response |> Map.delete(:response_status)
  end

  def queue_id_in_results?(%{queue_id: queue_id}, results),
    do: queue_id_in_results?(queue_id, results)

  def queue_id_in_results?(queue_id, results),
    do: Enum.find(results, nil, fn %{queue_id: id} -> id == queue_id end) != nil

  # ListKeyset

  test "gRPC list_keyset() - successfully walk the list in both directions" do
    ppls = Range.new(0, 5) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params = %{project_id: "123", label: "master", page_token: "", page_size: 2}

    assert {next, ""} = assert_list_keyset_valid(ppls, params, [4, 5])

    params = params |> Map.put(:page_token, next)
    assert {next_2, previous} = assert_list_keyset_valid(ppls, params, [2, 3])

    params = params |> Map.put(:page_token, next_2)
    assert {"", previous_2} = assert_list_keyset_valid(ppls, params, [0, 1])

    params = params |> Map.merge(%{page_token: previous_2, direction: :PREVIOUS})
    assert {next_2, previous} == assert_list_keyset_valid(ppls, params, [2, 3])

    params = params |> Map.merge(%{page_token: previous, direction: :PREVIOUS})
    assert {next, ""} == assert_list_keyset_valid(ppls, params, [4, 5])
  end

  defp assert_list_keyset_valid(all_ppls, params, [lower_bound, upper_bound]) do
    request = params |> Proto.deep_new!(ListKeysetRequest)

    assert {:ok, response} = list_keyset(request, :ok)

    assert %{pipelines: pipelines, next_page_token: next, previous_page_token: previous} =
             response

    included = all_ppls |> Enum.slice(lower_bound..upper_bound)

    excluded =
      all_ppls
      |> Enum.with_index()
      |> Enum.reject(fn {i, _} -> i < lower_bound or i > upper_bound end)
      |> Enum.map(fn {_, el} -> el end)

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end

    {next, previous}
  end

  test "gRPC list_keyset() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    error =
      %{project_id: "123", label: "master", page_token: "", page_size: 5}
      |> Map.delete(:project_id)
      |> Proto.deep_new!(ListKeysetRequest)
      |> list_keyset(:error)

    assert error.status == GRPC.Status.resource_exhausted()
    assert error.message == "Too many requests, resources exhausted, try again later."

    InFlightCounter.set_limit(:list, old_list)
  end

  test "gRPC list_keyset() -  fails when given timestamps are wrong (done before created etc.)" do
    ts_1 = DateTime.utc_now()
    :timer.sleep(50)
    ts_2 = DateTime.utc_now()
    :timer.sleep(50)
    ts_3 = DateTime.utc_now()

    assert_list_ks_invalid_dates([ts_1, ts_2, nil, nil], :created_after, :created_before)
    assert_list_ks_invalid_dates([nil, nil, ts_1, ts_2], :done_after, :done_before)
    assert_list_ks_invalid_dates([ts_3, ts_2, ts_1, nil], :created_before, :done_before)
    assert_list_ks_invalid_dates([ts_3, ts_2, nil, ts_1], :created_before, :done_after)
    assert_list_ks_invalid_dates([nil, ts_2, ts_1, nil], :created_after, :done_before)
    assert_list_ks_invalid_dates([nil, ts_2, nil, ts_1], :created_after, :done_after)
  end

  defp assert_list_ks_invalid_dates(timestamps, key_1, key_2) do
    message =
      %{project_id: "123", label: "master", page_token: "", page_size: 5}
      |> add_timestamps(timestamps)
      |> Proto.deep_new!(
        ListKeysetRequest,
        transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
      )
      |> list_keyset(:error)
      |> Map.get(:message)

    assert message ==
             "Inavlid values od fields '#{key_1}' and '#{key_2}'" <>
               " - first has to be before second."
  end

  test "gRPC list_keyset() - error when called without project_id or wf_id" do
    params = %{project_id: "123", label: "master", page_token: "", page_size: 5}

    message =
      params
      |> Map.delete(:project_id)
      |> Proto.deep_new!(ListKeysetRequest)
      |> list_keyset(:error)
      |> Map.get(:message)

    assert message == "Either 'project_id' or 'wf_id' parameters are required."
  end

  defp list_keyset(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list_keyset(request)

    assert {^expected_status, list_response} = response

    if expected_status == :ok do
      list_response |> Proto.to_map()
    else
      list_response
    end
  end

  # List

  test "gRPC list() - valid params - success" do
    ppls = Range.new(0, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params =
      %{project_id: "123", branch_name: "master", page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, response} = list_ppls(params, :ok)

    assert %{
             pipelines: pipelines,
             page_number: 1,
             page_size: 5,
             total_entries: 10,
             total_pages: 2
           } = response

    excluded = ppls |> Enum.slice(0..4)
    included = ppls |> Enum.slice(5..9)

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl)
    end
  end

  test "gRPC list() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params =
      %{project_id: "123", branch_name: "master", page: 1, page_size: 5}
      |> ListRequest.new()

    msg = "Too many requests, resources exhausted, try again later."
    assert list_ppls_error(params, GRPC.Status.resource_exhausted(), msg)

    InFlightCounter.set_limit(:list, old_list)
  end

  test "gRPC list() - filter by yml_file_path and branch" do
    assert _ppl_1 = insert_new_ppl(0)
    assert ppl_2 = insert_new_ppl(1, %{"branch_name" => "dev"})
    assert ppl_3 = insert_new_ppl(2, %{"branch_name" => "dev", "file_name" => "a.yml"})

    # list only with project_id returns all three pipelines
    params = %{project_id: "123", page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{total_entries: 3}} = list_ppls(params, :ok)

    # list with branch=dev returns second and third pipeline
    params = %{project_id: "123", branch_name: "dev", page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{pipelines: pipelines, total_entries: 2}} = list_ppls(params, :ok)
    assert list_result_contains?(pipelines, [ppl_2, ppl_3])

    # list with yml_file_path=.semaphore/a.yml returns only third pipeline
    params =
      %{project_id: "123", yml_file_path: ".semaphore/a.yml", page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{pipelines: pipelines, total_entries: 1}} = list_ppls(params, :ok)
    assert list_result_contains?(pipelines, [ppl_3])
  end

  test "gRPC list() -  fails when given timestamps are wrong (done before created etc.)" do
    ts_1 = DateTime.utc_now()
    :timer.sleep(50)
    ts_2 = DateTime.utc_now()
    :timer.sleep(50)
    ts_3 = DateTime.utc_now()

    assert_list_invalid_dates([ts_1, ts_2, nil, nil], :created_after, :created_before)
    assert_list_invalid_dates([nil, nil, ts_1, ts_2], :done_after, :done_before)
    assert_list_invalid_dates([ts_3, ts_2, ts_1, nil], :created_before, :done_before)
    assert_list_invalid_dates([ts_3, ts_2, nil, ts_1], :created_before, :done_after)
    assert_list_invalid_dates([nil, ts_2, ts_1, nil], :created_after, :done_before)
    assert_list_invalid_dates([nil, ts_2, nil, ts_1], :created_after, :done_after)
  end

  defp assert_list_invalid_dates(timestamps, key_1, key_2) do
    message =
      "Inavlid values od fields '#{key_1}' and '#{key_2}' - first has to be before second."

    %{project_id: "123", page: 1, page_size: 5}
    |> add_timestamps(timestamps)
    |> Proto.deep_new!(
      ListRequest,
      transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
    )
    |> list_ppls(:error, message)
  end

  @tag :integration
  test "gRPC list() - filter by created(done)_before(after) timestamps" do
    ts_1 = DateTime.utc_now()

    {:ok, %{ppl_id: ppl_id_1}} =
      %{"repo_name" => "2_basic", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    ts_2 = DateTime.utc_now()

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"repo_name" => "2_basic", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    ts_3 = DateTime.utc_now()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id_1, "done", 10_000)
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id_2, "done", 10_000)

    ts_4 = DateTime.utc_now()

    {:ok, %{ppl_id: ppl_id_3}} =
      %{"repo_name" => "2_basic", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id_3, "done", 10_000)

    ts_5 = DateTime.utc_now()

    Test.Helpers.stop_all_loopers(loopers)

    # created_before
    assert_ts_list_valid([ts_1, nil, nil, nil], [], [ppl_id_1, ppl_id_2, ppl_id_3])
    assert_ts_list_valid([ts_2, nil, nil, nil], [ppl_id_1], [ppl_id_2, ppl_id_3])
    assert_ts_list_valid([ts_3, nil, nil, nil], [ppl_id_1, ppl_id_2], [ppl_id_3])
    assert_ts_list_valid([ts_4, nil, nil, nil], [ppl_id_1, ppl_id_2], [ppl_id_3])
    assert_ts_list_valid([ts_5, nil, nil, nil], [ppl_id_1, ppl_id_2, ppl_id_3], [])

    # created_after
    assert_ts_list_valid([nil, ts_5, nil, nil], [], [ppl_id_1, ppl_id_2, ppl_id_3])
    assert_ts_list_valid([nil, ts_4, nil, nil], [ppl_id_3], [ppl_id_1, ppl_id_2])
    assert_ts_list_valid([nil, ts_3, nil, nil], [ppl_id_3], [ppl_id_1, ppl_id_2])
    assert_ts_list_valid([nil, ts_2, nil, nil], [ppl_id_2, ppl_id_3], [ppl_id_1])
    assert_ts_list_valid([nil, ts_1, nil, nil], [ppl_id_1, ppl_id_2, ppl_id_3], [])

    # created_before & created_after
    assert_ts_list_valid([ts_5, ts_1, nil, nil], [ppl_id_1, ppl_id_2, ppl_id_3], [])

    # done_before
    assert_ts_list_valid([nil, nil, ts_3, nil], [], [ppl_id_1, ppl_id_2, ppl_id_3])
    assert_ts_list_valid([nil, nil, ts_4, nil], [ppl_id_1, ppl_id_2], [ppl_id_3])
    assert_ts_list_valid([nil, nil, ts_5, nil], [ppl_id_1, ppl_id_2, ppl_id_3], [])

    # done_after
    assert_ts_list_valid([nil, nil, nil, ts_3], [ppl_id_1, ppl_id_2, ppl_id_3], [])
    assert_ts_list_valid([nil, nil, nil, ts_4], [ppl_id_3], [ppl_id_1, ppl_id_2])
    assert_ts_list_valid([nil, nil, nil, ts_5], [], [ppl_id_1, ppl_id_2, ppl_id_3])

    # done_before & done_after
    assert_ts_list_valid([nil, nil, ts_5, ts_3], [ppl_id_1, ppl_id_2, ppl_id_3], [])

    # all four together
    assert_ts_list_valid([ts_2, ts_1, ts_5, ts_3], [ppl_id_1], [ppl_id_2, ppl_id_3])
  end

  defp assert_ts_list_valid(timestamps, included, excluded) do
    params =
      %{project_id: "123", page: 1, page_size: 5}
      |> add_timestamps(timestamps)
      |> Proto.deep_new!(
        ListRequest,
        transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
      )

    assert {:ok, response} = list_ppls(params, :ok)
    assert response.total_entries == length(included)
    assert list_result_contains?(response.pipelines, included)
    refute list_result_contains?(response.pipelines, excluded)
  end

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}

  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  @query_ts_names ~w(created_before created_after done_before done_after)a

  defp add_timestamps(map, timestamps) do
    @query_ts_names
    |> Enum.zip(timestamps)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(map, fn {k, v} -> {k, v} end)
  end

  @tag :integration
  test "gRPC list() - filter by wf_id" do
    Test.Helpers.start_all_loopers()

    topology = [
      {:schedule, nil, %{"project_id" => "to_list"}},
      {:schedule_extension, 0},
      {:partial_rebuild, 1}
    ]

    {wf_1, wf_1_ppl_ids} = topology |> WorkflowBuilder.build() |> extract_ids()
    {wf_2, wf_2_ppl_ids} = topology |> WorkflowBuilder.build() |> extract_ids()

    params =
      %{wf_id: wf_1, page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{pipelines: pipelines, total_entries: 3}} = list_ppls(params, :ok)
    assert list_result_contains?(pipelines, wf_1_ppl_ids)
    refute list_result_contains?(pipelines, wf_2_ppl_ids)

    params =
      %{project_id: "to_list", wf_id: wf_2, page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{pipelines: pipelines, total_entries: 3}} = list_ppls(params, :ok)
    assert list_result_contains?(pipelines, wf_2_ppl_ids)
    refute list_result_contains?(pipelines, wf_1_ppl_ids)
  end

  defp extract_ids(tuple_list) do
    wf_id = tuple_list |> Enum.at(0) |> elem(1)
    ppl_ids = tuple_list |> Enum.map(fn {:ok, _wf_id, ppl_id} -> ppl_id end)
    {wf_id, ppl_ids}
  end

  @tag :integration
  test "gRPC list() - filter by git_ref_types" do
    ppls =
      Range.new(0, 14)
      |> Enum.map(fn index ->
        insert_new_ppl(index, %{"label" => label(index), "hook_id" => hook_id(index)})
      end)

    ppl_id = ppls |> Enum.at(14) |> Map.get(:ppl_id)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params =
      %{git_ref_types: [:TAG, :PR], project_id: "123", page: 2, page_size: 3}
      |> Proto.deep_new!(ListRequest)

    assert {:ok, %{pipelines: pipelines, total_entries: 10}} = list_ppls(params, :ok)

    included = ppls |> Enum.slice(9..11)
    excluded = Enum.slice(ppls, 0..8) ++ Enum.slice(ppls, 12..14)

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)
  end

  defp hook_id(ind) when ind < 5, do: "branch"
  defp hook_id(ind) when ind < 10, do: "tag"
  defp hook_id(_ind), do: "pr"

  defp label(ind) when ind < 5, do: "master"
  defp label(ind) when ind < 10, do: "v1.0.2"
  defp label(_ind), do: "123"

  @tag :integration
  test "gRPC list() - filter by label" do
    ppls =
      Range.new(0, 14)
      |> Enum.map(fn index ->
        insert_new_ppl(index, %{"label" => label(index), "hook_id" => hook_id(index)})
      end)

    ppl_id = ppls |> Enum.at(14) |> Map.get(:ppl_id)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params =
      %{git_ref_types: [:BRANCH], project_id: "123", label: "master", page: 2, page_size: 3}
      |> Proto.deep_new!(ListRequest)

    assert {:ok, %{pipelines: pipelines, total_entries: 5}} = list_ppls(params, :ok)

    # oldest two ppl's should be on the second page
    included = ppls |> Enum.slice(0..1)
    excluded = ppls |> Enum.slice(2..14)

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)
  end

  @tag :integration
  test "gRPC list() - filter by queue_id" do
    ppls =
      Range.new(0, 9)
      |> Enum.map(fn index ->
        insert_new_ppl(index, %{"label" => label(index)})
      end)

    ppl_id = ppls |> Enum.at(9) |> Map.get(:ppl_id)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{name: "master-.semaphore/semaphore.yml", project_id: "123", scope: "project"}
    assert {:ok, queue} = QueuesQueries.get_by_name_and_id(params)

    params =
      %{queue_id: queue.queue_id, project_id: "123", page: 2, page_size: 3}
      |> Proto.deep_new!(ListRequest)

    assert {:ok, %{pipelines: pipelines, total_entries: 5}} = list_ppls(params, :ok)

    included = ppls |> Enum.slice(0..1)
    excluded = ppls |> Enum.slice(2..14)

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)
  end

  test "gRPC list() - error when called without project_id or wf_id" do
    params = %{project_id: "123", branch_name: "master", page: 1, page_size: 5}

    message = "Either 'project_id' or 'wf_id' parameters are required."

    params
    |> Map.delete(:project_id)
    |> ListRequest.new()
    |> list_ppls(:error, message)
  end

  defp list_ppls_error(request, expected_status, msg) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list(request)

    assert {:error, %GRPC.RPCError{status: expected_status, message: msg}} == response
  end

  defp list_ppls(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list(request)

    assert {:ok, list_response} = response
    assert %{response_status: %{code: status_code, message: msg}} = list_response
    assert code(expected_status) == status_code
    assert message == msg

    list_response |> Map.delete(:response_status) |> ToTuple.ok()
  end

  defp insert_new_ppl(index, args \\ %{}) do
    request_args =
      %{
        "branch_name" => "master",
        "commit_sha" => "sha" <> Integer.to_string(index),
        "project_id" => "123"
      }
      |> Map.merge(args)
      |> Test.Helpers.schedule_request_factory(:local)

    request_args = Map.put(request_args, "request_token", UUID.uuid4())
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    blocks = [%{"build" => build}, %{"build" => build}]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}

    assert {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req, "regular")
    assert {:ok, _ppl_or} = PplOriginsQueries.insert(ppl_req.id, request_args)
    ppl
  end

  defp list_result_contains?(results, expected_results, function \\ :ppl_id_in_results?)
  defp list_result_contains?(results, [], _function), do: length(results) == 0

  defp list_result_contains?(results, expected_results, function) do
    Enum.reduce(expected_results, true, fn expected, acc ->
      case acc do
        false -> false
        true -> apply(__MODULE__, function, [expected, results])
      end
    end)
  end

  def ppl_id_in_results?(%{ppl_id: ppl_id}, results),
    do: ppl_id_in_results?(ppl_id, results)

  def ppl_id_in_results?(ppl_id, results),
    do: Enum.find(results, nil, fn %{ppl_id: id} -> id == ppl_id end) != nil

  # ListRequesters

  @tag :integration
  test "gRPC list_requesters - valid params => success" do
    organization_id = Ecto.UUID.generate()

    [
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => "api", "organization_id" => organization_id},
        :github
      ),
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => "api", "organization_id" => organization_id},
        :bitbucket
      ),
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => "hook", "organization_id" => organization_id},
        :github
      ),
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => "hook", "organization_id" => organization_id},
        :bitbucket
      ),
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => "schedule", "organization_id" => organization_id},
        :github
      ),
      Test.Helpers.schedule_request_factory(
        %{"triggered_by" => "schedule", "organization_id" => organization_id},
        :bitbucket
      )
    ]
    |> Enum.with_index()
    |> Enum.map(fn {params, idx} ->
      {:ok, ppl_request} = PplRequestsQueries.insert_request(params)

      ppl_request
      |> PplRequestsQueries.insert_source(%{
        "repo_host_username" => "some-user-#{idx}",
        "user_id" => params["requester_id"]
      })
    end)

    one_hour = 60 * 60

    requested_at_lte = DateTime.utc_now()
    requested_at_gt = Timex.shift(requested_at_lte, hours: -3)

    params =
      %{
        page_size: 3,
        organization_id: organization_id,
        requested_at_gt: requested_at_gt,
        requested_at_lte: requested_at_lte
      }
      |> Proto.deep_new!(
        ListRequestersRequest,
        transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
      )

    assert {:ok, response} = list_requesters(params)
    assert length(response.requesters) == 3
    assert response.next_page_token != ""

    assert {:ok, response} = list_requesters(%{params | page_token: response.next_page_token})

    assert length(response.requesters) == 1
    assert response.next_page_token == ""
  end

  defp list_requesters(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list_requesters(request)

    response
  end

  # ListActivity

  @tag :integration
  test "gRPC list_activity() - invalid request parameters => error returned " do
    request =
      %{organization_id: "", page_token: "", page_size: 1}
      |> Proto.deep_new!(ListActivityRequest)

    assert %GRPC.RPCError{status: 3, message: msg} = list_activity(request, :error)
    assert msg == "Value of required field: 'organization_id' is empty string."
  end

  @tag :integration
  test "gRPC list_activity() - no active pipelines => empty list returned" do
    request =
      %{organization_id: "123", page_token: "", page_size: 1}
      |> Proto.deep_new!(ListActivityRequest)

    assert %{pipelines: [], previous_page_token: "", next_page_token: ""} ==
             list_activity(request, :ok)
  end

  @tag :integration
  test "gRPC list_activity() - valid request => paginated results returned" do
    {:ok, ppl_1} = create_ppl(%{"organization_id" => "123"})
    {:ok, ppl_2} = create_ppl(%{"organization_id" => "123", "label" => "dev"})
    {:ok, ppl_3} = create_ppl(%{"organization_id" => "123", "label" => "stg"})
    {:ok, ppl_4} = create_ppl(%{"organization_id" => "456", "label" => "asdf"})
    {:ok, ppl_5} = create_ppl(%{"organization_id" => "456", "label" => "asdf"})

    loopers = start_running_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_4.ppl_id, "running", 10_000)
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_5.ppl_id, "queuing", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # test if both running and queuing pipelines are included

    req_0 =
      %{organization_id: "456", page_token: "", page_size: 2}
      |> Proto.deep_new!(ListActivityRequest)

    assert %{pipelines: result_0, previous_page_token: "", next_page_token: n_token} =
             list_activity(req_0, :ok)

    assert list_result_contains?(result_0, [ppl_5, ppl_4])
    refute list_result_contains?(result_0, [ppl_1, ppl_2, ppl_1])

    # test if tokens are valid and listing direction works

    req_1 =
      %{organization_id: "123", page_token: "", page_size: 1}
      |> Proto.deep_new!(ListActivityRequest)

    assert %{pipelines: result_1, previous_page_token: "", next_page_token: n_token} =
             list_activity(req_1, :ok)

    assert list_result_contains?(result_1, [ppl_3])
    refute list_result_contains?(result_1, [ppl_1, ppl_2, ppl_4, ppl_5])

    for ppl <- result_1 do
      assert assert_ppl_triggerer(ppl, true)
    end

    req_2 =
      %{organization_id: "123", page_token: n_token, page_size: 1}
      |> Proto.deep_new!(ListActivityRequest)

    assert %{pipelines: result_2, previous_page_token: p_token, next_page_token: _n_token_2} =
             list_activity(req_2, :ok)

    assert list_result_contains?(result_2, [ppl_2])
    refute list_result_contains?(result_2, [ppl_1, ppl_3, ppl_4, ppl_5])

    for ppl <- result_2 do
      assert assert_ppl_triggerer(ppl, true)
    end

    req_3 =
      %{organization_id: "123", page_token: p_token, page_size: 1, direction: :PREVIOUS}
      |> Proto.deep_new!(ListActivityRequest)

    assert %{pipelines: result_3, previous_page_token: "", next_page_token: _n_token_3} =
             list_activity(req_3, :ok)

    assert list_result_contains?(result_3, [ppl_3])
    refute list_result_contains?(result_3, [ppl_1, ppl_2, ppl_4, ppl_5])

    for ppl <- result_3 do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  defp create_ppl(params) do
    %{"repo_name" => "7_termination", "project_id" => "0987"}
    |> Map.merge(params)
    |> Test.Helpers.schedule_request_factory(:local)
    |> Actions.schedule()
  end

  defp start_running_loopers() do
    []
    # Ppls Loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    # PplSubInits Loopers
    |> Test.Helpers.start_sub_init_loopers()
    # PplBlocks Loopers
    |> Test.Helpers.start_ppl_block_loopers()
  end

  defp list_activity(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list_activity(request)

    assert {^expected_status, list_response} = response

    if expected_status == :ok do
      list_response |> Proto.to_map!()
    else
      list_response
    end
  end

  # ListGrouped

  @tag :integration
  test "gRPC list_grouped() -  project scoped implicit queues" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params =
      %{queue_type: [:IMPLICIT], project_id: "123", page: 1, page_size: 3}
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 2} = list_grouped(params, :OK)

    included = [ppl_2, ppl_6]
    excluded = [ppl_1, ppl_3, ppl_4, ppl_5, ppl_7, ppl_8]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  @tag :integration
  test "gRPC list_grouped() -  project scoped user generated queues" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{
      name: "dev-.semaphore/semaphore.yml",
      scope: "project",
      project_id: "123"
    }

    up_params = %{name: "updated_3", user_generated: true}

    update_queue(params, up_params)

    params =
      %{
        queue_type: [:USER_GENERATED],
        project_id: "123",
        page: 1,
        page_size: 3
      }
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 1} = list_grouped(params, :OK)

    included = [ppl_6]
    excluded = [ppl_1, ppl_2, ppl_3, ppl_4, ppl_5, ppl_7, ppl_8]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  @tag :integration
  test "gRPC list_grouped() -  org scoped implicit queues" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{name: "master-.semaphore/semaphore.yml", scope: "project", project_id: "123"}
    up_params = %{name: "updated", scope: "organization", organization_id: "123"}
    update_queue(params, up_params)

    update_queue(
      %{params | project_id: "456"},
      %{up_params | name: "updated_1", organization_id: "456"}
    )

    params = %{name: "dev-.semaphore/semaphore.yml", scope: "project", project_id: "123"}
    update_queue(params, %{up_params | name: "updated_2"})

    update_queue(
      %{params | project_id: "456"},
      %{up_params | name: "updated_3", organization_id: "456"}
    )

    params =
      %{queue_type: [:IMPLICIT], organization_id: "123", page: 1, page_size: 3}
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 2} = list_grouped(params, :OK)

    included = [ppl_2, ppl_6]
    excluded = [ppl_1, ppl_3, ppl_4, ppl_5, ppl_7, ppl_8]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  @tag :integration
  test "gRPC list_grouped() -  org scoped user generated queues" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{
      name: "dev-.semaphore/semaphore.yml",
      scope: "project",
      project_id: "123"
    }

    up_params = %{
      name: "updated_3",
      scope: "organization",
      organization_id: "123",
      user_generated: true
    }

    update_queue(params, up_params)

    params =
      %{
        queue_type: [:USER_GENERATED],
        organization_id: "123",
        page: 1,
        page_size: 3
      }
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 1} = list_grouped(params, :OK)

    included = [ppl_6]
    excluded = [ppl_1, ppl_2, ppl_3, ppl_4, ppl_5, ppl_7, ppl_8]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  @tag :integration
  test "gRPC list_grouped() -  both scopes implicit queues" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{name: "master-.semaphore/semaphore.yml", scope: "project", project_id: "123"}
    up_params = %{name: "updated", scope: "organization", organization_id: "123"}
    update_queue(params, up_params)

    params = %{name: "dev-.semaphore/semaphore.yml", scope: "project", project_id: "123"}
    update_queue(params, %{up_params | name: "updated_2"})

    params =
      %{queue_type: [:IMPLICIT], organization_id: "123", project_id: "456", page: 1, page_size: 5}
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 4} = list_grouped(params, :OK)

    included = [ppl_2, ppl_4, ppl_6, ppl_8]
    excluded = [ppl_1, ppl_3, ppl_5, ppl_7]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  @tag :integration
  test "gRPC list_grouped() -  both scopes user-generated queues" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{name: "master-.semaphore/semaphore.yml", scope: "project", project_id: "123"}

    up_params = %{
      name: "updated",
      scope: "organization",
      organization_id: "123",
      user_generated: true
    }

    update_queue(params, up_params)

    params = %{name: "dev-.semaphore/semaphore.yml", scope: "project", project_id: "456"}
    update_queue(params, %{name: "updated_2", user_generated: true})

    params =
      %{
        queue_type: [:USER_GENERATED],
        organization_id: "123",
        project_id: "456",
        page: 1,
        page_size: 5
      }
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 2} = list_grouped(params, :OK)

    included = [ppl_2, ppl_8]
    excluded = [ppl_1, ppl_3, ppl_4, ppl_5, ppl_6, ppl_7]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  @tag :integration
  test "gRPC list_grouped() -  both scopes, both queue types" do
    ppl_1 = insert_new_ppl(0, %{"label" => "master", "project_id" => "123"})
    ppl_2 = insert_new_ppl(1, %{"label" => "master", "project_id" => "123"})
    ppl_3 = insert_new_ppl(2, %{"label" => "master", "project_id" => "456"})
    ppl_4 = insert_new_ppl(3, %{"label" => "master", "project_id" => "456"})
    ppl_5 = insert_new_ppl(4, %{"label" => "dev", "project_id" => "123"})
    ppl_6 = insert_new_ppl(5, %{"label" => "dev", "project_id" => "123"})
    ppl_7 = insert_new_ppl(6, %{"label" => "dev", "project_id" => "456"})
    ppl_8 = insert_new_ppl(7, %{"label" => "dev", "project_id" => "456"})

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_8.ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{name: "master-.semaphore/semaphore.yml", scope: "project", project_id: "123"}
    up_params = %{name: "updated", scope: "organization", organization_id: "123"}
    update_queue(params, up_params)

    params = %{name: "dev-.semaphore/semaphore.yml", scope: "project", project_id: "123"}

    up_params = %{
      name: "updated_2",
      scope: "organization",
      organization_id: "123",
      user_generated: true
    }

    update_queue(params, up_params)

    params = %{name: "dev-.semaphore/semaphore.yml", scope: "project", project_id: "456"}
    up_params = %{name: "updated_3", user_generated: true}
    update_queue(params, up_params)

    params =
      %{
        queue_type: [:IMPLICIT, :USER_GENERATED],
        organization_id: "123",
        project_id: "456",
        page: 1,
        page_size: 5
      }
      |> Proto.deep_new!(ListGroupedRequest)

    assert %{pipelines: pipelines, total_entries: 4} = list_grouped(params, :OK)

    included = [ppl_2, ppl_4, ppl_6, ppl_8]
    excluded = [ppl_1, ppl_3, ppl_5, ppl_7]

    assert list_result_contains?(pipelines, included)
    refute list_result_contains?(pipelines, excluded)

    for ppl <- pipelines do
      assert assert_ppl_triggerer(ppl, true)
    end
  end

  defp update_queue(params, to_update) do
    assert {:ok, queue} = QueuesQueries.get_or_insert_queue(params)

    assert {:ok, _} = queue |> Queues.changeset(to_update) |> Ppl.EctoRepo.update()
  end

  defp list_grouped(request, expected_status, msg \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.list_grouped(request)

    assert {:ok, lg_response} = response
    assert {:ok, response} = Proto.to_map(lg_response)
    assert %{response_status: %{code: ^expected_status, message: ^msg}} = response

    response |> Map.delete(:response_status)
  end

  # ScheduleExtension

  test "gRPC schedule_extension() - refuse if project deletion was requested" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "10_schedule_extension", "project_id" => "to-delete"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, message} = delete_ppls_from_project("to-delete")
    assert message == "Pipelines from given project are scheduled for deletion."

    assert_schedule_extension("/foo/bar/test.yml", ppl_id, :refused)
  end

  @tag :integration
  test "gRPC schedule_extension() local - succedes when given valid params" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "10_schedule_extension"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    test_valid_pipeline_description_passes(ppl_id)
    assert_yml_file_path_has_same_value_as_in_request(ppl_id)

    ppl_id_2 = assert_schedule_extension("/foo/bar/test.yml", ppl_id, :ok)
    test_valid_pipeline_description_passes(ppl_id_2)
    assert_yml_file_path_has_same_value_as_in_request(ppl_id_2)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id_2)
    assert [ppl_id] == ppl_req.prev_ppl_artefact_ids
    assert ppl_id == ppl_req.request_args["extension_of"]
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id_2)
    assert {:ok, inital_ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl_id == ppl.extension_of
    assert inital_ppl.wf_number == ppl.wf_number
  end


  @tag :integration
  test "gRPC schedule_extension() local - succedes when extending task initial ppl" do
    {:ok, %{ppl_id: ppl_id}} =
      %{
        "requester_id" => "10_schedule_extension",
        "repo_name" => "",
        "owner" => "",
        "branch_name" => "master",
        "label" => "master",
        "branch_id" =>  "",
        "hook_id" =>  "",
        "commit_sha" => "",
        "triggered_by" => "schedule",
        "scheduler_task_id" => "scheduler_task_id"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule(true, true, true)

    test_valid_pipeline_description_passes(ppl_id)
    assert_yml_file_path_has_same_value_as_in_request(ppl_id)

    ppl_id_2 = assert_schedule_extension("/foo/bar/test.yml", ppl_id, :ok)
    test_valid_pipeline_description_passes(ppl_id_2)
    assert_yml_file_path_has_same_value_as_in_request(ppl_id_2)

    assert {:ok, old_ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id_2)
    assert [ppl_id] == ppl_req.prev_ppl_artefact_ids
    assert ppl_id == ppl_req.request_args["extension_of"]
    assert old_ppl_req.request_args["hook_id"] == ppl_req.request_args["hook_id"]

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id_2)
    assert {:ok, inital_ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl_id == ppl.extension_of
    assert inital_ppl.wf_number == ppl.wf_number
  end

  defp assert_schedule_extension(file_path, ppl_id, expected_status) do
    request =
      %{
        file_path: file_path,
        ppl_id: ppl_id,
        request_token: UUID.uuid4(),
        prev_ppl_artefact_ids: [ppl_id]
      }
      |> ScheduleExtensionRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.schedule_extension(request)

    assert {:ok, sch_ext_response} = response
    assert %{ppl_id: ppl_id, response_status: %{code: status_code}} = sch_ext_response
    assert code(expected_status) == status_code

    ppl_id
  end

  # PartialRebuild

  test "gRPC partial_rebuild() - fails when ppl_id not found" do
    expected_message = "\"Pipeline with id: non-existing-ppl not found\""
    assert_partial_rebuild("non-existing-ppl", "123", :error, expected_message)
  end

  test "gRPC partial_rebuild() - refuse if project deletion was requested" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "14_free_topology_failing_block", "project_id" => "to-delete"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, message} = delete_ppls_from_project("to-delete")
    assert message == "Pipelines from given project are scheduled for deletion."

    expected_message = "Project with id to-delete was deleted."
    assert_partial_rebuild(ppl_id, UUID.uuid4(), :refused, expected_message)
  end

  @tag :integration
  test "gRPC partial_rebuild() - fails when given pipeline is running" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "14_free_topology_failing_block"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    expected_message = "Only pipelines which are in done state can be partial rebuilt."
    assert_partial_rebuild(ppl_id, UUID.uuid4(), :error, expected_message)
  end

  @tag :integration
  test "gRPC partial_rebuild() - fails when given pipeline is passed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "5_v1_full", "file_name" =>"no_cmd_files.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    expected_message = "Pipelines which passed can not be partial rebuilt."
    assert_partial_rebuild(ppl_id, UUID.uuid4(), :error, expected_message)
  end

  @tag :integration
  test "gRPC partial_rebuild() - succedes when given valid params" do
    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "14_free_topology_failing_block",
        "label" => "master",
        "commit_sha" => "1234567"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 20_000)

    request_token = UUID.uuid4()
    new_ppl_id = assert_partial_rebuild(ppl_id, request_token, :ok)

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(new_ppl_id, "done", 20_000)
    Test.Helpers.stop_all_loopers(loopers)

    {ppl_id, new_ppl_id}
    |> assert_rebuilt_ppl_req_valid(request_token)
    |> assert_rebuilt_ppl_valid()
    |> assert_rebuilt_ppl_blocks_are_valid()
  end

  @tag :integration
  test "gRPC partial_rebuild() - succedes with rebuilds of task initial ppls" do
    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "",
        "owner" => "",
        "branch_name" => "master",
        "label" => "master",
        "branch_id" =>  "",
        "hook_id" =>  "",
        "commit_sha" => "",
        "triggered_by" => "schedule",
        "requester_id" => "14_free_topology_failing_block",
        "scheduler_task_id" => "scheduler_task_id"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule(true, true, true)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 20_000)

    request_token = UUID.uuid4()
    new_ppl_id = assert_partial_rebuild(ppl_id, request_token, :ok)

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(new_ppl_id, "done", 20_000)
    Test.Helpers.stop_all_loopers(loopers)

    {ppl_id, new_ppl_id}
    |> assert_rebuilt_ppl_req_valid(request_token)
    |> assert_rebuilt_ppl_valid()
    |> assert_rebuilt_ppl_blocks_are_valid()
  end

  defp assert_rebuilt_ppl_req_valid(params = {ppl_id, new_ppl_id}, request_token) do
    {:ok, original} = PplRequestsQueries.get_by_id(ppl_id)
    {:ok, duplicate} = PplRequestsQueries.get_by_id(new_ppl_id)

    assert_same_except(original, duplicate, [
      :id,
      :definition,
      :request_token,
      :initial_request,
      :switch_id,
      :inserted_at,
      :updated_at,
      :request_args
    ])

    assert duplicate.initial_request == false
    assert duplicate.request_token == request_token
    assert duplicate.request_args["partially_rerun_by"] == "rebuild_user"
    assert original.request_args == duplicate.request_args |> Map.drop(["partially_rerun_by"])
    assert NaiveDateTime.compare(original.inserted_at, duplicate.inserted_at) == :lt
    params
  end

  defp assert_rebuilt_ppl_valid(params = {ppl_id, new_ppl_id}) do
    {:ok, original} = PplsQueries.get_by_id(ppl_id)
    {:ok, duplicate} = PplsQueries.get_by_id(new_ppl_id)

    assert_same_except(original, duplicate, [
      :id,
      :ppl_id,
      :partial_rebuild_of,
      :inserted_at,
      :updated_at
    ])

    assert duplicate.partial_rebuild_of == ppl_id
    assert NaiveDateTime.compare(original.inserted_at, duplicate.inserted_at) == :lt
    params
  end

  defp assert_rebuilt_ppl_blocks_are_valid(params = {ppl_id, new_ppl_id}) do
    {:ok, original_blocks} = PplBlocksQueries.get_all_by_id(ppl_id)
    {:ok, duplicate_blocks} = PplBlocksQueries.get_all_by_id(new_ppl_id)

    original_blocks
    |> Enum.each(fn orig_blk ->
      dpl_blk = Enum.at(duplicate_blocks, orig_blk.block_index)

      assert_same_except(orig_blk, dpl_blk, [
        :id,
        :ppl_id,
        :duplicate,
        :block_id,
        :connections,
        :inserted_at,
        :updated_at
      ])

      assert dpl_blk.duplicate == true

      if orig_blk.result == "passed" do
        assert blocks_reference_same_build(orig_blk.block_id, dpl_blk.block_id)
      else
        assert (is_nil(orig_blk.block_id) && is_nil(dpl_blk.block_id)) ||
                 orig_blk.block_id != dpl_blk.block_id
      end

      assert NaiveDateTime.compare(orig_blk.inserted_at, dpl_blk.inserted_at) == :lt
    end)

    params
  end

  defp blocks_reference_same_build(orig_block_id, dpl_block_id) do
    {:ok, orig_blk_desc} = Block.describe(orig_block_id)
    {:ok, dpl_blk_desc} = Block.describe(dpl_block_id)

    assert orig_blk_desc.build_req_id == dpl_blk_desc.build_req_id
  end

  defp assert_same_except(struct1, struct2, keys) do
    assert struct1 |> Map.from_struct() |> Map.drop(keys) ==
             struct2 |> Map.from_struct() |> Map.drop(keys)
  end

  @tag :integration
  test "gRPC partial_rebuild() is idempotent" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "14_free_topology_failing_block"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 20_000)
    Test.Helpers.stop_all_loopers(loopers)

    request_token = UUID.uuid4()
    new_ppl_id_1 = assert_partial_rebuild(ppl_id, request_token, :ok)
    new_ppl_id_2 = assert_partial_rebuild(ppl_id, request_token, :ok)
    assert new_ppl_id_1 == new_ppl_id_2
  end

  @tag :integration
  test "gRPC partial_rebuild() - succeeds when no deployment target is specified" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "14_free_topology_failing_block"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 20_000)
    Test.Helpers.stop_all_loopers(loopers)

    request_token = UUID.uuid4()
    new_ppl_id = assert_partial_rebuild(ppl_id, request_token, :ok)
    assert is_binary(new_ppl_id)
  end

  @tag :integration
  test "gRPC partial_rebuild() - fails when deployment target permission is denied" do
    deployment_target_id = UUID.uuid4()
    {:ok, %{ppl_id: ppl_id}} = create_pipeline_with_deployment_target(deployment_target_id)

    # Mock GoferClient to return access denied
    with_mock GoferClient, [
      verify_deployment_target_access: fn(_, _, _, _) -> {:error, :banned_subject} end
    ] do
      expected_message = "Access to deployment target denied: :banned_subject"
      assert_partial_rebuild(ppl_id, UUID.uuid4(), :error, expected_message)
    end
  end

  @tag :integration
  test "gRPC partial_rebuild() - succeeds when deployment target permission is granted" do
    deployment_target_id = UUID.uuid4()
    {:ok, %{ppl_id: ppl_id}} = create_pipeline_with_deployment_target(deployment_target_id)

    # Mock GoferClient to return access granted
    with_mock GoferClient, [
      verify_deployment_target_access: fn(_, _, _, _) -> {:ok, :access_granted} end
    ] do
      request_token = UUID.uuid4()
      new_ppl_id = assert_partial_rebuild(ppl_id, request_token, :ok)
      assert is_binary(new_ppl_id)
    end
  end

  @tag :integration
  test "gRPC partial_rebuild() - fails when deployment target verification returns error" do
    deployment_target_id = UUID.uuid4()
    {:ok, %{ppl_id: ppl_id}} = create_pipeline_with_deployment_target(deployment_target_id)

    # Mock GoferClient to return syncing target error
    with_mock GoferClient, [
      verify_deployment_target_access: fn(_, _, _, _) -> {:error, :syncing_target} end
    ] do
      expected_message = "Access to deployment target denied: :syncing_target"
      assert_partial_rebuild(ppl_id, UUID.uuid4(), :error, expected_message)
    end
  end

  defp create_pipeline_with_deployment_target(deployment_target_id) do
    source_args = Test.Support.RequestFactory.source_args(%{})

    %{
      "repo_name" => "14_free_topology_failing_block",
      "deployment_target_id" => deployment_target_id
    }
    |> Test.Helpers.schedule_request_factory(:local)
    |> Map.put("source_args", source_args)
    |> Actions.schedule()
    |> case do
      {:ok, %{ppl_id: ppl_id}} = result ->
        loopers = Test.Helpers.start_all_loopers()
        {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 20_000)
        Test.Helpers.stop_all_loopers(loopers)
        result
      error -> error
    end
  end

  defp assert_partial_rebuild(ppl_id, request_token, expected_status, expected_message \\ "") do
    request =
      %{ppl_id: ppl_id, request_token: request_token, user_id: "rebuild_user"}
      |> PartialRebuildRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.partial_rebuild(request)

    assert {:ok, rebuild_response} = response
    assert %{ppl_id: ppl_id, response_status: resp_status} = rebuild_response
    assert %{code: status_code, message: ^expected_message} = resp_status
    assert code(expected_status) == status_code

    ppl_id
  end

  # Terminate

  test "gRPC terminate() -  - ppl_id not found" do
    assert_terminate_ppl("does-not-exist", :error)
  end

  @tag :integration
  test "gRPC terminate() - terminate running pipeline" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "7_termination"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    :timer.sleep(4_000)
    assert_state(ppl_id, "", "running")

    {message, user_id} = assert_terminate_ppl(ppl_id, :ok)
    assert "Pipeline termination started." = message

    :timer.sleep(2_000)
    assert_state(ppl_id, user_id, "stopping")

    args = [ppl_id, loopers, "stopped"]
    Helpers.assert_finished_for_less_than(__MODULE__, :ppl_terminated, args, 30_000)
    assert_blocks_results(ppl_id, "stopped-canceled")
  end

  defp assert_terminate_ppl(ppl_id, expected_status) do
    user_id = UUID.uuid4()

    message =
      %{ppl_id: ppl_id, requester_id: user_id}
      |> TerminateRequest.new()
      |> terminate_ppl(expected_status)

    {message, user_id}
  end

  defp assert_state(ppl_id, user_id, state) do
    request = %{ppl_id: ppl_id} |> DescribeRequest.new()
    {ppl, _blocks} = describe_ppl(request, :ok)
    assert state == ppl.state |> from_proto(:state)
    assert user_id == ppl.terminated_by
  end

  defp terminate_ppl(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.terminate(request)

    assert {:ok, terminate_response} = response
    assert %{response_status: %{code: status_code, message: message}} = terminate_response
    assert code(expected_status) == status_code
    message
  end

  def ppl_terminated(ppl_id, loopers, desired_result) do
    :timer.sleep(1_000)

    request = %{ppl_id: ppl_id} |> DescribeRequest.new()
    {ppl, _blocks} = describe_ppl(request, :ok)
    result = ppl.result |> from_proto(:result)
    ppl_terminated_(ppl_id, loopers, desired_result, result)
  end

  defp ppl_terminated_(_ppl_id, loopers, desired_result, result)
       when result == desired_result do
    Test.Helpers.stop_all_loopers(loopers)
    :pass
  end

  defp ppl_terminated_(ppl_id, loopers, desired_result, _),
    do: ppl_terminated(ppl_id, loopers, desired_result)

  defp assert_blocks_results(ppl_id, "stopped-canceled") do
    request = %{ppl_id: ppl_id, detailed: true} |> DescribeRequest.new()
    {_ppl, blocks} = describe_ppl(request, :ok)
    assert is_list(blocks)

    block_one = Enum.at(blocks, 0)
    assert block_one.result |> from_proto(:result) == "stopped"

    block_two = Enum.at(blocks, 1)
    assert block_two.result |> from_proto(:result) == "canceled"
  end

  defp from_proto(state, :state),
    do: state |> State.key() |> Atom.to_string() |> String.downcase()

  defp from_proto(result, :result),
    do: result |> Result.key() |> Atom.to_string() |> String.downcase()

  defp from_proto(result_reason, :result_reason),
    do: result_reason |> ResultReason.key() |> Atom.to_string() |> String.downcase()

  defp assert_yml_file_path_has_same_value_as_in_request(ppl_id) do
    {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    args = ppl_req.request_args

    assert(ppl.yml_file_path == Path.join(args["working_dir"], args["file_name"]))
  end
end
