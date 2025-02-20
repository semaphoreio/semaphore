defmodule GithubNotifier.Models.Project do
  defstruct [:id, :org_id, :owner_id, :url, :status, :repository_id]

  require Logger

  @spec find(String.t()) :: GithubNotifier.Models.Project | nil
  def find(id) do
    Watchman.benchmark("fetch_project.duration", fn ->
      req =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata: InternalApi.Projecthub.RequestMeta.new(),
          id: id
        )

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:github_notifier, :projecthub_grpc_endpoint))

      Logger.debug(fn ->
        "Sending Project describe request for project_id: #{id}"
      end)

      Logger.debug(inspect(req))

      {:ok, res} =
        InternalApi.Projecthub.ProjectService.Stub.describe(channel, req, timeout: 30_000)

      Logger.debug("Received Project describe response")
      Logger.debug(inspect(res))

      case InternalApi.Projecthub.ResponseMeta.Code.key(res.metadata.status.code) do
        :OK -> construct(res.project)
        _ -> nil
      end
    end)
  end

  defp construct(raw_project) do
    %__MODULE__{
      :id => raw_project.metadata.id,
      :org_id => raw_project.metadata.org_id,
      :owner_id => raw_project.metadata.owner_id,
      :url => raw_project.spec.repository.url,
      :repository_id => raw_project.spec.repository.id,
      :status => raw_project.spec.repository.status |> Poison.encode!() |> Poison.decode!()
    }
  end
end
