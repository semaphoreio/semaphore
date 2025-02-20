defimpl RepositoryHub.Server.ListAccessibleRepositoriesAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Toolkit, Validator}
  alias InternalApi.Repository.{ListAccessibleRepositoriesResponse, RemoteRepository}
  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, gitlab_token} <- GitlabAdapter.fetch_token(request.user_id),
         {:ok, response} <-
           GitlabClient.list_repositories(
             %{
               page_token: request.page_token,
               only_public?: request.only_public
             },
             token: gitlab_token
           ) do
      %ListAccessibleRepositoriesResponse{
        repositories: Enum.map(response.items, &build_repository/1),
        next_page_token: response.next_page_token
      }
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :user_id}, :is_uuid],
        chain: [{:from!, :integration_type}, :is_gitlab_integration_type],
        chain: [{:from!, :page_token}, :is_string]
      ]
    )
  end

  defp build_repository(%{} = repository) do
    project_access =
      get_in(repository, ["permissions", "project_access", "access_level"])
      |> GitlabClient.Permissions.admin?()

    group_access =
      get_in(repository, ["permissions", "group_access", "access_level"])
      |> GitlabClient.Permissions.admin?()

    admin_access = project_access || group_access

    %RemoteRepository{
      id: repository["id"] |> Integer.to_string(),
      name: repository["path"],
      description: repository["description"],
      url: repository["ssh_url_to_repo"],
      full_name: repository["path_with_namespace"],
      addable: admin_access,
      reason: map_reason(admin_access)
    }
  end

  defp map_reason(false), do: "You need Owner access to the reposiotry"
  defp map_reason(true), do: ""
end
