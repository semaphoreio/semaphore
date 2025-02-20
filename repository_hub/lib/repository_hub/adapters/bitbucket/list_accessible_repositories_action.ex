defimpl RepositoryHub.Server.ListAccessibleRepositoriesAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    BitbucketClient,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.ListAccessibleRepositoriesResponse
  import Toolkit

  @impl true
  def execute(_adapter, request) do
    request.user_id
    |> BitbucketAdapter.fetch_token()
    |> unwrap(fn github_token ->
      BitbucketClient.list_repositories(
        %{
          query: build_query(request),
          page_token: request.page_token
        },
        token: github_token
      )
    end)
    |> unwrap(fn paged_result ->
      next_page_token = BitbucketAdapter.next_page_token(paged_result)
      {build_repositories(paged_result), next_page_token}
    end)
    |> unwrap(fn {remote_repositories, next_page_token} ->
      %ListAccessibleRepositoriesResponse{
        repositories: remote_repositories,
        next_page_token: next_page_token
      }
      |> wrap()
    end)
  end

  defp build_query(%{only_public: true}), do: "repository.is_private=false"
  defp build_query(_), do: ""

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, :is_bitbucket_integration_type],
        chain: [{:from!, :page_token}, :is_string]
      ]
    )
  end

  defp build_repositories(%{"values" => results} = _response) do
    results
    |> Enum.map(fn
      %{
        "permission" => permission,
        "repository" => %{
          "uuid" => repository_uuid,
          "full_name" => full_name,
          "name" => name
          # "links" => %{"clone" => clone_urls}
        }
      } ->
        repo_name =
          full_name
          |> String.split("/")
          |> List.last(name)

        %InternalApi.Repository.RemoteRepository{
          id: repository_uuid,
          name: repo_name,
          description: "",
          url: "git://bitbucket.org/#{full_name}.git",
          full_name: full_name,
          addable: map_addable(permission),
          reason: map_reason(permission)
        }
    end)
  end

  defp map_addable("owner"), do: true
  defp map_addable("admin"), do: true
  defp map_addable(_), do: false

  defp map_reason("owner"), do: ""
  defp map_reason("admin"), do: ""
  defp map_reason(_), do: "You need admin access to the reposiotry"
end
