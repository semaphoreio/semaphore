defimpl RepositoryHub.Server.DescribeRemoteRepositoryAction, for: RepositoryHub.GithubAdapter do
  # credo:disable-for-this-file
  alias RepositoryHub.{
    Validator,
    Toolkit,
    GithubAdapter,
    GithubClient,
    Model
  }

  alias InternalApi.Repository.{
    RemoteRepository,
    DescribeRemoteRepositoryResponse
  }

  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, git_repository} <- Model.GitRepository.from_github(request.url),
         {:ok, github_token} <- GithubAdapter.token(adapter, request.user_id, git_repository),
         {:ok, github_repository} <- get_github_repository(adapter, git_repository, github_token),
         {:ok, remote_repository} <- build_remote_repository(github_repository, git_repository) do
      %DescribeRemoteRepositoryResponse{
        remote_repository: remote_repository
      }
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, check: &valid_integration_type/1],
        chain: [
          {:from!, :url},
          any: [:is_github_url],
          error_message: "only github urls are allowed"
        ]
      ]
    )
  end

  defp valid_integration_type(status) do
    status in [
      :GITHUB_APP,
      :GITHUB_OAUTH_TOKEN
    ]
  end

  defp get_github_repository(adapter, git_repository, github_token) do
    GithubClient.find_repository(
      %{
        repo_owner: git_repository.owner,
        repo_name: git_repository.repo
      },
      token: github_token
    )
    |> unwrap(fn
      github_repository when adapter.integration_type == "github_app" ->
        %{github_repository | with_admin_access?: true}
        |> wrap()

      github_repository ->
        github_repository
        |> wrap()
    end)
  end

  defp build_remote_repository(github_repository, git_repository) do
    addable = github_repository.with_admin_access?

    reason =
      if addable do
        ""
      else
        "The user does not have admin access to this repository."
      end

    %RemoteRepository{
      id: github_repository.id,
      name: github_repository.name,
      description: github_repository.description,
      url: git_repository.ssh_git_url,
      full_name: github_repository.full_name,
      addable: addable,
      reason: reason
    }
    |> wrap()
  end
end
