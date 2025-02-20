defimpl RepositoryHub.Server.DescribeAction, for: RepositoryHub.UniversalAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.Model.{Repositories, RepositoryQuery, DeployKeyQuery}
  alias InternalApi.Repository.DescribeResponse

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, repository} <- fetch_repository(request.repository_id),
         {:ok, private_key_enc} <- fetch_ssh_key(request.repository_id, request.include_private_ssh_key),
         {:ok, private_key} <-
           RepositoryHub.Encryptor.decrypt(
             RepositoryHub.DeployKeyEncryptor,
             private_key_enc,
             "semaphore-#{repository.project_id}"
           ) do
      %DescribeResponse{
        repository: Repositories.to_grpc_model(repository),
        private_ssh_key: private_key
      }
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :include_private_ssh_key}, any: [eq: true, eq: false]]
      ]
    )
  end

  defp fetch_repository(repository_id) do
    RepositoryQuery.get_by_id(repository_id)
  end

  defp fetch_ssh_key(repository_id, true = _fetch_key?) do
    case DeployKeyQuery.get_by_repository_id(repository_id) do
      {:ok, ssh_key_model} -> ssh_key_model.private_key_enc
      _ -> ""
    end
    |> wrap()
  end

  defp fetch_ssh_key(_repository_id, false = _fetch_key?) do
    wrap("")
  end
end
