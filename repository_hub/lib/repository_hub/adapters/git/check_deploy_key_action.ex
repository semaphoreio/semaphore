defimpl RepositoryHub.Server.CheckDeployKeyAction, for: RepositoryHub.GitAdapter do
  alias RepositoryHub.{
    GitAdapter,
    Model,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.CheckDeployKeyResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitAdapter.context(adapter, request.repository_id),
         {:ok, deploy_key} <- fetch_deploy_key(context.repository.id) do
      %CheckDeployKeyResponse{
        deploy_key: %InternalApi.Repository.DeployKey{
          title: "semaphore-#{context.repository.project_id}",
          fingerprint: Model.DeployKeys.fingerprint(deploy_key),
          created_at: to_proto_time(deploy_key.inserted_at),
          public_key: deploy_key.public_key
        }
      }
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

  defp fetch_deploy_key(repository_id) do
    Model.DeployKeyQuery.get_by_repository_id(repository_id)
    |> unwrap_error(fn error ->
      %{message: error, status: GRPC.Status.not_found()}
      |> error
    end)
  end
end
