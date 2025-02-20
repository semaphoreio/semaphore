defimpl RepositoryHub.Server.DescribeManyAction, for: RepositoryHub.UniversalAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.Model.{Repositories, RepositoryQuery}
  alias InternalApi.Repository.DescribeManyResponse

  import Toolkit

  @impl true
  def execute(_adapter, request) do
    %{
      id: Map.get(request, :repository_ids, []),
      project_id: Map.get(request, :project_ids, [])
    }
    |> filter_repositories()
    |> unwrap(fn repositories ->
      repositories
      |> Enum.map(&Repositories.to_grpc_model/1)
      |> wrap()
    end)
    |> unwrap(fn repositories ->
      %DescribeManyResponse{repositories: repositories}
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_ids}, check: &all_uids/1],
        chain: [{:from!, :project_ids}, check: &all_uids/1]
      ]
    )
  end

  defp all_uids(ids) do
    any_errors? =
      ids
      |> Enum.any?(fn v ->
        r = RepositoryHub.BaseValidator.select(:is_uuid).(v, [])

        r
        |> case do
          {:error, _} -> true
          _ -> false
        end
      end)

    not any_errors?
  end

  defp filter_repositories(params) do
    RepositoryQuery.filter(params)
  end
end
