defmodule Ppl.DefinitionReviser.BlocksReviser.GlobalJobConfig.Test do
  use Ppl.IntegrationCase

  import Mock

  alias Ppl.PplSubInits.Model.{PplSubInitsQueries, PplSubInits}
  alias InternalApi.Artifacthub.GetSignedURLResponse
  alias Ppl.PplSubInits.STMHandler.CompilationState
  alias InternalApi.Projecthub.DescribeResponse
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.TaskClient
  alias Util.Proto

  @url_env_name "INTERNAL_API_URL_ARTIFACTHUB"
  @url_env_name_2 "INTERNAL_API_URL_PROJECT"
  @mock_server_port 58_770
  @mock_server_port_2 53_822

  setup_all do
    {:ok, %{port: artifact_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(ArtifactServiceMock)
    {:ok, %{port: project_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(ProjectServiceMock)

    {:ok, artifact_port: artifact_port, project_port: project_port}
  end

  setup %{artifact_port: artifact_port, project_port: project_port} do
    old_artifact_url = System.get_env(@url_env_name)
    old_project_url = System.get_env(@url_env_name_2)

    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, artifact_port)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name_2, project_port)

    on_exit(fn ->
      System.put_env(@url_env_name, old_artifact_url)
      System.put_env(@url_env_name_2, old_project_url)
    end)

    Test.Helpers.truncate_db()

    {:ok, %{}}
  end

  @tag :integration
  test "Pipelines with various combinations of global and block level job configs are passing" do

    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    filenames =[
      "cmd-files-both.yml", "cmd-file-commands.yml", "commands-both.yml",
      "commands-cmd-file.yml", "env-vars-both.yml", "secrets-both.yml"
    ]

    ppl_ids =
      Enum.map(filenames, fn file_name ->

        assert {:ok, ppl_id} = schedule_ppl(file_name)

        if file_name not in [ "commands-both.yml", "env-vars-both.yml", "secrets-both.yml" ] do
          ProjectServiceMock
          |> GrpcMock.expect(:describe, fn _req, _ ->
            %{
              metadata: %{status: %{code: :OK}},
              project: %{spec: %{artifact_store_id: "art_id_1"}}
            }
            |> Proto.deep_new!(DescribeResponse)
          end)

          ArtifactServiceMock
          |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
              %{url: file_name}
              |> Proto.deep_new!(GetSignedURLResponse)
            end)

          :timer.sleep(5_000)

          assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
          assert psi.state == "compilation"
          assert {:ok, "done", "passed"} == TaskClient.describe(psi.compile_task_id)

          with_mock HTTPoison, [get: &(mocked_get(&1))] do
            assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
            assert {:ok, params = %{state: "regular_init"}} == exit_func.(:repo, :changes)
            assert {:ok, _psi} = psi |> PplSubInits.changeset(params) |> Repo.update()
          end

          ppl_id
        else
          ppl_id
        end
      end)

    # to avoid starting the remaining looper individually, we stop the ones already
    # started and start all of them again
    Test.Helpers.stop_all_loopers(loopers)
    loopers = Test.Helpers.start_all_loopers()

    Enum.map(ppl_ids, fn ppl_id ->

      assert {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

      assert ppl.result == "passed"
    end)

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(ArtifactServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  defp schedule_ppl(file_name) do
    assert {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "25_global_job_config", "file_name" => file_name, "project_id" => "prj_1"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Ppl.Actions.schedule()

    {:ok, ppl_id}
  end

  def mocked_get(file_name) do
    assert {:ok, yml_file} = Block.CodeRepo.Local.get_file("25_global_job_config", ".semaphore/#{file_name}")

    {:ok,
      %HTTPoison.Response{
        status_code: 200,
        body: yml_file
      }
    }
  end
end
