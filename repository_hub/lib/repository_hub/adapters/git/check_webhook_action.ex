defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.GitAdapter do
  require Logger
  alias InternalApi.Repository.{CheckWebhookResponse, Webhook}
  alias RepositoryHub.GitAdapter
  alias RepositoryHub.Validator
  alias RepositoryHub.Toolkit
  import Toolkit

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

  # @impl true
  # def execute(adapter, request) do
  #   with {:ok, context} <- GitAdapter.context(adapter, request.repository_id),
  #         repository <- context.repository do
  #     if repository.connected do
  #       %CheckWebhookResponse{
  #         webhook: %Webhook{
  #           url: repository.url
  #         }
  #       }
  #       |> wrap()
  #     else
  #       {:error, "Webhook is not connected"}
  #     end
  #   end
  # end

  # @impl true
  # def validate(_adapter, request) do
  #   request
  #   |> Validator.validate(
  #     all: [
  #       chain: [{:from!, :repository_id}, :is_uuid]
  #     ]
  #   )
  # end
end
