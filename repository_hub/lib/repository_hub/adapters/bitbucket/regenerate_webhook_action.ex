defimpl RepositoryHub.Server.RegenerateWebhookAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    Model,
    BitbucketClient,
    OrganizationClient,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.RegenerateWebhookResponse

  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> Multi.run(:organization, fn _repo, context ->
      OrganizationClient.describe(context.project.metadata.org_id)
      |> unwrap(fn response ->
        wrap(response.organization)
      end)
    end)
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
    |> Multi.run(:remove_in_bitbucket, fn
      _, context ->
        context.repository.hook_id
        |> case do
          nil ->
            wrap(:ok)

          hook_id ->
            BitbucketClient.remove_webhook(
              %{
                repo_owner: context.repository.owner,
                repo_name: context.repository.name,
                webhook_id: hook_id
              },
              token: context.bitbucket_token
            )
        end
    end)
    |> Multi.run(:webhook_secret, fn _repo, context ->
      Model.Repositories.generate_hook_secret(context.repository)
    end)
    |> Multi.run(:new_bitbucket_webhook, fn _repo, context ->
      {hook_secret, _} = context.webhook_secret

      BitbucketClient.create_webhook(
        %{
          repo_owner: context.repository.owner,
          repo_name: context.repository.name,
          url: BitbucketClient.Webhook.url(context.organization.org_username, context.repository.id),
          events: BitbucketClient.Webhook.events(),
          secret: hook_secret
        },
        token: context.bitbucket_token
      )
    end)
    |> Multi.run(:update_repository_webhook, fn _repo, context ->
      {_, hook_secret_enc} = context.webhook_secret

      Model.RepositoryQuery.update(context.repository, %{
        hook_id: "#{context.new_bitbucket_webhook.id}",
        hook_secret_enc: hook_secret_enc
      })
    end)
    |> RepositoryHub.Repo.transaction(timeout: 30_000)
    |> unwrap(fn context ->
      %RegenerateWebhookResponse{
        webhook: %InternalApi.Repository.Webhook{url: context.new_bitbucket_webhook.url}
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
