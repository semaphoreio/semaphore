defmodule Scheduler.Actions.RunNowImpl.Test do
  use ExUnit.Case, async: false

  alias Scheduler.Actions.RunNowImpl

  alias Scheduler.Periodics.Model.PeriodicsQueries, as: PQueries

  @grpc_port 50_055
  @mocked_services [
    Test.MockWorkflowService,
    Test.MockRepoProxyService,
    Test.MockFeatureService,
    Test.MockProjectService,
    Test.MockRepositoryService
  ]

  setup_all do
    GRPC.Server.start(@mocked_services, @grpc_port)
    on_exit(fn -> GRPC.Server.stop(@mocked_services) end)
  end

  setup do
    Test.Helpers.truncate_db()
    ids = Test.Helpers.seed_front_db()

    reset_mock_feature_service()
    use_mock_workflow_service()
    use_mock_repo_proxy_service()
    use_mock_project_service()
    use_mock_repository_service()

    mock_workflow_service_response("ok")
    mock_feature_response("disabled")
    mock_project_service_response("ok")
    mock_repository_service_response("ok")

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")
    {:ok, %{ids: ids}}
  end

  describe "run_now/1" do
    test "when id is missing" do
      assert {:error, {:INVALID_ARGUMENT, "The 'id' parameter can not be empty string."}} =
               RunNowImpl.run_now(%{id: "", requester: "user_1"})
    end

    test "when requester is missing" do
      assert {:error, {:INVALID_ARGUMENT, "The 'requester' parameter can not be empty string."}} =
               RunNowImpl.run_now(%{id: "some_id", requester: ""})
    end

    test "when periodic is not found" do
      assert {:error, {:NOT_FOUND, "Scheduler with id:'invalid_id' not found."}} =
               RunNowImpl.run_now(%{id: "invalid_id", requester: "user_1"})
    end

    test "when periodic has default branch and pipeline file then these are not mandatory", ctx do
      assert {:ok, periodics} = insert_periodics(ctx.ids)

      assert {:ok, %{trigger: trigger}} = RunNowImpl.run_now(run_now_params(periodics))

      assert %{branch: "master", pipeline_file: "deploy.yml", parameter_values: []} = trigger
    end

    test "when periodic has default branch and pipeline file then these are overriden", ctx do
      assert {:ok, periodics} =
               insert_periodics(ctx.ids, %{branch: "develop", pipeline_file: "test.yml"})

      assert {:ok, %{trigger: trigger}} =
               RunNowImpl.run_now(
                 run_now_params(periodics, %{branch: "master", pipeline_file: "deploy.yml"})
               )

      assert %{branch: "master", pipeline_file: "deploy.yml", parameter_values: []} = trigger
    end

    test "when periodic has required parameters without defaults and value is not provided then returns error",
         ctx do
      assert {:ok, periodics} =
               insert_periodics(ctx.ids, %{
                 parameters: [
                   %{name: "param1", required: true, default_value: nil}
                 ]
               })

      assert {:error, {:INVALID_ARGUMENT, "Parameter 'param1' is required."}} =
               RunNowImpl.run_now(run_now_params(periodics, %{parameter_values: []}))
    end

    test "when periodic has required parameters with defaults and value is empty then default is used",
         ctx do
      assert {:ok, periodics} =
               insert_periodics(ctx.ids, %{
                 parameters: [
                   %{name: "param1", required: true, default_value: "value1"}
                 ]
               })

      assert {:ok, %{triggers: [trigger]}} =
               RunNowImpl.run_now(
                 run_now_params(periodics, %{
                   parameter_values: [
                     %{name: "param1", value: ""}
                   ]
                 })
               )

      assert %{parameter_values: [%{name: "param1", value: "value1"}]} = trigger
    end

    test "when periodic has required parameters and value is given then override a default",
         ctx do
      assert {:ok, periodics} =
               insert_periodics(ctx.ids, %{
                 parameters: [
                   %{name: "param1", required: true, default_value: "value1"}
                 ]
               })

      assert {:ok, %{trigger: trigger}} =
               RunNowImpl.run_now(
                 run_now_params(periodics, %{
                   parameter_values: [
                     %{name: "param1", value: "value2"}
                   ]
                 })
               )

      assert %{parameter_values: [%{name: "param1", value: "value2"}]} = trigger
    end

    test "when project service returns error with JustRun enabled then returns error", ctx do
      mock_feature_response("just_run")
      mock_project_service_response("failed_precondition")

      assert {:ok, periodics} =
               insert_periodics(ctx.ids, %{
                 parameters: [
                   %{name: "param1", required: true, default_value: "value1"}
                 ]
               })

      assert {:error, {:FAILED_PRECONDITION, "Project assigned to periodic was not found."}} =
               RunNowImpl.run_now(
                 run_now_params(periodics, %{
                   parameter_values: [
                     %{name: "param1", value: "value2"}
                   ]
                 })
               )
    end

    test "when repository service returns error with JustRun enabled then returns error", ctx do
      mock_feature_response("just_run")
      mock_repository_service_response("failed_precondition")

      assert {:ok, periodics} =
               insert_periodics(ctx.ids, %{
                 parameters: [
                   %{name: "param1", required: true, default_value: "value1"}
                 ]
               })

      assert {:error, {:FAILED_PRECONDITION, "Cannot find git reference refs/heads/master."}} =
               RunNowImpl.run_now(
                 run_now_params(periodics, %{
                   parameter_values: [
                     %{name: "param1", value: "value2"}
                   ]
                 })
               )
    end

    test "when periodic is started with run_now then requester_id and triggered_by are properly set",
         ctx do
      alias Scheduler.Actions.ScheduleWfImpl

      requester_id = UUID.uuid4()
      assert {:ok, periodics} = insert_periodics(ctx.ids)

      assert {:ok, %{trigger: trigger}} =
               RunNowImpl.run_now(run_now_params(periodics, requester_id: requester_id))

      repository = %{id: UUID.uuid4(), integration_type: :GITHUB_OAUTH_TOKEN}

      assert {:ok, schedule_params} =
               ScheduleWfImpl.form_just_run_schedule_params(periodics, trigger, repository)

      assert schedule_params.service == :GIT_HUB
      assert schedule_params.requester_id == requester_id
      assert schedule_params.triggered_by == :MANUAL_RUN
    end
  end

  describe "merge_values/2" do
    test "when optional parameter has no default value and value given then value is used" do
      parameters = [
        %{name: "param1", required: false, default_value: "value1"},
        %{name: "param2", required: false, default_value: ""},
        %{name: "param3", required: false, default_value: nil}
      ]

      request_values = [
        %{name: "param1", value: "value"},
        %{name: "param2", value: "value"},
        %{name: "param3", value: "value"}
      ]

      assert {:ok,
              [
                %{name: "param1", value: "value"},
                %{name: "param2", value: "value"},
                %{name: "param3", value: "value"}
              ]} = RunNowImpl.merge_values(parameters, request_values)
    end

    test "when optional parameter has default value and no value given then default is used" do
      parameters = [
        %{name: "param1", required: false, default_value: "value1"},
        %{name: "param2", required: false, default_value: "value2"},
        %{name: "param3", required: false, default_value: "value3"}
      ]

      request_values = [%{name: "param1", value: "value"}]

      assert {:ok,
              [
                %{name: "param1", value: "value"},
                %{name: "param2", value: "value2"},
                %{name: "param3", value: "value3"}
              ]} = RunNowImpl.merge_values(parameters, request_values)
    end

    test "when optional parameter has no default value and no value given then parameters are omitted" do
      parameters = [
        %{name: "param1", required: false, default_value: "value1"},
        %{name: "param2", required: false, default_value: ""},
        %{name: "param3", required: false, default_value: nil}
      ]

      request_values = [%{name: "param1", value: "value"}]

      assert {:ok, [%{name: "param1", value: "value"}]} =
               RunNowImpl.merge_values(parameters, request_values)
    end

    test "when required parameter has no value given and default value is present then uses default" do
      parameters = [
        %{name: "param1", required: true, default_value: "value1"},
        %{name: "param2", required: true, default_value: ""},
        %{name: "param3", required: true, default_value: nil}
      ]

      request_values = [%{name: "param2", value: "v"}, %{name: "param3", value: "value"}]

      assert {:ok,
              [
                %{name: "param1", value: "value1"},
                %{name: "param2", value: "v"},
                %{name: "param3", value: "value"}
              ]} = RunNowImpl.merge_values(parameters, request_values)
    end

    test "when required parameter has no value given and default value is not present then error is returned" do
      parameters = [
        %{name: "param1", required: true, default_value: "value1"},
        %{name: "param2", required: true, default_value: ""},
        %{name: "param3", required: true, default_value: nil}
      ]

      request_values = [%{name: "param1", value: "value1"}, %{name: "param2", value: "value"}]

      assert {:error, {:INVALID_ARGUMENT, "Parameter 'param3' is required."}} =
               RunNowImpl.merge_values(parameters, request_values)
    end
  end

  defp insert_periodics(ids, extra \\ %{}) do
    %{
      requester_id: ids.usr_id,
      organization_id: ids.org_id,
      name: "Periodic_1",
      project_name: "Project_1",
      recurring: if(is_nil(extra[:recurring]), do: true, else: extra[:recurring]),
      project_id: ids.pr_id,
      branch: extra[:branch] || "master",
      at: extra[:at] || "* * * * *",
      pipeline_file: extra[:pipeline_file] || "deploy.yml",
      parameters: extra[:parameters] || []
    }
    |> PQueries.insert()
  end

  defp run_now_params(periodic, extra \\ %{}) do
    %{
      id: periodic.id,
      requester: extra[:requester_id] || periodic.requester_id,
      branch: extra[:branch] || "",
      pipeline_file: extra[:pipeline_file] || "",
      parameter_values: extra[:parameter_values] || []
    }
  end

  defp use_mock_workflow_service(),
    do:
      Application.put_env(
        :scheduler,
        :workflow_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  def mock_workflow_service_response(value),
    do: Application.put_env(:scheduler, :mock_workflow_service_response, value)

  defp use_mock_repo_proxy_service(),
    do:
      Application.put_env(
        :scheduler,
        :repo_proxy_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  defp reset_mock_feature_service() do
    Cachex.clear(Elixir.Scheduler.FeatureHubProvider)

    Application.put_env(
      :scheduler,
      :feature_api_grpc_endpoint,
      "localhost:#{inspect(@grpc_port)}"
    )
  end

  defp mock_feature_response(value),
    do: Application.put_env(:scheduler, :mock_feature_service_response, value)

  defp use_mock_project_service(),
    do:
      Application.put_env(
        :scheduler,
        :projecthub_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  defp mock_project_service_response(value),
    do: Application.put_env(:scheduler, :mock_project_service_response, value)

  defp use_mock_repository_service(),
    do:
      Application.put_env(
        :scheduler,
        :repositoryhub_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  defp mock_repository_service_response(value),
    do: Application.put_env(:scheduler, :mock_repository_service_response, value)
end
