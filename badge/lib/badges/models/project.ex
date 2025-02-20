defmodule Badges.Models.Project do
  defstruct [:id, :pipeline_file, :public]

  require Logger

  def find(name, org_id, metadata) do
    Watchman.benchmark("fetch_project.duration", fn ->
      req =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(org_id: org_id),
          name: name
        )

      Logger.info("Metadata: #{inspect(metadata)}")

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.describe(channel(), req, options(metadata))

      case res.metadata.status.code do
        :OK -> construct(res.project)
        _ -> nil
      end
    end)
  end

  defp construct(project) do
    %__MODULE__{
      :id => project.metadata.id,
      :pipeline_file => project.spec.repository.pipeline_file,
      :public => project.spec.public
    }
  end

  defp channel do
    {:ok, ch} = GRPC.Stub.connect(Application.fetch_env!(:badges, :projecthub_grpc_endpoint))
    ch
  end

  defp options(tracing_headers) do
    [timeout: 30_000, metadata: tracing_headers]
  end
end
