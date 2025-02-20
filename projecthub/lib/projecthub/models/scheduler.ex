defmodule Projecthub.Models.Scheduler do
  defstruct [:id, :name, :branch, :at, :pipeline_file, :status]

  require Logger

  def list(project, metadata \\ nil) do
    req =
      InternalApi.PeriodicScheduler.ListRequest.new(
        project_id: project.id,
        page: 1,
        page_size: 500
      )

    {:ok, res} = InternalApi.PeriodicScheduler.PeriodicService.Stub.list(channel(), req, options(metadata))

    if res.status.code == status_ok() do
      {:ok, construct_list(res.periodics)}
    else
      Logger.error("Failed to list schedulers for project #{project.id} with status: #{inspect(res.status)}")

      {:error, res.status.message}
    end
  end

  def delete(scheduler, requester_id, metadata \\ nil) do
    req =
      InternalApi.PeriodicScheduler.DeleteRequest.new(
        id: scheduler.id,
        requester: requester_id
      )

    {:ok, res} = InternalApi.PeriodicScheduler.PeriodicService.Stub.delete(channel(), req, options(metadata))

    if res.status.code == status_ok() do
      {:ok, nil}
    else
      Logger.error("Failed to delete scheduler #{scheduler.id} with status: #{inspect(res.status)}")

      {:error, res.status.message}
    end
  end

  def apply(scheduler, project, requester_id, metadata \\ nil) do
    scheduler_yml_definition = to_yaml(scheduler, project)

    Logger.info("Scheduler yml definition: #{inspect(scheduler_yml_definition)}")

    req =
      InternalApi.PeriodicScheduler.ApplyRequest.new(
        organization_id: project.organization_id,
        requester_id: requester_id,
        yml_definition: scheduler_yml_definition
      )

    {:ok, res} = InternalApi.PeriodicScheduler.PeriodicService.Stub.apply(channel(), req, options(metadata))

    if res.status.code == status_ok() do
      {:ok, nil}
    else
      Logger.error(
        "Failed to create/update scheduler #{scheduler.name} for project #{project.id}, with status: #{inspect(res.status)}"
      )

      {:error, res.status.message}
    end
  end

  defp to_yaml(scheduler = %{status: status}, project) when status != :STATUS_UNSPECIFIED and status != nil do
    yaml =
      scheduler
      |> Map.put(:status, :STATUS_UNSPECIFIED)
      |> to_yaml(project)

    yaml <>
      """
        paused: #{scheduler.status == :STATUS_INACTIVE}
      """
  end

  defp to_yaml(scheduler, project) do
    """
    apiVersion: v1.0
    kind: Schedule
    metadata:
      name: \"#{scheduler.name}\"
      id: \"#{scheduler.id}\"
    spec:
      project: \"#{project.name}\"
      branch: \"#{scheduler.branch}\"
      at: \"#{scheduler.at}\"
      pipeline_file: \"#{scheduler.pipeline_file}\"
    """
  end

  def construct_list(raw_schedulers) do
    raw_schedulers
    |> Enum.map(fn s -> construct(s) end)
  end

  defp construct(%InternalApi.PeriodicScheduler.Periodic{} = raw_scheduler) do
    %__MODULE__{
      :id => raw_scheduler.id,
      :name => raw_scheduler.name,
      :branch => raw_scheduler.branch,
      :at => raw_scheduler.at,
      :pipeline_file => raw_scheduler.pipeline_file,
      :status => construct_status(raw_scheduler.paused)
    }
  end

  defp construct(%InternalApi.Projecthub.Project.Spec.Scheduler{} = raw_scheduler) do
    %__MODULE__{
      :id => raw_scheduler.id,
      :name => raw_scheduler.name,
      :branch => raw_scheduler.branch,
      :at => raw_scheduler.at,
      :pipeline_file => raw_scheduler.pipeline_file,
      :status => raw_scheduler.status
    }
  end

  defp construct_status(true), do: :STATUS_INACTIVE
  defp construct_status(false), do: :STATUS_ACTIVE

  defp channel do
    GRPC.Stub.connect(Application.fetch_env!(:projecthub, :periodic_scheduler_grpc_endpoint),
      interceptors: [
        Projecthub.Util.GRPC.ClientRequestIdInterceptor,
        {
          Projecthub.Util.GRPC.ClientLoggerInterceptor,
          skip_logs_for: ~w(
            list
          )
        },
        Projecthub.Util.GRPC.ClientRunAsyncInterceptor
      ]
    )
    |> case do
      {:ok, channel} -> channel
      _ -> nil
    end
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end

  defp status_ok, do: :OK
end
