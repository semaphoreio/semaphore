defimpl RepositoryHub.Server.DescribeRevisionAction, for: RepositoryHub.GitAdapter do
  @moduledoc """
  Describes a branch, tag or commit of a Generic Git repository.

  There is no provider API behind a Generic Git repository, so the revision is
  resolved with the `git` command line over SSH, authenticated with the deploy key
  Semaphore generated for the project (see `RepositoryHub.GitCliClient`).

  Scheduled tasks, "Run workflow" and the API go through this action before they
  can start a workflow; without it they fail with "Cannot find git reference".
  """

  alias RepositoryHub.{
    GitCliClient,
    Model,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.{
    Commit,
    DescribeRevisionResponse
  }

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, repository} <- Model.RepositoryQuery.get_by_id(request.repository_id),
         {:ok, private_key} <- fetch_private_key(repository),
         {:ok, commit} <- describe(repository.url, request.revision, private_key) do
      %DescribeRevisionResponse{
        commit: %Commit{
          sha: commit.sha,
          msg: commit.message,
          author_name: commit.author_name,
          author_uuid: "",
          author_avatar_url: ""
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
        chain: [{:from!, [:revision, :commit_sha]}, any: [:is_sha, :is_empty]],
        any: [
          chain: [{:from!, [:revision, :reference]}, :is_string, :is_not_empty],
          chain: [{:from!, [:revision, :commit_sha]}, :is_string, :is_not_empty]
        ]
      ]
    )
  end

  # A commit sha pins the revision; the reference is then only informative.
  defp describe(url, %{commit_sha: commit_sha}, private_key) when commit_sha not in [nil, ""] do
    fetch_commit(url, commit_sha, private_key)
  end

  # A fully qualified reference (what plumber and the scheduler send) is fetched
  # directly: the fetch resolves it and reads its commit over a single SSH
  # connection. Every connection costs about a second on some servers, and plumber
  # gives the whole call 5 s. Any failure falls back to resolving the reference
  # first, which also tells an unknown reference apart from a refused fetch.
  defp describe(url, %{reference: "refs/" <> _ = reference}, private_key) do
    case fetch_commit(url, reference, private_key) do
      {:ok, _} = ok -> ok
      {:error, _} -> describe_by_listing(url, reference, private_key)
    end
  end

  defp describe(url, %{reference: reference}, private_key) do
    describe_by_listing(url, reference, private_key)
  end

  # Without a sha, the reference is resolved first so that an unknown branch or tag
  # is reported as such. The commit metadata is best effort: a server refusing the
  # fetch still lets the workflow start on the right sha.
  defp describe_by_listing(url, reference, private_key) do
    with {:ok, resolved} <- GitCliClient.get_reference(%{url: url, reference: reference}, private_key: private_key) do
      case fetch_commit(url, resolved.sha, private_key) do
        {:ok, _} = ok ->
          ok

        {:error, reason} ->
          log_warn(["Could not read commit #{resolved.sha} of #{url}, answering with the sha only", inspect(reason)])

          wrap(%{sha: resolved.sha, message: "", author_name: "", author_email: ""})
      end
    end
  end

  defp fetch_commit(url, revision, private_key) do
    GitCliClient.get_commit(%{url: url, revision: revision}, private_key: private_key)
  end

  defp fetch_private_key(repository) do
    with {:ok, deploy_key} <- Model.DeployKeyQuery.get_by_repository_id(repository.id) do
      RepositoryHub.Encryptor.decrypt(
        RepositoryHub.DeployKeyEncryptor,
        deploy_key.private_key_enc,
        "semaphore-#{deploy_key.project_id}"
      )
    end
    |> unwrap_error(fn error ->
      fail_with(:precondition, "Deploy key is not available for this repository: #{inspect(error)}")
    end)
  end
end
