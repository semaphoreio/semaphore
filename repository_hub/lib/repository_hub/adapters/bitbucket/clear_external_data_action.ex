defimpl RepositoryHub.Server.ClearExternalDataAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{BitbucketAdapter, BitbucketClient, Model, Toolkit, Validator}
  alias InternalApi.Repository.ClearExternalDataResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    case BitbucketAdapter.context(adapter, request.repository_id) do
      {:ok, adapter_context} ->
        repository = adapter_context.repository
        bitbucket_token = adapter_context.bitbucket_token

        remove_deploy_key(repository, bitbucket_token)
        remove_webhook(repository, bitbucket_token)

        build_response(repository)

      error -> error
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(chain: [{:from!, :repository_id}, :is_uuid])
  end

  defp remove_deploy_key(repository, bitbucket_token) do
    case Model.DeployKeyQuery.get_by_repository_id(repository.id) do
      {:ok, deploy_key} ->
        Model.DeployKeyQuery.delete(deploy_key.id)

        BitbucketClient.remove_deploy_key(
          %{repo_owner: repository.owner, repo_name: repository.name, key_id: deploy_key.remote_id},
          token: bitbucket_token
        )
        |> unwrap_error(fn _ -> wrap(:not_found) end)

      _ -> {:ok, nil}
    end
  end

  defp remove_webhook(repository, bitbucket_token) do
    if repository.hook_id != "" do
      BitbucketClient.remove_webhook(
        %{repo_owner: repository.owner, repo_name: repository.name, webhook_id: repository.hook_id},
        token: bitbucket_token
      )
      |> unwrap_error(fn _ -> wrap(:not_found) end)
    else
      {:ok, nil}
    end
  end

  defp build_response(repository) do
    repository
    |> Model.Repositories.to_grpc_model()
    |> then(fn grpc_repository ->
      %ClearExternalDataResponse{repository: grpc_repository}
      |> wrap()
    end)
  end
end
