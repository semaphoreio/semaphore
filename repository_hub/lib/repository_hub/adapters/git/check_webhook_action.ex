defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.GitAdapter do
  require Logger
  alias InternalApi.Repository.{CheckWebhookResponse, Webhook}

  alias RepositoryHub.{
    GitAdapter,
    Toolkit,
    OrganizationClient
  }

  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitAdapter.context(adapter, request.repository_id),
         {:ok, organization} <- get_organization(context.project.metadata.org_id) do
      %CheckWebhookResponse{
        webhook: %Webhook{
          url: RepositoryHub.GitClient.Webhook.url(organization.org_username, context.repository.id)
        }
      }
      |> wrap()
    end
  end

  defp get_organization(org_id) do
    OrganizationClient.describe(org_id)
    |> unwrap(fn response ->
      wrap(response.organization)
    end)
  end

  @impl true
  def validate(_adapter, request) do
    {:ok, request}
  end
end
