defmodule Rbac.Api.Project do
  require Logger

  def fetch(project_id) do
    Watchman.benchmark("fetch_project.duration", fn ->
      req =
        %InternalApi.Projecthub.DescribeRequest{
          id: project_id,
          metadata: %InternalApi.Projecthub.RequestMeta{}
        }

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:rbac, :projecthub_grpc_endpoint))

      result = InternalApi.Projecthub.ProjectService.Stub.describe(channel, req, timeout: 30_000)

      case result do
        {:ok, response} when response.metadata.status.code == :OK ->
          response

        _ ->
          nil
      end
    end)
  end
end
