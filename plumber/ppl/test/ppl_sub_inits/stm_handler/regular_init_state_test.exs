defmodule Ppl.PplSubInits.STMHandler.RegularInitState.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Actions
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplSubInits.STMHandler.RegularInitState
  alias Ppl.PplBlocks.Model.PplBlocksQueries

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    Application.put_env(:gofer_client, :test_gofer_service_response, "valid")
    Test.Helpers.truncate_db()
    :ok
  end

  # Reproduces the following race:
  #
  # A termination is requested on a pipeline while its sub_init is mid-flight in
  # 'regular_init' scheduling. The regular_init scheduling snapshot was taken
  # before the terminate request was recorded, so the terminate is ignored, and
  # regular_init's exit function still creates the pipeline blocks. Meanwhile the
  # pipeline has already transitioned to 'done', so those freshly-created blocks
  # are never picked up by the waiting-block scheduler (which only selects blocks
  # whose pipeline is 'running' OR that carry a terminate_request) and stay stuck
  # in 'waiting' forever.
  @tag :integration
  test "termination requested while regular_init is scheduling must not leave orphaned blocks" do
    # Schedule a pipeline and drive its sub_init up to (but not through)
    # regular_init - there is no RegularInitState looper running, so the sub_init
    # deterministically settles in 'regular_init'.
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "2_basic"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = start_loopers_until_regular_init()
    psi = wait_for_psi_state(ppl_id, "regular_init", 5_000)
    Test.Helpers.stop_all_loopers(loopers)

    assert psi.state == "regular_init"
    # Blocks are created by regular_init's exit function, so none exist yet.
    assert {:error, _} = PplBlocksQueries.get_all_by_id(ppl_id)

    # regular_init runs its slow scheduling work (definition acquisition, gofer
    # switch creation, ...) with a clean terminate_request snapshot, returning the
    # block-creating exit function.
    assert {:ok, exit_func} = RegularInitState.scheduling_handler(psi)

    # The race: a termination request lands on the sub_init AFTER the snapshot was
    # taken but BEFORE the exit function commits (pipeline auto-cancel / stop /
    # branch deletion during initialization).
    assert {:ok, _} = PplSubInitsQueries.terminate(psi, "stop", "API call")

    # The exit function runs inside the STM exit transaction.
    {:ok, exit_result} = Repo.transaction(fn -> exit_func.(Repo, %{}) end)

    # Desired behaviour: with a termination pending, regular_init must NOT create
    # blocks (they would be orphaned in 'waiting' once the pipeline is 'done'),
    # and the sub_init should end up canceled.
    assert {:error, _} = PplBlocksQueries.get_all_by_id(ppl_id)
    assert {:ok, %{state: "done", result: "canceled"}} = exit_result
  end

  defp start_loopers_until_regular_init do
    []
    |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.ConceivedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
  end

  defp wait_for_psi_state(ppl_id, desired, timeout) when timeout > 0 do
    {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)

    if psi.state == desired do
      psi
    else
      :timer.sleep(100)
      wait_for_psi_state(ppl_id, desired, timeout - 100)
    end
  end

  defp wait_for_psi_state(ppl_id, _desired, _timeout) do
    {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    psi
  end
end
