defimpl RepositoryHub.Server.CreateAction, for: RepositoryHub.GitAdapter do
  alias RepositoryHub.{
    Validator,
    Toolkit,
    UniversalAdapter,
    Model
  }

  alias Model.{
    RepositoryQuery,
    Repositories
  }

  alias InternalApi.Repository.CreateResponse

  import Toolkit
  @impl true
  def execute(adapter, request) do
    with {:ok, repository} <- insert_repository(adapter, request),
         grpc_repository <- Repositories.to_grpc_model(repository) do
      %CreateResponse{repository: grpc_repository}
      |> wrap()
    end
  end

  defp insert_repository(adapter, request) do
    RepositoryQuery.insert(
      %{
        project_id: request.project_id,
        pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
        commit_status: nil,
        whitelist: UniversalAdapter.fetch_whitelist_settings(request),
        name: "",
        owner: "",
        private: true,
        provider: "git",
        integration_type: adapter.integration_type,
        url: request.repository_url,
        default_branch: request.default_branch,
        remote_id: ""
      },
      on_conflict: :nothing
    )
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      chain: [
        all: [
          chain: [{:from!, :project_id}, :is_uuid],
          chain: [{:from!, :user_id}, :is_uuid],
          chain: [{:from!, :integration_type}, :is_git_integration_type],
          chain: [{:from!, :integration_type}, eq: :GIT, error_message: "github adapter does not work with bitbucket"]
        ]
      ]
    )
  end
end
