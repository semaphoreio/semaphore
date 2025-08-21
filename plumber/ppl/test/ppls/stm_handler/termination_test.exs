defmodule Ppl.Ppls.Termination.Test do
  use Ppl.IntegrationCase
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.{PplSubInits, PplSubInitsQueries}
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.EctoRepo, as: Repo
  alias Test.Helpers

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "23_initializing_test",
        "file_name" => "/exec_time_limit/valid_example.yml"}
      |> Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    {:ok, %{ppl_req: ppl_req, ppl: ppl, psi: psi}}
  end

  test "stop pipeline in initializing state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    t_params = %{request: "stop", desc: "API call" }
    handler = Ppl.Ppls.STMHandler.InitializingState
    desired_result = {"init-stopping", nil, nil}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert ppl_trace.pending_at |> is_nil()
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()
  end

  test "cancel pipeline in initializing state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    t_params = %{request: "cancel", desc: "API call" }

    handler = Ppl.Ppls.STMHandler.InitializingState
    desired_result = {"init-stopping", nil, nil}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert ppl_trace.pending_at |> is_nil()
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()
  end

  test "stop pipeline in initializing stop state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    t_params = %{request: "stop", desc: "API call" }

    subinit_loopers = start_all_subinit_loopers()

    init_handler = Ppl.Ppls.STMHandler.InitializingState
    desired_result = {"init-stopping", nil, nil}

    assert_terminated(ppl, t_params, init_handler, desired_result, 5_000)

    {:ok, init_stopping_pid} = Ppl.Ppls.STMHandler.InitStoppingState.start_link()
    desired_result = {"done", "canceled", "user"}

    updated_ppl = Repo.get(Ppls, ppl.id)
    args =[updated_ppl, desired_result, [init_stopping_pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert ppl_trace.pending_at |> is_nil()
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.done_at) == :lt

    Enum.each(subinit_loopers, fn {_, pid} -> GenServer.stop(pid) end)
  end

  test "cancel pipeline in initializing stopping state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    subinit_loopers = start_all_subinit_loopers()

    t_params = %{request: "cancel", desc: "API call"}

    handler = Ppl.Ppls.STMHandler.InitializingState
    desired_result = {"init-stopping", nil, nil}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)

    {:ok, init_stopping_pid} = Ppl.Ppls.STMHandler.InitStoppingState.start_link()
    desired_result = {"done", "canceled", "user"}
    updated_ppl = Repo.get(Ppls, ppl.id)
    args =[updated_ppl, desired_result, [init_stopping_pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert ppl_trace.pending_at |> is_nil()
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()

    Enum.each(subinit_loopers, fn {_, pid} -> GenServer.stop(pid) end)
  end

  @tag :integration
  test "terminate ppl in init when SubInit is already done and blocks exist", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    {:ok, pid_1} = Ppl.PplSubInits.STMHandler.CreatedState.start_link()
    {:ok, pid_2} = Ppl.PplSubInits.STMHandler.FetchingState.start_link()
    {:ok, pid_3} = Ppl.PplSubInits.STMHandler.CompilationState.start_link()
    {:ok, pid_4} = Ppl.PplSubInits.STMHandler.RegularInitState.start_link()

    args =[ctx.psi, {"done", "passed", nil}, [pid_1, pid_2, pid_3, pid_4]]
    Helpers.assert_finished_for_less_than(__MODULE__, :subinit_in_state?, args, 5_000)

    t_params = %{request: "stop", desc: "API call" }
    handler = Ppl.Ppls.STMHandler.InitializingState
    desired_result = {"init-stopping", nil, nil}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert ppl_trace.pending_at |> is_nil()
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()
  end

  @tag :integration
  test "pipeline is terminated properly when blocks are created after termination signal", ctx do
    ppl = Map.get(ctx, :ppl)
    ppl_id = ppl.ppl_id
    assert ppl.state == "initializing"
    psi = Map.get(ctx, :psi)
    assert psi.state == "created"

    subinit_loopers = start_all_subinit_loopers()

    args =[psi, {"done", "passed", nil}, [subinit_loopers[:subinit_created], subinit_loopers[:subinit_fetching], subinit_loopers[:subinit_compilation], subinit_loopers[:subinit_regular_init]]]
    Helpers.assert_finished_for_less_than(__MODULE__, :subinit_in_state?, args, 5_000)

    loopers = start_all_loopers()

    {:ok, terminated_ppl} = terminate_ppl(ppl, "stop", "API call")
    assert terminated_ppl.terminate_request == "stop"

    init_stopping_args = [terminated_ppl, {"init-stopping", nil, nil}, [loopers[:initializing_state]]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, init_stopping_args, 5_000)

    {:ok, updated_ppl} = PplsQueries.get_by_id(ppl_id)
    assert updated_ppl.state == "init-stopping"

    done_args = [updated_ppl, {"done", "canceled", "user"}, [loopers[:init_stopping_state]]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, done_args, 5_000)

    assert_blocks_termination_initiated(updated_ppl)

    {:ok, final_ppl} = PplsQueries.get_by_id(ppl_id)
    assert final_ppl.state == "done"
    assert final_ppl.result == "canceled"

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl_id)
    assert ppl_trace.created_at != nil
    assert ppl_trace.done_at != nil
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.done_at) == :lt

    Enum.each(loopers, fn {_, pid} ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)
  end

  # Start all necessary pipeline STM handlers
  defp start_all_loopers() do
    %{
      initializing_state: start_process(Ppl.Ppls.STMHandler.InitializingState),
      init_stopping_state: start_process(Ppl.Ppls.STMHandler.InitStoppingState)
    }
  end

  # Start all necessary pipeline subinit STM handlers
  defp start_all_subinit_loopers() do
    %{
      subinit_created: start_process(Ppl.PplSubInits.STMHandler.CreatedState),
      subinit_fetching: start_process(Ppl.PplSubInits.STMHandler.FetchingState),
      subinit_compilation: start_process(Ppl.PplSubInits.STMHandler.CompilationState),
      subinit_regular_init: start_process(Ppl.PplSubInits.STMHandler.RegularInitState)
    }
  end

  defp start_process(module) do
    Process.whereis(module) || (fn ->
      {:ok, pid} = module.start_link()
      pid
    end.())
  end


  def subinit_in_state?(psi, desired_state, loopers) do
    :timer.sleep 500
    psi = Repo.get(PplSubInits, psi.id)
    subinit_in_state_({psi.state, psi.result, psi.result_reason}, psi, desired_state, loopers)
  end

  defp subinit_in_state_({state, result, reason}, psi, {desired_state, desired_result, desired_reason}, loopers)
  when state == desired_state and result == desired_result and reason == desired_reason do
    Enum.map(loopers, fn lp -> GenServer.stop(lp) end)
    assert psi.recovery_count == 0
    :pass
  end
  defp subinit_in_state_(_, psi, desired_result, loopers),
    do: subinit_in_state?(psi, desired_result, loopers)

  @tag :integration
  test "stop pipeline in pending state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    {:ok, pid} = Ppl.Ppls.STMHandler.InitializingState.start_link()
    {:ok, pid_2} = Ppl.PplSubInits.STMHandler.CreatedState.start_link()
    {:ok, pid_3} = Ppl.PplSubInits.STMHandler.FetchingState.start_link()
    {:ok, pid_4} = Ppl.PplSubInits.STMHandler.CompilationState.start_link()
    {:ok, pid_5} = Ppl.PplSubInits.STMHandler.RegularInitState.start_link()
    args =[ppl, {"pending", nil, nil}, [pid, pid_2, pid_3, pid_4, pid_5]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    ppl = Repo.get(Ppls, ppl.id)
    t_params = %{request: "stop", desc: "API call" }
    handler = Ppl.Ppls.STMHandler.PendingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.pending_at) == :lt
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.done_at) == :lt

    ppl = Repo.get(Ppls, ppl.id)
    assert_blocks_termination_initiated(ppl)
  end

  @tag :integration
  test "cancel pipeline in pending state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    {:ok, pid} = Ppl.Ppls.STMHandler.InitializingState.start_link()
    {:ok, pid_2} = Ppl.PplSubInits.STMHandler.CreatedState.start_link()
    {:ok, pid_3} = Ppl.PplSubInits.STMHandler.FetchingState.start_link()
    {:ok, pid_4} = Ppl.PplSubInits.STMHandler.CompilationState.start_link()
    {:ok, pid_5} = Ppl.PplSubInits.STMHandler.RegularInitState.start_link()
    args =[ppl, {"pending", nil, nil}, [pid, pid_2, pid_3, pid_4, pid_5]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 7_000)

    ppl = Repo.get(Ppls, ppl.id)
    t_params = %{request: "cancel", desc: "API call" }
    handler = Ppl.Ppls.STMHandler.PendingState
    desired_result = {"done", "canceled", "user"}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.pending_at) == :lt
    assert ppl_trace.queuing_at |> is_nil()
    assert ppl_trace.running_at |> is_nil()
    assert ppl_trace.stopping_at |> is_nil()
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.done_at) == :lt

    ppl = Repo.get(Ppls, ppl.id)
    assert_blocks_termination_initiated(ppl)
  end

  @tag :integration
  test "stop pipeline in running state", ctx do
    ppl = Map.get(ctx, :ppl)
    assert ppl.state == "initializing"

    {:ok, pid} = Ppl.Ppls.STMHandler.InitializingState.start_link()
    {:ok, pid_2} = Ppl.PplSubInits.STMHandler.CreatedState.start_link()
    {:ok, pid_3} = Ppl.PplSubInits.STMHandler.FetchingState.start_link()
    {:ok, pid_4} = Ppl.PplSubInits.STMHandler.CompilationState.start_link()
    {:ok, pid_5} = Ppl.PplSubInits.STMHandler.RegularInitState.start_link()
    args = [ppl, {"pending", nil, nil},  [pid, pid_2, pid_3, pid_4, pid_5]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 7_000)

    {:ok, pid} = Ppl.Ppls.STMHandler.PendingState.start_link()
    {:ok, pid2} = Ppl.Ppls.STMHandler.QueuingState.start_link()
    {:ok, pid3} = Ppl.PplBlocks.STMHandler.InitializingState.start_link()
    {:ok, pid4} = Ppl.PplBlocks.STMHandler.WaitingState.start_link()
    args = [ppl, {"running", nil, nil}, [pid, pid2, pid3, pid4]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    ppl = Repo.get(Ppls, ppl.id)
    t_params = %{request: "stop", desc: "API call" }
    handler = Ppl.Ppls.STMHandler.RunningState
    desired_result = {"stopping", nil, nil}

    assert_terminated(ppl, t_params, handler, desired_result, 5_000)
    Ppls |> Repo.get(ppl.id) |> assert_blocks_termination_initiated()

    ppl = Repo.get(Ppls, ppl.id)
    loopers = start_all_other_loopers()
    args = [ppl, {"done", "stopped", "user"}, loopers]

    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, 5_000)

    assert {:ok, ppl_trace} = PplTracesQueries.get_by_id(ppl.ppl_id)
    assert NaiveDateTime.compare(ppl_trace.created_at |> DateTime.to_naive(),
                                ppl.inserted_at) == :eq
    assert DateTime.compare(ppl_trace.created_at, ppl_trace.pending_at) == :lt
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.queuing_at) == :lt
    assert DateTime.compare(ppl_trace.queuing_at, ppl_trace.running_at) == :lt
    assert DateTime.compare(ppl_trace.pending_at, ppl_trace.running_at) == :lt
    assert DateTime.compare(ppl_trace.running_at, ppl_trace.stopping_at) == :lt
    assert DateTime.compare(ppl_trace.stopping_at, ppl_trace.done_at) == :lt

    assert {:ok, tl} = TimeLimitsQueries.get_by_id(ppl.ppl_id)
    assert tl.state == "done"
    assert tl.result == "canceled"
    assert tl.result_reason == "user"

    assert {:ok, tl} = TimeLimitsQueries.get_by_id_and_index(ppl.ppl_id, 0)
    assert tl.state == "done"
    assert tl.result == "canceled"
    assert tl.result_reason == "user"
  end

  defp start_all_other_loopers() do
    []
    |> Enum.concat([Ppl.Ppls.STMHandler.StoppingState.start_link()])
    # PplBlocks Loopers
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
    |> Enum.concat([Ppl.TimeLimits.STMHandler.PplBlockTrackingState.start_link()])
    |> Enum.map(fn {:ok, pid} -> pid end)
  end

  defp assert_terminated(ppl, t_params, handler, desired_result, timeout) do
    {:ok, ppl} = terminate_ppl(ppl, t_params.request, t_params.desc)

    {:ok, pid} = Kernel.apply(handler, :start_link, [])
    args =[ppl, desired_result, [pid]]
    Helpers.assert_finished_for_less_than(__MODULE__, :check_state?, args, timeout)
  end

  defp terminate_ppl(ppl, t_req, t_desc) do
    ppl
    |> Ppls.changeset(%{terminate_request: t_req, terminate_request_desc: t_desc})
    |> Repo.update()
  end

  defp assert_blocks_termination_initiated(ppl) do
    assert {:ok, ppl_blk} = PplBlocksQueries.get_by_id_and_index(ppl.ppl_id, 0)
    assert ppl_blk.terminate_request == ppl.terminate_request
    assert ppl_blk.terminate_request_desc == ppl.terminate_request_desc
  end

  def check_state?(ppl, desired_state, looper) do
    :timer.sleep 500
    ppl = Repo.get(Ppls, ppl.id)
    check_state_({ppl.state, ppl.result, ppl.result_reason}, ppl, desired_state, looper)
  end

  defp check_state_({state, result, reason}, ppl, {desired_state, desired_result, desired_reason}, looper)
  when state == desired_state and result == desired_result and reason == desired_reason do
    Enum.map(looper, fn lp -> GenServer.stop(lp) end)
    assert ppl.recovery_count == 0
    :pass
  end
  defp check_state_(_, ppl, desired_result, looper), do: check_state?(ppl, desired_result, looper)
end
