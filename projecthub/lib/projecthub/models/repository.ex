defmodule Projecthub.Models.Repository do
  alias Projecthub.RepositoryHubClient
  alias __MODULE__
  import Toolkit

  defmodule SQL do
    # Added temporarily for filtering projects by urls
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id
    schema "repositories" do
      belongs_to(:project, Projecthub.Models.Project)

      field(:hook_id, :string)
      field(:name, :string)
      field(:owner, :string)
      field(:private, :boolean)
      field(:provider, :string)
      field(:integration_type, :string)
      field(:default_branch, :string)
      field(:connected, :boolean)
      field(:url, :string)
      field(:pipeline_file, :string, default: ".semaphore/semaphore.yml")
      field(:commit_status, :map)
      field(:whitelist, :map)
      field(:created_at, :utc_datetime)
      field(:updated_at, :utc_datetime)
    end
  end

  defstruct [
    :id,
    :name,
    :owner,
    :private,
    :provider,
    :url,
    :project_id,
    :pipeline_file,
    :integration_type,
    :commit_status,
    :whitelist,
    :default_branch,
    :hook_id
  ]

  @type t() :: %Repository{
          id: Ecto.UUID.t(),
          name: String.t(),
          owner: String.t(),
          private: boolean(),
          provider: String.t(),
          url: String.t(),
          project_id: Ecto.UUID.t(),
          pipeline_file: String.t(),
          integration_type: InternalApi.RepositoryIntegrator.IntegrationType.t(),
          commit_status: InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          whitelist: InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t(),
          hook_id: String.t()
        }

  @type create_params() :: %{
          :commit_status => InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          :integration_type => :BITBUCKET | :GITHUB_APP | :GITHUB_OAUTH_TOKEN | integer,
          :only_public => boolean,
          :pipeline_file => binary,
          :project_id => binary,
          :repository_url => binary,
          :user_id => binary,
          :whitelist => InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t(),
          optional(any) => any
        }

  @type update_params() :: %{
          optional(:integration_type) => InternalApi.RepositoryIntegrator.IntegrationType.t(),
          optional(:url) => String.t(),
          optional(:pipeline_file) => String.t(),
          optional(:commit_status) => InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          optional(:whitelist) => InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t()
        }

  @spec create(create_params) :: Toolkit.maybe_result(InternalApi.Repository.Repository.t())
  def create(params) do
    params = %{
      project_id: params.project_id,
      request_id: Map.get(params, :request_id, ""),
      user_id: params.user_id,
      pipeline_file: params.pipeline_file,
      repository_url: params.repository_url,
      only_public: params.only_public,
      integration_type: params.integration_type,
      commit_status: params.commit_status,
      whitelist: params.whitelist
    }

    params
    |> RepositoryHubClient.create()
    |> unwrap_with_repository()
  end

  @spec update(t(), update_params()) :: Toolkit.maybe_result(t())
  def update(repository, params) do
    params =
      %{
        repository_id: repository.id,
        url: repository.url,
        pipeline_file: repository.pipeline_file,
        commit_status: repository.commit_status,
        whitelist: repository.whitelist,
        integration_type: repository.integration_type
      }
      |> Map.merge(params)

    params
    |> RepositoryHubClient.update()
    |> unwrap_with_repository()
  end

  def destroy(repository) do
    RepositoryHubClient.delete(%{repository_id: repository.id})
    |> unwrap_with_repository()
  end

  def clear_external_data(repository) do
    RepositoryHubClient.clear_external_data(%{repository_id: repository.id})
    |> unwrap_with_repository()
  end

  def find_for_project(project_id) do
    RepositoryHubClient.describe_many(%{project_ids: [project_id]})
    |> unwrap(fn
      %{repositories: [repository | _]} ->
        wrap(repository)

      _ ->
        error("failed to find repository for project")
    end)
    |> unwrap(&from_grpc/1)
  end

  def find_for_project_ids(project_ids) do
    project_ids_chunks =
      project_ids
      |> Enum.chunk_every(50)

    {:ok, stream_supervisor} = Task.Supervisor.start_link()

    stream_supervisor
    |> Task.Supervisor.async_stream(
      project_ids_chunks,
      fn project_ids ->
        {:ok, %{repositories: repositories}} = RepositoryHubClient.describe_many(%{project_ids: project_ids})

        repositories
      end,
      ordered: false,
      max_concurrency: 2
    )
    |> Enum.to_list()
    |> Enum.flat_map(&unwrap!/1)
    |> Enum.map(fn repository ->
      repository
      |> from_grpc()
      |> unwrap!
    end)
  end

  defp unwrap_with_repository(response) do
    response
    |> unwrap(fn
      %{repository: repository} ->
        wrap(repository)

      other ->
        error("can't unwrap repository from #{inspect(other)}")
    end)
    |> unwrap(&from_grpc/1)
    |> wrap()
  end

  @spec from_grpc(any()) :: Toolkit.maybe_result(t())
  def from_grpc(%InternalApi.Repository.Repository{} = message) do
    %Repository{
      id: message.id,
      name: message.name,
      owner: message.owner,
      private: message.private,
      provider: message.provider,
      url: message.url,
      project_id: message.project_id,
      pipeline_file: message.pipeline_file,
      integration_type: message.integration_type,
      commit_status: message.commit_status,
      whitelist: message.whitelist,
      hook_id: message.hook_id,
      default_branch: message.default_branch
    }
    |> wrap()
  end

  def from_grpc(other) do
    error("can't convert to a #{__MODULE__} from #{inspect(other)}")
  end
end
