defmodule Scheduler.Actions.ScheduleWfImpl do
  @moduledoc """
  Module handles collecting params and scheduling workflow trough WorkflowClient.
  Scheduling is initiated periodically via quantum library based on periodic entity configs.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries
  alias Scheduler.FrontDB.Model.FrontDBQueries
  alias Scheduler.Clients.{WorkflowClient, RepoProxyClient, ProjecthubClient, RepositoryClient}
  alias Scheduler.Workers.ScheduleTaskManager
  alias Scheduler.Utils.GitReference
  alias Util.ToTuple
  alias LogTee, as: LT

  def start_schedule_task(periodic_id, timestamp) do
    with {:ok, periodic} <- PeriodicsQueries.get_by_id(periodic_id),
         :continue <- skip_in_first_minute(timestamp),
         {:ok, trigger} <- PeriodicsTriggersQueries.insert(periodic),
         {:ok, pid} <- ScheduleTaskManager.start_schedule_task(periodic, trigger) do
      {:ok, pid}
    else
      :skip ->
        periodic_id
        |> LT.info("Skipping scheduling in first minute for periodic: ")
        |> ToTuple.ok()

      error ->
        error |> LT.warn("Failed to load periodic or create trigger: ")
    end
  end

  defp skip_in_first_minute(timestamp) do
    case Timex.compare(timestamp, DateTime.utc_now(), :minutes) do
      0 -> :skip
      _ -> :continue
    end
  end

  def schedule_wf(periodic, trigger) do
    Watchman.benchmark("PeriodicSch.schedule_just_run", fn ->
      with {:ok, repository} <- fetch_project_repository(trigger.project_id),
           {:ok, params} <- form_just_run_schedule_params(periodic, trigger, repository),
           {:ok, _commit} <- fetch_branch_revision(repository.id, Map.to_list(params.git)),
           {:ok, wf_id} <- WorkflowClient.schedule(params) do
        params = %{
          scheduled_workflow_id: wf_id,
          scheduling_status: "passed",
          error_description: nil,
          attempts: (trigger.attempts || 0) + 1
        }

        Watchman.increment({"PeriodicSch.schedule_wf_success", ["just-run"]})
        PeriodicsTriggersQueries.update(trigger, params)
      else
        error ->
          Watchman.increment({"PeriodicSch.schedule_wf_failure", ["just-run"]})
          record_error(error, trigger)
          error
      end
    end)
  end

  def fetch_project_repository(project_id) do
    case ProjecthubClient.describe(project_id) do
      {:ok, project} -> {:ok, project.spec.repository}
      {:error, _reason} -> {:error, {:missing_project, project_id}}
    end
  end

  def fetch_branch_revision(repository_id, revision_args) do
    case RepositoryClient.describe_revision(repository_id, revision_args) do
      {:ok, commit} -> {:ok, commit}
      {:error, _reason} -> {:error, {:missing_revision, revision_args}}
    end
  end

  def form_just_run_schedule_params(periodic, trigger, repository) do
    requester_id =
      if trigger.run_now_requester_id,
        do: trigger.run_now_requester_id,
        else: periodic.requester_id

    triggered_by =
      if trigger.run_now_requester_id,
        do: :MANUAL_RUN,
        else: :SCHEDULE

    # Handle backwards compatibility: normalize reference to full format
    git_reference = GitReference.normalize(trigger.reference)

    # Extract branch name for legacy branch_name field
    branch_name = GitReference.extract_name(trigger.reference)

    %{
      service: schedule_workflow_service_type(repository.integration_type),
      repo: %{branch_name: branch_name},
      request_token: trigger.periodic_id <> "-#{trigger.id}",
      project_id: trigger.project_id,
      requester_id: requester_id,
      definition_file: trigger.pipeline_file,
      organization_id: periodic.organization_id,
      label: branch_name,
      scheduler_task_id: periodic.id,
      git: %{
        reference: git_reference,
        commit_sha: ""
      },
      triggered_by: triggered_by,
      env_vars: parameter_values_to_env_vars(trigger.parameter_values)
    }
    |> ToTuple.ok()
  end

  defp schedule_workflow_service_type(:GITHUB_OAUTH_TOKEN), do: :GIT_HUB
  defp schedule_workflow_service_type(:GITHUB_APP), do: :GIT_HUB
  defp schedule_workflow_service_type(:BITBUCKET), do: :BITBUCKET
  defp schedule_workflow_service_type(:GITLAB), do: :GITLAB
  defp schedule_workflow_service_type(:GIT), do: :GIT

  defp parameter_values_to_env_vars(parameter_values) do
    Enum.into(parameter_values, [], &parameter_value_to_env_var/1)
  end

  defp parameter_value_to_env_var(%{name: name, value: value}) do
    %{name: name, value: if(is_nil(value), do: "", else: value)}
  end

  # The error is saved in DB after each failed attempt, so we can debug months
  # later when logs are not available. If scheduling passes in the following
  # attempt, the error_description field will be cleared.
  def record_error({:error, error}, trigger), do: record_error(error, trigger)

  def record_error(error, trigger) do
    with log_msg <- "Scheduling for periodic #{trigger.periodic_id} failed with error",
         str_error <- error |> to_str() |> LT.warn(log_msg),
         str_error <- str_error |> String.slice(0..253),
         params <- %{error_description: str_error, attempts: (trigger.attempts || 0) + 1} do
      PeriodicsTriggersQueries.update(trigger, params)
    end
  end

  def to_str(val) when is_binary(val), do: val
  def to_str(val), do: "#{inspect(val)}"
end
