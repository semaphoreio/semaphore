defmodule Ppl.PplSubInits.STMHandler.ConceivedState.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.PplSubInits.STMHandler.ConceivedState
  alias Ppl.TaskClient
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplSubInits.STMHandler.FetchingState
  alias InternalApi.Projecthub.DescribeResponse
  alias InternalApi.PreFlightChecksHub, as: PfcApi
  alias Ppl.Actions
  alias Util.Proto

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "when hook is created => pipeline goes to created" do
    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "one_path.yml",
        "working_dir" => ".semaphore/change_in",
        "label" => "one_path",
        "branch_name" => "one_path",
        "branch_id" => "",
        "hook_id" => "",
        "triggered_by" => "schedule",
        "scheduler_task_id" => "12345"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule(true, true, true)


    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "conceived"

    assert {:ok, exit_func} = ConceivedState.scheduling_handler(psi)
    assert exit_func.(:repo, :changes) == {:ok, %{state: "created"}}

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    assert ppl_req.request_args |> Map.get("hook_id", "") == "hook_id"
    assert ppl_req.request_args |> Map.get("branch_id", "") == "branch_id"

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl.owner == "renderedtext"
    assert ppl.repo_name == "zebra"
    assert ppl.branch_name == "master"
    assert ppl.commit_sha == "0000000000000000000000000000000000000001"
    assert ppl.repository_id == "00000000-0000-4000-a000-000000000001"

    :timer.sleep(2_000)

    Test.Helpers.stop_all_loopers(loopers)
  end
end
