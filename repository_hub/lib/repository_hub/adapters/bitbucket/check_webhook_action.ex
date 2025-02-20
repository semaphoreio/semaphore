defimpl RepositoryHub.Server.CheckWebhookAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    Model,
    BitbucketClient,
    OrganizationClient,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.CheckWebhookResponse
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
    |> Multi.run(:bitbucket_webhook, fn _repo, context ->
      BitbucketClient.find_webhook(
        %{
          repo_owner: context.repository.owner,
          repo_name: context.repository.name,
          url: BitbucketClient.Webhook.url(context.organization.org_username, context.repository.id),
          events: BitbucketClient.Webhook.events(),
          webhook_id: context.repository.hook_id
        },
        token: context.bitbucket_token
      )
    end)
    |> Multi.run(:webhook_has_secret, fn _repo, context ->
      check_secret_presence?(context.bitbucket_webhook)
    end)
    |> Multi.run(:update_repository_hook, fn _repo, context ->
      # We should consider removing this. One would expect that "check" action is stateless
      context.repository
      |> Model.RepositoryQuery.update(%{hook_id: "#{context.bitbucket_webhook.id}"})
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      %CheckWebhookResponse{webhook: %InternalApi.Repository.Webhook{url: context.bitbucket_webhook.url}}
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

  defp check_secret_presence?(bitbucket_webhook) do
    bitbucket_webhook.has_secret?
    |> case do
      true -> wrap(bitbucket_webhook)
      false -> error("Webhook secret is missing")
    end
  end
end
