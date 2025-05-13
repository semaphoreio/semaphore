defimpl RepositoryHub.Server.CreateAction, for: RepositoryHub.GitAdapter do
  alias RepositoryHub.{
    Validator,
    Toolkit,
    UniversalAdapter,
    Model
  }

  alias Model.{
    RepositoryQuery,
    Repositories,
    GitRepository
  }

  alias InternalApi.Repository.CreateResponse

  import Toolkit
  @impl true
  def execute(adapter, request) do
    with {:ok, git_repository} <- GitRepository.from_generic(request.repository_url),
         {:ok, repository} <- insert_repository(adapter, request, git_repository),
         grpc_repository <- Repositories.to_grpc_model(repository) do
      %CreateResponse{repository: grpc_repository}
      |> wrap()
    end
  end

  defp insert_repository(adapter, request, git_repository) do
    RepositoryQuery.insert(
      %{
        project_id: request.project_id,
        pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
        commit_status: nil,
        whitelist: UniversalAdapter.fetch_whitelist_settings(request),
        name: git_repository.repo,
        owner: git_repository.owner,
        private: true,
        provider: "git",
        integration_type: adapter.integration_type,
        url: request.repository_url,
        default_branch: request.default_branch,
        remote_id: "",
        connected: false
      },
      on_conflict: :nothing
    )
  end

  @impl true
  @spec validate(RepositoryHub.GitAdapter.t(), any()) :: {:error, any()} | {:ok, any()}
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      chain: [
        all: [
          chain: [{:from!, :project_id}, :is_uuid],
          chain: [{:from!, :user_id}, :is_uuid],
          chain: [{:from!, :integration_type}, :is_git_integration_type]
        ]
      ]
    )
  end
end
