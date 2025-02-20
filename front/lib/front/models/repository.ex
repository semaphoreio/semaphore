defmodule Front.Models.Repository do
  defstruct [:name, :description, :url, :owner_name, :owner_avatar, :addable]

  def list_repositories(user_id, integration_type, page_token, open_source) do
    req =
      InternalApi.Repository.ListAccessibleRepositoriesRequest.new(
        user_id: user_id,
        integration_type: map_integratin_type(integration_type),
        page_token: page_token,
        only_public: open_source
      )

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:front, :repositoryhub_grpc_endpoint))

    {:ok, res} =
      InternalApi.Repository.RepositoryService.Stub.list_accessible_repositories(
        channel,
        req,
        timeout: 30_000
      )

    %{
      repos: map_repos(res.repositories),
      next_page_token: res.next_page_token
    }
  end

  defp map_integratin_type("github_oauth_token"),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN)

  defp map_integratin_type("github_app"),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)

  defp map_integratin_type("bitbucket"),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:BITBUCKET)

  defp map_integratin_type("gitlab"),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GITLAB)

  defp map_integratin_type("git"),
    do: InternalApi.RepositoryIntegrator.IntegrationType.value(:GIT)

  defp map_repos(repos) do
    repos
    |> Enum.map(fn repo ->
      %{
        addable: repo.addable,
        name: repo.name,
        description: repo.description,
        url: repo.url,
        full_name: repo.full_name
      }
    end)
  end
end
