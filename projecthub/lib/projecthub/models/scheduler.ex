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
    Logger.info("Creating/updating scheduler #{scheduler.name} for project #{project.id}")

    req =
      InternalApi.PeriodicScheduler.PersistRequest.new(
        id: scheduler.id,
        name: scheduler.name,
        description: "",
        recurring: true,
        state: :UNCHANGED,
        organization_id: project.organization_id,
        project_name: project.name,
        requester_id: requester_id,
        reference: format_branch_as_reference(scheduler.branch),
        pipeline_file: scheduler.pipeline_file,
        at: scheduler.at,
        parameters: [],
        project_id: project.id
      )

    {:ok, res} = InternalApi.PeriodicScheduler.PeriodicService.Stub.persist(channel(), req, options(metadata))

    if res.status.code == status_ok() do
      {:ok, nil}
    else
      Logger.error(
        "Failed to create/update scheduler #{scheduler.name} for project #{project.id}, with status: #{inspect(res.status)}"
      )

      {:error, res.status.message}
    end
  end

  def construct_list(raw_schedulers) do
    raw_schedulers
    |> Enum.map(fn s -> construct(s) end)
  end

  defp construct(%InternalApi.PeriodicScheduler.Periodic{} = raw_scheduler) do
    %__MODULE__{
      :id => raw_scheduler.id,
      :name => raw_scheduler.name,
      :branch => extract_branch_name(raw_scheduler.reference),
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

  # Helper function to extract branch name from Git reference format
  # "refs/heads/main" -> "main"
  # "refs/tags/v1.0" -> "refs/tags/v1.0"
  # "main" -> "main" (fallback for plain strings)
  defp extract_branch_name(reference) when is_binary(reference) do
    cond do
      String.starts_with?(reference, "refs/heads/") ->
        String.replace_prefix(reference, "refs/heads/", "")

      true ->
        reference
    end
  end

  defp extract_branch_name(_), do: ""

  # Helper function to format branch name as Git reference
  # "main" -> "refs/heads/main"
  # "refs/tags/v1.0" -> "refs/tags/v1.0" (default to branch format)
  defp format_branch_as_reference(tag = "refs/tags/" <> _), do: tag
  defp format_branch_as_reference(pr = "refs/pull/" <> _), do: pr

  defp format_branch_as_reference(branch_name) when is_binary(branch_name) do
    "refs/heads/#{branch_name}"
  end

  defp format_branch_as_reference(_), do: "refs/heads/main"
end
