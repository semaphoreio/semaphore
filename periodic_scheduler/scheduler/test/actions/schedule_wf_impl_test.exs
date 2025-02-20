defmodule Scheduler.Actions.ScheduleWfImpl.Test do
  use ExUnit.Case

  alias Scheduler.Actions.ScheduleWfImpl
  alias Scheduler.Workers.ScheduleTask
  alias Scheduler.Workers.ScheduleTaskManager
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries, as: PTQueries

  @mocks [
    AssertPramsWorkflowService,
    AssertPramsRepoProxy,
    Test.MockFeatureService,
    Test.MockProjectService,
    Test.MockRepositoryService
  ]
  @grpc_port 50_055

  setup_all do
    project_id = UUID.uuid4()
    org_id = UUID.uuid4()

    GRPC.Server.start(@mocks, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(@mocks)
    end)

    {:ok, %{project_id: project_id, org_id: org_id}}
  end

  setup do
    Test.Helpers.truncate_db()
    ids = Test.Helpers.seed_front_db()
    reset_mock_feature_service()
    mock_feature_response("disabled")

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")

    assert {:ok, periodic} = periodic_params(ids) |> PeriodicsQueries.insert()
    {:ok, %{periodic: periodic, ids: ids}}
  end

  defp periodic_params(ids) do
    %{
      requester_id: ids.usr_id,
      organization_id: ids.org_id,
      name: "Periodic_1",
      project_name: "Project_1",
      project_id: ids.pr_id,
      branch: "master",
      at: "* * * * *",
      pipeline_file: "deploy.yml"
    }
  end

  test "schedule() - schedule params are correctly formed when there is only after in hook payload",
       ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(2_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "passed"
    assert tr.scheduled_workflow_id == "wf_id"
    assert tr.error_description == nil
    assert tr.attempts == 1
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
  end

  test "schedule() - schedule params are correctly formed for JustRun case", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("just_run")
    reset_mock_feature_service()
    mock_feature_response("just_run")
    use_mock_project_service()
    mock_projecthub_response("ok")
    use_mock_repository_service()
    mock_repositoryhub_response("ok")

    ts_before = DateTime.utc_now()
    timestamp = Timex.shift(ts_before, minutes: -1)

    ctx.periodic
    |> Periodics.changeset("v1.1", %{
      parameters: [
        %{name: "param1", required: true, default_value: "value1"},
        %{name: "param2", required: false, default_value: "value2"},
        %{name: "param3", required: false}
      ]
    })
    |> Scheduler.PeriodicsRepo.update!()

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(2_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)

    assert tr.scheduling_status == "passed"
    assert tr.scheduled_workflow_id == "wf_id"
    assert tr.error_description == nil
    assert tr.attempts == 1

    assert Map.new(tr.parameter_values, &{&1.name, &1.value}) ==
             %{"param1" => "value1", "param2" => "value2"}

    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
  end

  test "schedule() - schedule params are correctly formed for bitbucket in JustRun case", ctx do
    alias Scheduler.Actions.ScheduleWfImpl

    use_mock_workflow_service()
    mock_workflow_service_response("just_run")
    reset_mock_feature_service()
    mock_feature_response("just_run")
    use_mock_project_service()
    mock_projecthub_response("ok")
    use_mock_repository_service()
    mock_repositoryhub_response("ok")

    ts_before = DateTime.utc_now()
    timestamp = Timex.shift(ts_before, minutes: -1)

    periodic =
      ctx.periodic
      |> Periodics.changeset("v1.1", %{
        parameters: [
          %{name: "param1", required: true, default_value: "value1"},
          %{name: "param2", required: false, default_value: "value2"},
          %{name: "param3", required: false}
        ]
      })
      |> Scheduler.PeriodicsRepo.update!()

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(2_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)

    assert tr.scheduling_status == "passed"
    assert tr.scheduled_workflow_id == "wf_id"
    assert tr.error_description == nil

    assert Map.new(tr.parameter_values, &{&1.name, &1.value}) ==
             %{"param1" => "value1", "param2" => "value2"}

    assert tr.attempts == 1

    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt

    repository = %{id: UUID.uuid4(), integration_type: :BITBUCKET}

    assert {:ok, schedule_params} =
             ScheduleWfImpl.form_just_run_schedule_params(periodic, tr, repository)

    assert schedule_params.service == :BITBUCKET
    assert schedule_params.requester_id == periodic.requester_id
    assert schedule_params.triggered_by == :SCHEDULE
  end

  test "schedule() - when project service fails for JustRun case then workflow is not scheduled",
       ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("just_run")
    reset_mock_feature_service()
    mock_feature_response("just_run")
    use_mock_project_service()
    mock_projecthub_response("failed_precondition")
    use_mock_repository_service()
    mock_repositoryhub_response("ok")

    ts_before = DateTime.utc_now()
    timestamp = Timex.shift(ts_before, minutes: -1)

    periodic =
      ctx.periodic
      |> Periodics.changeset("v1.1", %{
        parameters: [
          %{name: "param1", required: true, default_value: "value1"},
          %{name: "param2", required: false, default_value: "value2"},
          %{name: "param3", required: false}
        ]
      })
      |> Scheduler.PeriodicsRepo.update!()

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(2_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)

    assert tr.scheduling_status == "failed"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "{:missing_project, \"#{periodic.project_id}\"}"

    assert Map.new(tr.parameter_values, &{&1.name, &1.value}) ==
             %{"param1" => "value1", "param2" => "value2"}

    assert tr.attempts >= 1

    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
  end

  test "schedule() - when repository service fails for JustRun case then workflow is not scheduled",
       ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("just_run")
    reset_mock_feature_service()
    mock_feature_response("just_run")
    use_mock_project_service()
    mock_projecthub_response("ok")
    use_mock_repository_service()
    mock_repositoryhub_response("failed_precondition")

    ts_before = DateTime.utc_now()
    timestamp = Timex.shift(ts_before, minutes: -1)

    ctx.periodic
    |> Periodics.changeset("v1.1", %{
      parameters: [
        %{name: "param1", required: true, default_value: "value1"},
        %{name: "param2", required: false, default_value: "value2"},
        %{name: "param3", required: false}
      ]
    })
    |> Scheduler.PeriodicsRepo.update!()

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(2_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)

    assert tr.scheduling_status == "failed"
    assert tr.scheduled_workflow_id == ""

    assert tr.error_description ==
             "{:missing_revision, [commit_sha: \"\", reference: \"refs/heads/master\"]}"

    assert Map.new(tr.parameter_values, &{&1.name, &1.value}) ==
             %{"param1" => "value1", "param2" => "value2"}

    assert tr.attempts >= 1

    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
  end

  test "schedule() - when using Create API schedule params are correctly formed and proper API is called",
       %{project_id: project_id, org_id: org_id} do
    use_mock_repo_proxy_service(project_id)
    mock_repo_proxy_service_response("ok")
    reset_mock_feature_service()
    mock_feature_response("scheduler_hook")

    ids = %{
      usr_id: UUID.uuid4(),
      org_id: org_id,
      pr_id: project_id
    }

    assert {:ok, periodic} = periodic_params(ids) |> PeriodicsQueries.insert()

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(periodic.id, timestamp)

    :timer.sleep(5_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(periodic.id, 1)
    assert tr.scheduling_status == "passed"
    assert tr.scheduled_workflow_id == "repo_proxy_wf_id"
    assert tr.error_description == nil
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1
    reset_mock_feature_service()
  end

  test "schedule() - schedule params are correctly formed when there is only head_commit in hook payload",
       ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    payload = %{head_commit: %{id: ctx.ids.commit_sha}, after: ""}
    request = '{"payload": #{inspect(Jason.encode!(payload))}}'

    assert {:ok, _resp} =
             "UPDATE workflows SET request = '#{request}' WHERE true"
             |> Scheduler.FrontRepo.query([])

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(2_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "passed"
    assert tr.scheduled_workflow_id == "wf_id"
    assert tr.error_description == nil
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1
  end

  test "schedule() - scheduling fails if commit_sha can not be found", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("ok")

    payload = %{head_commit: %{id: ""}, after: ""}
    request = '{"payload": #{inspect(Jason.encode!(payload))}}'

    assert {:ok, _resp} =
             "UPDATE workflows SET request = '#{request}' WHERE true"
             |> Scheduler.FrontRepo.query([])

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(4_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "failed"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "Hook is missing commit_sha data"
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1
  end

  test "schedule() - scheduling fails if pipeline limit is exhausted", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("resource_exhausted")

    ts_before = DateTime.utc_now()
    Timex.shift(ts_before, minutes: -1)
    {:ok, trigger} = PTQueries.insert(ctx.periodic)
    state = %{periodic: ctx.periodic, trigger: trigger}

    assert {:stop, :restart, _state} = ScheduleTask.handle_info(:schedule_workflow, state)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "running"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "%{code: :RESOURCE_EXHAUSTED, message: \"Error\"}"
    assert tr.attempts == 1
  end

  test "schedule() - error response from workflow service is stored in trigger", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("invalid_argument")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(4_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "failed"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "%{code: :INVALID_ARGUMENT, message: \"Error\"}"
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1
  end

  test "schedule() - error response when calling Create API is stored in trigger", %{
    project_id: project_id,
    org_id: org_id
  } do
    use_mock_repo_proxy_service(project_id)
    mock_repo_proxy_service_response("invalid_argument")
    reset_mock_feature_service()
    mock_feature_response("scheduler_hook")

    ids = %{
      usr_id: UUID.uuid4(),
      org_id: org_id,
      pr_id: project_id
    }

    assert {:ok, periodic} = periodic_params(ids) |> PeriodicsQueries.insert()

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(periodic.id, timestamp)

    :timer.sleep(4_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(periodic.id, 1)
    assert tr.scheduling_status == "failed"
    assert tr.scheduled_workflow_id == ""
    assert String.contains?(tr.error_description, "message: \"Invalid argument\"")
    assert String.contains?(tr.error_description, "status: 3")
    assert String.contains?(tr.error_description, "GRPC.RPCError")
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1
    reset_mock_feature_service()
  end

  test "schedule() - too long error message from wf service is stored truncated to max length",
       ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("too_long_error_msg")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(4_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "failed"
    assert tr.scheduled_workflow_id == ""

    assert "%{code: :INVALID_ARGUMENT, message: \"aaaaaaa" <> _rest = tr.error_description

    assert String.length(tr.error_description) == 254
    assert tr.attempts >= 1
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
  end

  test "schedule() - error message is removed if next scheduling attempt passes", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("invalid_argument")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(1_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "running"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "%{code: :INVALID_ARGUMENT, message: \"Error\"}"
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1

    mock_workflow_service_response("ok")
    :timer.sleep(3_000)

    assert {:ok, [tr2]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr2.scheduling_status == "passed"
    assert tr2.scheduled_workflow_id == "wf_id"
    assert tr2.error_description == nil
    assert DateTime.compare(tr2.scheduled_at, ts_before) == :gt
    assert tr2.attempts >= tr.attempts
  end

  test "schedule() - scheduling fails if periodic is supended", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("invalid_argument")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(1_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "running"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "%{code: :INVALID_ARGUMENT, message: \"Error\"}"
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1

    assert {:ok, _periodic} = PeriodicsQueries.suspend(ctx.periodic)

    :timer.sleep(2_000)

    assert {:ok, [tr2]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr2.scheduling_status == "failed"
    assert tr2.scheduled_workflow_id == ""
    assert tr2.error_description == "Scheduler with id '#{ctx.periodic.id}' is suspended."
    assert DateTime.compare(tr2.scheduled_at, ts_before) == :gt
    assert tr2.attempts >= tr.attempts
  end

  test "schedule() - scheduling fails if periodic is paused", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("invalid_argument")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(1_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "running"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "%{code: :INVALID_ARGUMENT, message: \"Error\"}"
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1

    assert {:ok, _periodic} = PeriodicsQueries.pause(ctx.periodic, "user_1")

    :timer.sleep(2_000)

    assert {:ok, [tr2]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr2.scheduling_status == "failed"
    assert tr2.scheduled_workflow_id == ""
    assert tr2.error_description == "Scheduler with id '#{ctx.periodic.id}' is paused."
    assert tr2.attempts >= tr.attempts
    assert DateTime.compare(tr2.scheduled_at, ts_before) == :gt
  end

  test "schedule() - restarting schedulr task is terminated if periodic is deleted", ctx do
    use_mock_workflow_service()
    mock_workflow_service_response("invalid_argument")

    ts_before = DateTime.utc_now()

    timestamp = Timex.shift(ts_before, minutes: -1)

    assert {:ok, _pid} = ScheduleWfImpl.start_schedule_task(ctx.periodic.id, timestamp)

    :timer.sleep(1_000)

    assert {:ok, [tr]} = PTQueries.get_n_by_periodic_id(ctx.periodic.id, 1)
    assert tr.scheduling_status == "running"
    assert tr.scheduled_workflow_id == ""
    assert tr.error_description == "%{code: :INVALID_ARGUMENT, message: \"Error\"}"
    assert DateTime.compare(tr.scheduled_at, ts_before) == :gt
    assert tr.attempts >= 1

    assert %{workers: 1} = ScheduleTaskManager.count_children()

    assert {:ok, _message} = Scheduler.Actions.delete(%{id: ctx.periodic.id, requester: "asdf"})

    :timer.sleep(2_000)

    assert %{workers: 0} = ScheduleTaskManager.count_children()
  end

  defp use_mock_project_service(),
    do:
      Application.put_env(
        :scheduler,
        :projecthub_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  defp use_mock_repository_service(),
    do:
      Application.put_env(
        :scheduler,
        :repositoryhub_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  defp use_mock_workflow_service(),
    do:
      Application.put_env(
        :scheduler,
        :workflow_api_grpc_endpoint,
        "localhost:#{inspect(@grpc_port)}"
      )

  def mock_workflow_service_response(value),
    do: Application.put_env(:scheduler, :mock_workflow_service_response, value)

  defp use_mock_repo_proxy_service(project_id) do
    Application.put_env(
      :scheduler,
      :repo_proxy_api_grpc_endpoint,
      "localhost:#{inspect(@grpc_port)}"
    )

    Application.put_env(:scheduler, :repo_proxy_service, {Test.MockRepoProxy, project_id})
  end

  defp reset_mock_feature_service() do
    Cachex.clear(Elixir.Scheduler.FeatureHubProvider)

    Application.put_env(
      :scheduler,
      :feature_api_grpc_endpoint,
      "localhost:#{inspect(@grpc_port)}"
    )
  end

  defp mock_projecthub_response(value),
    do: Application.put_env(:scheduler, :mock_project_service_response, value)

  defp mock_repositoryhub_response(value),
    do: Application.put_env(:scheduler, :mock_repository_service_response, value)

  defp mock_feature_response(value),
    do: Application.put_env(:scheduler, :mock_feature_service_response, value)

  def mock_repo_proxy_service_response(value),
    do: Application.put_env(:scheduler, :mock_repo_proxy_service_response, value)
end

defmodule AssertPramsWorkflowService do
  use GRPC.Server, service: InternalApi.PlumberWF.WorkflowService.Service
  use ExUnit.Case

  alias InternalApi.PlumberWF.ScheduleResponse
  alias Util.Proto

  def schedule(request, _stream) do
    assert :GIT_HUB = request.service
    assert {:ok, _} = request.project_id |> UUID.info()

    if Application.get_env(:scheduler, :mock_workflow_service_response) != "just_run" do
      assert {:ok, _} = request.branch_id |> UUID.info()
      assert {:ok, _} = request.hook_id |> UUID.info()
      assert {:ok, _} = request.repo.commit_sha |> UUID.info()
    end

    assert {:ok, _} = request.requester_id |> UUID.info()
    assert {:ok, _} = request.organization_id |> UUID.info()
    assert request.label == "master"
    assert request.request_token != ""
    assert request.snapshot_id == ""
    assert request.definition_file == "deploy.yml"

    response_type = Application.get_env(:scheduler, :mock_workflow_service_response)

    if response_type == "just_run" do
      assert request.repo.owner == ""
      assert request.repo.repo_name == ""
      assert request.repo.commit_sha == ""
      assert request.repo.branch_name == "master"
    end

    response_type = if response_type == "just_run", do: "ok", else: response_type
    respond(response_type)
  end

  defp respond("ok") do
    %{status: %{code: :OK}}
    |> Map.merge(%{wf_id: "wf_id"})
    |> Proto.deep_new!(ScheduleResponse)
  end

  defp respond("invalid_argument") do
    %{status: %{code: :INVALID_ARGUMENT, message: "Error"}}
    |> Proto.deep_new!(ScheduleResponse)
  end

  defp respond("resource_exhausted") do
    %{status: %{code: :RESOURCE_EXHAUSTED, message: "Error"}}
    |> Proto.deep_new!(ScheduleResponse)
  end

  defp respond("too_long_error_msg") do
    msg =
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" <>
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" <>
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" <>
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" <>
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    assert String.length(msg) == 300

    %{status: %{code: :INVALID_ARGUMENT, message: msg}}
    |> Proto.deep_new!(ScheduleResponse)
  end
end

defmodule AssertPramsRepoProxy do
  use GRPC.Server, service: InternalApi.RepoProxy.RepoProxyService.Service
  use ExUnit.Case

  alias InternalApi.RepoProxy.CreateResponse
  alias Util.Proto

  def create(request, _stream) do
    assert {:ok, _} = request.requester_id |> UUID.info()
    {_module, expected_project_id} = Application.get_env(:scheduler, :repo_proxy_service)
    assert request.project_id == expected_project_id
    assert request.request_token != ""
    assert request.git.commit_sha == ""
    assert request.git.reference == "refs/heads/master"
    assert request.definition_file == "deploy.yml"
    assert request.triggered_by == :SCHEDULE

    response_type = Application.get_env(:scheduler, :mock_repo_proxy_service_response)
    respond(response_type)
  end

  defp respond("ok") do
    %{workflow_id: "repo_proxy_wf_id", pipeline_id: "ppl_id", hook_id: "hook_id"}
    |> Proto.deep_new!(CreateResponse)
  end

  defp respond("invalid_argument") do
    msg = "Invalid argument"
    raise GRPC.RPCError, status: GRPC.Status.invalid_argument(), message: msg
  end
end
