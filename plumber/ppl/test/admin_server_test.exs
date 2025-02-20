defmodule Ppl.Admin.Server.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias InternalApi.Plumber.{Admin, TerminateAllRequest, GetYamlRequest}
  alias Ppl.Actions
  alias Util.Proto

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "get_yaml returns yaml definition for existing pipeline" do
    assert {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 7_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert {:ok, ppl_or} = PplOriginsQueries.get_by_id(ppl_id)

    yaml = assert_get_yaml_returns(ppl_id, :ok)
    assert yaml == ppl_or.initial_definition
  end

  test "get_yaml returns error for non-existing pipeline" do
    id = UUID.uuid4()
    message = inspect({:error, "Pipeline origin for pipeline with id: #{id} not found"})
    yaml = assert_get_yaml_returns(id, :error, message)
    assert yaml == ""
  end

  defp assert_get_yaml_returns(ppl_id, expected_status, expected_message \\ "") do
    request = %{ppl_id: ppl_id} |> GetYamlRequest.new()

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> Admin.Stub.get_yaml(request)

    assert {:ok, get_all_response} = response
    assert %{yaml: yaml, response_status: %{code: status_code, message: message}}
             = get_all_response
    assert code(expected_status) == status_code
    assert message == expected_message
    yaml
  end

  test "set admin termination flags for all pipelines from given branch of given project" do
    ppls = Range.new(0, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)

    # First to done, second to runnning, and every other to queuing
    ppls |> Enum.map(fn ppl -> to_state(ppl, "queuing") end)
    ppls |> Enum.at(0) |> to_state("done")
    ppls |> Enum.at(1) |> to_state("running")

    assert_terminate_all(:ok, "Termination started for 9 pipelines.", :ADMIN_ACTION)

    assert_ppls_termination_flags_set(ppls, :ADMIN_ACTION)
  end

  test "set branch deletion termination flags for all pipelines from given branch of given project" do
    ppls = Range.new(0, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)

    # First to done, second to runnning, and every other to queuing
    ppls |> Enum.map(fn ppl -> to_state(ppl, "queuing") end)
    ppls |> Enum.at(0) |> to_state("done")
    ppls |> Enum.at(1) |> to_state("running")

    assert_terminate_all(:ok, "Termination started for 9 pipelines.", :BRANCH_DELETION)

    assert_ppls_termination_flags_set(ppls, :BRANCH_DELETION)
  end

  defp assert_ppls_termination_flags_set(ppls, reason) do
    ppls
    |> Enum.drop(2)
    |> Enum.map(fn ppl ->
          assert {:ok, from_db} = PplsQueries.get_by_id(ppl.ppl_id)
          assert from_db.terminate_request == "stop"
          assert from_db.terminate_request_desc == description(reason)
          assert from_db.terminated_by == terminated_by(reason)
       end)
  end

  defp description(:ADMIN_ACTION), do: "admin action"
  defp description(:BRANCH_DELETION), do: "branch deletion"

  defp terminated_by(:ADMIN_ACTION), do: "admin"
  defp terminated_by(:BRANCH_DELETION), do: "branch deletion"

  defp assert_terminate_all(expected_status, expected_message, reason) do
    request = %{project_id: "123", branch_name: "master", reason: reason}
              |> Proto.deep_new!(TerminateAllRequest)

    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> Admin.Stub.terminate_all(request)

    assert {:ok, terminate_all_response} = response
    assert %{response_status: %{code: status_code, message: message}} = terminate_all_response
    assert code(expected_status) == status_code
    assert message == expected_message
  end

  defp insert_new_ppl(index) do
    request_args = %{"branch_name"=> "master", "commit_sha" => "sha" <> Integer.to_string(index),
                     "project_id" => "123"} |> Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    blocks = [%{"build" => build}, %{"build" => build}]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v3.0", "agent" => agent,
                      "blocks" => blocks}

    request_args = Map.put(request_args, "request_token", UUID.uuid4())
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    ppl
  end

  def query_params() do
    %{initial_query: Ppl.Ppls.Model.Ppls, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.Ppls.Model.Ppls, returning: [:id, :ppl_id],
      allowed_states: ~w(initializing pending queuing running stopping done)}
  end

  def to_state(ppl, state) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(ppl, fn _, _ -> {:ok, %{state: state}} end, args)
    PplsQueries.get_by_id(ppl.ppl_id)
  end

  defp code(:ok), do: 0
  defp code(:error), do: 1
end
