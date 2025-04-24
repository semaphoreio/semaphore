defimpl RepositoryHub.Server.ClearExternalDataAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Model, Toolkit, Validator}
  alias InternalApi.Repository.ClearExternalDataResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, adapter_context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, _} <- remove_deploy_key(adapter_context.repository, adapter_context.gitlab_token),
         {:ok, _} <- remove_webhook(adapter_context.repository, adapter_context.gitlab_token) do
      build_response(adapter_context.repository)
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(chain: [{:from!, :repository_id}, :is_uuid])
  end

  defp remove_deploy_key(repository, gitlab_token) do
    case Model.DeployKeyQuery.get_by_repository_id(repository.id) do
      {:ok, deploy_key} ->
        Model.DeployKeyQuery.delete(deploy_key.id)

        GitlabClient.remove_deploy_key(
          %{repository_id: repository.remote_id, key_id: deploy_key.remote_id},
          token: gitlab_token
        )
        |> unwrap_error(fn _ -> wrap(:not_found) end)

      _ ->
        {:ok, nil}
    end
  end

  defp remove_webhook(repository, gitlab_token) do
    if repository.hook_id != "" do
      GitlabClient.remove_webhook(
        %{repository_id: repository.remote_id, webhook_id: repository.hook_id},
        token: gitlab_token
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
