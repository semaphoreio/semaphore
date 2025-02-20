defimpl RepositoryHub.Server.GetSshKeyAction, for: RepositoryHub.UniversalAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.Model.DeployKeyQuery
  alias InternalApi.Repository.GetSshKeyResponse

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, deploy_key} <- DeployKeyQuery.get_by_repository_id(request.repository_id),
         {:ok, private_key} <-
           RepositoryHub.Encryptor.decrypt(
             RepositoryHub.DeployKeyEncryptor,
             deploy_key.private_key_enc,
             "semaphore-#{deploy_key.project_id}"
           ) do
      %GetSshKeyResponse{private_ssh_key: private_key}
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
end
