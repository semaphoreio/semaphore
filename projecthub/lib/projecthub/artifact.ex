defmodule Projecthub.Artifact do
  require Logger
  alias Projecthub.Models.Project

  alias InternalApi.Artifacthub, as: ArtifactApi
  alias InternalApi.Artifacthub.ArtifactService.Stub

  # Note:
  # Artifacthub database has `artifact_id` column (artifacthub API)
  # Front database has `artifact_store_id` (project API)

  def api_endpoint do
    Application.fetch_env!(:projecthub, :artifacthub_grpc_endpoint)
  end

  def create_for_project(project_id, metadata \\ nil) do
    Logger.info("Creating artifact for project: #{project_id}")

    {:ok, channel} =
      GRPC.Stub.connect(api_endpoint(),
        interceptors: [
          Projecthub.Util.GRPC.ClientRequestIdInterceptor,
          Projecthub.Util.GRPC.ClientLoggerInterceptor,
          Projecthub.Util.GRPC.ClientRunAsyncInterceptor
        ]
      )

    req = ArtifactApi.CreateRequest.new(request_token: project_id)

    Stub.create(channel, req, options(metadata))
    |> case do
      {:ok, res} ->
        project_id
        |> Project.find()
        |> elem(1)
        |> Project.update_record(%{artifact_store_id: res.artifact.id})

        Watchman.increment("artifacthub.create.succeeded")
        Logger.info("Successfully created artifact for project: #{project_id}")

      {_, res} ->
        Watchman.increment("artifacthub.create.failed")
        Logger.error("Couldn't create artifact for project: #{project_id}: #{inspect(res)}")

        nil
    end
  end

  def destroy(artifact_id, project_id, metadata \\ nil) do
    Logger.info("Deleting artifact #{artifact_id}")

    {:ok, channel} =
      GRPC.Stub.connect(api_endpoint(),
        interceptors: [
          Projecthub.Util.GRPC.ClientRequestIdInterceptor,
          Projecthub.Util.GRPC.ClientLoggerInterceptor,
          Projecthub.Util.GRPC.ClientRunAsyncInterceptor
        ]
      )

    req = ArtifactApi.DestroyRequest.new(artifact_id: artifact_id)

    Stub.destroy(channel, req, options(metadata))
    |> case do
      {:ok, _} ->
        Watchman.increment("artifacthub.destroy.succeeded")
        Logger.info("Destroyed artifact #{artifact_id} for project #{project_id}")

      {_, res} ->
        Watchman.increment("artifacthub.destroy.failed")

        Logger.error("Destroying artifact failed #{artifact_id} for project #{project_id}: #{inspect(res)}")

        nil
    end
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end
end
