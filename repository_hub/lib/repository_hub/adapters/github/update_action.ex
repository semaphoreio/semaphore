defimpl RepositoryHub.Server.UpdateAction, for: RepositoryHub.GithubAdapter do
  # credo:disable-for-this-file

  alias RepositoryHub.{
    GithubAdapter,
    Toolkit,
    Validator,
    Model,
    UniversalAdapter,
    GithubConnector
  }

  alias Ecto.Multi

  alias InternalApi.Repository.UpdateResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, adapter_context} <- GithubAdapter.context(adapter, request.repository_id),
         {:ok, target_git_repository} <- Model.GitRepository.from_github(request.url),
         {:ok, target_token} <-
           GithubAdapter.token(adapter, adapter_context.project.metadata.owner_id, target_git_repository),
         {:ok, connector} <- GithubConnector.setup(adapter_context.repository.id, adapter_context.github_token),
         {:ok, change} <- GithubConnector.prepare_url_change(connector, request.url, target_token, request.user_id) do
      Multi.new()
      |> Multi.run(:repository, fn _repo, _context ->
        GithubConnector.apply_url_change(change)
      end)
      |> Multi.run(:updated_repository, fn _repo, context ->
        params =
          %{
            pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
            commit_status: UniversalAdapter.fetch_commit_status(request),
            whitelist: UniversalAdapter.fetch_whitelist_settings(request)
          }
          |> with_github_app_switch?(adapter, request)

        context.repository
        |> Model.RepositoryQuery.update(
          params,
          returning: true
        )
        |> unwrap(&Model.Repositories.to_grpc_model/1)
        |> wrap()
      end)
      |> commit(change)
    end
  end

  defp commit(multi, change) do
    case transaction(multi, change) do
      {:ok, repository} ->
        GithubConnector.remove_github_resources(change.old_resources)
        %UpdateResponse{repository: repository}

      error ->
        GithubConnector.remove_github_resources(change.created)
        error
    end
  end

  defp transaction(multi, change) do
    RepositoryHub.Repo.transaction(multi)
    |> unwrap(&wrap(&1.updated_repository))
  rescue
    error ->
      case committed_repository(change) do
        {:ok, repository} ->
          wrap(Model.Repositories.to_grpc_model(repository))

        _ ->
          GithubConnector.remove_github_resources(change.created)
          reraise error, __STACKTRACE__
      end
  end

  defp committed_repository(%{created: %{hook_id: hook_id}} = change) when not is_nil(hook_id) do
    Model.RepositoryQuery.get_by_id(change.connector.repository.id)
    |> unwrap(fn repository ->
      if to_string(repository.hook_id) == to_string(hook_id),
        do: wrap(repository),
        else: error(:not_committed)
    end)
  end

  defp committed_repository(_change), do: error(:not_committed)

  def with_github_app_switch?(params, adapter, request) do
    if adapter.integration_type == "github_oauth_token" and
         request.integration_type == :GITHUB_APP do
      params
      |> Map.put(:integration_type, "github_app")
    else
      params
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [
          {:from!, :url},
          any: [:is_github_url],
          error_message: "only github urls are allowed"
        ]
      ]
    )
  end
end
