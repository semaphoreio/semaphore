defimpl RepositoryHub.Server.DeleteAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.Model
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{BitbucketAdapter, Model, BitbucketClient}
  alias InternalApi.Repository.DeleteResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> Multi.run(:deploy_key, fn _repo, context ->
      Model.DeployKeyQuery.get_by_repository_id(context.repository.id)
      |> unwrap_error(fn _ ->
        wrap(:not_found)
      end)
    end)
    |> Multi.run(:remove_deploy_key, fn
      _repo, %{deploy_key: :not_found} ->
        wrap(:ok)

      _, context ->
        Model.DeployKeyQuery.delete(context.deploy_key.id)
    end)
    |> Multi.run(:remove_bitbucket_key, fn
      _repo, %{deploy_key: :not_found} ->
        "Skiping Bitbucket deploy key removal - deploy key not found"
        |> log(level: :info)

        wrap(:ok)

      _, context ->
        BitbucketClient.remove_deploy_key(
          %{
            repo_owner: context.repository.owner,
            repo_name: context.repository.name,
            key_id: "#{context.deploy_key.remote_id}"
          },
          token: context.bitbucket_token
        )
        |> unwrap_error(fn _ ->
          wrap(:not_found)
        end)
    end)
    |> Multi.run(:remove_webhook, fn
      _repo, %{repository: %{hook_id: ""}} ->
        "Skiping Bitbucket webhook removal - no hook id"
        |> log(level: :info)

        wrap(:ok)

      _, context ->
        BitbucketClient.remove_webhook(
          %{
            repo_owner: context.repository.owner,
            repo_name: context.repository.name,
            webhook_id: context.repository.hook_id
          },
          token: context.bitbucket_token
        )
        |> unwrap_error(fn _ ->
          wrap(:not_found)
        end)
    end)
    |> Multi.run(:delete_repository, fn _repo, context ->
      Model.RepositoryQuery.delete(context.repository.id)
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      %DeleteResponse{
        repository: Model.Repositories.to_grpc_model(context.repository)
      }
      |> wrap()
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(chain: [{:from!, :repository_id}, :is_uuid])
  end
end
