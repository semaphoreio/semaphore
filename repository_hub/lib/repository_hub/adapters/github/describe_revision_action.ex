defimpl RepositoryHub.Server.DescribeRevisionAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.GithubClient
  alias RepositoryHub.GithubAdapter
  # credo:disable-for-this-file
  alias RepositoryHub.{
    Validator,
    Toolkit,
    GithubAdapter,
    GithubClient
  }

  alias InternalApi.Repository.{
    Commit,
    DescribeRevisionResponse
  }

  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GithubAdapter.context(adapter, request.repository_id),
         {:ok, reference} <- get_reference(request.revision.reference, context.repository, context.github_token),
         {:ok, commit} <- get_commit(request.revision.commit_sha, reference, context) do
      %DescribeRevisionResponse{
        commit: %Commit{
          sha: commit.sha,
          msg: commit.message,
          author_name: commit.author_name,
          author_uuid: to_string(commit.author_uuid),
          author_avatar_url: commit.author_avatar_url
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
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, [:revision, :commit_sha]}, any: [:is_sha, :is_empty]]
      ]
    )
  end

  defp get_reference(reference, repository, github_token) do
    GithubClient.get_reference(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name,
        reference: reference
      },
      token: github_token
    )
  end

  defp get_commit(_commit_sha, %{type: "tag"} = reference, context) do
    GithubClient.get_commit(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: reference.sha
      },
      token: context.github_token
    )
  end

  defp get_commit("", %{type: "branch"} = reference, context) do
    GithubClient.get_commit(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: reference.sha
      },
      token: context.github_token
    )
  end

  defp get_commit(commit_sha, %{type: "branch"} = _reference, context) do
    GithubClient.get_commit(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: commit_sha
      },
      token: context.github_token
    )
  end
end
