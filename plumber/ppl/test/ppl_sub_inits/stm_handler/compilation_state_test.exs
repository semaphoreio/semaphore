defmodule Ppl.PplSubInits.STMHandler.CompilationState.Test do
  use Ppl.IntegrationCase, async: false

  import Mock

  alias Ppl.TaskClient
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplSubInits.STMHandler.CompilationState
  alias InternalApi.Artifacthub.GetSignedURLResponse
  alias InternalApi.Projecthub.DescribeResponse
  alias Ppl.Actions
  alias Util.Proto

  @url_env_name "INTERNAL_API_URL_ARTIFACTHUB"
  @url_env_name_2 "INTERNAL_API_URL_PROJECT"

  setup_all do
    {:ok, %{port: artifact_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(ArtifactServiceMock)
    {:ok, %{port: project_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(ProjectServiceMock)
    {:ok, %{artifact_port: artifact_port, project_port: project_port}}
  end

  setup %{artifact_port: artifact_port, project_port: project_port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, artifact_port)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name_2, project_port)
    :ok
  end

  setup do
    Test.Helpers.truncate_db()

    {:ok, %{}}
  end


  @tag :integration
  test "when compilation task is stopped by the user => sub_init goes to done-stopped state" do
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

      :timer.sleep(2_000)

      assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
      assert psi.state == "compilation"


      with_mocks([
        {HTTPoison, [], [get: &(mocked_get(&1))]},
        {TaskClient, [], [describe: fn _ -> {:ok, "done", "stopped"} end]},
        ])  do
        assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
        assert {:ok, result} = exit_func.(:repo, :changes)
        assert result.state == "done"
        assert result.result == "stopped"
        assert result.result_reason == "user"
      end

      GrpcMock.verify!(ProjectServiceMock)

      Test.Helpers.stop_all_loopers(loopers)
  end


  @tag :integration
  test "when compilation task fails => logs are fetched and stored in error_description" do
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

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "compilation"

    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        %{url: "logs_url_value"}
        |> Proto.deep_new!(GetSignedURLResponse)
    end)

    with_mocks([
      {HTTPoison, [], [get: &(mocked_get(&1))]},
      {TaskClient, [], [describe: fn _ -> {:ok, "done", "failed"} end]},
      ])  do
      assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
      assert {:ok, result} = exit_func.(:repo, :changes)
      assert result.state == "done"
      assert result.result == "failed"
      assert result.result_reason == "malformed"
      assert result.error_description == expected_logs()
    end

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(ArtifactServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when compilation fails without log file => ppl is stuck, error_description is generic" do
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

    {:ok, %{ppl_id: ppl_id, wf_id: wf_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "one_path.yml",
        "working_dir" => ".semaphore/change_in", "label" => "one_path",
        "branch_name" => "one_path", "organization_id" => UUID.uuid4()}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "compilation"

    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn req, _ ->
        assert req.path  == "artifacts/workflows/#{wf_id}/"
                             <> "compilation/#{ppl_id}-one_path.yml.logs"

        %{url: "return_404"}
        |> Proto.deep_new!(GetSignedURLResponse)
    end)
    |> GrpcMock.expect(:get_signed_url, fn req, _ ->
      assert req.path  == "artifacts/workflows/#{wf_id}/"
                           <> "compilation/one_path.yml.logs"

        %{url: "return_404"}
        |> Proto.deep_new!(GetSignedURLResponse)
    end)

    with_mocks([
      {HTTPoison, [], [get: &(mocked_get(&1))]},
      {TaskClient, [], [describe: fn _ -> {:ok, "done", "failed"} end]},
      ])  do
      assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
      assert {:ok, result} = exit_func.(:repo, :changes)
      assert result.state == "done"
      assert result.result == "failed"
      assert result.result_reason == "stuck"
      assert result.error_description == expected_logs(:generic)
    end

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(ArtifactServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when compilation fails with empty log file => ppl is stuck, error_description is generic" do
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

    :timer.sleep(4_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "compilation"

    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        %{url: "return_empty_logs"}
        |> Proto.deep_new!(GetSignedURLResponse)
    end)

    with_mocks([
      {HTTPoison, [], [get: &(mocked_get(&1))]},
      {TaskClient, [], [describe: fn _ -> {:ok, "done", "failed"} end]},
      ])  do
      assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
      assert {:ok, result} = exit_func.(:repo, :changes)
      assert result.state == "done"
      assert result.result == "failed"
      assert result.result_reason == "stuck"
      assert result.error_description == expected_logs(:generic)
    end

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(ArtifactServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when compilation task passes but yaml is not uploaded => ppl is stuck, error_description is generic" do
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

    {:ok, %{ppl_id: ppl_id, wf_id: wf_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "one_path.yml",
        "working_dir" => ".semaphore/change_in", "label" => "one_path",
        "branch_name" => "one_path", "organization_id" => UUID.uuid4()}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(5_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "compilation"
    assert {:ok, "done", "passed"} == TaskClient.describe(psi.compile_task_id)

    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn req, _ ->
        assert req.path  == "artifacts/workflows/#{wf_id}/"
                             <> "compilation/#{ppl_id}-one_path.yml"

        %{url: "return_404"}
        |> Proto.deep_new!(GetSignedURLResponse)
    end)
    |> GrpcMock.expect(:get_signed_url, fn req, _ ->
      assert req.path  == "artifacts/workflows/#{wf_id}/"
                           <> "compilation/one_path.yml"

        %{url: "return_404"}
        |> Proto.deep_new!(GetSignedURLResponse)
    end)

    with_mock HTTPoison, [get: &(mocked_get(&1))] do
      assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
      assert {:ok, result} = exit_func.(:repo, :changes)
      assert result.state == "done"
      assert result.result == "failed"
      assert result.result_reason == "stuck"
      assert result.error_description == expected_logs(:generic)
    end

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(ArtifactServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when compilation task passes => yaml is fetched and stored and sub_init goes to regular_ini" do
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

    :timer.sleep(10_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "compilation"
    assert {:ok, "done", "passed"} == TaskClient.describe(psi.compile_task_id)

    ArtifactServiceMock
    |> GrpcMock.expect(:get_signed_url, fn _req, _ ->
        %{url: "yml_url_value"}
        |> Proto.deep_new!(GetSignedURLResponse)
      end)

    with_mock HTTPoison, [get: &(mocked_get(&1))] do
      assert {:ok, exit_func} = CompilationState.scheduling_handler(psi)
      assert {:ok, %{state: "regular_init"}} == exit_func.(:repo, :changes)

      assert {:ok, ppl_or} = PplOriginsQueries.get_by_id(ppl_id)
      assert ppl_or.initial_definition == expected_definition()
    end

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(ArtifactServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  def mocked_get("yml_url_value") do
    {:ok,
      %HTTPoison.Response{
        status_code: 200,
        body:
         "version: v1.0\nname: Test pipeline\nagent:\n  machine:\n    "
         <> "type: e1-standard-2\n    os_image: ubuntu2004\nblocks:\n  "
         <> "- name: Test Block\n    dependencies: []\n    task:\n      jobs:\n"
         <> "        - name: Test job\n          commands:\n            - echo test\n"
      }
    }
  end

  def mocked_get("logs_url_value") do
    {:ok,
      %HTTPoison.Response{
        status_code: 200,
        body:
          "{\"location\":{\"file\":\".semaphore/semaphore.yml\",\"path\":[\"blocks\","
          <> "\"0\",\"run\",\"when\"]},\"message\":\"Unknown git reference 'main'.\","
          <> "\"type\":\"ErrorChangeInMissingBranch\"}\n"
      }
    }
  end
  def mocked_get("return_empty_logs") do
    {:ok,
      %HTTPoison.Response{
        status_code: 200,
        body: ""
      }
    }
  end
  def mocked_get("return_404") do
    {:ok,
      %HTTPoison.Response{
        status_code: 404,
        body: "<?xml version='1.0' encoding='UTF-8'?><Error><Code>NoSuchKey</Code>"
              <> "<Message>The specified key does not exist.</Message><Details>"
              <> "No such object: /artifacts/workflows/<wf_id>/compilation/semaphore.yml"
              <> "</Details></Error>"
      }
    }
  end

  defp expected_definition() do
    "version: v1.0\nname: Test pipeline\nagent:\n  machine:\n    "
    <> "type: e1-standard-2\n    os_image: ubuntu2004\nblocks:\n  "
    <> "- name: Test Block\n    dependencies: []\n    task:\n      jobs:\n"
    <> "        - name: Test job\n          commands:\n            - echo test\n"
  end

  defp expected_logs(type \\ :missing_branch)
  defp expected_logs(:generic) do
    "{\"message\":\"Initialization step failed, see logs for more details.\","
    <> "\"location\":{\"file\":\".semaphore/change_in/one_path.yml\",\"path\":[]},"
    <> "\"type\":\"ErrorInitializationFailed\"}\n"
  end
  defp expected_logs(:missing_branch) do
    "{\"location\":{\"file\":\".semaphore/semaphore.yml\",\"path\":[\"blocks\","
    <> "\"0\",\"run\",\"when\"]},\"message\":\"Unknown git reference 'main'.\","
    <> "\"type\":\"ErrorChangeInMissingBranch\"}\n"
  end
end
