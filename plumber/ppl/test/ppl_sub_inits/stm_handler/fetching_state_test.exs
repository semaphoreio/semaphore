defmodule Ppl.PplSubInits.STMHandler.FetchingState.Test do
  use Ppl.IntegrationCase, async: false

  alias Ppl.TaskClient
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplSubInits.STMHandler.FetchingState
  alias InternalApi.Projecthub.DescribeResponse
  alias InternalApi.PreFlightChecksHub, as: PfcApi
  alias Ppl.Actions
  alias Util.Proto

  @url_env_name "INTERNAL_API_URL_PROJECT"
  @url_env_name_pfc "INTERNAL_API_URL_PFC"
  @url_env_name_org "INTERNAL_API_URL_ORGANIZATION"

  setup_all do
    {:ok, %{port: project_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(ProjectServiceMock)
    {:ok, %{project_port: project_port}}
  end

  setup %{project_port: project_port} do
    Test.Helpers.truncate_db()
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, project_port)

    :ok
  end

  @tag :integration
  test "when pipeline does not need compilation => sub_init goes to regular_init state" do
    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "multiple_valid_whens.yml",
        "label" => "multiple_valid_whens",
        "branch_name" => "multiple_valid_whens"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "fetching"

    assert {:ok, exit_func} = FetchingState.scheduling_handler(psi)
    assert exit_func.(:repo, :changes) == {:ok, %{state: "regular_init"}}

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when there is error in fetching org settings => sub_init fails with timeout" do
    System.put_env("INTERNAL_API_URL_ORGANIZATION", "non-existent-url:20034")
    on_exit(fn -> System.put_env("INTERNAL_API_URL_ORGANIZATION", "localhost:50053") end)

    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "multiple_valid_whens.yml",
        "label" => "multiple_valid_whens",
        "branch_name" => "multiple_valid_whens"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "fetching"

    assert {:ok, exit_func} = FetchingState.scheduling_handler(psi)
    assert exit_func.(:repo, :changes) == {:error, {:organization_settings, :timeout}}

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when there org settings don't have necessary settings => sub_init goes to done-failed-malformed state" do
    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "one_path.yml",
        "working_dir" => ".semaphore/change_in",
        "label" => "one_path",
        "branch_name" => "one_path"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, %{port: org_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(OrganizationServiceMock)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name_org, org_port)
    on_exit(fn ->
      System.put_env(@url_env_name_org, "localhost:50053")
    end)

    GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, fn _request, _stream ->
      Util.Proto.deep_new!(InternalApi.Organization.FetchOrganizationSettingsResponse, %{
        settings: []
      })
    end)

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "fetching"

    assert {:ok, exit_func} = FetchingState.scheduling_handler(psi)

    assert exit_func.(:repo, :changes) ==
             {:ok,
              %{
                state: "done",
                error_description:
                  "Error: \"Machine type and OS image for initialization job are not defined\"",
                result: "failed",
                result_reason: "malformed"
              }}

    GrpcMock.verify!(OrganizationServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when pipeline needs compilation => pipeline goes to compilationa and task is started" do
    ProjectServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      %{
        metadata: %{status: %{code: :OK}},
        project: %{spec: %{artifact_store_id: "art_id_1"}}
      }
      |> Proto.deep_new!(DescribeResponse)
    end)

    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "one_path.yml",
        "working_dir" => ".semaphore/change_in",
        "label" => "one_path",
        "branch_name" => "one_path"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "fetching"

    assert {:ok, exit_func} = FetchingState.scheduling_handler(psi)

    assert {:ok, %{state: "compilation", compile_task_id: compl_task_id}} =
             exit_func.(:repo, :changes)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)
    assert ppl_req.request_args["artifact_store_id"] == "art_id_1"

    :timer.sleep(2_000)

    assert {:ok, "done", "passed"} == TaskClient.describe(compl_task_id)

    GrpcMock.verify!(ProjectServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when pipeline has pre-flight checks => pipeline goes to compilationa and task is started" do
    ProjectServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      %{
        metadata: %{status: %{code: :OK}},
        project: %{spec: %{artifact_store_id: "art_id_1"}}
      }
      |> Proto.deep_new!(DescribeResponse)
    end)

    {:ok, %{port: pfc_port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(PFCServiceMock)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name_pfc, pfc_port)

    on_exit(fn ->
      System.put_env(@url_env_name_pfc, "localhost:50053")
    end)

    PFCServiceMock
    |> GrpcMock.expect(:describe, fn _request, _stream ->
      Proto.deep_new!(PfcApi.DescribeResponse, %{
        status: %{code: :OK},
        pre_flight_checks: %{
          organization_pfc: %{
            commands: [~s[echo "organization PFC"]],
            secrets: ["ORG_SECRET"]
          },
          project_pfc: %{
            commands: [~s[echo "project PFC"]],
            secrets: ["PRJ_SECRET"],
            agent: %{
              machine_type: "e1-standard-4",
              os_image: "ubuntu2004"
            }
          }
        }
      })
    end)

    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "multiple_valid_whens.yml",
        "label" => "multiple_valid_whens",
        "branch_name" => "multiple_valid_whens"
      }
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "fetching"

    assert {:ok, exit_func} = FetchingState.scheduling_handler(psi)

    assert {:ok, %{state: "compilation", compile_task_id: compl_task_id}} =
             exit_func.(:repo, :changes)

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    assert ppl_req.pre_flight_checks["organization_pfc"] == %{
             "commands" => [~s[echo "organization PFC"]],
             "secrets" => ["ORG_SECRET"]
           }

    assert ppl_req.pre_flight_checks["project_pfc"] == %{
             "commands" => [~s[echo "project PFC"]],
             "secrets" => ["PRJ_SECRET"],
             "agent" => %{
               "machine_type" => "e1-standard-4",
               "os_image" => "ubuntu2004"
             }
           }

    :timer.sleep(4_000)

    assert {:ok, "done", "passed"} == TaskClient.describe(compl_task_id)

    GrpcMock.verify!(ProjectServiceMock)
    GrpcMock.verify!(PFCServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "when pipeline comes from git service => sub_init goes to compilation and task is started" do
    ProjectServiceMock
    |> GrpcMock.expect(:describe, fn _req, _ ->
      %{
        metadata: %{status: %{code: :OK}},
        project: %{spec: %{artifact_store_id: "art_id_1"}}
      }
      |> Proto.deep_new!(DescribeResponse)
    end)

    loopers =
      []
      |> Enum.concat([Task.Supervisor.start_link(name: PplsTaskSupervisor)])
      |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
      |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
      |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])

    {:ok, %{ppl_id: ppl_id}} =
      %{
        "repo_name" => "22_skip_block",
        "file_name" => "multiple_valid_whens.yml",
        "label" => "multiple_valid_whens",
        "branch_name" => "multiple_valid_whens"
      }
      |> Test.Helpers.schedule_request_factory(:git)
      |> Actions.schedule()

    :timer.sleep(2_000)

    assert {:ok, psi} = PplSubInitsQueries.get_by_id(ppl_id)
    assert psi.state == "fetching"

    assert {:ok, exit_func} = FetchingState.scheduling_handler(psi)
    assert {:ok, %{state: "compilation", compile_task_id: compl_task_id}} =
             exit_func.(:repo, :changes)

    :timer.sleep(2_000)

    assert {:ok, "done", "passed"} == TaskClient.describe(compl_task_id)

    GrpcMock.verify!(ProjectServiceMock)

    Test.Helpers.stop_all_loopers(loopers)
  end
end
