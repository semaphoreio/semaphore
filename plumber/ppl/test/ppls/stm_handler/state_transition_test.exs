defmodule Ppl.Looper.Ppls.StateTransition.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.EctoRepo, as: Repo
  alias Test.Helpers

  @grpc_port 50555

  setup_all do
    GRPC.Server.start(Test.MockGoferService, @grpc_port)
    Application.put_env(:gofer_client, :gofer_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:gofer_client, :test_gofer_service_response, "valid")

    on_exit(fn ->
      GRPC.Server.stop(Test.MockGoferService)
    end)

    {:ok, %{}}
  end

  setup do
    Test.Helpers.truncate_db()

    request_pass = Helpers.schedule_request_factory(:local)
    {:ok, ppl_req_pass} = PplRequestsQueries.insert_request(request_pass)
    {:ok, _ppl_or_pass} = PplOriginsQueries.insert(ppl_req_pass.id, request_pass)
    ppl_req_pass = Map.from_struct(ppl_req_pass)

    request_fail = %{"repo_name" => "3_should_fail"} |> Helpers.schedule_request_factory(:local)
    {:ok, ppl_req_fail} = PplRequestsQueries.insert_request(request_fail)
    {:ok, _ppl_or_fail} = PplOriginsQueries.insert(ppl_req_fail.id, request_fail)
    ppl_req_fail = Map.from_struct(ppl_req_fail)

    {:ok, %{ppl_req_pass: ppl_req_pass, ppl_req_fail: ppl_req_fail}}
  end

  @tag :integration
  test "Ppls looper transitions - pass", ctx do
    ppl_req_pass = Map.get(ctx, :ppl_req_pass)
    {:ok, ppl} = PplsQueries.insert(ppl_req_pass)
    assert ppl.state == "initializing"
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req_pass, "regular")
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)

    loopers = start_loopers()

    init_loopers =
      [Ppl.Ppls.STMHandler.InitializingState.start_link()]
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    args = [ppl, {"pending", nil}, init_loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 7_000)

    ppl = Repo.get(Ppls, ppl.id)
    looper = Ppl.Ppls.STMHandler.PendingState.start_link()
    looper_2 = Ppl.Ppls.STMHandler.QueuingState.start_link()
    args = [ppl, {"running", nil}, [looper, looper_2]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 7_000)

    ppl = Repo.get(Ppls, ppl.id)

    looper = Ppl.Ppls.STMHandler.RunningState.start_link()
    args = [ppl, {"done", "passed"}, [looper] ++ loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 10_000)
  end

  @tag :integration
  test "Ppls looper transitions - pass and trace is set", ctx do
    ppl_req_pass = Map.get(ctx, :ppl_req_pass)
    {:ok, ppl} = PplsQueries.insert(ppl_req_pass)
    assert ppl.state == "initializing"
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req_pass, "regular")
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)

    loopers = start_loopers(:all)
    args = [ppl, {"done", "passed"}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 15_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.pending_at) == :lt
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.running_at) == :lt
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.queuing_at) == :lt
    assert DateTime.compare(ppl_trace.queuing_at, ppl_trace.done_at) == :lt
    assert is_nil(ppl_trace.stopping_at)
  end

  defp start_loopers() do
    []
    # PplBlocks Loopers
    |> Enum.concat([Ppl.PplBlocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.WaitingState.start_link()])
    |> Enum.concat([Ppl.PplBlocks.STMHandler.RunningState.start_link()])
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
    # Tasks Loopers
    |> Enum.concat([Block.Tasks.STMHandler.PendingState.start_link()])
    |> Enum.concat([Block.Tasks.STMHandler.RunningState.start_link()])
  end

  defp start_loopers(:all) do
    start_loopers()
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.RunningState.start_link()])
    # PplSubInits Loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  @tag :integration
  test "Ppls looper transitions - validation fail", ctx do
    ppl_req_fail = Map.get(ctx, :ppl_req_fail)
    {:ok, ppl} = PplsQueries.insert(ppl_req_fail)
    assert ppl.state == "initializing"
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req_fail, "regular")

    loopers =
      [Ppl.Ppls.STMHandler.InitializingState.start_link()]
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    args = [ppl, {"done", "failed"}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 10_000)
  end

  @tag :integration
  test "Ppls looper transitions - execution fail" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test", "file_name" => "failing_test.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl.state == "initializing"

    loopers = start_loopers(:all)

    args = [ppl, {"done", "failed"}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 15_000)
  end

  @tag :integration
  test "Ppls recovery counter is reset on transition out of scheduling", ctx do
    ppl_req_pass = Map.get(ctx, :ppl_req_pass)
    assert {:ok, ppl} = PplsQueries.insert(ppl_req_pass)
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req_pass, "regular")
    assert ppl.state == "initializing"

    assert {:ok, ppl} =
             ppl
             |> Ppls.changeset(%{recovery_count: 1})
             |> Repo.update()

    assert ppl.recovery_count == 1

    loopers =
      [Ppl.Ppls.STMHandler.InitializingState.start_link()]
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    args = [ppl, {"pending", nil}, loopers]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)
  end

  def check_state?(ppl, desired_state, loopers) do
    :timer.sleep(500)
    ppl = Repo.get(Ppls, ppl.id)
    check_state_({ppl.state, ppl.result}, ppl, desired_state, loopers)
  end

  defp check_state_({state, result}, ppl, {desired_state, desired_result}, loopers)
       when state == desired_state and result == desired_result do
    Enum.map(loopers, fn {:ok, looper} -> GenServer.stop(looper) end)
    assert ppl.recovery_count == 0
    :pass
  end

  defp check_state_(_, ppl, desired_result, loopers),
    do: check_state?(ppl, desired_result, loopers)
end
