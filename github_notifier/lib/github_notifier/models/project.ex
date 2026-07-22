defmodule GithubNotifier.Models.Project do
  defstruct [:id, :org_id, :owner_id, :url, :status, :repository_id]

  require Logger

  @spec find(String.t()) :: GithubNotifier.Models.Project | nil
  def find(id) do
    Watchman.benchmark("fetch_project.duration", fn ->
      req =
        struct(InternalApi.Projecthub.DescribeRequest,
          metadata: struct(InternalApi.Projecthub.RequestMeta),
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

      case res.metadata.status.code do
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
      :status =>
        raw_project.spec.repository.status
        |> Poison.encode!()
        |> Poison.decode!()
        |> drop_unknown_fields()
    }
  end

  defp drop_unknown_fields(map) when is_map(map) do
    map
    |> Map.drop(["__unknown_fields__", "__protobuf__"])
    |> Map.new(fn {k, v} -> {k, drop_unknown_fields(v)} end)
  end

  defp drop_unknown_fields(list) when is_list(list), do: Enum.map(list, &drop_unknown_fields/1)
  defp drop_unknown_fields(value), do: value
end
