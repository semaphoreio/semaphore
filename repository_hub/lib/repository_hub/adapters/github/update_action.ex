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
    with {:ok, adapter_context} <- GithubAdapter.context(adapter, request.repository_id) do
      Multi.new()
      |> Multi.put(:repository, adapter_context.repository)
      |> Multi.put(:github_token, adapter_context.github_token)
      |> Multi.run(:connector, fn _repo, context ->
        GithubConnector.setup(context.repository.id, context.github_token)
      end)
      |> Multi.run(:update_repository_url, fn _repo, context ->
        context.connector
        |> GithubConnector.update_repository_url(request.url)
      end)
      |> Multi.run(:updated_repository, fn _repo, context ->
        params =
          %{
            pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
            commit_status: UniversalAdapter.fetch_commit_status(request),
            whitelist: UniversalAdapter.fetch_whitelist_settings(request)
          }
          |> with_github_app_switch?(adapter, request)

        context.update_repository_url.repository
        |> Model.RepositoryQuery.update(
          params,
          returning: true
        )
        |> unwrap(&Model.Repositories.to_grpc_model/1)
        |> wrap()
      end)
      |> RepositoryHub.Repo.transaction()
      |> unwrap(fn context ->
        %UpdateResponse{repository: context.updated_repository}
      end)
    end
  end

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
