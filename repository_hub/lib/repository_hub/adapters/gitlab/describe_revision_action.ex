defimpl RepositoryHub.Server.DescribeRevisionAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Toolkit, Validator}
  alias InternalApi.Repository.{DescribeRevisionResponse, Commit}
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, reference} <- get_reference(request.revision.reference, context.repository, context.gitlab_token),
         {:ok, commit} <- get_commit(request.revision.commit_sha, reference, context),
         {:ok, author} <- get_author(commit, context) do
      %DescribeRevisionResponse{
        commit: %Commit{
          sha: commit.sha,
          msg: commit.message,
          author_name: commit.author_name,
          author_uuid: author.id,
          author_avatar_url: author.avatar_url
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

  defp get_reference(reference, repository, gitlab_token) do
    GitlabClient.get_reference(
      %{
        repository_id: repository.remote_id,
        reference: reference
      },
      token: gitlab_token
    )
  end

  defp get_commit(_commit_sha, %{type: type} = reference, context) when type in ["tag", "branch"] do
    GitlabClient.get_commit(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: reference.sha
      },
      token: context.gitlab_token
    )
  end

  defp get_commit(commit_sha, %{type: "commit"} = _reference, context) do
    GitlabClient.get_commit(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: commit_sha
      },
      token: context.gitlab_token
    )
  end

  defp get_author(commit, context) do
    case GitlabClient.find_user(%{search: commit.author_email}, context.gitlab_token) do
      {:ok, user} ->
        wrap(user)

      {:error, _} ->
        %{
          id: "",
          avatar_url: ""
        }
        |> wrap()
    end
  end
end
