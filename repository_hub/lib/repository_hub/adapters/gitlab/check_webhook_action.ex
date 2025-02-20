defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.GitlabAdapter do
  @moduledoc """
  gitlab does not include info about secret token presence, so it's not checked
  """
  require Logger
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GitlabAdapter, GitlabClient, OrganizationClient, Model}
  alias InternalApi.Repository.CheckWebhookResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, organization} <- get_organization(context.project.metadata.org_id),
         {:ok, remote_webhook} <- get_remote_hook(context, organization),
         {:ok, _} <-
           Model.RepositoryQuery.update(context.repository, %{hook_id: remote_webhook.id}),
         grpc_webhook <- build_webhook(remote_webhook) do
      %CheckWebhookResponse{webhook: grpc_webhook}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid]
      ]
    )
  end

  defp get_organization(org_id) do
    OrganizationClient.describe(org_id)
    |> unwrap(fn response ->
      wrap(response.organization)
    end)
  end

  defp get_remote_hook(context, organization) do
    GitlabClient.find_webhook(
      %{
        id: context.repository.id,
        repository_id: context.repository.remote_id,
        webhook_id: context.repository.hook_id,
        url: GitlabClient.Webhook.url(organization.org_username, context.repository.id),
        events: GitlabClient.Webhook.events()
      },
      token: context.gitlab_token
    )
  end

  defp build_webhook(remote_hook) do
    %InternalApi.Repository.Webhook{
      url: remote_hook.url
    }
  end
end
