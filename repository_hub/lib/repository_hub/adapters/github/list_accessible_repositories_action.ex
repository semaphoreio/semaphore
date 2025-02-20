defimpl RepositoryHub.Server.ListAccessibleRepositoriesAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, GithubClient, Model}

  alias InternalApi.Repository.ListAccessibleRepositoriesResponse

  import Toolkit

  @impl true
  def execute(adapter, request) do
    adapter
    |> fetch_repositories(request)
    |> unwrap(fn {results, next_page_token} ->
      %ListAccessibleRepositoriesResponse{
        repositories: results,
        next_page_token: next_page_token
      }
      |> wrap()
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, check: &valid_integration_type/1],
        chain: [{:from!, :page_token}, :is_string]
      ]
    )
  end

  defp valid_integration_type(status) do
    status in [
      :GITHUB_APP,
      :GITHUB_OAUTH_TOKEN
    ]
  end

  defp fetch_repositories(
         %GithubAdapter{integration_type: "github_oauth_token"} = adapter,
         request
       ) do
    adapter
    |> GithubAdapter.fetch_token_by_user_id(request.user_id)
    |> unwrap(fn github_token ->
      GithubClient.list_repositories(
        %{
          type: map_repositories_type(request),
          page_token: request.page_token
        },
        token: github_token
      )
    end)
    |> unwrap(fn results ->
      {build_github_repositories(results), ""}
    end)
  end

  defp fetch_repositories(%GithubAdapter{integration_type: "github_app"}, request) do
    RepositoryHub.UserClient.get_repository_provider_uids(
      :GITHUB,
      request.user_id
    )
    |> unwrap(fn uids ->
      uids
      |> Enum.map(fn uid -> String.to_integer(uid) end)
      |> Model.GithubAppQuery.list_repositories()
      |> unwrap(fn repositories ->
        {build_db_repositories(repositories), ""}
      end)
    end)
  end

  defp map_repositories_type(%{only_public: true}), do: "public"
  defp map_repositories_type(_), do: "all"

  defp build_db_repositories(results) do
    results
    |> Enum.map(fn github_collaborator ->
      repository_name =
        github_collaborator.r_name
        |> String.split("/")
        |> Enum.drop(1)
        |> Enum.join("-")

      %InternalApi.Repository.RemoteRepository{
        id: github_collaborator.id,
        name: repository_name,
        description: "",
        url: "git://github.com/#{github_collaborator.r_name}.git",
        full_name: github_collaborator.r_name || "",
        addable: true,
        reason: ""
      }
    end)
  end

  defp build_github_repositories(results) do
    results
    |> Enum.map(fn
      %{
        "id" => id,
        "name" => name,
        "full_name" => full_name,
        "git_url" => url,
        "description" => description
      } = repo ->
        %InternalApi.Repository.RemoteRepository{
          id: "#{id}",
          name: name || "",
          description: description || "",
          url: url,
          full_name: full_name || "",
          addable: map_addable(repo),
          reason: map_reason(repo)
        }
    end)
  end

  defp map_addable(repo), do: get_in(repo, ["permissions", "admin"]) || false

  defp map_reason(true), do: ""
  defp map_reason(false), do: "You need admin access to the repository"
  defp map_reason(repo), do: map_reason(map_addable(repo))
end
