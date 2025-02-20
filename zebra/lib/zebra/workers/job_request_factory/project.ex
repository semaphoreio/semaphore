defmodule Zebra.Workers.JobRequestFactory.Project do
  require Logger

  def find(id), do: find_by_id(id)

  def find_by_id_or_name(id_or_name, org_id, user_id) do
    if uuid?(id_or_name) do
      find_by_id(id_or_name, org_id, user_id)
    else
      find_by_name(id_or_name, org_id, user_id)
    end
  end

  def find_by_id(project_id, org_id \\ "", user_id \\ "") do
    Watchman.benchmark("zebra.external.projecthub.describe", fn ->
      alias InternalApi.Projecthub.DescribeRequest, as: Request
      alias InternalApi.Projecthub.RequestMeta
      alias InternalApi.Projecthub.ProjectService.Stub

      req =
        Request.new(id: project_id, metadata: RequestMeta.new(org_id: org_id, user_id: user_id))

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :projecthub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.describe(channel, req, timeout: 30_000) do
        if res.metadata.status.code == 0 do
          project = Zebra.Models.Project.from_api(res.project)
          {:ok, project}
        else
          {:stop_job_processing, "Project #{project_id} not found"}
        end
      else
        e ->
          Logger.info("Failed to fetch info for Project##{project_id}, #{inspect(e)}")

          {:error, :communication_error}
      end
    end)
  end

  def find_by_name(project_name, org_id, user_id) do
    Watchman.benchmark("zebra.external.projecthub.describe", fn ->
      alias InternalApi.Projecthub.DescribeRequest, as: Request
      alias InternalApi.Projecthub.RequestMeta
      alias InternalApi.Projecthub.ProjectService.Stub

      req =
        Request.new(
          name: project_name,
          metadata: RequestMeta.new(org_id: org_id, user_id: user_id)
        )

      with {:ok, endpoint} <- Application.fetch_env(:zebra, :projecthub_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.describe(channel, req, timeout: 30_000) do
        if res.metadata.status.code == 0 do
          project = Zebra.Models.Project.from_api(res.project)
          {:ok, project}
        else
          {:stop_job_processing, "Project #{project_name} not found"}
        end
      else
        e ->
          Logger.info("Failed to fetch info for Project##{project_name}, #{inspect(e)}")

          {:error, :communication_error}
      end
    end)
  end

  def uuid?(id_or_name) do
    case UUID.info(id_or_name) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
