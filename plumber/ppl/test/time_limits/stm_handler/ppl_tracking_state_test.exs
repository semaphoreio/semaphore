defmodule  Ppl.TimeLimits.STMHandler.PplTrackingState.Test do
  use Ppl.IntegrationCase, async: false

  import Ecto.Query

  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Actions
  alias Test.Helpers

  @grpc_port 50066

  setup_all do
    {:ok, %{port: port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    Application.put_env(:gofer_client, :gofer_grpc_url, "localhost:#{port}")
    Application.put_env(:gofer_client, :test_gofer_service_response, "valid")
    {:ok, %{}}
  end

  setup do
    Test.Helpers.truncate_db()

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "sleep 5"]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    task = %{"jobs" => [job_1], "agent" => agent}
    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => [%{"task" => task}]}

    {:ok, %{definition: definition}}
  end

  @tag :integration
  test "time limit for ppl goes to done-canceled if ppl was already finished", ctx do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/valid_example.yml"}
      |> Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)

    loopers = start_init_loopers() |> start_all_other_loopers()

    args =[ppl, {"done", "passed", nil}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 15_000)

    assert {:ok, tl} = TimeLimitsQueries.get_by_id(ppl.ppl_id)
    assert tl.state == "tracking"

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    ppl = ppl |> Map.put(:exec_time_limit_min, -2)
    assert {:ok, _tl} = TimeLimitsQueries.set_time_limit(ppl, "pipeline")

    {:ok, pid} = Ppl.TimeLimits.STMHandler.PplTrackingState.start_link()

    :timer.sleep(1_500)

    assert {:ok, tl} = TimeLimitsQueries.get_by_id(ppl.ppl_id)
    assert tl.state == "done"
    assert tl.result == "canceled"
    assert tl.result_reason == "ppl done"

    GenServer.stop(pid)
  end

  @tag :integration
  test "pipeline is terminated when it is running for longer than execution_time_limt", ctx do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/valid_example.yml"}
      |> Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    assert {:ok, _ppl_req} = PplRequestsQueries.insert_definition(ppl_req, ctx.definition)

    loopers = start_init_loopers()
    args =[ppl, {"running", nil, nil}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 15_000)

    assert {1,  _} = Ppls |> where([p], p.ppl_id == ^ppl.ppl_id)
                    |> update(set: [exec_time_limit_min: -2]) |> Repo.update_all([])

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, _tl} = TimeLimitsQueries.set_time_limit(ppl, "pipeline")

    loopers = start_all_other_loopers()

    args =[ppl, {"done", "stopped", "timeout"}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 15_000)
  end

  defp start_init_loopers() do
    []
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  defp start_all_other_loopers(loopers \\ []) do
    loopers
    |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
    |> Enum.concat([Ppl.Ppls.STMHandler.RunningState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.StoppingState.start_link()])
    # PplBlocks Loopers
    |> Enum.concat([Ppl.PplBlocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.WaitingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.StoppingState.start_link()])
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.StoppingState.start_link()])
    # Tasks Loopers
    |> Enum.concat([Block.Tasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.RunningState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.StoppingState.start_link()])
    # TimeLimits Looper
    |> Enum.concat([Ppl.TimeLimits.STMHandler.PplTrackingState.start_link()])
  end

  def check_state?(ppl, desired_state, loopers) do
    :timer.sleep 500
    ppl = Repo.get(Ppls, ppl.id)
    check_state_({ppl.state, ppl.result, ppl.result_reason}, ppl, desired_state, loopers)
  end

  defp check_state_({state, result, reason}, ppl, {desired_state, desired_result, desired_reason}, loopers)
  when state == desired_state and result == desired_result and reason == desired_reason do
    Enum.map(loopers, fn {:ok, lp} -> GenServer.stop(lp) end)
    assert ppl.recovery_count == 0
    :pass
  end
  defp check_state_(_, ppl, desired_result, loopers), do: check_state?(ppl, desired_result, loopers)

end
