defmodule Plumber.WorkflowAPI.Server.Test do
  @test_commit_sha_1 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  @test_commit_sha_2 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  use Ppl.IntegrationCase

  alias Util.{Proto, ToTuple}
  alias Ppl.Grpc.InFlightCounter
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Test.Support.WorkflowBuilder
  alias Google.Protobuf.Timestamp

  alias InternalApi.Plumber.{
    PipelineService,
    DeleteRequest,
    ScheduleExtensionRequest,
    PartialRebuildRequest,
    ValidateYamlRequest
  }

  alias InternalApi.PlumberWF.{
    ScheduleRequest,
    WorkflowService,
    TerminateRequest,
    GetPathRequest,
    ListRequest,
    DescribeRequest,
    DescribeManyRequest,
    RescheduleRequest,
    GetProjectIdRequest,
    ListLabelsRequest,
    ListGroupedRequest,
    ListKeysetRequest,
    ListGroupedKSRequest,
    ListLatestWorkflowsRequest
  }

  setup_all do
    # here only to fix flakiness in tests, because first call tends to timeout
    Ppl.RepoProxyClient.describe("asdf")
    :ok
  end

  setup do
    Test.Helpers.truncate_db()

    urls = %{workflow_service: "localhost:50053", plumber_service: "localhost:50053"}
    start_supervised!({WorkflowBuilder.Impl, urls})
    :ok
  end

  # Reschedule

  test "gRPC reschedule() - fails when there is no workflow with given wf_id" do
    wf_id = UUID.uuid4()
    message = {:not_found, "Workflow with id: #{wf_id} not found."}

    %{wf_id: wf_id, requester_id: "123", request_token: UUID.uuid4()}
    |> RescheduleRequest.new()
    |> reschedule_workflow(:INVALID_ARGUMENT, "#{inspect(message)}")
  end

  test "gRPC reschedule() - fails when project deletion was already requested" do
    params = %{"project_id" => "to-delete"}
    assert [{:ok, wf_id, _ppl_id}] = WorkflowBuilder.build([{:schedule, nil, params}])

    assert {:ok, message} = delete_ppls_from_project("to-delete")
    assert message == "Pipelines from given project are scheduled for deletion."

    message = "Project with id to-delete was deleted."

    %{wf_id: wf_id, requester_id: "123", request_token: UUID.uuid4()}
    |> RescheduleRequest.new()
    |> reschedule_workflow(:FAILED_PRECONDITION, message)
  end

  @tag :integration
  test "gRPC reschedule() - limit exceeded" do
    old_env = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "2")

    # First
    params =
      %{"service" => :LOCAL, "project_id" => "to-queue"}
      |> Test.Support.RequestFactory.schedule_args(:local)

    assert [{:ok, _wf_id, ppl_id}] = WorkflowBuilder.build([{:schedule, nil, params}])

    loopers = start_loopers_running()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 10_000)

    # Second
    params =
      %{"service" => :LOCAL, "project_id" => "to-queue"}
      |> Test.Support.RequestFactory.schedule_args(:local)

    assert [{:ok, wf_id, ppl_id}] = WorkflowBuilder.build([{:schedule, nil, params}])

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "queuing", 10_000)
    stop_loopers(loopers)

    # Third
    message = "Limit of queuing pipelines reached"

    %{wf_id: wf_id, requester_id: "123", request_token: UUID.uuid4()}
    |> RescheduleRequest.new()
    |> reschedule_workflow(:RESOURCE_EXHAUSTED, message)

    System.put_env("PPL_QUEUE_LIMIT", old_env)
  end

  @tag :integration
  test "gRPC reschedule() - succeeds and initial ppl passes" do
    params = Test.Support.RequestFactory.schedule_args(%{"service" => :LOCAL}, :local)
    assert [{:ok, wf_id, ppl_id}] = WorkflowBuilder.build([{:schedule, nil, params}])

    request =
      %{wf_id: wf_id, requester_id: "123", request_token: UUID.uuid4()}
      |> RescheduleRequest.new()

    assert {:ok, response} = reschedule_workflow(request, :OK)
    assert %{wf_id: new_wf_id, ppl_id: new_ppl_id} = response
    assert new_wf_id != wf_id
    assert new_ppl_id != ppl_id

    loopers = Test.Helpers.start_all_loopers()

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(new_ppl_id, "done", 15_000)

    Test.Helpers.stop_all_loopers(loopers)

    assert {:ok, response} = describe_workflow(DescribeRequest.new(%{wf_id: new_wf_id}), :OK)
    assert %{workflow: wf} = response |> Proto.to_map!()
    assert wf.triggered_by == :HOOK
    assert wf.rerun_of == wf_id
    assert wf.requester_id == "123"
  end

  @tag :integration
  test "gRPC reschedule() - succeeds and initial ppl passes with scheduler_task_id" do
    params =
      %{
        service: enum_val("local"),
        repo_name: "2_basic",
        request_token: UUID.uuid4(),
        requester_id: UUID.uuid4(),
        branch_id: "",
        hook_id: "",
        scheduler_task_id: "scheduler_task_id"
      }

    assert {:ok, wf_id, ppl_id} = WorkflowBuilder.schedule( params)

    request =
      %{wf_id: wf_id, requester_id: "123", request_token: UUID.uuid4()}
      |> RescheduleRequest.new()

    assert {:ok, response} = reschedule_workflow(request, :OK)
    assert %{wf_id: new_wf_id, ppl_id: new_ppl_id} = response
    assert new_wf_id != wf_id
    assert new_ppl_id != ppl_id

    assert {:ok, old_ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(new_ppl_id)

    assert ppl_req.request_args |> Map.get("scheduler_task_id") == "scheduler_task_id"
    assert ppl_req.wf_id == new_wf_id
    assert ppl_req.request_args["hook_id"] == old_ppl_req.request_args["hook_id"]

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_req.id)
    assert ppl.ppl_id == new_ppl_id
    assert ppl.scheduler_task_id == "scheduler_task_id"

    assert {:ok, ppl_req} = PplSubInitsQueries.get_by_id(ppl_req.id)
    assert ppl_req.state == "created"
  end

  defp reschedule_workflow(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.reschedule(request)

    assert {:ok, rsch_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(rsch_response)
    assert expected_status == status_code
    assert message == msg

    rsch_response |> Map.delete(:status) |> ToTuple.ok()
  end

  # GetProjectId

  test "gRPC get_project_id() - failes when wf_id is omitted" do
    message = "'wf_id' - invalid value: '', it must be a not empty string."

    %{wf_id: ""}
    |> GetProjectIdRequest.new()
    |> get_project_id(:INVALID_ARGUMENT, message)
  end

  test "gRPC get_project_id() - failes when there is no workflow with given wf_id" do
    wf_id = UUID.uuid4()
    message = "{:not_found, \"Workflow with id: #{wf_id} not found.\"}"

    %{wf_id: wf_id}
    |> GetProjectIdRequest.new()
    |> get_project_id(:INVALID_ARGUMENT, message)
  end

  test "gRPC get_project_id() - succedes when given valid wf_id" do
    params = %{
      "project_id" => "qwerty",
      "hook_id" => "asdf",
      "requester_id" => "zxcv",
      "branch_id" => "uiop",
      "branch_name" => "fghj",
      "commit_sha" => String.slice(@test_commit_sha_1, 0, 4)
    }

    assert [{:ok, wf_id, _ppl_id}] = WorkflowBuilder.build([{:schedule, nil, params}])

    assert {:ok, gpi_response} = get_project_id(GetProjectIdRequest.new(%{wf_id: wf_id}), :OK)
    assert gpi_response.project_id == "qwerty"
  end

  defp get_project_id(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.get_project_id(request)

    assert {:ok, gpi_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(gpi_response)
    assert expected_status == status_code
    assert message == msg

    gpi_response |> Map.delete(:status) |> ToTuple.ok()
  end

  # Describe

  test "gRPC describe() - failes when wf_id is omitted" do
    message = "'wf_id' - invalid value: '', it must be a not empty string."

    %{wf_id: ""}
    |> DescribeRequest.new()
    |> describe_workflow(:FAILED_PRECONDITION, message)
  end

  test "gRPC describe() - failes when there is no workflow with given wf_id" do
    wf_id = UUID.uuid4()
    message = "Workflow with id: #{wf_id} not found"

    %{wf_id: wf_id}
    |> DescribeRequest.new()
    |> describe_workflow(:FAILED_PRECONDITION, message)
  end

  test "gRPC describe() - refuse request when there are to many unfinished ones" do
    old_desc = InFlightCounter.set_limit(:describe, 0)

    message = "Too many requests, resources exhausted, try again later."

    %{wf_id: UUID.uuid4()}
    |> DescribeRequest.new()
    |> describe_workflow_error(GRPC.Status.resource_exhausted(), message)

    InFlightCounter.set_limit(:describe, old_desc)
  end

  test "gRPC describe() - succedes when given valid params" do
    ts_before = DateTime.utc_now()

    params = %{
      "project_id" => "qwerty",
      "hook_id" => "asdf",
      "requester_id" => "zxcv",
      "branch_id" => "uiop",
      "branch_name" => "fghj",
      "commit_sha" => String.slice(@test_commit_sha_1, 0, 4),
      "triggered_by" => :SCHEDULE
    }

    assert [{:ok, wf_id, ppl_id}] = WorkflowBuilder.build([{:schedule, nil, params}])

    ts_after = DateTime.utc_now()

    assert {:ok, response} = describe_workflow(DescribeRequest.new(%{wf_id: wf_id}), :OK)
    assert %{workflow: wf} = response |> Proto.to_map!()
    assert wf.wf_id == wf_id
    assert wf.initial_ppl_id == ppl_id
    assert wf.project_id == params["project_id"]
    assert wf.hook_id == params["hook_id"]
    assert wf.requester_id == params["requester_id"]
    assert wf.branch_id == params["branch_id"]
    assert wf.branch_name == params["branch_name"]
    assert wf.commit_sha == params["commit_sha"]
    assert DateTime.compare(ts_before, wf.created_at |> to_date_time()) == :lt
    assert DateTime.compare(wf.created_at |> to_date_time(), ts_after) == :lt
    assert wf.triggered_by == :SCHEDULE
    assert wf.rerun_of == ""
  end

  defp describe_workflow_error(request, expected_status, msg) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")

    assert {:error, %GRPC.RPCError{status: expected_status, message: msg}} ==
             channel |> WorkflowService.Stub.describe(request)
  end

  defp describe_workflow(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.describe(request)

    assert {:ok, describe_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(describe_response)
    assert expected_status == status_code
    assert message == msg

    describe_response |> Map.delete(:status) |> ToTuple.ok()
  end

  defp to_date_time(timestamp) do
    ts_in_microseconds = timestamp.seconds * 1_000_000 + Integer.floor_div(timestamp.nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  # DescribeMany

  test "gRPC describe_many() - returns empty list when wf_ids is empty" do
    assert {:ok, %{workflows: []}} =
      %{wf_ids: []}
      |> DescribeManyRequest.new()
      |> describe_many_workflows(:OK, "")
  end

  test "gRPC describe_many() - fails when there are empty strings in wf_ids" do
    assert {:ok, %{workflows: []}} =
      %{wf_ids: ["", ""]}
      |> DescribeManyRequest.new()
      |> describe_many_workflows(:OK, "")
  end

  test "gRPC describe_many() - retuns empty list when there are no workflows with given ids" do
    assert {:ok, %{workflows: []}} =
      %{wf_ids: [UUID.uuid4(), UUID.uuid4()]}
      |> DescribeManyRequest.new()
      |> describe_many_workflows(:OK, "")
  end

  test "gRPC describe_many() - succeeds when given valid params" do
    ts_before = DateTime.utc_now()

    params = %{
      "project_id" => "qwerty",
      "hook_id" => "asdf",
      "requester_id" => "zxcv",
      "branch_id" => "uiop",
      "branch_name" => "fghj",
      "commit_sha" => String.slice(@test_commit_sha_1, 0, 4),
      "triggered_by" => :SCHEDULE
    }

    assert [{:ok, wf_id1, ppl_id1}] = WorkflowBuilder.build([{:schedule, nil, params}])
    assert [{:ok, wf_id2, ppl_id2}] = WorkflowBuilder.build([{:schedule, nil, params}])

    ts_after = DateTime.utc_now()

    assert {:ok, %{workflows: workflows}} =
      %{wf_ids: [wf_id1, wf_id2]}
      |> DescribeManyRequest.new()
      |> describe_many_workflows(:OK, "")

    for wf <- workflows do
      assert wf.wf_id in [wf_id1, wf_id2]
      assert wf.initial_ppl_id in [ppl_id1, ppl_id2]
      assert wf.project_id == params["project_id"]
      assert wf.hook_id == params["hook_id"]
      assert wf.requester_id == params["requester_id"]
      assert wf.branch_id == params["branch_id"]
      assert wf.branch_name == params["branch_name"]
      assert wf.commit_sha == params["commit_sha"]
      assert DateTime.compare(ts_before, wf.created_at |> to_date_time()) == :lt
      assert DateTime.compare(wf.created_at |> to_date_time(), ts_after) == :lt
      assert wf.triggered_by == 1
      assert wf.rerun_of == ""
    end
  end

  defp describe_many_workflows_error(request, expected_status, msg) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")

    assert {:error, %GRPC.RPCError{status: expected_status, message: msg}} ==
             channel |> WorkflowService.Stub.describe_many(request)
  end

  defp describe_many_workflows(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.describe_many(request)

    assert {:ok, describe_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(describe_response)
    assert expected_status == status_code
    assert message == msg

    describe_response |> Map.delete(:status) |> ToTuple.ok()
  end

  # ListLatestWorkflows

  test "gRPC list_latest_workflows() - fails when project_id is omitted" do
    params = %{project_id: "list_latest_workflows", page_token: "", page_size: 5}

    message =
      params
      |> Map.delete(:project_id)
      |> Proto.deep_new!(ListLatestWorkflowsRequest)
      |> list_latest_workflows(:error)
      |> Map.get(:message)

    assert message == "'project_id' - invalid value: '', it must be a not empty string."
  end

  test "gRPC list_latest_workflows() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params = %{project_id: "list_latest_workflows", page_token: "", page_size: 5}

    error =
      params
      |> Map.delete(:project_id)
      |> Proto.deep_new!(ListLatestWorkflowsRequest)
      |> list_latest_workflows(:error)

    assert error.status == GRPC.Status.resource_exhausted()
    assert error.message == "Too many requests, resources exhausted, try again later."

    InFlightCounter.set_limit(:list, old_list)
  end

  @tag :integration
  test "gRPC list_latest_workflows() - successfully walk the list in both directions" do
    all_wfs =
      Range.new(0, 5)
      |> Enum.map(fn ind ->
        %{
          "label" => label_grouped(ind),
          "branch_name" => label_grouped(ind),
          "hook_id" => hook_id_grouped(ind),
          "project_id" => "list_latest_workflows",
          "repo_name" => "2_basic"
        }
        |> WorkflowBuilder.schedule()
      end)

    ppl_id = all_wfs |> Enum.at(5) |> elem(2)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{
      project_id: "list_latest_workflows",
      git_ref_types: [:BRANCH],
      page_size: 2,
      page_token: ""
    }

    assert {next, ""} = assert_list_latest_workflows_valid(all_wfs, params, [4, 5])

    params = params |> Map.put(:page_token, next)
    assert {next_2, previous} = assert_list_latest_workflows_valid(all_wfs, params, [2, 3])

    params = params |> Map.put(:page_token, next_2)
    assert {"", previous_2} = assert_list_latest_workflows_valid(all_wfs, params, [0, 1])

    params = params |> Map.merge(%{page_token: previous_2, direction: :PREVIOUS})
    assert {next_2, previous} == assert_list_latest_workflows_valid(all_wfs, params, [2, 3])

    params = params |> Map.merge(%{page_token: previous, direction: :PREVIOUS})
    assert {next, ""} == assert_list_latest_workflows_valid(all_wfs, params, [4, 5])
  end

  @tag :integration
  test "gRPC list_latest_workflows() - returns latest workflow per distinct label when given valid params" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "20")

    all_wfs =
      Range.new(0, 17)
      |> Enum.map(fn ind ->
        %{
          "label" => label_grouped(ind),
          "hook_id" => hook_id_grouped(ind),
          "branch_name" => label_grouped(ind),
          "project_id" => "list_latest_workflows",
          "repo_name" => "2_basic"
        }
        |> WorkflowBuilder.schedule()
      end)

    ppl_id = all_wfs |> Enum.at(17) |> elem(2)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # filter by git_ref_types
    params = %{
      project_id: "list_latest_workflows",
      git_ref_types: [:BRANCH],
      page_size: 13,
      page_token: ""
    }

    assert {_next, ""} = assert_list_latest_workflows_valid(all_wfs, params, [0, 5])

    params = params |> Map.put(:git_ref_types, [:BRANCH, :TAG])
    assert {_next, ""} = assert_list_latest_workflows_valid(all_wfs, params, [0, 11])

    params = params |> Map.put(:git_ref_types, [:BRANCH, :TAG, :PR])
    assert {_next, ""} = assert_list_latest_workflows_valid(all_wfs, params, [5, 17])

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  defp assert_list_latest_workflows_valid(all_wfs, params, [lower, upper]) do
    request = params |> Proto.deep_new!(ListLatestWorkflowsRequest)

    assert {:ok, response} = list_latest_workflows(request, :ok)
    assert %{workflows: wfs, next_page_token: n_token, previous_page_token: p_token} = response

    included = all_wfs |> Enum.slice(lower..upper)

    excluded =
      all_wfs
      |> Enum.with_index()
      |> Enum.reject(fn {i, _} -> i < lower or i > upper end)
      |> Enum.map(fn {_, el} -> el end)

    assert list_result_contains?(wfs, included)
    refute list_result_contains?(wfs, excluded)

    {n_token, p_token}
  end

  defp list_latest_workflows(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_latest_workflows(request)

    assert {^expected_status, list_response} = response

    if expected_status == :ok do
      list_response |> Proto.to_map()
    else
      list_response
    end
  end

  # ListGroupedKS

  test "gRPC list_grouped_ks() - fails when project_id is omitted" do
    params = %{project_id: "list_grouped_ks", page_token: "", page_size: 5}

    message =
      params
      |> Map.delete(:project_id)
      |> Proto.deep_new!(ListGroupedKSRequest)
      |> list_grouped_ks(:error)
      |> Map.get(:message)

    assert message == "'project_id' - invalid value: '', it must be a not empty string."
  end

  test "gRPC list_grouped_ks() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params = %{project_id: "list_grouped_ks", page_token: "", page_size: 5}

    error =
      params
      |> Map.delete(:project_id)
      |> Proto.deep_new!(ListGroupedKSRequest)
      |> list_grouped_ks(:error)

    assert error.status == GRPC.Status.resource_exhausted()
    assert error.message == "Too many requests, resources exhausted, try again later."

    InFlightCounter.set_limit(:list, old_list)
  end

  @tag :integration
  test "gRPC list_grouped_ks() - successfully walk the list in both directions" do
    all_wfs =
      Range.new(0, 5)
      |> Enum.map(fn ind ->
        %{
          "label" => label_grouped(ind),
          "hook_id" => hook_id_grouped(ind),
          "project_id" => "list_grouped_ks",
          "repo_name" => "2_basic"
        }
        |> WorkflowBuilder.schedule()
      end)

    ppl_id = all_wfs |> Enum.at(5) |> elem(2)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{
      project_id: "list_grouped_ks",
      git_ref_types: [:BRANCH],
      page_size: 2,
      page_token: ""
    }

    assert {next, ""} = assert_list_grouped_ks_valid(all_wfs, params, [4, 5])

    params = params |> Map.put(:page_token, next)
    assert {next_2, previous} = assert_list_grouped_ks_valid(all_wfs, params, [2, 3])

    params = params |> Map.put(:page_token, next_2)
    assert {"", previous_2} = assert_list_grouped_ks_valid(all_wfs, params, [0, 1])

    params = params |> Map.merge(%{page_token: previous_2, direction: :PREVIOUS})
    assert {next_2, previous} == assert_list_grouped_ks_valid(all_wfs, params, [2, 3])

    params = params |> Map.merge(%{page_token: previous, direction: :PREVIOUS})
    assert {next, ""} == assert_list_grouped_ks_valid(all_wfs, params, [4, 5])
  end

  @tag :integration
  test "gRPC list_grouped_ks() - returns latest workflow per distinct label when given valid params" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "20")

    all_wfs =
      Range.new(0, 17)
      |> Enum.map(fn ind ->
        %{
          "label" => label_grouped(ind),
          "hook_id" => hook_id_grouped(ind),
          "project_id" => "list_grouped_ks",
          "repo_name" => "2_basic"
        }
        |> WorkflowBuilder.schedule()
      end)

    ppl_id = all_wfs |> Enum.at(17) |> elem(2)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # filter by git_ref_types
    params = %{
      project_id: "list_grouped_ks",
      git_ref_types: [:BRANCH],
      page_size: 13,
      page_token: ""
    }

    assert {_next, ""} = assert_list_grouped_ks_valid(all_wfs, params, [0, 5])

    params = params |> Map.put(:git_ref_types, [:BRANCH, :TAG])
    assert {_next, ""} = assert_list_grouped_ks_valid(all_wfs, params, [0, 11])

    params = params |> Map.put(:git_ref_types, [:BRANCH, :TAG, :PR])
    assert {_next, ""} = assert_list_grouped_ks_valid(all_wfs, params, [5, 17])

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  defp assert_list_grouped_ks_valid(all_wfs, params, [lower, upper]) do
    request = params |> Proto.deep_new!(ListGroupedKSRequest)

    assert {:ok, response} = list_grouped_ks(request, :ok)
    assert %{workflows: wfs, next_page_token: n_token, previous_page_token: p_token} = response

    included = all_wfs |> Enum.slice(lower..upper)

    excluded =
      all_wfs
      |> Enum.with_index()
      |> Enum.reject(fn {i, _} -> i < lower or i > upper end)
      |> Enum.map(fn {_, el} -> el end)

    assert list_result_contains?(wfs, included)
    refute list_result_contains?(wfs, excluded)

    {n_token, p_token}
  end

  defp list_grouped_ks(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_grouped_ks(request)

    assert {^expected_status, list_response} = response

    if expected_status == :ok do
      list_response |> Proto.to_map()
    else
      list_response
    end
  end

  # ListGrouped

  test "gRPC list_grouped() - fails when project_id is omitted" do
    params = %{project_id: "list_grouped", page: 1, page_size: 5}

    message = "'project_id' - invalid value: '', it must be a not empty string."

    params
    |> Map.delete(:project_id)
    |> ListGroupedRequest.new()
    |> list_grouped(:INVALID_ARGUMENT, message)
  end

  test "gRPC list_grouped() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params = %{project_id: "list_grouped", page: 1, page_size: 5}

    message = "Too many requests, resources exhausted, try again later."

    params
    |> Map.delete(:project_id)
    |> ListGroupedRequest.new()
    |> list_grouped_error(GRPC.Status.resource_exhausted())

    InFlightCounter.set_limit(:list, old_list)
  end

  @tag :integration
  test "gRPC list_grouped() - returns latest workflow per distinct label when given valid params" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "20")

    all_wfs =
      Range.new(0, 17)
      |> Enum.map(fn ind ->
        %{
          "label" => label_grouped(ind),
          "hook_id" => hook_id_grouped(ind),
          "project_id" => "list_grouped",
          "repo_name" => "2_basic"
        }
        |> WorkflowBuilder.schedule()
      end)

    ppl_id = all_wfs |> Enum.at(17) |> elem(2)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 12_000)
    Test.Helpers.stop_all_loopers(loopers)

    # filter by git_ref_types
    params = %{project_id: "list_grouped", git_ref_types: [:BRANCH], page: 3, page_size: 2}
    assert_list_grouped_valid(all_wfs, params, [0, 1, 6, 3])

    params = params |> Map.put(:git_ref_types, [:BRANCH, :TAG])
    assert_list_grouped_valid(all_wfs, params, [6, 7, 12, 6])

    params = params |> Map.put(:git_ref_types, [:BRANCH, :TAG, :PR])
    assert_list_grouped_valid(all_wfs, params, [12, 13, 18, 9])

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  defp assert_list_grouped_valid(all_wfs, params, boundries) do
    request = params |> Proto.deep_new!(ListGroupedRequest)

    [lower, upper, tot_entries, tot_pages] = boundries

    assert {:ok, response} = list_grouped(request, :OK)

    assert %{
             workflows: wfs,
             page_number: 3,
             total_pages: tot_pages,
             total_entries: tot_entries,
             page_size: 2
           } = response

    included = all_wfs |> Enum.slice(lower..upper)

    excluded =
      all_wfs
      |> Enum.with_index()
      |> Enum.reject(fn {i, _} -> i < lower or i > upper end)
      |> Enum.map(fn {_, el} -> el end)

    assert list_result_contains?(wfs, included)
    refute list_result_contains?(wfs, excluded)
  end

  defp label_grouped(ind) when ind < 6, do: "master-" <> Integer.to_string(ind)
  defp label_grouped(ind) when ind < 12, do: "refs/tags/v1." <> Integer.to_string(ind)
  defp label_grouped(ind), do: "pull-request-12" <> Integer.to_string(ind)

  defp hook_id_grouped(ind) when ind < 6, do: "branch"
  defp hook_id_grouped(ind) when ind < 12, do: "tag"
  defp hook_id_grouped(ind), do: "pr"

  defp list_grouped_error(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_grouped(request)

    assert {:error, %{status: ^expected_status}} = response
  end

  defp list_grouped(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_grouped(request)

    assert {:ok, ll_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(ll_response)
    assert expected_status == status_code
    assert message == msg

    ll_response |> Map.delete(:status) |> ToTuple.ok()
  end

  # ListLabels

  test "gRPC list_labels() - fails when project_id is omitted" do
    params = %{project_id: "list_labels", page: 1, page_size: 5}

    message = "'project_id' - invalid value: '', it must be a not empty string."

    params
    |> Map.delete(:project_id)
    |> ListLabelsRequest.new()
    |> list_labels(:INVALID_ARGUMENT, message)
  end

  test "gRPC list_labels() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params = %{project_id: "list_labels", page: 1, page_size: 5}

    message = "Too many requests, resources exhausted, try again later."

    params
    |> Map.delete(:project_id)
    |> ListLabelsRequest.new()
    |> list_labels_error(GRPC.Status.resource_exhausted(), message)

    InFlightCounter.set_limit(:list, old_list)
  end

  test "gRPC list_labels() - rerurns distinct label values when given valid params" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "15")

    all_labels =
      Range.new(0, 11)
      |> Enum.map(fn ind ->
        label = label(ind)
        WorkflowBuilder.schedule(%{"branch_name" => label, "project_id" => "list_labels"})
        label
      end)

    params =
      %{project_id: "list_labels", page: 1, page_size: 5}
      |> ListLabelsRequest.new()

    assert {:ok, response} = list_labels(params, :OK)

    assert %{labels: labels, page_number: 1, page_size: 5, total_entries: 10, total_pages: 2} =
             response

    excluded = all_labels |> Enum.slice(0..4)
    included = all_labels |> Enum.slice(5..11)

    assert list_labels_result_contains?(labels, included)
    refute list_labels_result_contains?(labels, excluded)

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  defp label(ind) when ind < 9, do: "label-" <> Integer.to_string(ind)
  defp label(_ind), do: "label-9"

  defp list_labels_error(request, expected_status, msg) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_labels(request)

    assert {:error, %{status: ^expected_status, message: ^msg}} = response
  end

  defp list_labels(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_labels(request)

    assert {:ok, ll_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(ll_response)
    assert expected_status == status_code
    assert message == msg

    ll_response |> Map.delete(:status) |> ToTuple.ok()
  end

  defp list_labels_result_contains?(results, included) do
    Enum.reduce(included, true, fn label, acc ->
      case acc do
        false ->
          false

        true ->
          Enum.find_value(results, false, fn res_label -> label == res_label end)
      end
    end)
  end

  # ListKeyset

  test "gRPC list_keyset() - failes when  project_ids, project_id and organization_id is omitted" do
    params = %{
      project_id: "list_keyset",
      organization_id: "org1",
      requester_id: "123",
      branch_name: "master",
      page_size: 5,
      project_ids: ["1234"]
    }

    message = "One of 'project_ids', 'project_id' or 'organization_id' parameters is required."

    params
    |> Map.drop([:project_ids, :project_id, :organization_id])
    |> ListKeysetRequest.new()
    |> list_keyset(:INVALID_ARGUMENT, message)
  end

  test "gRPC list_keyset() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params = %{project_id: "list_keyset", branch_name: "master", page_size: 5}

    message = "Too many requests, resources exhausted, try again later."

    params
    |> ListKeysetRequest.new()
    |> list_keyset_error(GRPC.Status.resource_exhausted(), message)

    InFlightCounter.set_limit(:list, old_list)
  end

  test "gRPC list_keyset() - filtering by triggers" do
    wfs = Range.new(0, 9) |> Enum.map(fn ind -> WorkflowBuilder.schedule(keyset_params(ind)) end)

    params =
      %{
        project_id: "list_keyset",
        branch_name: "to_list",
        page_size: 5,
        triggerers: [:HOOK, :SCHEDULE]
      }
      |> Proto.deep_new!(ListKeysetRequest)

    assert {:ok, response} = list_keyset(params, :OK)
    assert %{workflows: workflows, next_page_token: token, previous_page_token: ""} = response

    excluded =
      wfs
      |> Enum.with_index()
      |> Enum.filter(fn {a, i} -> i in [0, 1, 2, 5, 8] end)
      |> Enum.map(fn {a, i} -> a end)

    included =
      wfs
      |> Enum.with_index()
      |> Enum.reject(fn {a, i} -> i in [0, 1, 2, 5, 8] end)
      |> Enum.map(fn {a, i} -> a end)

    assert list_result_contains?(workflows, included)
    refute list_result_contains?(workflows, excluded)

    params =
      %{project_id: "list_keyset", branch_name: "to_list", page_size: 5, triggerers: [:API]}
      |> Proto.deep_new!(ListKeysetRequest)

    assert {:ok, response} = list_keyset(params, :OK)
    assert %{workflows: workflows, next_page_token: token, previous_page_token: ""} = response

    excluded =
      wfs
      |> Enum.with_index()
      |> Enum.filter(fn {a, i} -> i in [0, 1, 3, 4, 6, 7, 9] end)
      |> Enum.map(fn {a, i} -> a end)

    included =
      wfs
      |> Enum.with_index()
      |> Enum.reject(fn {a, i} -> i in [0, 1, 3, 4, 6, 7, 9] end)
      |> Enum.map(fn {a, i} -> a end)

    assert list_result_contains?(workflows, included)
    refute list_result_contains?(workflows, excluded)
  end

  test "gRPC list_keyset() - succeeds when given valid params" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "15")

    wfs = Range.new(0, 9) |> Enum.map(fn ind -> WorkflowBuilder.schedule(keyset_params(ind)) end)

    params =
      %{project_id: "list_keyset", branch_name: "to_list", page_size: 5}
      |> Proto.deep_new!(ListKeysetRequest)

    assert {:ok, response} = list_keyset(params, :OK)
    assert %{workflows: workflows, next_page_token: token, previous_page_token: ""} = response

    excluded = wfs |> Enum.slice(0..4)
    included = wfs |> Enum.slice(5..9)

    assert list_result_contains?(workflows, included)
    refute list_result_contains?(workflows, excluded)

    params =
      %{project_id: "list_keyset", branch_name: "to_list", page_size: 5, page_token: token}
      |> Proto.deep_new!(ListKeysetRequest)

    assert {:ok, response} = list_keyset(params, :OK)
    assert %{workflows: workflows, next_page_token: "", previous_page_token: p_token} = response

    included = wfs |> Enum.slice(0..4)
    excluded = wfs |> Enum.slice(5..9)

    assert list_result_contains?(workflows, included)
    refute list_result_contains?(workflows, excluded)

    params =
      %{
        project_id: "list_keyset",
        branch_name: "to_list",
        page_size: 5,
        page_token: p_token,
        direction: :PREVIOUS
      }
      |> Proto.deep_new!(ListKeysetRequest)

    assert {:ok, response} = list_keyset(params, :OK)
    assert %{workflows: workflows, next_page_token: ^token, previous_page_token: ""} = response

    excluded = wfs |> Enum.slice(0..4)
    included = wfs |> Enum.slice(5..9)

    assert list_result_contains?(workflows, included)
    refute list_result_contains?(workflows, excluded)

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  defp list_keyset_error(request, expected_status, msg) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_keyset(request)

    assert {:error, %{status: ^expected_status, message: ^msg}} = response
  end

  defp list_keyset(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list_keyset(request)

    assert {:ok, list_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(list_response)
    assert expected_status == status_code
    assert message == msg

    list_response |> Map.delete(:status) |> ToTuple.ok()
  end

  defp keyset_params(index, params \\ %{}) do
    %{
      "branch_name" => "to_list",
      "project_id" => "list_keyset",
      "label" => "to_list",
      "commit_sha" => String.slice(@test_commit_sha_1, 0, 3) <> Integer.to_string(index),
      "organization_id" => "org1",
      "repo_name" => "2_basic",
      "triggered_by" => rem(index, 3)
    }
    |> Map.merge(params)
  end

  # List

  test "gRPC list() - failes when  project_ids, project_id and organization_id is omitted" do
    params = %{
      project_id: "list_project",
      organization_id: "org1",
      requester_id: "123",
      branch_name: "master",
      page: 1,
      page_size: 5,
      project_ids: ["1234"]
    }

    message = "One of 'project_ids', 'project_id' or 'organization_id' parameters is required."

    params
    |> Map.drop([:project_ids, :project_id, :organization_id])
    |> ListRequest.new()
    |> list_workflows(:INVALID_ARGUMENT, message)
  end

  test "gRPC list() - refuse request when there are to many unfinished ones" do
    old_list = InFlightCounter.set_limit(:list, 0)

    params = %{project_id: "list_project", branch_name: "master", page: 1, page_size: 5}

    message = "Too many requests, resources exhausted, try again later."

    params
    |> Map.delete(:project_id)
    |> ListRequest.new()
    |> list_workflows_error(GRPC.Status.resource_exhausted(), message)

    InFlightCounter.set_limit(:list, old_list)
  end

  test "gRPC list() - succeeds when given valid params" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "15")

    wfs = Range.new(0, 9) |> Enum.map(fn ind -> WorkflowBuilder.schedule(list_params(ind)) end)

    params =
      %{project_id: "list_project", branch_name: "to_list", page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, response} = list_workflows(params, :OK)

    assert %{
             workflows: workflows,
             page_number: 1,
             page_size: 5,
             total_entries: 10,
             total_pages: 2
           } = response

    excluded = wfs |> Enum.slice(0..4)
    included = wfs |> Enum.slice(5..9)

    assert list_result_contains?(workflows, included)
    refute list_result_contains?(workflows, excluded)

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  test "gRPC list() - filter by branch_name" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "15")

    wf_1 = WorkflowBuilder.schedule(list_params(0))
    wf_2 = WorkflowBuilder.schedule(list_params(0, %{"branch_name" => "dev"}))

    # list only with project_id returns both workflows
    params = %{project_id: "list_project", page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{workflows: wfs, total_entries: 2}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_1, wf_2])

    # list with branch=dev returns second workflow
    params =
      %{project_id: "list_project", branch_name: "dev", page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{workflows: wfs, total_entries: 1}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_2])

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  @tag :integration
  test "gRPC list() - filter by label and git_ref_types" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "15")

    wf_1 = WorkflowBuilder.schedule(list_params(0))

    wf_2 =
      WorkflowBuilder.schedule(
        list_params(0, %{"label" => "v1.0", "hook_id" => "tag", "branch_name" => "refs/tag/v1.0"})
      )

    wf_3 =
      WorkflowBuilder.schedule(
        list_params(0, %{"label" => "123", "hook_id" => "pr", "branch_name" => "pull-request-123"})
      )

    ppl_id = elem(wf_3, 2)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # list with label=123 returns third wf
    params =
      %{project_id: "list_project", label: "123", page: 1, page_size: 5} |> ListRequest.new()

    assert {:ok, %{workflows: wfs, total_entries: 1}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_3])

    # list with git_ref_types = ["branch", "tag"] returns first and second wf
    params =
      %{project_id: "list_project", git_ref_types: [:BRANCH, :TAG], page: 1, page_size: 5}
      |> Proto.deep_new!(ListRequest)

    assert {:ok, %{workflows: wfs, total_entries: 2}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_1, wf_2])

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  test "gRPC list() -  fails when created_after is after created_before" do
    ts_1 = DateTime.utc_now()
    :timer.sleep(50)
    ts_2 = DateTime.utc_now()

    message =
      "Inavlid values od fields 'created_after' and 'created_before' - first has to be before second."

    %{project_id: "123", page: 1, page_size: 5, created_after: ts_2, created_before: ts_1}
    |> Proto.deep_new!(
      ListRequest,
      transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
    )
    |> list_workflows(:INVALID_ARGUMENT, message)
  end

  test "gRPC list() - filter by created_before(after)" do
    ts_1 = DateTime.utc_now()

    wf_1 = WorkflowBuilder.schedule(list_params(0))

    ts_2 = DateTime.utc_now()

    wf_2 = WorkflowBuilder.schedule(list_params(0))

    ts_3 = DateTime.utc_now()

    # created_before
    assert_ts_list_valid(ts_1, nil, [], [wf_1, wf_2])
    assert_ts_list_valid(ts_2, nil, [wf_1], [wf_2])
    assert_ts_list_valid(ts_3, nil, [wf_1, wf_2], [])

    # created_after
    assert_ts_list_valid(nil, ts_1, [wf_1, wf_2], [])
    assert_ts_list_valid(nil, ts_2, [wf_2], [wf_1])
    assert_ts_list_valid(nil, ts_3, [], [wf_1, wf_2])

    # created_before & created_after
    assert_ts_list_valid(ts_2, ts_1, [wf_1], [wf_2])
    assert_ts_list_valid(ts_3, ts_1, [wf_1, wf_2], [])
    assert_ts_list_valid(ts_3, ts_2, [wf_2], [wf_1])
  end

  defp assert_ts_list_valid(cb, ca, included, excluded) do
    params =
      %{project_id: "list_project", page: 1, page_size: 5}
      |> add_timestamp(:created_before, cb)
      |> add_timestamp(:created_after, ca)
      |> Proto.deep_new!(
        ListRequest,
        transformations: %{Timestamp => {__MODULE__, :date_time_to_timestamps}}
      )

    assert {:ok, %{workflows: wfs}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, included)
    refute list_result_contains?(wfs, excluded)
  end

  defp add_timestamp(map, _key, nil), do: map
  defp add_timestamp(map, key, value), do: Map.put(map, key, value)

  def date_time_to_timestamps(_field_name, nil), do: %{seconds: 0, nanos: 0}

  def date_time_to_timestamps(_field_name, date_time = %DateTime{}) do
    %{}
    |> Map.put(:seconds, DateTime.to_unix(date_time, :second))
    |> Map.put(:nanos, elem(date_time.microsecond, 0) * 1_000)
  end

  test "gRPC list() - filter by requester_id" do
    old_limit = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "15")

    wf_1 = WorkflowBuilder.schedule(list_params(0))
    wf_2 = WorkflowBuilder.schedule(list_params(0, %{"requester_id" => "user1"}))

    wf_3 =
      WorkflowBuilder.schedule(
        list_params(0, %{"requester_id" => "user1", "project_id" => "second_project"})
      )

    # list only with organization_id returns all workflows
    params = %{organization_id: "org1", page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{workflows: wfs, total_entries: 3}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_1, wf_2, wf_3])

    # list with requester_id=user1 and org_id=org1 returns second and third workflow
    params =
      %{organization_id: "org1", requester_id: "user1", page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{workflows: wfs, total_entries: 2}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_2, wf_3])

    # list with requester_id=user1 and project_id=second_project returns only third workflow
    params =
      %{project_id: "second_project", requester_id: "user1", page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{workflows: wfs, total_entries: 1}} = list_workflows(params, :OK)
    assert list_result_contains?(wfs, [wf_3])

    System.put_env("PPL_QUEUE_LIMIT", old_limit)
  end

  defp list_params(index, params \\ %{}) do
    %{
      "branch_name" => "to_list",
      "project_id" => "list_project",
      "label" => "to_list",
      "commit_sha" => String.slice(@test_commit_sha_1, 0, 3) <> Integer.to_string(index),
      "organization_id" => "org1",
      "repo_name" => "2_basic"
    }
    |> Map.merge(params)
  end

  defp list_workflows_error(request, expected_status, msg) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list(request)

    assert {:error, %{status: ^expected_status, message: ^msg}} = response
  end

  defp list_workflows(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.list(request)

    assert {:ok, list_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(list_response)
    assert expected_status == status_code
    assert message == msg

    list_response |> Map.delete(:status) |> ToTuple.ok()
  end

  defp list_result_contains?(results, []), do: length(results) == 0

  defp list_result_contains?(results, included) do
    Enum.reduce(included, true, fn {:ok, wf_id, ppl_id}, acc ->
      case acc do
        false -> false
        true -> workflow_in_results?(wf_id, ppl_id, results)
      end
    end)
  end

  defp workflow_in_results?(wf_id, ppl_id, results) do
    Enum.find_value(results, false, fn wf_desc ->
      wf_desc.wf_id == wf_id and wf_desc.initial_ppl_id == ppl_id
    end)
  end

  # GetPath

  @tag :integration
  test "gRPC get_path() - works for all combinations of request params" do
    Test.Helpers.start_all_loopers()

    topology = [
      {:schedule, nil},
      {:schedule_extension, 0},
      {:partial_rebuild, 1},
      {:schedule_extension, 0},
      {:partial_rebuild, 3},
      {:schedule_extension, 2}
    ]

    result = WorkflowBuilder.build(topology)

    wf_id = result |> Enum.at(0) |> elem(1)

    expected_path = [
      %{ppl_id: get_id(result, 0), switch_id: "", rebuild_partition: [get_id(result, 0)]},
      %{
        ppl_id: get_id(result, 2),
        switch_id: "",
        rebuild_partition: [get_id(result, 1), get_id(result, 2)]
      },
      %{ppl_id: get_id(result, 5), switch_id: "", rebuild_partition: [get_id(result, 5)]}
    ]

    response = %{wf_id: wf_id} |> GetPathRequest.new() |> assert_get_path_valid(:OK)
    assert response |> Proto.to_map!() |> Map.get(:path) == expected_path
  end

  defp get_id(list, index), do: list |> Enum.at(index) |> elem(2)

  defp assert_get_path_valid(request, expected_status) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.get_path(request)

    assert {:ok, path_response} = response
    assert %{status: %{code: status_code}} = Proto.to_map!(path_response)
    assert expected_status == status_code
    path_response
  end

  # Terminate

  test "gRPC terminate() - fails when requester_id is empty " do
    wf_id = args(:v1, :full) |> assert_schedule_response_status(:OK)

    request = %{wf_id: wf_id} |> TerminateRequest.new()

    assert "'requester_id' - invalid value: '', it must be a not empty string." ==
             terminate_wf(request, :INVALID_ARGUMENT)
  end

  test "gRPC terminate() - fails when wf_id is empty " do
    request = %{requester_id: "user_1"} |> TerminateRequest.new()

    assert "'wf_id' - invalid value: '', it must be a not empty string." ==
             terminate_wf(request, :INVALID_ARGUMENT)
  end

  test "gRPC terminate() - fails when non-existing workflow id is given" do
    request = %{wf_id: "non-existing", requester_id: "user_1"} |> TerminateRequest.new()

    assert "Workflow with id: non-existing not found." ==
             terminate_wf(request, :FAILED_PRECONDITION)
  end

  @tag :integration
  test "gRPC terminate() - suceeds when given valid params" do
    wf_id = args(:v1, :extension) |> assert_schedule_response_status(:OK)
    assert {:ok, ppl_req} = PplRequestsQueries.get_initial_wf_ppl(wf_id)
    ppl_id_1 = ppl_req.id
    assert {:ok, ppl_id_2} = schedule_extension(ppl_id_1, :OK)

    assert_pipelines_termianted([ppl_id_1, ppl_id_2], wf_id)

    assert {:ok, ppl_id_3} = partial_rebuild(ppl_id_1, :OK)
    assert {:ok, ppl_id_4} = validate_yaml(ppl_id_2, :OK, valid_definition())

    assert_pipelines_termianted([ppl_id_3, ppl_id_4], wf_id)
  end

  defp assert_pipelines_termianted(ppl_ids, wf_id) do
    loopers = start_loopers_running()

    ppl_ids
    |> Enum.map(fn ppl_id ->
      {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "running", 5_000)
    end)

    request = %{wf_id: wf_id, requester_id: "user_1"} |> TerminateRequest.new()

    assert "Termination started for #{length(ppl_ids)} pipelines." ==
             terminate_wf(request, :OK)

    loopers =
      loopers
      |> Enum.concat([Ppl.Ppls.STMHandler.RunningState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.StoppingState.start_link()])
      |> Enum.concat([Ppl.PplBlocks.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.PplBlocks.STMHandler.WaitingState.start_link()])

    ppl_ids
    |> Enum.map(fn ppl_id ->
      {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 5_000)
    end)

    stop_loopers(loopers)
  end

  defp terminate_wf(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.terminate(request)

    assert {:ok, terminate_response} = response

    assert %{status: %{code: status_code, message: message}} = Proto.to_map!(terminate_response)

    assert expected_status == status_code
    message
  end

  defp schedule_extension(ppl_id, expected_status) do
    request =
      %{
        file_path: "../foo/bar/test.yml",
        request_token: UUID.uuid4(),
        ppl_id: ppl_id,
        prev_ppl_artefact_ids: [ppl_id]
      }
      |> ScheduleExtensionRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.schedule_extension(request)

    assert {:ok, sch_ext_response} = response

    assert %{ppl_id: ppl_id, response_status: %{code: status_code}} =
             Proto.to_map!(sch_ext_response)

    assert expected_status == status_code

    {:ok, ppl_id}
  end

  defp partial_rebuild(ppl_id, expected_status) do
    request =
      %{ppl_id: ppl_id, request_token: UUID.uuid4()}
      |> PartialRebuildRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.partial_rebuild(request)

    assert {:ok, rebuild_response} = response

    assert %{ppl_id: ppl_id, response_status: %{code: status_code}} =
             Proto.to_map!(rebuild_response)

    assert expected_status == status_code

    {:ok, ppl_id}
  end

  defp validate_yaml(ppl_id, expected_status, definition) do
    request =
      %{yaml_definition: definition, ppl_id: ppl_id}
      |> ValidateYamlRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.validate_yaml(request)

    assert {:ok, validate_response} = response

    assert %{ppl_id: ppl_id, response_status: %{code: status_code}} =
             Proto.to_map!(validate_response)

    assert expected_status == status_code

    {:ok, ppl_id}
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

  # Schedule

  test "gRPC schedule() - full v1 specification" do
    %{
      service: enum_val("local"),
      repo_name: "5_v1_full",
      request_token: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }
    |> assert_schedule_response_status(:OK)
  end

  test "gRPC schedule() - bitbucket repo" do
    %{
      service: enum_val("bitbucket"),
      repo_name: "5_v1_full",
      request_token: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }
    |> assert_schedule_response_status(:OK)
  end

  test "gRPC schedule() - git repo" do
    %{
      service: enum_val("git"),
      repo_name: "5_v1_full",
      request_token: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }
    |> assert_schedule_response_status(:OK)
  end

  test "gRPC schedule() - gitlab repo" do
    %{
      service: enum_val("gitlab"),
      repo_name: "5_v1_full",
      request_token: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }
    |> assert_schedule_response_status(:OK)
  end

  test "gRPC schedule() - empty request_token" do
    %{
      service: enum_val("local"),
      repo_name: "2_basic",
      request_token: "",
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }
    |> assert_schedule_response_status(:INVALID_ARGUMENT)
  end

  test "gRPC schedule() - persists scheduler_task_id" do
    request_token = UUID.uuid4()

    %{
      service: enum_val("local"),
      repo_name: "2_basic",
      request_token: request_token,
      requester_id: UUID.uuid4(),
      branch_id: "",
      hook_id: "",
      scheduler_task_id: "scheduler_task_id"
    }
    |> assert_schedule_response_status(:OK)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_request_token(request_token)
    assert ppl_req.request_args |> Map.get("scheduler_task_id") == "scheduler_task_id"

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_req.id)
    assert ppl.scheduler_task_id == "scheduler_task_id"

    assert {:ok, ppl_req} = PplSubInitsQueries.get_by_id(ppl_req.id)
    assert ppl_req.state == "conceived"
  end

  @tag :integration
  test "gRPC schedule() - limit exceeded" do
    old_env = System.get_env("PPL_QUEUE_LIMIT")
    System.put_env("PPL_QUEUE_LIMIT", "2")
    first_req_token = UUID.uuid4()

    args = %{
      owner: "psr",
      repo_name: "2_basic",
      branch_id: "456",
      hook_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      service: enum_val("local"),
      commit_sha: @test_commit_sha_2,
      branch_name: "master",
      request_token: first_req_token,
      project_id: "123"
    }

    # First
    _wf_id = args |> assert_schedule_response_status(:OK)
    assert {:ok, ppl_req} = PplRequestsQueries.get_by_request_token(first_req_token)

    loopers = start_loopers_running()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_req.id, "running", 5_000)

    # Second
    second_req_token = UUID.uuid4()

    _wf_id =
      %{args | request_token: second_req_token}
      |> assert_schedule_response_status(:OK)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_request_token(second_req_token)

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_req.id, "queuing", 5_000)
    stop_loopers(loopers)

    # Third
    args |> assert_schedule_response_status(:RESOURCE_EXHAUSTED)
    System.put_env("PPL_QUEUE_LIMIT", old_env)
  end

  defp start_loopers_running() do
    []
    # Ppls loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    # PplSubInits loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn {:ok, pid} -> GenServer.stop(pid) end)
  end

  test "gRPC schedule() - refuse if project deletion was requested" do
    assert {:ok, message} = delete_ppls_from_project("to-delete")
    assert message == "Pipelines from given project are scheduled for deletion."

    args(:v1, :full)
    |> Map.merge(%{project_id: "to-delete"})
    |> assert_schedule_response_status(:FAILED_PRECONDITION)
  end

  defp delete_ppls_from_project(project_id) do
    {:ok, request} = Proto.deep_new(DeleteRequest, %{project_id: project_id, requester: "sudo"})

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> PipelineService.Stub.delete(request)

    assert {:ok, delete_response} = response
    assert %{status: %{code: :OK, message: message}} = Proto.to_map!(delete_response)
    {:ok, message}
  end

  # Create

  test "gRPC create() - create workflow" do
    %{
      service: 3,
      project_id: UUID.uuid4(),
      request_token: UUID.uuid4(),
      label: "some_label",
      organization_id: UUID.uuid4()
    }
    |> InternalApi.PlumberWF.CreateRequest.new()
    |> create_wf()
  end

  ########

  defp assert_correct_branch(req_token, branch) do
    val =
      req_token
      |> PplRequestsQueries.get_by_request_token()
      |> elem(1)
      |> Map.get(:request_args)
      |> Map.get("branch_name")

    assert val == branch
  end

  defp assert_schedule_response_status(args, expected_status) do
    args |> form_schedule_request() |> schedule_wf(expected_status)
  end

  defp schedule_wf(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.schedule(request)

    assert {:ok, schedule_response} = response
    assert %{wf_id: wf_id, status: %{code: ^expected_status}} = Proto.to_map!(schedule_response)

    wf_id
  end

  defp create_wf(request) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.create(request)

    assert {:ok, schedule_response} = response
    assert %{wf_id: wf_id} = Proto.to_map!(schedule_response)

    wf_id
  end

  defp args(:v1, :basic),
    do: %{
      service: enum_val("local"),
      repo_name: "2_basic",
      hook_id: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      request_token: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }

  defp args(:v1, :full),
    do: %{
      service: enum_val("local"),
      repo_name: "5_v1_full",
      hook_id: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      request_token: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }

  defp args(:v1, :deleted_test),
    do: %{
      service: enum_val("local"),
      repo_name: "9_build_deleted_test",
      requester_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      request_token: UUID.uuid4()
    }

  defp args(:v1, :extension),
    do: %{
      service: enum_val("local"),
      repo_name: "10_schedule_extension",
      branch_id: UUID.uuid4(),
      hook_id: UUID.uuid4(),
      request_token: UUID.uuid4(),
      requester_id: UUID.uuid4()
    }

  defp enum_val("git_hub"), do: 0
  defp enum_val("local"), do: 1
  defp enum_val("bitbucket"), do: 3
  defp enum_val("gitlab"), do: 4
  defp enum_val("git"), do: 5

  defp form_schedule_request(opts) do
    %{}
    |> Map.merge(%{hook_id: Map.get(opts, :hook_id)})
    |> Map.merge(%{requester_id: Map.get(opts, :requester_id)})
    |> Map.merge(%{request_token: Map.get(opts, :request_token)})
    |> Map.merge(%{branch_id: Map.get(opts, :branch_id)})
    |> Map.merge(%{service: Map.get(opts, :service)})
    |> Map.merge(%{repo: repo_field(opts)})
    |> Map.merge(%{project_id: get_it_or_rand(opts, :project_id)})
    |> Map.merge(%{organization_id: get_it_or_rand(opts, :organization_id)})
    |> Map.merge(%{scheduler_task_id: Map.get(opts, :scheduler_task_id, "")})
    |> ScheduleRequest.new()
  end

  defp repo_field(opts) do
    [:owner, :repo_name, :branch_name, :commit_sha]
    |> Enum.reduce(%{}, fn field, acc ->
      %{} |> Map.put(field, get_it_or_rand(opts, field)) |> Map.merge(acc)
    end)
    |> ScheduleRequest.Repo.new()
  end

  defp get_it_or_rand(opts, filed), do: Map.get(opts, filed) || UUID.uuid4()
end
