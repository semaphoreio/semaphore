defimpl RepositoryHub.Server.GetFileAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator
  alias InternalApi.Repository.{GetFileResponse, File}
  alias RepositoryHub.{GithubAdapter, GithubClient}

  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GithubAdapter.context(adapter, request.repository_id),
         {:ok, file} <- get_file(request, context.repository, context.github_token),
         grpc_file <- %File{path: request.path, content: file} do
      %GetFileResponse{file: grpc_file}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :commit_sha}, :is_sha],
        chain: [{:from!, :path}, :is_file_path]
      ]
    )
  end

  defp get_file(request, repository, github_token) do
    GithubClient.get_file(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name,
        commit_sha: request.commit_sha,
        path: request.path
      },
      token: github_token
    )
  end
end
