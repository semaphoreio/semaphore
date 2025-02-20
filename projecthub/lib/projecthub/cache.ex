defmodule Projecthub.Cache do
  require Logger
  alias Projecthub.Models.Project

  def create_for_project(project_id, metadata \\ nil) do
    Logger.info("Creating cache for project: #{project_id}")

    req = InternalApi.Cache.CreateRequest.new()

    {:ok, res} =
      InternalApi.Cache.CacheService.Stub.create(
        channel(),
        req,
        options(metadata)
      )

    if res.status.code == :OK do
      {:ok, _} = update_project(project_id, res.cache_id)

      Logger.info("Successfully created cache for project: #{project_id}")
    else
      Logger.error("Couldn't create cache for project: #{project_id}: #{inspect(res)}")

      nil
    end
  end

  def destroy(cache_id, project_id, metadata \\ nil) do
    alias InternalApi.Cache.CacheService.Stub

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

  defp update_project(project_id, cache_id) do
    {:ok, project} = Project.find(project_id)
    Project.update_record(project, %{cache_id: cache_id})
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
