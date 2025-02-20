defimpl RepositoryHub.Server.UpdateAction, for: RepositoryHub.GitlabAdapter do
  # credo:disable-for-this-file

  alias RepositoryHub.{
    GitlabAdapter,
    Toolkit,
    Validator,
    Model,
    UniversalAdapter,
    OrganizationClient,
    GitlabConnector
  }

  alias Ecto.Multi
  alias InternalApi.Repository.UpdateResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    GitlabAdapter.multi(adapter, request.repository_id)
    |> unwrap(fn multi ->
      multi
      |> Multi.run(:organization, fn _repo, context ->
        OrganizationClient.describe(context.project.metadata.org_id)
        |> unwrap(fn response ->
          wrap(response.organization)
        end)
      end)
      |> Multi.run(:connector, fn _repo, context ->
        GitlabConnector.setup(context.repository.id, context.gitlab_token)
      end)
      |> Multi.run(:update_repository_url, fn _repo, context ->
        context.connector
        |> GitlabConnector.update_repository_url(request.url, context.organization.org_username)
      end)
      |> Multi.run(:updated_repository, fn _repo, context ->
        params = %{
          pipeline_file: UniversalAdapter.fetch_pipeline_file(request),
          commit_status: UniversalAdapter.fetch_commit_status(request),
          whitelist: UniversalAdapter.fetch_whitelist_settings(request)
        }

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
        |> wrap()
      end)
    end)
    |> unwrap_error(fn error ->
      error(error)
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [
          {:from!, :url},
          any: [:is_gitlab_url],
          error_message: "only gitlab urls are allowed"
        ]
      ]
    )
  end
end
