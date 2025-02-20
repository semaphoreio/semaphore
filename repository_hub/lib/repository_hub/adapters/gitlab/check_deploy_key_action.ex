defimpl RepositoryHub.Server.CheckDeployKeyAction, for: RepositoryHub.GitlabAdapter do
  require Logger
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GitlabAdapter, GitlabClient, Model}
  alias InternalApi.Repository.CheckDeployKeyResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, deploy_key} <- get_deploy_key(context.repository.id),
         {:ok, remote_key} <-
           get_remote_key(context.repository, deploy_key, context.gitlab_token),
         grpc_deploy_key <- build_deploy_key(deploy_key, remote_key) do
      %CheckDeployKeyResponse{deploy_key: grpc_deploy_key}
      |> wrap()
    else
      {:error, :deploy_key, error, _changes_so_far} ->
        error(%{
          status: GRPC.Status.not_found(),
          message: "Deploy key for repository not found: #{error.message}"
        })

      {:error, :repository, error, _changes_so_far} ->
        error(%{
          status: GRPC.Status.not_found(),
          message: "Repository not found: #{error.message}"
        })

      {:error, %{message: _, status: _} = response} ->
        error(response)
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

  defp get_remote_key(repository, deploy_key, gitlab_token) do
    GitlabClient.find_deploy_key(
      %{
        repository_id: repository.remote_id,
        key_id: deploy_key.remote_id
      },
      token: gitlab_token
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
