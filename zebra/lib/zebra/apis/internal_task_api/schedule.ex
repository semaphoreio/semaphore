defmodule Zebra.Apis.InternalTaskApi.Schedule do
  require Logger

  alias Semaphore.Jobs.V1alpha.Job.Spec, as: Spec
  alias Zebra.LegacyRepo, as: Repo

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

  @spec create_task(InternalApi.Task.Task.t()) :: {:ok, Zebra.Models.Task.t()}
  defp create_task(req) do
    Watchman.benchmark("internal_task_api.schedule.create_task.duration", fn ->
      Repo.transaction(fn ->
        {:ok, task} =
          Zebra.Models.Task.create(
            version: "v0.0",
            request: Zebra.Models.Task.encode_request(req),
            hook_id: req.hook_id,
            workflow_id: req.wf_id,
            ppl_id: req.ppl_id,
            build_request_id: req.request_token,
            fail_fast_strategy: encode_fail_fast_strategy(req.fail_fast)
          )

        req.jobs
        |> Enum.with_index()
        |> Enum.each(fn {j, index} ->
          {:ok, job} = create_job(task.id, req, j, index)

          onprem_metrics(job)
        end)

        task
      end)
    end)
  end

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
        execution_time_limit: valid_time_limit(job_req.execution_time_limit),
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
  defp valid_time_limit(value)
       when value > 0 and value <= @max_job_execution_time_limit,
       do: value * 60

  defp valid_time_limit(_), do: @default_job_execution_time_limit

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
