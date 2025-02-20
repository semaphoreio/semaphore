defimpl RepositoryHub.Server.RegenerateWebhookAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, OrganizationClient, Toolkit, Validator, Model}
  alias InternalApi.Repository.RegenerateWebhookResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    adapter
    |> GitlabAdapter.multi(request.repository_id)
    |> Multi.run(:organization, fn _repo, context ->
      OrganizationClient.describe(context.project.metadata.org_id)
      |> unwrap(fn response ->
        wrap(response.organization)
      end)
    end)
    |> Multi.run(:remove_webhook, fn _repo, context ->
      context.repository.hook_id
      |> case do
        nil ->
          wrap(:ok)

        _ ->
          Model.RepositoryQuery.update(context.repository, %{hook_id: ""})
      end
    end)
    |> Multi.run(:remove_in_gitlab, fn _, context ->
      context.repository.hook_id
      |> case do
        nil ->
          wrap(:ok)

        hook_id ->
          GitlabClient.remove_webhook(
            %{
              repository_id: context.repository.remote_id,
              webhook_id: hook_id
            },
            token: context.gitlab_token
          )
      end
    end)
    |> Multi.run(:webhook_secret, fn _repo, context ->
      Model.Repositories.generate_hook_secret(context.repository)
    end)
    |> Multi.run(:gitlab_webhook_name, fn _repo, context ->
      "semaphore-#{context.repository.owner}-#{context.repository.name}"
      |> wrap()
    end)
    |> Multi.run(:new_gitlab_webhook, fn _repo, context ->
      {hook_secret, _} = context.webhook_secret

      GitlabClient.create_webhook(
        %{
          repository_id: context.repository.remote_id,
          name: context.gitlab_webhook_name,
          events: GitlabClient.Webhook.events(),
          secret: hook_secret,
          url: GitlabClient.Webhook.url(context.organization.org_username, context.repository.id)
        },
        token: context.gitlab_token
      )
    end)
    |> Multi.run(:update_repository_webhook, fn _repo, context ->
      {_, hook_secret_enc} = context.webhook_secret

      Model.RepositoryQuery.update(context.repository, %{
        hook_id: "#{context.new_gitlab_webhook.id}",
        hook_secret_enc: hook_secret_enc
      })
    end)
    |> RepositoryHub.Repo.transaction(timeout: 30_000)
    |> unwrap(fn %{update_repository_webhook: repository} ->
      %RegenerateWebhookResponse{
        webhook: %InternalApi.Repository.Webhook{
          url: repository.url
        }
      }
      |> wrap()
    end)
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
