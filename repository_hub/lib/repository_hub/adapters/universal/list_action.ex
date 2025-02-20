defimpl RepositoryHub.Server.ListAction, for: RepositoryHub.UniversalAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.Model.{Repositories, RepositoryQuery}
  alias RepositoryHub.Validator

  alias InternalApi.Repository.ListResponse

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    repositories =
      RepositoryQuery.list_by_project(request.project_id)
      |> Enum.map(&Repositories.to_grpc_model/1)

    %ListResponse{repositories: repositories}
    |> wrap()
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :project_id}, :is_uuid]
      ]
    )
  end
end
