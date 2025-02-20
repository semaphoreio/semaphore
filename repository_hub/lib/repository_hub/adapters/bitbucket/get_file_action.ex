defimpl RepositoryHub.Server.GetFileAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    BitbucketClient,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.{GetFileResponse, File}
  import Toolkit

  @impl true
  def execute(adapter, request) do
    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      BitbucketClient.get_file(
        %{
          repo_owner: context.repository.owner,
          repo_name: context.repository.name,
          commit_sha: request.commit_sha,
          path: request.path
        },
        token: context.bitbucket_token
      )
    end)
    |> unwrap(fn file ->
      %GetFileResponse{file: %File{path: request.path, content: file}}
      |> wrap()
    end)
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
end
