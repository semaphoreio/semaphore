defimpl RepositoryHub.Server.CheckDeployKeyAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    BitbucketClient,
    Model,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.CheckDeployKeyResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> Multi.run(:deploy_key, fn _repo, context ->
      Model.DeployKeyQuery.get_by_repository_id(context.repository.id)
      |> unwrap_error(fn error ->
        %{message: error, status: GRPC.Status.not_found()}
        |> error
      end)
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      BitbucketClient.find_deploy_key(
        %{
          repo_owner: context.repository.owner,
          repo_name: context.repository.name,
          key_id: context.deploy_key.remote_id
        },
        token: context.bitbucket_token
      )
      |> unwrap(fn remote_key ->
        %InternalApi.Repository.DeployKey{
          title: remote_key.title,
          fingerprint: Model.DeployKeys.fingerprint(context.deploy_key),
          created_at: to_proto_time(context.deploy_key.inserted_at)
        }
      end)
    end)
    |> unwrap(fn deploy_key ->
      %CheckDeployKeyResponse{deploy_key: deploy_key}
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
