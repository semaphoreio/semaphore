defmodule Plumber.WorkflowAPI.WfNumber.Test do
  use Ppl.IntegrationCase

  alias Ppl.Ppls.Model.PplsQueries
  alias Test.Support.WorkflowBuilder
  alias InternalApi.PlumberWF.{RescheduleRequest, WorkflowService}
  alias Util.Proto

  @grpc_port 50_064

  setup_all do
    GRPC.Server.start(Test.MockGoferService, @grpc_port)

    on_exit fn ->
      GRPC.Server.stop(Test.MockGoferService)
    end


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

  @tag :integration
  test "wf_number correctly set for all pipelines form workflows with different topology" do
    test_wf_number("wf-number-test-1")
  end

  defp test_wf_number(project_id) do
    use_mock_gofer_service()
    test_gofer_service_response("valid")

    loopers = Test.Helpers.start_all_loopers()

    params = %{"project_id" => project_id}

    topologies =
      [
        [{:schedule, nil, params}, {:schedule_extension, 0}],
        [{:schedule, nil, params}, {:partial_rebuild, 0}],
        [{:schedule, nil, params}, {:schedule_extension, 0}, {:partial_rebuild, 1}],
        [{:schedule, nil, params}, {:schedule_extension, 0}, {:partial_rebuild, 0}, {:partial_rebuild, 1}],
        [{:schedule, nil, params}, {:schedule_extension, 0}, {:partial_rebuild, 0}, {:schedule_extension, 2}],
      ]

    results =
      topologies |> Enum.map(fn topology -> WorkflowBuilder.build(topology) end)

    ppl_id = results |> Enum.at(-1) |> Enum.at(-1) |> elem(2)

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 30_000)

    results
    |> Enum.with_index()
    |> Enum.map(fn {result, index} ->
      result |> Enum.map(fn {:ok, _wf_id, ppl_id} ->
        assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
        assert ppl.state in ["pending", "running", "stopping", "done"]
        assert ppl.wf_number == index + 1
      end)
    end)

    wf_id = results |> Enum.at(-1) |> Enum.at(-1) |> elem(1)

    ppl_id =
      %{wf_id: wf_id, request_token: UUID.uuid4()}
      |> Proto.deep_new!(RescheduleRequest)
      |> reschedule_workflow(:OK)

    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 3_000)

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl.wf_number == length(results) + 1

    Test.Helpers.stop_all_loopers(loopers)
  end

  defp reschedule_workflow(request, expected_status, message \\ "") when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50053")
    response = channel |> WorkflowService.Stub.reschedule(request)

    assert {:ok, rsch_response} = response
    assert %{status: %{code: status_code, message: msg}} = Proto.to_map!(rsch_response)
    assert expected_status == status_code
    assert message == msg

    rsch_response.ppl_id
  end


  defp use_mock_gofer_service(),
    do: System.put_env("INTERNAL_API_URL_GOFER", "localhost:#{@grpc_port}")
  defp test_gofer_service_response(value),
    do: Application.put_env(:gofer_client, :test_gofer_service_response, value)
end
