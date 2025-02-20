defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, Model, GithubClient}
  alias InternalApi.Repository.CheckWebhookResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GithubAdapter.context(adapter, request.repository_id),
         {:ok, github_webhook} <- get_github_webhook(context.repository, context.project, context.github_token),
         {:ok, github_webhook} <- check_secret_presence?(github_webhook),
         {:ok, _} <-
           Model.RepositoryQuery.update(context.repository, %{hook_id: github_webhook.id}),
         grpc_webhook <- %InternalApi.Repository.Webhook{url: github_webhook.url} do
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

  defp get_github_webhook(repository, project, github_token) do
    GithubClient.find_webhook(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name,
        url: GithubClient.Webhook.url(project.metadata.id),
        events: GithubClient.Webhook.events(),
        webhook_id: repository.hook_id
      },
      token: github_token
    )
  end

  defp check_secret_presence?(github_webhook) do
    github_webhook.has_secret?
    |> case do
      true -> wrap(github_webhook)
      false -> error("Webhook secret is missing")
    end
  end
end
