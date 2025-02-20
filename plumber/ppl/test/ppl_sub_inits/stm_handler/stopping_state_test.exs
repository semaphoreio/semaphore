defmodule Ppl.PplSubInits.STMHandler.StoppingState.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.TaskClient
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias InternalApi.Projecthub.DescribeResponse
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.Actions
  alias Util.Proto

  @url_env_name "INTERNAL_API_URL_PROJECT"

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(ProjectServiceMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, port)
    Test.Helpers.truncate_db()
    :ok
  end


  @tag :integration
  test "when pipeline is terminated while compilation task is running => sub init goes through stopping state" do
    Application.put_env(:ppl, :environment, :stopping_test)

    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    ProjectServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
        %{
          metadata: %{status: %{code: :OK}},
          project: %{spec: %{artifact_store_id: "art_id_1"}}
        }
        |> Proto.deep_new!(DescribeResponse)
      end)

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "one_path.yml",
        "working_dir" => ".semaphore/change_in", "label" => "one_path",
        "branch_name" => "one_path", "organization_id" => UUID.uuid4()}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(1_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "compilation"

    assert {:ok, _msg} = Actions.terminate(%{"ppl_id" => ppl_id, "requester_id" => "user_id"})

    loopers =
      loopers |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])

    :timer.sleep(3_000)

    assert {:ok, "done", "stopped"} == TaskClient.describe(psi.compile_task_id)
    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "stopping"

    loopers =
      loopers |> Enum.concat([Ppl.PplSubInits.STMHandler.StoppingState.start_link()])

    :timer.sleep(500)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "done"
    assert psi.result == "stopped"

    assert {:ok, ppl} = PplsQueries.get_by_id(ppl_id)
    assert ppl.state == "done"
    assert ppl.result == "canceled"

    GrpcMock.verify!(ProjectServiceMock)

    Test.Helpers.stop_all_loopers(loopers)

    Application.put_env(:ppl, :environment, :test)
  end
end
