defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.GitAdapter do
  require Logger
  alias InternalApi.Repository.{CheckWebhookResponse, Webhook}
  alias RepositoryHub.Toolkit
  import Toolkit

  @impl true
  def execute(_adapter, _request) do
    %CheckWebhookResponse{
      webhook: %Webhook{
        url: ""
      }
    }
    |> wrap()
  end

  @impl true
  def validate(_adapter, request) do
    {:ok, request}
  end
end
