defmodule Ppl.Ppls.STMHandler.Initializing.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.AfterPplTasks.Model.AfterPplTasksQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    Test.Helpers.truncate_db()
    :ok
  end

  @tag :integration
  test "additional fileds are set when pipeline exits initializing" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test", "file_name" => "additional_fileds.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    loopers = start_init_loopers()

    :timer.sleep(5_000)

    assert {:error, _} = AfterPplTasksQueries.get_by_id(ppl.ppl_id)
    assert {:ok, ppl} = PplsQueries.get_by_id(ppl.ppl_id)
    assert ppl.state == "pending"
    assert ppl.name == "Test pipeline 1"
    assert ppl.fast_failing == "none"
    assert ppl.with_after_task == false
    assert ppl.exec_time_limit_min == 150

    assert {:ok, ppl_blk} = PplBlocksQueries.get_by_id_and_index(ppl.ppl_id, 0)
    assert ppl_blk.state == "initializing"
    assert ppl_blk.name == "B1"
    assert ppl_blk.exec_time_limit_min == 120

    stop_loopers(loopers)
  end

  @tag :integration
  test "after pipeline is initialized when it's included in definition" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "30_after_ppl_test"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    loopers = start_init_loopers()
    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 5_000)

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl.ppl_id)

    assert ppl.with_after_task == true
    assert ppl.state == "pending"
    assert ppl.name == "Pipeline"

    assert {:ok, _} = AfterPplTasksQueries.get_by_id(ppl.ppl_id)

    stop_loopers(loopers)
  end

  @tag :integration
  test "default values for additional fields are set when pipeline without them in yaml def exits initializing" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    loopers = start_init_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 5_000)

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl.ppl_id)
    assert ppl.state == "pending"
    assert ppl.name == "Pipeline"
    assert ppl.with_after_task == false
    assert ppl.fast_failing == "none"
    assert ppl.exec_time_limit_min == 60

    stop_loopers(loopers)
  end

  @tag :integration
  test "gofer service is called with valid params and resulting switch_id is stored in db" do
    test_gofer_service_response("valid")

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test", "file_name" => "promotions.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    loopers = start_init_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "pending", 5_000)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:ok, _} = UUID.info(ppl_req.switch_id)

    stop_loopers(loopers)
  end

  defp start_init_loopers() do
    []
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  defp stop_loopers(loopers) do
    loopers |> Enum.map(fn {:ok, pid} -> GenServer.stop(pid) end)
  end

  defp test_gofer_service_response(value),
    do: Application.put_env(:gofer_client, :test_gofer_service_response, value)
end
