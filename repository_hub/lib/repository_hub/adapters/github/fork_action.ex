defimpl RepositoryHub.Server.ForkAction, for: RepositoryHub.GithubAdapter do
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
    ForkResponse
  }

  import Toolkit

  @impl true

  def execute(%GithubAdapter{integration_type: "github_app"} = _adapter, _request) do
    fail_with(:precondition, "Fork action doesn't work with Github Apps.")
  end

  def execute(%GithubAdapter{integration_type: "github_oauth_token"} = adapter, request) do
    with {:ok, git_repository} <- Model.GitRepository.new(request.url),
         {:ok, github_token} <- GithubAdapter.token(adapter, request.user_id, git_repository),
         {:ok, github_repository} <- get_github_repository(git_repository, github_token),
         {:ok, forked_repository} <- fork_repository(git_repository, github_token),
         {:ok, remote_repository} <- build_remote_repository(github_repository, forked_repository) do
      %ForkResponse{remote_repository: remote_repository}
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
          error_message: "Only github urls are allowed."
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

  defp get_github_repository(git_repository, github_token) do
    GithubClient.find_repository(
      %{
        repo_owner: git_repository.owner,
        repo_name: git_repository.repo
      },
      token: github_token
    )
  end

  defp fork_repository(git_repository, github_token) do
    GithubClient.fork(
      %{
        repo_owner: git_repository.owner,
        repo_name: git_repository.repo
      },
      token: github_token
    )
  end

  defp build_remote_repository(github_repository, forked_repository) do
    %RemoteRepository{
      id: "",
      name: github_repository.name,
      description: github_repository.description,
      url: forked_repository.url,
      full_name: github_repository.full_name,
      addable: true,
      reason: ""
    }
    |> wrap()
  end
end
