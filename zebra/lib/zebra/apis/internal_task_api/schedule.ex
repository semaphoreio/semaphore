defmodule Zebra.Apis.InternalTaskApi.Schedule do
  require Logger
  import Ecto.Query

  alias Semaphore.Jobs.V1alpha.Job.Spec, as: Spec
  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job

  @default_job_priority 50
  # in seconds
  @default_job_execution_time_limit 24 * 60 * 60
  # in minutes
  @max_job_execution_time_limit 24 * 60

  @spec schedule(InternalApi.Task.Task.t()) :: {:ok, Zebra.Models.Task.t()}
  def schedule(req) do
    case find_already_scheduled_task(req) do
      {:ok, task} -> {:ok, task}
      {:error, :not_found} -> create_task(req)
    end
  end

  def validate(req) do
    if Enum.empty?(req.jobs) do
      {:error, :invalid_argument, "A task must have at least one job"}
    else
      :ok
    end
  end

  def find_already_scheduled_task(req) do
    Watchman.benchmark("internal_task_api.schedule.find_already_scheduled_task.duration", fn ->
      Zebra.Models.Task.find_by_request_token(req.request_token)
    end)
  end

  @spec create_task(InternalApi.Task.Task.t()) ::
          {:ok, Zebra.Models.Task.t()} | {:error, :invalid_argument, String.t()}
  def create_task(req) do
    Watchman.benchmark("internal_task_api.schedule.create_task.duration", fn ->
      result =
        Repo.transaction(fn ->
          copy_ctx = resolve_copy_context(req)

          task = insert_task(req)

          req.jobs
          |> Enum.with_index()
          |> Enum.each(fn {j, index} ->
            create_task_job(task, req, j, index, copy_ctx)
          end)

          task
        end)

      handle_transaction_result(result, req)
    end)
  end

  defp handle_transaction_result({:ok, task}, req), do: maybe_finish_all_copy(task, req)

  defp handle_transaction_result({:error, :already_scheduled}, req) do
    find_already_scheduled_task(req)
  end

  defp handle_transaction_result({:error, {:invalid_argument, msg}}, _req) do
    {:error, :invalid_argument, msg}
  end

  # Inserts the task row. A losing concurrent insert on the same request_token
  # surfaces as a changeset error (via the build_request_id unique_constraint);
  # roll back so the winning task is re-read outside the transaction.
  defp insert_task(req) do
    case Zebra.Models.Task.create(
           version: "v0.0",
           request: Zebra.Models.Task.encode_request(req),
           hook_id: req.hook_id,
           workflow_id: req.wf_id,
           ppl_id: req.ppl_id,
           build_request_id: req.request_token,
           fail_fast_strategy: encode_fail_fast_strategy(req.fail_fast)
         ) do
      {:ok, task} ->
        task

      {:error, %Ecto.Changeset{} = changeset} ->
        if Keyword.has_key?(changeset.errors, :build_request_id) do
          Repo.rollback(:already_scheduled)
        else
          Repo.rollback({:invalid_argument, "failed to create task: #{inspect(changeset.errors)}"})
        end
    end
  end

  # Run vs copy decision for a single job spec, executed inside the transaction.
  defp create_task_job(task, req, job_req, job_index, copy_ctx) do
    case classify_job(job_req, req, copy_ctx) do
      :run ->
        run_job(task.id, req, job_req, job_index)

      {:copy, member} ->
        case Job.create_copy(member, task.id) do
          {:ok, _copy} ->
            :ok

          {:error, reason} ->
            Repo.rollback({:invalid_argument, "failed to create copy: #{inspect(reason)}"})
        end

      {:invalid, msg} ->
        Repo.rollback({:invalid_argument, msg})
    end
  end

  defp run_job(task_id, req, job_req, job_index) do
    case create_job(task_id, req, job_req, job_index) do
      {:ok, job} ->
        onprem_metrics(job)

      {:error, reason} ->
        Repo.rollback({:invalid_argument, "failed to create job: #{inspect(reason)}"})
    end
  end

  # Resolve the exact-membership anchor once per request when any job spec
  # carries an original_job_id marker (D-14 amendment). Returns nil when the
  # request has no markers, or a %{members: %{id => job}} cache otherwise.
  # Rolls back with a typed invalid_argument on any anchor failure.
  defp resolve_copy_context(req) do
    if Enum.any?(req.jobs, fn j -> present?(j.original_job_id) end) do
      cond do
        not present?(req.original_task_id) ->
          Repo.rollback(
            {:invalid_argument, "original_task_id required when job markers are present"}
          )

        true ->
          load_copy_context(req)
      end
    else
      nil
    end
  end

  defp load_copy_context(req) do
    case Zebra.Models.Task.find(req.original_task_id) do
      {:error, :not_found} ->
        Repo.rollback(
          {:invalid_argument, "original_task_id #{req.original_task_id} does not exist"}
        )

      {:ok, original_task} ->
        if original_task.workflow_id != req.wf_id do
          Repo.rollback(
            {:invalid_argument,
             "original_task_id #{req.original_task_id} belongs to a different workflow"}
          )
        else
          %{members: load_members(original_task.id)}
        end
    end
  end

  defp load_members(original_task_id) do
    Job
    |> where([j], j.build_id == ^original_task_id)
    |> Repo.all()
    |> Map.new(fn j -> {j.id, j} end)
  end

  defp classify_job(job_req, req, copy_ctx) do
    if present?(job_req.original_job_id) do
      classify_copy_marker(job_req, req, copy_ctx)
    else
      :run
    end
  end

  defp classify_copy_marker(job_req, req, copy_ctx) do
    marker = job_req.original_job_id

    case Map.get(copy_ctx.members, marker) do
      nil ->
        classify_non_member(marker, req)

      member ->
        classify_member(member, marker, req)
    end
  end

  defp classify_member(member, marker, req) do
    cond do
      member.organization_id != req.org_id or member.project_id != req.project_id ->
        {:invalid,
         "original_job_id #{marker} belongs to a different tenant than the request"}

      copyable?(member) ->
        {:copy, member}

      true ->
        # A member that never finished+passed cannot be represented as a passed
        # copy; run it from its own spec instead of stranding the block.
        Watchman.increment("internal_task_api.schedule.copy_source_not_copyable")
        :run
    end
  end

  defp classify_non_member(marker, req) do
    case Job.find(marker) do
      {:ok, _foreign} ->
        # The job exists but is not a member of original_task_id: a
        # cross-membership forge. Fail loud (security).
        {:invalid,
         "original_job_id #{marker} is not a job of original_task_id #{req.original_task_id}"}

      {:error, :not_found} ->
        # No row anywhere: a genuinely retention-deleted member is
        # indistinguishable from a fabricated id. Run the job from its own
        # spec — no copy is minted, nothing leaks, the block is not stranded.
        Watchman.increment("internal_task_api.schedule.copy_source_missing")
        :run
    end
  end

  defp copyable?(member) do
    Job.finished?(member) and Job.passed?(member) and not is_nil(member.finished_at)
  end

  # An all-copy task (zero runnable pending jobs) is finished immediately rather
  # than waiting on the periodic TaskFinisher poller. Only runs when the request
  # actually carried copy markers, leaving the common run-only path untouched.
  defp maybe_finish_all_copy(task, req) do
    if Enum.any?(req.jobs, fn j -> present?(j.original_job_id) end) do
      pending_count =
        Job
        |> where([j], j.build_id == ^task.id and j.aasm_state == ^Job.state_pending())
        |> Repo.aggregate(:count)

      if pending_count == 0 do
        Zebra.Workers.TaskFinisher.lock_and_process(task.id)
        Zebra.Models.Task.find(task.id)
      else
        {:ok, task}
      end
    else
      {:ok, task}
    end
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true

  defp create_job(task_id, req, job_req, job_index) do
    Watchman.benchmark("internal_task_api.schedule.create_job.duration", fn ->
      Zebra.Models.Job.create(
        name: job_req.name,
        index: job_index,
        build_id: task_id,
        organization_id: req.org_id,
        project_id: req.project_id,
        deployment_target_id: req.deployment_target_id,
        repository_id: req.repository_id,
        machine_type: job_req.agent.machine.type,
        machine_os_image: job_req.agent.machine.os_image,
        execution_time_limit:
          configure_execution_time_limit(req.org_id, job_req.execution_time_limit),
        priority: valid_priority(job_req.priority),
        spec:
          Spec.new(
            project_id: req.project_id,
            agent:
              Spec.Agent.new(
                machine:
                  Spec.Agent.Machine.new(
                    type: job_req.agent.machine.type,
                    os_image: job_req.agent.machine.os_image
                  ),
                containers:
                  Enum.map(job_req.agent.containers, fn c ->
                    Spec.Agent.Container.new(
                      name: c.name,
                      command: c.command,
                      image: c.image,
                      env_vars:
                        Enum.map(c.env_vars, fn e ->
                          Spec.EnvVar.new(name: e.name, value: e.value)
                        end),
                      secrets:
                        Enum.map(c.secrets, fn s ->
                          Spec.Secret.new(name: s.name)
                        end)
                    )
                  end),
                image_pull_secrets:
                  Enum.map(job_req.agent.image_pull_secrets, fn s ->
                    Spec.Agent.ImagePullSecret.new(name: s.name)
                  end)
              ),
            secrets:
              Enum.map(job_req.secrets, fn s ->
                Spec.Secret.new(name: s.name)
              end),
            env_vars:
              Enum.map(job_req.env_vars, fn e ->
                Spec.EnvVar.new(name: e.name, value: e.value)
              end),
            commands: job_req.prologue_commands ++ job_req.commands,
            epilogue_always_commands: job_req.epilogue_always_cmds,
            epilogue_on_pass_commands: job_req.epilogue_on_pass_cmds,
            epilogue_on_fail_commands: job_req.epilogue_on_fail_cmds
          )
      )
    end)
  end

  defp valid_priority(value) when value >= 0 and value <= 100, do: value
  defp valid_priority(_), do: @default_job_priority

  # value of execution_time_limit is received in minutes and it is stored in seconds
  def configure_execution_time_limit(org_id, req_value) do
    {max_job_time_limit, deafult_job_time_limit} = find_max_and_default_job_time_limits(org_id)

    if req_value > 0 and req_value <= max_job_time_limit do
      req_value * 60
    else
      deafult_job_time_limit
    end
  end

  defp find_max_and_default_job_time_limits(org_id) do
    if org_verified?(org_id) do
      {@max_job_execution_time_limit, @default_job_execution_time_limit}
    else
      find_feature_based_job_time_limits(org_id)
    end
  end

  defp find_feature_based_job_time_limits(org_id) do
    if FeatureProvider.feature_enabled?(:max_job_execution_time_limit, param: org_id) do
      max_limit = FeatureProvider.feature_quota(:max_job_execution_time_limit, param: org_id)

      default_limit =
        if max_limit * 60 < @default_job_execution_time_limit do
          max_limit * 60
        else
          @default_job_execution_time_limit
        end

      {max_limit, default_limit}
    else
      {@max_job_execution_time_limit, @default_job_execution_time_limit}
    end
  end

  defp org_verified?(org_id) do
    case Zebra.Workers.Scheduler.Org.load(org_id) do
      {:ok, org} -> org.verified
      _ -> false
    end
  end

  def encode_fail_fast_strategy(strategy) do
    alias InternalApi.Task.ScheduleRequest.FailFast, as: FF

    cond do
      FF.value(:NONE) == strategy ->
        nil

      FF.value(:STOP) == strategy ->
        "stop"

      FF.value(:CANCEL) == strategy ->
        "cancel"

      true ->
        raise "unknown fail fast strategy"
    end
  end

  defp onprem_metrics(job) do
    if Zebra.on_prem?() do
      tags = [agent: job.machine_type]

      Watchman.increment(external: {"new_jobs", tags})
    end
  end
end
