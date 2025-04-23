defimpl RepositoryHub.Server.CleanExternalDataAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Model}
  alias RepositoryHub.Toolkit
  alias InternalApi.Repository.CleanExternalDataResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, adapter_context} <- GitlabAdapter.context(adapter, request.repository_id) do
      repository = adapter_context.repository
      gitlab_token = adapter_context.gitlab_token

      # Remove deploy key if exists
      with {:ok, deploy_key} <- Model.DeployKeyQuery.get_by_repository_id(repository.id) do
        Model.DeployKeyQuery.delete(deploy_key.id)

        GitlabClient.remove_deploy_key(
          %{repository_id: repository.remote_id, key_id: deploy_key.remote_id},
          token: gitlab_token
        )
        |> unwrap_error(fn _ -> wrap(:not_found) end)
      end

      # Remove webhook if exists
      if repository.hook_id != "" do
        GitlabClient.remove_webhook(
          %{repository_id: repository.remote_id, webhook_id: repository.hook_id},
          token: gitlab_token
        )
        |> unwrap_error(fn _ -> wrap(:not_found) end)
      end

      Model.Repositories.to_grpc_model(repository)
      |> then(fn grpc_repository ->
        %CleanExternalDataResponse{repository: grpc_repository}
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
