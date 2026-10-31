defimpl RepositoryHub.Server.UpdateAction, for: RepositoryHub.GitAdapter do
  @moduledoc """
  Updates the repository of a Generic Git project: its url, pipeline file and
  whitelist. There is no remote API to call, so the update only touches the
  repository record; the deploy key stays the same.
  """

  alias RepositoryHub.{
    Toolkit,
    UniversalAdapter,
    Validator
  }

  alias RepositoryHub.Model.{
    GitRepository,
    Repositories,
    RepositoryQuery
  }

  alias InternalApi.Repository.UpdateResponse

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, repository} <- RepositoryQuery.get_by_id(request.repository_id),
         {:ok, git_repository} <- GitRepository.from_generic(request.url),
         {:ok, updated} <- RepositoryQuery.update(repository, params(request, git_repository), returning: true) do
      %UpdateResponse{repository: Repositories.to_grpc_model(updated)}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :url}, :is_string, :is_not_empty]
      ]
    )
  end

  defp params(request, git_repository) do
    %{
      url: request.url,
      name: git_repository.repo,
      owner: git_repository.owner,
      pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
      commit_status: UniversalAdapter.fetch_commit_status(request),
      whitelist: UniversalAdapter.fetch_whitelist_settings(request)
    }
  end
end
