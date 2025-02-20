defmodule JobPage.Guard do
  require Logger
  alias JobPage.GrpcConfig

  def can_read_project?(user_id, org_id, project_id, metadata \\ nil) do
    Watchman.benchmark("authorized.duration", fn ->
      resource = resource_factory(type: :Project, id: project_id, org_id: org_id)
      action = InternalApi.Guard.Action.value(:READ)

      filter([resource], action, user_id, org_id, metadata)
      |> Enum.any?()
    end)
  end

  defp filter(resources, action, user_id, org_id, metadata) do
    req =
      InternalApi.Guard.FilterRequest.new(
        resources: resources,
        action: action,
        user_id: user_id,
        org_id: org_id
      )

    Logger.info("Filter request")
    Logger.info(inspect(req))

    {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:guard_grpc_endpoint))

    {:ok, res} =
      InternalApi.Guard.Guard.Stub.filter(channel, req, metadata: metadata, timeout: 30_000)

    Logger.info("Received filter response")
    Logger.info(inspect(res))

    res.resources
  end

  defp resource_factory(params) do
    defaults = [
      id: "*",
      type: 1,
      project_id: "",
      org_id: ""
    ]

    {_, params} =
      Keyword.get_and_update(params, :type, fn current ->
        {current, InternalApi.Guard.Resource.Type.value(current)}
      end)

    defaults |> Keyword.merge(params) |> InternalApi.Guard.Resource.new()
  end
end
