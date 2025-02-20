defimpl RepositoryHub.Server.CreateAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.{
    GithubAdapter,
    GithubClient,
    Validator,
    Toolkit,
    UniversalAdapter,
    Model,
    UserClient
  }

  alias Model.{
    RepositoryQuery,
    Repositories,
    GitRepository
  }

  alias InternalApi.Repository.CreateResponse

  import Toolkit
  @impl true
  def execute(adapter, request) do
    with {:ok, git_repository} <- GitRepository.new(request.repository_url),
         {:ok, github_token} <- GithubAdapter.token(adapter, request.user_id, git_repository),
         {:ok, github_repository} <- get_github_repository(git_repository, github_token),
         {:ok, permissions} <- get_permissions(adapter, github_repository, request.user_id, github_token),
         {:ok, _} <- valid?(adapter, github_repository, request.only_public, permissions),
         {:ok, repository} <- insert_repository(adapter, request, git_repository, github_repository),
         grpc_repository <- Repositories.to_grpc_model(repository) do
      %CreateResponse{repository: grpc_repository}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      chain: [
        all: [
          chain: [{:from!, :project_id}, :is_uuid],
          chain: [{:from!, :user_id}, :is_uuid],
          chain: [{:from!, :only_public}, check: &is_boolean/1],
          chain: [{:from!, :integration_type}, :is_github_integration_type],
          chain: [{:from!, :repository_url}, :is_github_url]
        ]
      ]
    )
  end

  defp valid?(adapter, github_repository, only_public?, permissions) do
    with {:ok, _} <- permissions_ok?(github_repository, adapter, permissions),
         {:ok, _} <- visiblity_ok?(github_repository, only_public?) do
      wrap(:ok)
    else
      error -> error
    end
  end

  defp visiblity_ok?(github_repository, only_public?) do
    if only_public? and github_repository.is_private? do
      error("Only public repositories can be added for open source organizations")
    else
      github_repository
    end
    |> wrap()
  end

  defp permissions_ok?(github_repository, adapter, permissions) do
    %{"admin" => with_admin_access?, "push" => with_write_access?} = permissions

    adapter
    |> case do
      %GithubAdapter{integration_type: "github_oauth_token"} when with_admin_access? ->
        github_repository

      %GithubAdapter{integration_type: "github_app"} when with_write_access? ->
        github_repository

      %GithubAdapter{integration_type: "github_oauth_token"} ->
        """
        Permission check failed for repository:
        #{inspect(github_repository)}
        """
        |> log(level: :debug)

        error("Admin permissions are required on the repository to add the project to Semaphore")

      %GithubAdapter{integration_type: "github_app"} ->
        """
        Permission check failed for repository:
        #{inspect(github_repository)}
        """
        |> log(level: :debug)

        error("Write permissions are required on the repository to add the project to Semaphore")
    end
    |> wrap()
  end

  defp get_permissions(%{integration_type: "github_oauth_token"}, repo, _, _),
    do: repo.permissions |> wrap

  defp get_permissions(%{integration_type: "github_app"}, repo, user_id, github_token) do
    {:ok, [username | _]} = UserClient.get_repository_provider_logins(:GITHUB, user_id)

    GithubClient.repository_permissions(
      %{
        repo_owner: repo.owner,
        repo_name: repo.name,
        username: username
      },
      token: github_token
    )
  end

  defp insert_repository(adapter, request, git_repository, github_repository) do
    RepositoryQuery.insert(
      %{
        project_id: request.project_id,
        pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
        commit_status: UniversalAdapter.fetch_commit_status(request),
        whitelist: UniversalAdapter.fetch_whitelist_settings(request),
        name: git_repository.repo,
        owner: git_repository.owner,
        private: github_repository.is_private?,
        provider: github_repository.provider,
        integration_type: adapter.integration_type,
        url: git_repository.ssh_git_url,
        default_branch: github_repository.default_branch,
        remote_id: github_repository.id
      },
      on_conflict: :nothing
    )
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
end
