defimpl RepositoryHub.Server.ClearExternalDataAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.{GithubAdapter, GithubClient, Model, Toolkit, Validator}
  alias InternalApi.Repository.ClearExternalDataResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, adapter_context} <- GithubAdapter.context(adapter, request.repository_id) do
      repository = adapter_context.repository
      github_token = adapter_context.github_token

      # Remove deploy key if exists
      with {:ok, deploy_key} <- Model.DeployKeyQuery.get_by_repository_id(repository.id) do
        Model.DeployKeyQuery.delete(deploy_key.id)

        GithubClient.remove_deploy_key(
          %{repo_owner: repository.owner, repo_name: repository.name, key_id: deploy_key.remote_id},
          token: github_token
        )
        |> unwrap_error(fn _ -> wrap(:not_found) end)
      end

      # Remove webhook if exists
      if repository.hook_id != "" do
        GithubClient.remove_webhook(
          %{repo_owner: repository.owner, repo_name: repository.name, webhook_id: repository.hook_id},
          token: github_token
        )
        |> unwrap_error(fn _ -> wrap(:not_found) end)
      end

      Model.Repositories.to_grpc_model(repository)
      |> then(fn grpc_repository ->
        %ClearExternalDataResponse{repository: grpc_repository}
        |> wrap()
      end)
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(chain: [{:from!, :repository_id}, :is_uuid])
  end
end
