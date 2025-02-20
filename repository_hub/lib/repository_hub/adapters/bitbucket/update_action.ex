defimpl RepositoryHub.Server.UpdateAction, for: RepositoryHub.BitbucketAdapter do
  # credo:disable-for-this-file

  alias RepositoryHub.{
    BitbucketAdapter,
    Toolkit,
    Validator,
    OrganizationClient,
    BitbucketConnector,
    UniversalAdapter,
    Model
  }

  alias InternalApi.Repository.UpdateResponse
  alias Ecto.Multi
  import Toolkit

  @impl true
  def execute(adapter, request) do
    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> Multi.run(:organization, fn _repo, context ->
      OrganizationClient.describe(context.project.metadata.org_id)
      |> unwrap(fn response ->
        wrap(response.organization)
      end)
    end)
    |> Multi.run(:connector, fn _repo, context ->
      BitbucketConnector.setup(context.repository.id, context.bitbucket_token)
    end)
    |> Multi.run(:update_repository_url, fn _repo, context ->
      context.connector
      |> BitbucketConnector.update_repository_url(request.url, context.organization.name)
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
          any: [:is_bitbucket_url],
          error_message: "only bitbucket urls are allowed"
        ]
      ]
    )
  end
end
