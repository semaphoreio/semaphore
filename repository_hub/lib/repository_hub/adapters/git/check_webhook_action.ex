defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.GitAdapter do
  require Logger

  @impl true
  def execute(_adapter, _request) do
    raise GRPC.RPCError,
      status: GRPC.Status.unimplemented(),
      message: "CheckWebhook action is not implemented for GIT."
  end

  @impl true
  def validate(_adapter, request) do
    {:ok, request}
  end
end
