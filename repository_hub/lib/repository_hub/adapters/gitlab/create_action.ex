defimpl RepositoryHub.Server.CreateAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{
    GitlabAdapter,
    GitlabClient,
    Toolkit,
    Validator,
    UniversalAdapter,
    Model
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
    alias Ecto.Multi

    Multi.new()
    |> Multi.run(:git_repository, fn _repo, _context ->
      GitRepository.from_gitlab(request.repository_url)
    end)
    |> Multi.run(:gitlab_token, fn _repo, _context ->
      GitlabAdapter.fetch_token(request.user_id)
    end)
    |> Multi.run(:gitlab_repository, fn _repo, context ->
      GitlabClient.find_repository(
        %{
          repo_owner: context.git_repository.owner,
          repo_name: context.git_repository.repo
        },
        token: context.gitlab_token
      )
    end)
    |> Multi.run(:valid?, fn _repo, context ->
      valid?(adapter, context.gitlab_repository, request.only_public)
    end)
    |> Multi.run(:repository, fn _repo, context ->
      RepositoryQuery.insert(
        %{
          project_id: request.project_id,
          pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
          commit_status: UniversalAdapter.fetch_commit_status(request),
          whitelist: UniversalAdapter.fetch_whitelist_settings(request),
          name: context.git_repository.repo,
          owner: context.git_repository.owner,
          private: context.gitlab_repository.is_private?,
          provider: context.gitlab_repository.provider,
          integration_type: adapter.integration_type,
          url: context.git_repository.ssh_git_url,
          default_branch: context.gitlab_repository.default_branch,
          remote_id: context.gitlab_repository.id
        },
        on_conflict: :nothing
      )
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      repository = Repositories.to_grpc_model(context.repository)

      %CreateResponse{repository: repository}
      |> wrap()
    end)
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
          chain: [{:from!, :integration_type}, :is_gitlab_integration_type],
          chain: [{:from!, :repository_url}, :is_gitlab_url]
        ]
      ]
    )
  end

  defp valid?(adapter, gitlab_repository, only_public?) do
    with {:ok, _} <- permissions_ok?(gitlab_repository, adapter),
         {:ok, _} <- visiblity_ok?(gitlab_repository, only_public?) do
      wrap(:ok)
    else
      error -> error
    end
  end

  defp visiblity_ok?(gitlab_repository, only_public?) do
    if only_public? and gitlab_repository.is_private? do
      error("Only public repositories can be added for open source organizations")
    else
      gitlab_repository
    end
    |> wrap()
  end

  defp permissions_ok?(gitlab_repository, adapter) do
    with_admin_access? = gitlab_repository.with_admin_access?

    adapter
    |> case do
      %GitlabAdapter{integration_type: "gitlab"} when with_admin_access? ->
        gitlab_repository

      _ ->
        """
        Permission check failed for repository:
        #{inspect(gitlab_repository)}
        """
        |> log(level: :debug)

        error("Admin permissions are required on the repository to add the project to Semaphore")
    end
    |> wrap()
  end
end
