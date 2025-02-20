defmodule Ppl.PplBlocks.Model.PplBlockConectionsTest do
  use Ppl.IntegrationCase

  alias InternalApi.Plumber.Pipeline.{State, ResultReason}

  setup_all do
    Test.Helpers.truncate_db

    {:ok, %{}}
  end

  @tag :integration
  test "implicit blocks dependencies" do
    schedule_request =
      Test.Helpers.schedule_request_factory(:local)
      |> Map.put("repo_name", "5_v1_full")
      |> Map.put("file_name", "no_cmd_files.yml")


    schedule_pipeline(schedule_request, "running")
  end

  @tag :integration
  test "explicit blocks dependencies exists - pass" do
    schedule_request =
      Test.Helpers.schedule_request_factory(:local)
      |> Map.put("repo_name", "13_free_topology")

    schedule_pipeline(schedule_request, "running")
  end

  @tag :integration
  test "explicit blocks dependencies exists - fail" do
    schedule_request =
      Test.Helpers.schedule_request_factory(:local)
      |> Map.put("repo_name", "12_failing_deps")


    {:ok, description} = schedule_pipeline(schedule_request, "done")

    assert description.state == "done"
    assert description.result_reason == "malformed"
    assert String.contains?(description.error_description, "unknown_block_name,")
  end

  defp schedule_pipeline(schedule_request, desired_state) do
    {:ok, %{ppl_id: ppl_id}} = Ppl.Actions.schedule(schedule_request)

    Ppl.Ppls.STMHandler.InitializingState.start_link
    Ppl.PplSubInits.STMHandler.CreatedState.start_link()
    Ppl.PplSubInits.STMHandler.FetchingState.start_link()
    Ppl.PplSubInits.STMHandler.CompilationState.start_link()
    Ppl.PplSubInits.STMHandler.RegularInitState.start_link()
    Ppl.Ppls.STMHandler.PendingState.start_link
    Ppl.Ppls.STMHandler.QueuingState.start_link
    resp = Test.Helpers.wait_for_ppl_state(ppl_id, desired_state)
    Ppl.Ppls.STMHandler.QueuingState.stop
    Ppl.Ppls.STMHandler.PendingState.stop
    Ppl.PplSubInits.STMHandler.CreatedState.stop()
    Ppl.PplSubInits.STMHandler.RegularInitState.stop()
    Ppl.Ppls.STMHandler.InitializingState.stop

    resp
  end
end
