defimpl RepositoryHub.Server.RegenerateWebhookAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, Model, GithubClient}
  alias InternalApi.Repository.RegenerateWebhookResponse

  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    with {:ok, adapter_context} <- GithubAdapter.context(adapter, request.repository_id) do
      Multi.new()
      |> Multi.put(:repository, adapter_context.repository)
      |> Multi.put(:github_token, adapter_context.github_token)
      |> Multi.run(:remove_webhook, fn
        _repo, context ->
          context.repository.hook_id
          |> case do
            nil ->
              wrap(:ok)

            _ ->
              Model.RepositoryQuery.update(context.repository, %{hook_id: ""})
          end
      end)
      |> Multi.run(:remove_in_github, fn
        _, context ->
          GithubClient.remove_webhook(
            %{
              repo_owner: context.repository.owner,
              repo_name: context.repository.name,
              webhook_id: context.repository.hook_id
            },
            token: context.github_token
          )
      end)
      |> Multi.run(:webhook_secret, fn _repo, context ->
        Model.Repositories.generate_hook_secret(context.repository)
      end)
      |> Multi.run(:new_github_webhook, fn _repo, context ->
        {hook_secret, _} = context.webhook_secret

        GithubClient.create_webhook(
          %{
            repo_owner: context.repository.owner,
            repo_name: context.repository.name,
            url: GithubClient.Webhook.url(context.repository.project_id),
            events: GithubClient.Webhook.events(),
            secret: hook_secret
          },
          token: context.github_token
        )
      end)
      |> Multi.run(:update_repository_webhook, fn _repo, context ->
        {_, hook_secret_enc} = context.webhook_secret

        Model.RepositoryQuery.update(context.repository, %{
          hook_id: context.new_github_webhook.id,
          hook_secret_enc: hook_secret_enc
        })
      end)
      |> RepositoryHub.Repo.transaction()
      |> unwrap(fn context ->
        %InternalApi.Repository.Webhook{url: context.new_github_webhook.url}
        |> then(fn grpc_webhook ->
          %RegenerateWebhookResponse{webhook: grpc_webhook}
          |> wrap()
        end)
      end)
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
end
