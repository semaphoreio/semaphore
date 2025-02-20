defimpl RepositoryHub.Server.GetFileAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Toolkit, Validator}
  alias InternalApi.Repository.{GetFileResponse, File}
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, file_content} <-
           GitlabClient.get_file(
             %{
               repository_id: context.repository.remote_id,
               commit_sha: request.commit_sha,
               path: request.path
             },
             token: context.gitlab_token
           ) do
      %GetFileResponse{file: %File{path: request.path, content: file_content}}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :path}, :is_string],
        chain: [{:from!, :commit_sha}, :is_sha]
      ]
    )
  end
end
