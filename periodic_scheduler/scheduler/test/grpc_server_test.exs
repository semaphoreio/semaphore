defmodule Scheduler.GrpcServer.Test do
  use ExUnit.Case

  alias InternalApi.PeriodicScheduler.{
    PeriodicService,
    ApplyRequest,
    DescribeRequest,
    ListRequest,
    ListKeysetRequest,
    VersionRequest,
    GetProjectIdRequest,
    PauseRequest,
    UnpauseRequest,
    DeleteRequest,
    RunNowRequest,
    LatestTriggersRequest,
    HistoryRequest,
    PersistRequest
  }

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Actions
  alias Crontab.CronExpression.Composer
  alias Test.MockWorkflowService
  alias Util.Proto

  setup do
    Test.Helpers.truncate_db()
    ids = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")

    {:ok, %{ids: ids}}
  end

  @mocks [
    MockWorkflowService,
    Test.MockFeatureService,
    Test.MockProjectService,
    Test.MockRepositoryService
  ]
  @grpc_port 50_056
  setup_all do
    GRPC.Server.start(@mocks, @grpc_port)
    reset_mock_feature_service()
    mock_feature_response("disabled")

    on_exit(fn ->
      GRPC.Server.stop(@mocks)
    end)

    {:ok, %{}}
  end

  # Apply

  test "gRPC apply() with apiVersion = 1.1 and recurring = true creates new periodic and starts quantum job for it",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition_v_1_1_recurring_(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    ts_before = NaiveDateTime.utc_now()

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    assert periodic.branch == "master"
    assert periodic.at == "0 0 * * * *"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.recurring
    assert periodic.paused == false
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert periodic.parameters |> List.first() |> Map.from_struct() == %{
             name: "environment",
             description: nil,
             required: true,
             options: ["production", "staging"],
             default_value: "staging"
           }

    assert jobs = QuantumScheduler.jobs()
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, periodic.at)
  end

  test "gRPC apply() with apiVersion = 1.1 and recurring=false creates new periodic and does not start quantum job for it",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition_v_1_1_non_recurring_(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    ts_before = NaiveDateTime.utc_now()

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    refute periodic.recurring
    refute periodic.at
    assert periodic.branch == "master"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.paused == false
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert periodic.parameters |> List.first() |> Map.from_struct() == %{
             name: "environment",
             description: nil,
             required: true,
             options: ["production", "staging"],
             default_value: "staging"
           }

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  defp default_params(ctx) do
    %{
      branch: "master",
      at: "0 0 * * * *",
      project: "Project 1",
      name: "P1",
      organization_id: ctx.ids.org_id,
      project_id: ctx.ids.pr_id,
      project_name: "Project 1",
      recurring: true,
      requester_id: ctx.ids.usr_id,
      pipeline_file: ".semaphore/cron.yml",
      paused: false,
      state: :UNCHANGED,
      parameters: [
        %{
          name: "environment",
          required: true,
          options: ["production", "staging"],
          default_value: "staging"
        }
      ]
    }
  end

  defp valid_yml_definition_v_1_1_recurring_(ctx, params) do
    params = default_params(ctx) |> Map.merge(params)

    """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: P1
      #{if is_nil(params[:id]), do: "", else: "id: #{params.id}"}
    spec:
      project: #{params.project}
      recurring: true
      branch: #{params.branch}
      at: #{params.at}
      pipeline_file: #{params.pipeline_file}
      #{if is_nil(params[:paused]), do: "", else: "paused: #{params.paused}"}
      parameters:
        - name: environment
          required: true
          options:
            - production
            - staging
          default_value: staging
    """
  end

  defp valid_yml_definition_v_1_1_non_recurring_(ctx, params) do
    params = default_params(ctx) |> Map.merge(params)

    """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: P1
      #{if is_nil(params[:id]), do: "", else: "id: #{params.id}"}
      #{if is_nil(params[:description]), do: "", else: "description: #{params.description}"}
    spec:
      project: #{params.project}
      recurring: false
      branch: master
      pipeline_file: .semaphore/cron.yml
      #{if is_nil(params[:paused]), do: "", else: "paused: #{params.paused}"}
      parameters:
        - name: environment
          required: true
          options:
            - production
            - staging
          default_value: staging
    """
  end

  test "gRPC apply() creates new periodic and starts quantum job for it", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    ts_before = NaiveDateTime.utc_now()

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    assert periodic.branch == "master"
    assert periodic.at == "0 0 * * * *"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.paused == false
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert jobs = QuantumScheduler.jobs()
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, periodic.at)
  end

  test "gRPC apply() with paused=true creates new periodic and does not quantum job for it",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{paused: true})
      }
      |> Proto.deep_new!(ApplyRequest)

    ts_before = NaiveDateTime.utc_now()

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    assert periodic.branch == "master"
    assert periodic.at == "0 0 * * * *"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.paused == true
    assert periodic.pause_toggled_by == request.requester_id
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :lt
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  defp valid_yml_definition(ctx, params) do
    default_params(ctx)
    |> Map.merge(params)
    |> valid_yml_definition_()
  end

  defp valid_yml_task_definition(ctx, params) do
    default_params(ctx)
    |> Map.merge(params)
    |> valid_yml_task_definition_()
  end

  defp valid_yml_definition_(params = %{id: id}) do
    """
    apiVersion: v1.0
    kind: Schedule
    metadata:
      name: #{params.name}
      id: #{id}
    spec:
      project: #{params.project}
      branch: #{params.branch}
      at: #{params.at}
      pipeline_file: #{params.pipeline_file}
      #{if params.paused != nil, do: "paused: #{params.paused}", else: ""}
    """
  end

  defp valid_yml_definition_(params) do
    """
    apiVersion: v1.0
    kind: Schedule
    metadata:
      name: #{params.name}
    spec:
      project: #{params.project}
      branch: #{params.branch}
      at: #{params.at}
      pipeline_file: #{params.pipeline_file}
      #{if params.paused != nil, do: "paused: #{params.paused}", else: ""}
    """
  end

  defp valid_yml_task_definition_(params) do
    """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: #{params.name}
    spec:
      project: #{params.project}
      recurring: #{params.recurring}
      branch: #{params.branch}]
      at: #{params.at}
      pipeline_file: #{params.pipeline_file}
      paused: #{params.paused == true}
      parameters:
      - name: environment
        required: true
        options:
        - production
        - staging
        default_value: staging
      - name: debug
        description: "Enable debug mode"
        required: false
        default_value: "false"
    """
  end

  defp apply_grpc(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.apply(request)

    assert {:ok, apply_response} = response

    assert %{id: id, status: %{code: ^expected_status, message: msg}} = apply_response

    {id, msg}
  end

  test "gRPC apply() updates existing periodic and it's quantum job", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    ts_before = NaiveDateTime.utc_now()

    params = %{id: id, at: "1 1 * * * *"}
    request_2 = request |> Map.put(:yml_definition, valid_yml_definition(ctx, params))
    assert {id_2, ""} = apply_grpc(request_2, :OK)
    assert id == id_2

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id_2)
    assert periodic.at == "1 1 * * * *"
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :gt
    assert NaiveDateTime.compare(ts_before, periodic.updated_at) == :lt
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert periodic.paused == false

    assert jobs = QuantumScheduler.jobs()
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, "1 1 * * * *")
  end

  test "gRPC apply() updates existing running periodic with paused=true and stops quantum job",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert jobs = QuantumScheduler.jobs()
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, "0 0 * * * *")

    ts_before = NaiveDateTime.utc_now()

    params = %{id: id, at: "1 1 * * * *", paused: true}
    request_2 = request |> Map.put(:yml_definition, valid_yml_definition(ctx, params))
    assert {id_2, ""} = apply_grpc(request_2, :OK)
    assert id == id_2

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id_2)
    assert periodic.at == "1 1 * * * *"
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :gt
    assert NaiveDateTime.compare(ts_before, periodic.updated_at) == :lt
    assert periodic.pause_toggled_by == request.requester_id
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :lt
    assert periodic.paused == true

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC apply() - updating paused periodic does not start it's quantum job nor change paused fields",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    pause_request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)
    assert "Scheduler was paused successfully." == pause_grpc(pause_request, :OK)
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
    ts_before = NaiveDateTime.utc_now()

    params = %{id: id, at: "1 1 * * * *", paused: true}
    request_2 = request |> Map.put(:yml_definition, valid_yml_definition(ctx, params))
    assert {id_2, ""} = apply_grpc(request_2, :OK)
    assert id == id_2
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id_2)
    assert periodic.paused == true
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :gt

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC apply() - updating paused periodic without paused field does not start it's quantum job",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    pause_request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)
    assert "Scheduler was paused successfully." == pause_grpc(pause_request, :OK)
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    ts_before = NaiveDateTime.utc_now()

    params = %{id: id, at: "1 1 * * * *", paused: nil}
    request_2 = request |> Map.put(:yml_definition, valid_yml_definition(ctx, params))
    require Logger
    assert {id_2, ""} = apply_grpc(request_2, :OK)
    assert id == id_2
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id_2)
    assert periodic.paused == true
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :gt
    assert periodic.pause_toggled_by == pause_request.requester

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC apply() - updating paused periodic with paused=false starts it's quantum job and update pause fields",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    pause_request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)
    assert "Scheduler was paused successfully." == pause_grpc(pause_request, :OK)
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    ts_before = NaiveDateTime.utc_now()

    params = %{id: id, at: "1 1 * * * *", paused: false}
    request_2 = request |> Map.put(:yml_definition, valid_yml_definition(ctx, params))
    assert {id_2, ""} = apply_grpc(request_2, :OK)
    assert id == id_2
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id_2)
    assert periodic.paused == false
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :lt
    assert periodic.pause_toggled_by == request_2.requester_id

    assert jobs = QuantumScheduler.jobs()
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, "1 1 * * * *")
  end

  test "gRPC apply() - updating suspended periodic does not start it's quantum job", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert {:ok, _periodic} = PeriodicsQueries.suspend(periodic)
    id |> String.to_atom() |> QuantumScheduler.delete_job()
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    params = %{id: id, at: "1 1 * * * *"}
    request_2 = request |> Map.put(:yml_definition, valid_yml_definition(ctx, params))
    assert {id_2, ""} = apply_grpc(request_2, :OK)
    assert id == id_2

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC apply() returns FAILED_PRECONDITION when project does not exist", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{project: "Non-existent"})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {"", msg} = apply_grpc(request, :FAILED_PRECONDITION)
    assert msg == "Project with name 'Non-existent' not found."
  end

  test "gRPC apply() returns FAILED_PRECONDITION when there are no hooks for given branch", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{branch: "dev"})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {"", msg} = apply_grpc(request, :FAILED_PRECONDITION)

    assert msg ==
             "At least one regular workflow run on targeted branch is needed before periodic can be created."
  end

  test "gRPC apply() returns INVALID_ARGUMENT when cron expression is invalid", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{at: "not-cron-expr"})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {"", msg} = apply_grpc(request, :INVALID_ARGUMENT)
    assert String.starts_with?(msg, "Invalid cron expression in 'at' field:")
  end

  test "gRPC apply() returns INVALID_ARGUMENT when one of parameters is missing", ctx do
    0..8
    |> Enum.map(fn ind ->
      definition =
        valid_yml_definition(ctx, %{})
        |> String.split("\n")
        |> Enum.with_index()
        |> Enum.reduce("", fn {str, index}, acc ->
          if index != ind, do: acc <> str <> "\n", else: acc
        end)

      request =
        %{
          requester_id: ctx.ids.usr_id,
          organization_id: ctx.ids.org_id,
          yml_definition: definition
        }
        |> Proto.deep_new!(ApplyRequest)

      assert {"", msg} = apply_grpc(request, :INVALID_ARGUMENT)
      assert String.contains?(msg, "malformed")
    end)
  end

  test "gRPC apply() returns INVALID_ARGUMENT when name or pipeline_file is empty string", ctx do
    [:name, :pipeline_file]
    |> Enum.map(fn field ->
      definition = valid_yml_definition(ctx, Map.put(%{}, field, "\"\""))

      request =
        %{
          requester_id: ctx.ids.usr_id,
          organization_id: ctx.ids.org_id,
          yml_definition: definition
        }
        |> Proto.deep_new!(ApplyRequest)

      assert {"", msg} = apply_grpc(request, :INVALID_ARGUMENT)
      assert msg == "The '#{field}' parameter can not be empty string."
    end)
  end

  # Persist

  defp persist_grpc(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.persist(request)

    assert {:ok, persist_response} = response

    assert %{periodic: periodic, status: %{code: ^expected_status, message: msg}} =
             persist_response

    {periodic, msg}
  end

  test "gRPC persist() with recurring = true creates new periodic and starts quantum job for it",
       ctx do
    request = default_params(ctx) |> Proto.deep_new!(PersistRequest)
    ts_before = NaiveDateTime.utc_now()

    assert {periodic, ""} = persist_grpc(request, :OK)
    assert {:ok, _} = UUID.info(periodic.id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(periodic.id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    assert periodic.branch == "master"
    assert periodic.at == "0 0 * * * *"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.recurring
    assert periodic.paused == false
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert periodic.parameters |> List.first() |> Map.from_struct() == %{
             name: "environment",
             description: nil,
             required: true,
             options: ["production", "staging"],
             default_value: "staging"
           }

    assert jobs = QuantumScheduler.jobs()
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, periodic.at)
  end

  test "gRPC persist() with recurring=false creates new periodic and does not start quantum job for it",
       ctx do
    request =
      default_params(ctx)
      |> Map.merge(%{recurring: false, at: ""})
      |> Proto.deep_new!(PersistRequest)

    ts_before = NaiveDateTime.utc_now()

    assert {periodic, ""} = persist_grpc(request, :OK)
    assert {:ok, _} = UUID.info(periodic.id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(periodic.id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    refute periodic.recurring
    refute periodic.at
    assert periodic.branch == "master"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.paused == false
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert periodic.parameters |> List.first() |> Map.from_struct() == %{
             name: "environment",
             description: nil,
             required: true,
             options: ["production", "staging"],
             default_value: "staging"
           }

    assert nil == periodic.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC persist() with state=paused creates new periodic and does not start quantum job for it",
       ctx do
    request =
      default_params(ctx) |> Map.merge(%{state: :PAUSED}) |> Proto.deep_new!(PersistRequest)

    ts_before = NaiveDateTime.utc_now()

    assert {periodic, ""} = persist_grpc(request, :OK)
    assert {:ok, _} = UUID.info(periodic.id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(periodic.id)
    assert periodic.requester_id == request.requester_id
    assert periodic.organization_id == request.organization_id
    assert periodic.name == "P1"
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.ids.pr_id
    assert periodic.recurring
    assert periodic.at == "0 0 * * * *"
    assert periodic.branch == "master"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.paused == true
    assert periodic.pause_toggled_by == ctx.ids.usr_id

    assert periodic.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix() ==
             periodic.pause_toggled_at |> DateTime.to_unix()

    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :lt

    assert periodic.parameters |> List.first() |> Map.from_struct() == %{
             name: "environment",
             description: nil,
             required: true,
             options: ["production", "staging"],
             default_value: "staging"
           }

    assert nil == periodic.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC persist() updates existing periodic and it's quantum job", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    ts_before = NaiveDateTime.utc_now()

    request_2 =
      default_params(ctx)
      |> Map.merge(%{id: id, at: "1 1 * * * *"})
      |> Proto.deep_new!(PersistRequest)

    assert {periodic, ""} = persist_grpc(request_2, :OK)
    assert id == periodic.id

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.at == "1 1 * * * *"
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :gt
    assert NaiveDateTime.compare(ts_before, periodic.updated_at) == :lt
    assert periodic.pause_toggled_by == ""
    assert periodic.pause_toggled_at == nil
    assert periodic.paused == false

    assert jobs = QuantumScheduler.jobs()
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, "1 1 * * * *")
  end

  test "gRPC persist() updates existing running periodic with paused=true and stops quantum job",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert jobs = QuantumScheduler.jobs()
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, "0 0 * * * *")

    ts_before = NaiveDateTime.utc_now()

    request_2 =
      default_params(ctx)
      |> Map.merge(%{id: id, at: "1 1 * * * *", state: :PAUSED})
      |> Proto.deep_new!(PersistRequest)

    assert {periodic, ""} = persist_grpc(request_2, :OK)
    assert id == periodic.id

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.at == "1 1 * * * *"
    assert NaiveDateTime.compare(ts_before, periodic.inserted_at) == :gt
    assert NaiveDateTime.compare(ts_before, periodic.updated_at) == :lt
    assert periodic.pause_toggled_by == request.requester_id
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :lt
    assert periodic.paused == true

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC persist() - updating paused periodic does not start it's quantum job nor change paused fields",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    pause_request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)
    assert "Scheduler was paused successfully." == pause_grpc(pause_request, :OK)
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
    ts_before = NaiveDateTime.utc_now()

    request_2 =
      default_params(ctx)
      |> Map.merge(%{id: id, at: "1 1 * * * *", state: :UNCHANGED})
      |> Proto.deep_new!(PersistRequest)

    assert {periodic, ""} = persist_grpc(request_2, :OK)
    assert id == periodic.id
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == true
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :gt

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC persist() - updating paused periodic with paused=false starts it's quantum job and update pause fields",
       ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    pause_request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)
    assert "Scheduler was paused successfully." == pause_grpc(pause_request, :OK)
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    ts_before = NaiveDateTime.utc_now()

    request_2 =
      default_params(ctx)
      |> Map.merge(%{id: id, at: "1 1 * * * *", state: :ACTIVE})
      |> Proto.deep_new!(PersistRequest)

    assert {periodic, ""} = persist_grpc(request_2, :OK)
    assert id == periodic.id
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == false
    assert NaiveDateTime.compare(ts_before, periodic.pause_toggled_at) == :lt
    assert periodic.pause_toggled_by == request_2.requester_id

    assert jobs = QuantumScheduler.jobs()
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    job_name = periodic.id |> String.to_atom()
    assert jobs[job_name].state == :active
    string_at = Composer.compose(jobs[job_name].schedule)
    assert String.ends_with?(string_at, "1 1 * * * *")
  end

  test "gRPC persist() - updating suspended periodic does not start it's quantum job", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _} = UUID.info(id)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert {:ok, _periodic} = PeriodicsQueries.suspend(periodic)
    id |> String.to_atom() |> QuantumScheduler.delete_job()
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    request_2 =
      default_params(ctx)
      |> Map.merge(%{id: id, at: "1 1 * * * *", state: :ACTIVE})
      |> Proto.deep_new!(PersistRequest)

    assert {periodic, ""} = persist_grpc(request_2, :OK)
    assert id == periodic.id

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC persist() returns FAILED_PRECONDITION when project does not exist", ctx do
    non_existent_project_id = UUID.uuid4()

    request =
      default_params(ctx)
      |> Map.merge(%{project_id: non_existent_project_id})
      |> Proto.deep_new!(PersistRequest)

    assert {nil, msg} = persist_grpc(request, :FAILED_PRECONDITION)
    assert msg == "Project with ID '#{non_existent_project_id}' not found."
  end

  test "gRPC persist() returns INVALID_ARGUMENT when cron expression is invalid", ctx do
    request = default_params(ctx) |> Map.merge(%{at: "asdf"}) |> Proto.deep_new!(PersistRequest)
    assert {nil, msg} = persist_grpc(request, :INVALID_ARGUMENT)
    assert String.starts_with?(msg, "Invalid cron expression in 'at' field:")
  end

  test "gRPC persist() returns INVALID_ARGUMENT when one of parameters is missing", ctx do
    for arg <- ~w(name branch pipeline_file organization_id project_id)a do
      request = default_params(ctx) |> Map.put(arg, "") |> Proto.deep_new!(PersistRequest)
      assert {nil, msg} = persist_grpc(request, :INVALID_ARGUMENT)
      assert String.contains?(msg, "empty")
    end
  end

  # Pause

  test "gRPC pause() - returns INVALID_ARGUMENT when id or requester is empty string" do
    request = %{id: "", requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "The 'id' parameter can not be empty string." ==
             pause_grpc(request, :INVALID_ARGUMENT)

    request = %{id: "id_1", requester: ""} |> Proto.deep_new!(PauseRequest)

    assert "The 'requester' parameter can not be empty string." ==
             pause_grpc(request, :INVALID_ARGUMENT)
  end

  test "gRPC pause() - returns NOT_FOUND when given id is not valid" do
    request = %{id: "id_1", requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler with id:'id_1' not found." == pause_grpc(request, :NOT_FOUND)
  end

  test "gRPC pause() - pauses periodic and returns OK when given valid params", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    assert %Quantum.Job{} = id |> String.to_atom() |> QuantumScheduler.find_job()

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_1"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC pause() - if periodic is already paused, return OK", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_1"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    request = %{id: id, requester: "user_2"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    assert {:ok, periodic2} = PeriodicsQueries.get_by_id(id)
    assert periodic2.paused == true
    assert periodic2.pause_toggled_by == "user_1"
    assert :eq == DateTime.compare(periodic.pause_toggled_at, periodic2.pause_toggled_at)
  end

  defp pause_grpc(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.pause(request)

    assert {:ok, pause_response} = response

    assert %{status: %{code: status_code, message: msg}} = pause_response

    assert expected_status == status_code

    msg
  end

  # Unpause

  test "gRPC unpause() - returns INVALID_ARGUMENT when id or requester is empty string" do
    request = %{id: "", requester: "user_1"} |> Proto.deep_new!(UnpauseRequest)

    assert "The 'id' parameter can not be empty string." ==
             unpause_grpc(request, :INVALID_ARGUMENT)

    request = %{id: "id_1", requester: ""} |> Proto.deep_new!(UnpauseRequest)

    assert "The 'requester' parameter can not be empty string." ==
             unpause_grpc(request, :INVALID_ARGUMENT)
  end

  test "gRPC unpause() - returns NOT_FOUND when given id is not valid" do
    request = %{id: "id_1", requester: "user_1"} |> Proto.deep_new!(UnpauseRequest)

    assert "Scheduler with id:'id_1' not found." == unpause_grpc(request, :NOT_FOUND)
  end

  test "gRPC unpause() - returns FAILED_PRECONDITION when cron expression is not valid", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{at: "0 0 30 2 * *"})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    assert %Quantum.Job{} = id |> String.to_atom() |> QuantumScheduler.find_job()

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_1"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    request = %{id: id, requester: "user_2"} |> Proto.deep_new!(UnpauseRequest)

    assert "The cron expression is invalid and must be corrected first." ==
             unpause_grpc(request, :FAILED_PRECONDITION)
  end

  test "gRPC unpause() - unpauses periodic and returns OK when given valid params", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    assert %Quantum.Job{} = id |> String.to_atom() |> QuantumScheduler.find_job()

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_1"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()

    request = %{id: id, requester: "user_2"} |> Proto.deep_new!(UnpauseRequest)

    assert "Scheduler was unpaused successfully." == unpause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == false
    assert periodic.pause_toggled_by == "user_2"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    assert %Quantum.Job{} = id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC unpause() - if periodic is not paused, return OK", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == true
    assert periodic.pause_toggled_by == "user_1"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    request = %{id: id, requester: "user_2"} |> Proto.deep_new!(UnpauseRequest)

    assert "Scheduler was unpaused successfully." == unpause_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.paused == false
    assert periodic.pause_toggled_by == "user_2"
    assert :lt == DateTime.compare(periodic.pause_toggled_at, DateTime.utc_now())

    request = %{id: id, requester: "user_3"} |> Proto.deep_new!(UnpauseRequest)

    assert "Scheduler was unpaused successfully." == unpause_grpc(request, :OK)

    assert {:ok, periodic2} = PeriodicsQueries.get_by_id(id)
    assert periodic2.paused == false
    assert periodic2.pause_toggled_by == "user_2"
    assert :eq == DateTime.compare(periodic.pause_toggled_at, periodic2.pause_toggled_at)
  end

  defp unpause_grpc(request, expected_status) when is_map(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.unpause(request)

    assert {:ok, unpause_response} = response

    assert %{status: %{code: status_code, message: msg}} = unpause_response

    assert expected_status == status_code

    msg
  end

  # RunNow

  test "gRPC run_now() - returns INVALID_ARGUMENT when id or requester is empty string" do
    request = %{id: "", requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    message = "The 'id' parameter can not be empty string."
    assert {:ok, nil, []} == run_now_grpc(request, :INVALID_ARGUMENT, message)

    request = %{id: "id_1", requester: ""} |> Proto.deep_new!(RunNowRequest)

    message = "The 'requester' parameter can not be empty string."
    assert {:ok, nil, []} == run_now_grpc(request, :INVALID_ARGUMENT, message)
  end

  test "gRPC run_now() - returns NOT_FOUND when given id is not valid" do
    request = %{id: "id_1", requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    message = "Scheduler with id:'id_1' not found."
    assert {:ok, nil, []} == run_now_grpc(request, :NOT_FOUND, message)
  end

  test "gRPC run_now() - returns FAILED_PRECONDITION if scheduler is suspended", ctx do
    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert {:ok, _periodic} = PeriodicsQueries.suspend(periodic)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    message = "The organization is supended."
    assert {:ok, nil, []} == run_now_grpc(request, :FAILED_PRECONDITION, message)
  end

  test "gRPC run_now() - with JustRun returns FAILED_PRECONDITION if project is not found", ctx do
    use_mock_project_service()
    use_mock_repository_service()

    mock_project_service_response("failed_precondition")
    mock_repository_service_response("ok")

    reset_mock_feature_service()
    mock_feature_response("just_run")
    on_exit(fn -> mock_feature_response("disabled") end)

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    assert {:ok, _periodic} = PeriodicsQueries.get_by_id(id)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    message = "Project assigned to periodic was not found."
    assert {:ok, nil, []} == run_now_grpc(request, :FAILED_PRECONDITION, message)
  end

  test "gRPC run_now() - with JustRun returns FAILED_PRECONDITION if revision is not found",
       ctx do
    use_mock_project_service()
    use_mock_repository_service()

    mock_project_service_response("ok")
    mock_repository_service_response("failed_precondition")

    reset_mock_feature_service()
    mock_feature_response("just_run")
    on_exit(fn -> mock_feature_response("disabled") end)

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    assert {:ok, _periodic} = PeriodicsQueries.get_by_id(id)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    message = "Cannot find git reference refs/heads/master."
    assert {:ok, nil, []} == run_now_grpc(request, :FAILED_PRECONDITION, message)
  end

  test "gRPC run_now() - with JustRun returns RESOURCE_EXHAUSTED if the queue is full on plumber",
       ctx do
    use_mock_workflow_service()
    use_mock_project_service()
    use_mock_repository_service()

    mock_workflow_service_response("resource_exhausted")
    mock_project_service_response("ok")
    mock_repository_service_response("ok")

    reset_mock_feature_service()
    mock_feature_response("just_run")
    on_exit(fn -> mock_feature_response("disabled") end)

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    message = "Too many pipelines in the queue."
    assert {:ok, nil, []} == run_now_grpc(request, :RESOURCE_EXHAUSTED, message)
  end

  test "gRPC run_now() - with JustRun when request is valid the workflow is scheduled", ctx do
    use_mock_workflow_service()
    use_mock_project_service()
    use_mock_repository_service()

    mock_workflow_service_response("ok")
    mock_project_service_response("ok")
    mock_repository_service_response("ok")

    reset_mock_feature_service()
    mock_feature_response("just_run")
    on_exit(fn -> mock_feature_response("disabled") end)

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    ts_before = DateTime.utc_now()

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    assert {:ok, periodic_desc, [trigger_desc]} = run_now_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

    keys = [
      :project_name,
      :description,
      :inserted_at,
      :updated_at,
      :pause_toggled_at,
      :__meta__,
      :reference_type,
      :reference_value
    ]

    assert periodic_desc
           |> Map.drop([
             :inserted_at,
             :description,
             :updated_at,
             :pause_toggled_at,
             :__struct__,
             :__unknown_fields__
           ]) ==
             periodic |> Map.from_struct() |> Map.drop(keys)

    assert periodic_desc.description == ""

    assert {:ok, [trigger]} = PeriodicsTriggersQueries.get_n_by_periodic_id(id, 1)
    assert trigger.scheduling_status == "passed"
    assert {:ok, _} = UUID.info(trigger.scheduled_workflow_id)
    assert trigger.run_now_requester_id == "user_1"
    assert trigger.error_description == nil
    assert DateTime.compare(trigger.scheduled_at, ts_before) == :gt

    tr_keys = ~w(inserted_at updated_at __meta__ id scheduled_at triggered_at recurring attempts
                 periodic_id periodics error_description __struct__ __unknown_fields__ reference_type reference_value)a

    assert trigger_desc |> Map.drop(tr_keys) ==
             trigger |> Map.from_struct() |> Map.drop(tr_keys)

    assert trigger_desc.error_description == ""
  end

  test "gRPC run_now() - without JustRun when request is valid the workflow is scheduled", ctx do
    use_mock_workflow_service()
    use_mock_project_service()
    use_mock_repository_service()

    mock_workflow_service_response("ok")
    mock_project_service_response("ok")
    mock_repository_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    ts_before = DateTime.utc_now()

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(RunNowRequest)

    assert {:ok, periodic_desc, [trigger_desc]} = run_now_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

    keys = [
      :project_name,
      :description,
      :inserted_at,
      :updated_at,
      :pause_toggled_at,
      :__meta__,
      :reference_type,
      :reference_value
    ]

    assert periodic_desc
           |> Map.drop([
             :inserted_at,
             :description,
             :updated_at,
             :pause_toggled_at,
             :__struct__,
             :__unknown_fields__
           ]) ==
             periodic |> Map.from_struct() |> Map.drop(keys)

    assert periodic_desc.description == ""

    assert {:ok, [trigger]} = PeriodicsTriggersQueries.get_n_by_periodic_id(id, 1)
    assert trigger.scheduling_status == "passed"
    assert {:ok, _} = UUID.info(trigger.scheduled_workflow_id)
    assert trigger.run_now_requester_id == "user_1"
    assert trigger.error_description == nil
    assert trigger.attempts == 1
    assert DateTime.compare(trigger.scheduled_at, ts_before) == :gt

    tr_keys = ~w(inserted_at updated_at __meta__ id scheduled_at triggered_at recurring attempts
                 periodic_id periodics error_description __struct__ __unknown_fields__ reference_type reference_value)a

    assert trigger_desc |> Map.drop(tr_keys) ==
             trigger |> Map.from_struct() |> Map.drop(tr_keys)

    assert trigger_desc.error_description == ""
  end

  defp run_now_grpc(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.run_now(request)

    assert {:ok, run_now_response} = response

    assert %{periodic: periodic, triggers: triggers, status: %{code: status_code, message: msg}} =
             run_now_response

    assert expected_status == status_code
    assert msg == message

    {:ok, periodic, triggers}
  end

  # Describe

  test "gRPC describe() - valid response when given valid id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    1..10
    |> Enum.map(fn _ ->
      assert {:ok, _pid} = Actions.start_schedule_task(id, DateTime.utc_now())
    end)

    assert {:ok, triggers} = PeriodicsTriggersQueries.get_n_by_periodic_id(id, 10)

    request = %{id: id} |> Proto.deep_new!(DescribeRequest)
    assert {:ok, periodic_desc, triggers_desc} = describe_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

    keys = [
      :project_name,
      :description,
      :inserted_at,
      :updated_at,
      :pause_toggled_at,
      :__meta__,
      :reference_type,
      :reference_value
    ]

    assert periodic_desc
           |> Map.drop([
             :inserted_at,
             :description,
             :updated_at,
             :pause_toggled_at,
             :__struct__,
             :__unknown_fields__
           ]) ==
             periodic |> Map.from_struct() |> Map.drop(keys)

    assert periodic_desc.description == ""

    tr_keys = ~w(inserted_at updated_at __meta__ id
                scheduled_at triggered_at periodic_id periodics)a

    triggers_desc
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {tr_desc, index} ->
      assert tr_desc |> Map.drop(tr_keys) ==
               Enum.at(triggers, index) |> Map.from_struct() |> Map.drop(tr_keys)
    end)
  end

  defp describe_grpc(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.describe(request)

    assert {:ok, desc_response} = response

    assert %{periodic: periodic, triggers: triggers, status: %{code: status_code, message: msg}} =
             desc_response

    assert expected_status == status_code
    assert msg == message

    {:ok, periodic, triggers}
  end

  test "gRPC describe() - valid response for paused periodic when given valid id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    request = %{id: id, requester: "user_1"} |> Proto.deep_new!(PauseRequest)

    assert "Scheduler was paused successfully." == pause_grpc(request, :OK)

    request = %{id: id} |> Proto.deep_new!(DescribeRequest)
    assert {:ok, periodic_desc, []} = describe_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

    keys = [
      :project_name,
      :description,
      :inserted_at,
      :updated_at,
      :pause_toggled_at,
      :__meta__,
      :reference_type,
      :reference_value
    ]

    assert periodic_desc
           |> Map.drop([
             :inserted_at,
             :description,
             :updated_at,
             :pause_toggled_at,
             :__struct__,
             :__unknown_fields__
           ]) ==
             periodic |> Map.from_struct() |> Map.drop(keys)

    assert periodic_desc.description == ""
  end

  test "gRPC describe() - NOT_FOUND error when periodic with given id is not found" do
    id = UUID.uuid4()
    msg = "Periodic with id: '#{id}' not found."
    request = DescribeRequest.new(id: id)
    assert {:ok, nil, []} == describe_grpc(request, :NOT_FOUND, msg)
  end

  test "gRPC describe() - INVALID_ARGUMENT error when id is empty string " do
    msg = "All search parameters in request are empty strings."
    assert {:ok, nil, []} == describe_grpc(DescribeRequest.new(), :INVALID_ARGUMENT, msg)
  end

  # History

  test "gRPC history() - valid response when given valid id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    1..16
    |> Enum.map(fn _ ->
      assert {:ok, _pid} = Actions.start_schedule_task(id, DateTime.utc_now())
    end)

    assert {:ok, triggers} = PeriodicsTriggersQueries.get_n_by_periodic_id(id, 10)

    request = %{periodic_id: id} |> Proto.deep_new!(HistoryRequest)
    assert {:ok, triggers_history, cursor_before, cursor_after} = history_grpc(request, :OK)

    tr_keys =
      ~w(inserted_at updated_at __meta__ id scheduled_at triggered_at periodic_id periodics)a

    triggers_history
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {tr_desc, index} ->
      assert tr_desc |> Map.drop(tr_keys) ==
               Enum.at(triggers, index) |> Map.from_struct() |> Map.drop(tr_keys)
    end)

    assert is_number(cursor_before)
    assert is_number(cursor_after)
  end

  defp history_grpc(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.history(request)

    assert {:ok, history_response} = response

    assert %{
             triggers: triggers,
             cursor_before: cursor_before,
             cursor_after: cursor_after,
             status: %{code: status_code, message: msg}
           } = history_response

    assert expected_status == status_code
    assert msg == message

    {:ok, triggers, cursor_before, cursor_after}
  end

  test "gRPC history() - NOT_FOUND error when periodic with given id is not found" do
    id = UUID.uuid4()
    msg = "Periodic '#{id}' not found."
    request = HistoryRequest.new(periodic_id: id)
    assert {:ok, [], 0, 0} == history_grpc(request, :NOT_FOUND, msg)
  end

  test "gRPC history() - INVALID_ARGUMENT error when id is empty string " do
    msg = "Missing argument: periodic_id"
    assert {:ok, [], 0, 0} == history_grpc(DescribeRequest.new(), :INVALID_ARGUMENT, msg)
  end

  # LatestTriggers

  test "gRPC latest_triggers() - valid response when given valid ids list", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    ts = Timex.now() |> Timex.shift(minutes: -3)

    # first periodic, 3 triggers, included in ids list
    assert id_1 = create_periodic(ctx.ids, 1)

    1..3
    |> Enum.map(fn _ ->
      assert {:ok, _pid} = Actions.start_schedule_task(id_1, ts)
    end)

    assert {:ok, [tr_1]} = PeriodicsTriggersQueries.get_n_by_periodic_id(id_1, 1)

    # second periodic, 5 triggers, included in ids list
    assert id_2 = create_periodic(ctx.ids, 2)

    1..5
    |> Enum.map(fn _ ->
      assert {:ok, _pid} = Actions.start_schedule_task(id_2, ts)
    end)

    assert {:ok, [tr_2]} = PeriodicsTriggersQueries.get_n_by_periodic_id(id_2, 1)

    # third periodic, no triggers, included in ids list
    assert id_3 = create_periodic(ctx.ids, 3)

    # fourth periodic, 7 triggers, not included in ids list

    assert id_4 = create_periodic(ctx.ids, 4)

    1..7
    |> Enum.map(fn _ ->
      assert {:ok, _pid} = Actions.start_schedule_task(id_4, ts)
    end)

    # test  latest_triggers() behavior

    request =
      %{periodic_ids: [id_1, id_2, id_3]}
      |> Proto.deep_new!(LatestTriggersRequest)

    assert {:ok, triggers} = latest_triggers(request, :OK)
    assert length(triggers) == 2

    assert res_tr_1 = Enum.find(triggers, fn elem -> elem.periodic_id == id_1 end)

    assert tr_1.triggered_at |> Map.get(:microsecond) |> elem(0) |> Kernel.*(1_000) ==
             res_tr_1 |> Map.get(:triggered_at) |> Map.get(:nanos)

    assert res_tr_2 = Enum.find(triggers, fn elem -> elem.periodic_id == id_2 end)

    assert tr_2.triggered_at |> Map.get(:microsecond) |> elem(0) |> Kernel.*(1_000) ==
             res_tr_2.triggered_at |> Map.get(:nanos)
  end

  test "gRPC latest_triggers() - empty list is returned if there are no periodic with given ids" do
    request =
      %{periodic_ids: [UUID.uuid4(), UUID.uuid4(), UUID.uuid4()]}
      |> Proto.deep_new!(LatestTriggersRequest)

    assert {:ok, []} == latest_triggers(request, :OK)
  end

  test "gRPC latest_triggers() - INVALID_ARGUMENT error when id list in request is empty" do
    msg = "Parameter 'periodic_ids' can not be an empty list."
    assert {:ok, []} == latest_triggers(LatestTriggersRequest.new(), :INVALID_ARGUMENT, msg)
  end

  test "gRPC latest_triggers() - Does not fail when triggererd_at is nil", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    # first periodic, 3 triggers, included in ids list
    assert id_1 = create_periodic(ctx.ids, 1)
    {:ok, periodic} = PeriodicsQueries.get_by_id(id_1)

    1..3
    |> Enum.map(fn _ ->
      assert {:ok, _pid} = PeriodicsTriggersQueries.insert(periodic, %{requester: "user-1"})
    end)

    assert {:ok, [_tr_1]} = PeriodicsTriggersQueries.get_n_by_periodic_id(id_1, 1)

    request =
      %{periodic_ids: [id_1]}
      |> Proto.deep_new!(LatestTriggersRequest)

    assert {:ok, triggers} = latest_triggers(request, :OK)
    assert length(triggers) == 1
  end

  defp latest_triggers(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.latest_triggers(request)

    assert {:ok, lt_response} = response

    assert %{triggers: triggers, status: %{code: status_code, message: msg}} = lt_response

    assert expected_status == status_code
    assert msg == message

    {:ok, triggers}
  end

  # List

  test "gRPC list() - valid response when listing by organization_id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params = %{organization_id: ctx.ids.org_id, page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{periodics: periodics, total_entries: 3}} = list_grpc(params, :OK)
    assert list_result_contains?(periodics, results)
  end

  test "gRPC list() - valid response when listing by project_id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params = %{project_id: ctx.ids.pr_id, page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{periodics: periodics, total_entries: 3}} = list_grpc(params, :OK)
    assert list_result_contains?(periodics, results)
  end

  test "gRPC list() - valid response when listing by requester_id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params =
      %{organization_id: ctx.ids.org_id, requester_id: ctx.ids.usr_id, page: 1, page_size: 5}
      |> ListRequest.new()

    assert {:ok, %{periodics: periodics, total_entries: 3}} = list_grpc(params, :OK)
    assert list_result_contains?(periodics, results)
  end

  test "gRPC list() - valid response when listing by query", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params =
      %{organization_id: ctx.ids.org_id, query: "2", page: 1, page_size: 5} |> ListRequest.new()

    assert {:ok, %{periodics: periodics, total_entries: 1}} = list_grpc(params, :OK)
    assert list_result_contains?(periodics, [results |> Enum.at(1)])
  end

  test "gRPC list() - valid response when listing ordered by creation date", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params =
      %{organization_id: ctx.ids.org_id, page: 1, page_size: 5, order: :BY_CREATION_DATE_DESC}
      |> ListRequest.new()

    assert {:ok, %{periodics: periodics, total_entries: 3}} = list_grpc(params, :OK)
    assert list_result_contains?(periodics, results |> Enum.reverse())
  end

  test "gRPC list() - works with periodics with parameters", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    reset_mock_feature_service()
    mock_feature_response("just_run")
    on_exit(fn -> mock_feature_response("disabled") end)

    results = 1..3 |> Enum.map(fn ind -> create_periodic_task(ctx.ids, ind) end)

    params = %{project_id: ctx.ids.pr_id, page: 1, page_size: 5} |> ListRequest.new()
    assert {:ok, %{periodics: periodics, total_entries: 3}} = list_grpc(params, :OK)
    assert list_result_contains?(periodics, results)
    assert parameters_valid?(periodics)
  end

  test "gRPC list() - INVALID_ARGUMENT error when both org_id and project_id are empty strings" do
    msg = "Either 'organization_id' or 'project_id' parameters are required."

    assert {:ok, %{page_number: 0, page_size: 0, periodics: [], total_entries: 0, total_pages: 0}} =
             list_grpc(ListRequest.new(), :INVALID_ARGUMENT, msg)
  end

  # ListKeyset

  test "gRPC list_keyset() - valid response when listing by organization_id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params =
      %{organization_id: ctx.ids.org_id, page_token: "", page_size: 5} |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: "", prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results)
  end

  test "gRPC list_keyset() - valid response when listing by project_id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params = %{project_id: ctx.ids.pr_id, page_token: "", page_size: 5} |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: "", prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results)
  end

  test "gRPC list_keyset() - valid response when listing ordered by creation date", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params =
      %{
        organization_id: ctx.ids.org_id,
        page_token: "",
        page_size: 5,
        order: :BY_CREATION_DATE_DESC
      }
      |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: "", prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results |> Enum.reverse())
  end

  test "gRPC list_keyset() - valid response when listing by query", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 1..3 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params =
      %{organization_id: ctx.ids.org_id, query: "2", page_token: "", page_size: 5}
      |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: "", prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, [results |> Enum.at(1)])
    assert Enum.count(periodics) == 1
  end

  test "gRPC list_keyset() - works with periodics with parameters", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    reset_mock_feature_service()
    mock_feature_response("just_run")
    on_exit(fn -> mock_feature_response("disabled") end)

    results = 1..3 |> Enum.map(fn ind -> create_periodic_task(ctx.ids, ind) end)

    params = %{project_id: ctx.ids.pr_id, page_token: "", page_size: 5} |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: "", prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results)
    assert parameters_valid?(periodics)
  end

  test "gRPC list_keyset() - valid response when paginating results", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    results = 0..9 |> Enum.map(fn ind -> create_periodic(ctx.ids, ind) end)

    params = %{project_id: ctx.ids.pr_id, page_token: "", page_size: 5} |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: npt, prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results |> Enum.take(5))
    assert npt != ""

    params =
      %{project_id: ctx.ids.pr_id, page_token: npt, page_size: 5, direction: :NEXT}
      |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: "", prev_page_token: ppt, page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results |> Enum.drop(5) |> Enum.take(5))

    params =
      %{project_id: ctx.ids.pr_id, page_token: ppt, page_size: 5, direction: :PREV}
      |> ListKeysetRequest.new()

    assert {:ok, %{periodics: periodics, next_page_token: npt, prev_page_token: "", page_size: 5}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results |> Enum.take(5))

    params =
      %{project_id: ctx.ids.pr_id, page_token: npt, page_size: 3, direction: :NEXT}
      |> ListKeysetRequest.new()

    assert {:ok,
            %{periodics: periodics, next_page_token: npt, prev_page_token: ppt, page_size: 3}} =
             list_keyset_grpc(params, :OK)

    assert list_result_contains?(periodics, results |> Enum.drop(5) |> Enum.take(3))
    assert npt != "" && ppt != ""
  end

  test "gRPC list_keyset() - INVALID_ARGUMENT error when both org_id and project_id are empty strings" do
    msg = "Either 'organization_id' or 'project_id' parameters are required."

    assert {:ok, %{next_page_token: "", prev_page_token: "", periodics: [], page_size: 0}} =
             list_keyset_grpc(ListKeysetRequest.new(), :INVALID_ARGUMENT, msg)
  end

  defp create_periodic(ids, ind) do
    yml = valid_yml_definition(%{ids: ids}, %{name: "P" <> "#{ind}"})

    request =
      %{requester_id: ids.usr_id, organization_id: ids.org_id, yml_definition: yml}
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    id
  end

  defp create_periodic_task(ids, ind) do
    yml = valid_yml_task_definition(%{ids: ids}, %{name: "P" <> "#{ind}"})

    request =
      %{requester_id: ids.usr_id, organization_id: ids.org_id, yml_definition: yml}
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    id
  end

  defp list_grpc(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.list(request)

    assert {:ok, list_response} = response

    assert rsp = %{status: %{code: status_code, message: msg}} = list_response

    assert expected_status == status_code
    assert msg == message

    {:ok, rsp |> Map.delete(:status)}
  end

  defp list_keyset_grpc(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.list_keyset(request)

    assert {:ok, list_response} = response

    assert rsp = %{status: %{code: status_code, message: msg}} = list_response

    assert expected_status == status_code
    assert msg == message

    {:ok, rsp |> Map.delete(:status)}
  end

  defp list_result_contains?(results, included) do
    included
    |> Enum.with_index()
    |> Enum.reduce_while(true, fn {periodic_id, ind}, _acc ->
      case Enum.at(results, ind) |> Map.get(:id) == periodic_id do
        false -> {:halt, false}
        true -> {:cont, true}
      end
    end)
  end

  defp parameters_valid?(periodics) do
    Enum.all?(periodics, fn periodic ->
      periodic.parameters
      |> Enum.map(&Map.take(&1, ~w(name description default_value required options)a))
      |> Map.new(&{&1.name, &1}) == %{
        "environment" => %{
          name: "environment",
          description: "",
          default_value: "staging",
          required: true,
          options: ["production", "staging"]
        },
        "debug" => %{
          name: "debug",
          description: "Enable debug mode",
          default_value: "false",
          required: false,
          options: []
        }
      }
    end)
  end

  # Delete

  test "gRPC delete() - periodic deleted when given periodic id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, _pid} = Actions.start_schedule_task(id, DateTime.utc_now())

    request = %{id: id, requester: "user1"} |> Proto.deep_new!(DeleteRequest)
    assert {:ok, msg} = delete_grpc(request, :OK)
    assert msg == "Periodic P1 with id #{id} was successfully deleted."

    assert {:error, _msg} = PeriodicsQueries.get_by_id(id)
    assert {:ok, []} == PeriodicsTriggersQueries.get_all_by_periodic_id(id)
    assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "gRPC delete() - NOT_FOUND error when periodic with given id is not found" do
    id = UUID.uuid4()
    request = DeleteRequest.new(id: id)
    assert {:ok, msg} = delete_grpc(request, :NOT_FOUND)
    assert msg == "Periodic with id: '#{id}' not found."
  end

  test "gRPC delete() - INVALID_ARGUMENT error when both id and org_id + name are empty strings" do
    assert {:ok, msg} = delete_grpc(DeleteRequest.new(), :INVALID_ARGUMENT)
    assert msg == "All search parameters in request are empty strings."
  end

  defp delete_grpc(request, expected_status) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.delete(request)

    assert {:ok, del_response} = response

    assert %{status: %{code: status_code, message: msg}} = del_response

    assert expected_status == status_code

    {:ok, msg}
  end

  # GetProjectId

  test "gRPC get_project_id() - returns project_id when given periodic id", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)

    request = GetProjectIdRequest.new(periodic_id: id)
    assert {:ok, project_id} = get_project_id_grpc(request, :OK)

    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
    assert periodic.project_id == project_id
  end

  test "gRPC get_project_id() - returns project_id when given org_id and project_name", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    request =
      %{
        requester_id: ctx.ids.usr_id,
        organization_id: ctx.ids.org_id,
        yml_definition: valid_yml_definition(ctx, %{})
      }
      |> Proto.deep_new!(ApplyRequest)

    assert {id, ""} = apply_grpc(request, :OK)
    assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

    request =
      %{organization_id: periodic.organization_id, project_name: periodic.project_name}
      |> GetProjectIdRequest.new()

    assert {:ok, project_id} = get_project_id_grpc(request, :OK)

    assert periodic.project_id == project_id
  end

  test "gRPC get_project_id() - NOT_FOUND error when project_id for given params is not found" do
    random_string = UUID.uuid4()

    request_1 =
      GetProjectIdRequest.new(organization_id: UUID.uuid4(), project_name: random_string)

    msg = "Project with name '#{random_string}' not found."
    assert {:ok, ""} = get_project_id_grpc(request_1, :NOT_FOUND, msg)

    request_2 = GetProjectIdRequest.new(periodic_id: random_string)
    msg = "Periodic with id: '#{random_string}' not found."
    assert {:ok, ""} = get_project_id_grpc(request_2, :NOT_FOUND, msg)
  end

  test "gRPC get_project_id() - INVALID_ARGUMENT error when all identifiers are empty strings" do
    msg = "One of these is required: periodic_id or organization_id + project_name."
    assert {:ok, ""} = get_project_id_grpc(GetProjectIdRequest.new(), :INVALID_ARGUMENT, msg)
  end

  defp get_project_id_grpc(request, expected_status, message \\ "") do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    response = channel |> PeriodicService.Stub.get_project_id(request)

    assert {:ok, gpid_response} = response

    assert %{project_id: id, status: %{code: status_code, message: msg}} = gpid_response

    assert expected_status == status_code
    assert message == msg

    {:ok, id}
  end

  # Version

  test "server availability by calling version() rpc" do
    {:ok, channel} = GRPC.Stub.connect("localhost:50050")
    request = VersionRequest.new()
    response = channel |> PeriodicService.Stub.version(request)
    assert {:ok, version_response} = response
    assert Map.get(version_response, :version) == Mix.Project.config()[:version]
  end

  # Utility

  defp use_mock_workflow_service(),
    do:
      Application.put_env(
        :scheduler,
        :workflow_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  def mock_workflow_service_response(value),
    do: Application.put_env(:scheduler, :mock_workflow_service_response, value)

  def mock_workflow_service_response_time(value),
    do: Application.put_env(:scheduler, :mock_workflow_service_response_time, value)

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
