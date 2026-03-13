defmodule Projecthub.Cache do
  require Logger
  alias Projecthub.Models.Project
  alias InternalApi.Cache.CacheService.Stub

  def create_for_project(project_id, metadata \\ nil) do
    Logger.info("Creating cache for project: #{project_id}")

    with {:ok, project} <- Project.find(project_id),
         req <- build_create_request(project),
         {:ok, res} <- Stub.create(channel(), req, options(metadata)) do
      if res.status.code == :OK do
        {:ok, _} = update_project(project_id, res.cache_id)

        Logger.info("Successfully created cache for project: #{project_id}")
      else
        Logger.error("Couldn't create cache for project: #{project_id}: #{inspect(res)}")

        nil
      end
    else
      {:error, reason} ->
        Logger.error("Couldn't create cache for project: #{project_id}: #{inspect(reason)}")
        nil
    end
  end

  def destroy(cache_id, project_id, metadata \\ nil) do
    with req <- InternalApi.Cache.DestroyRequest.new(cache_id: cache_id),
         {:ok, _} <- Stub.destroy(channel(), req, options(metadata)) do
      Watchman.increment("cachehub.destroy.succeeded")

      Logger.info("Scheduled cache store deletion #{cache_id} for project #{project_id}")
    else
      {_, res} ->
        Watchman.increment("cachehub.destroy.failed")

        Logger.error("Deletion of cache store failed #{cache_id} for project #{project_id}: #{inspect(res)}")

        nil
    end
  end

  def provision_ceph_cache(cache_id, organization_id, project_id, project_name \\ nil, metadata \\ nil) do
    req =
      InternalApi.Cache.ProvisionCephCacheRequest.new(
        cache_id: cache_id,
        organization_id: organization_id,
        project_id: project_id,
        project_name: project_name || ""
      )

    case Stub.provision_ceph_cache(channel(), req, options(metadata)) do
      {:ok, res} when res.status.code == :OK ->
        Logger.info(
          "Queued Ceph cache provisioning cache_id=#{cache_id} org_id=#{organization_id} project_id=#{project_id}"
        )

        {:ok, res}

      {:ok, res} ->
        Logger.error(
          "Failed to queue Ceph cache provisioning cache_id=#{cache_id} org_id=#{organization_id} project_id=#{project_id} status=#{inspect(res.status)}"
        )

        {:error, res}

      {:error, reason} ->
        Logger.error(
          "Ceph cache provisioning call failed cache_id=#{cache_id} org_id=#{organization_id} project_id=#{project_id} reason=#{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp update_project(project_id, cache_id) do
    {:ok, project} = Project.find(project_id)
    Project.update_record(project, %{cache_id: cache_id})
  end

  defp build_create_request(project) do
    InternalApi.Cache.CreateRequest.new(
      organization_id: project.organization_id,
      project_id: project.id,
      project_name: project.name,
      backend: backend_for_org(project.organization_id)
    )
  end

  defp backend_for_org(org_id) do
    if FeatureProvider.feature_enabled?(:use_ceph_for_cache, param: org_id) do
      InternalApi.Cache.Backend.value(:CEPH)
    else
      InternalApi.Cache.Backend.value(:SFTP)
    end
  end

  defp channel do
    case GRPC.Stub.connect(Application.fetch_env!(:projecthub, :cache_grpc_endpoint),
           interceptors: [
             Projecthub.Util.GRPC.ClientRequestIdInterceptor,
             Projecthub.Util.GRPC.ClientLoggerInterceptor,
             Projecthub.Util.GRPC.ClientRunAsyncInterceptor
           ]
         ) do
      {:ok, channel} -> channel
      _ -> nil
    end
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end
end
