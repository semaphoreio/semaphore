defimpl RepositoryHub.Server.CheckDeployKeyAction, for: RepositoryHub.GithubAdapter do
  require Logger
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, GithubClient, Model}
  alias InternalApi.Repository.CheckDeployKeyResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GithubAdapter.context(adapter, request.repository_id),
         {:ok, deploy_key} <- get_deploy_key(context.repository.id),
         {:ok, remote_key} <- get_remote_key(context.repository, deploy_key, context.github_token),
         grpc_deploy_key <- build_deploy_key(deploy_key, remote_key) do
      %CheckDeployKeyResponse{deploy_key: grpc_deploy_key}
      |> wrap()
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

  defp get_deploy_key(repository_id) do
    Model.DeployKeyQuery.get_by_repository_id(repository_id)
    |> unwrap_error(fn error ->
      %{message: error, status: GRPC.Status.not_found()}
      |> error
    end)
  end

  defp get_remote_key(repository, deploy_key, github_token) do
    GithubClient.find_deploy_key(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name,
        key_id: deploy_key.remote_id
      },
      token: github_token
    )
  end

  defp build_deploy_key(deploy_key, remote_key) do
    %InternalApi.Repository.DeployKey{
      title: remote_key.title,
      fingerprint: Model.DeployKeys.fingerprint(deploy_key),
      created_at: to_proto_time(deploy_key.inserted_at)
    }
  end
end
