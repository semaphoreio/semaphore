defmodule Rbac.Api.Repository do
  def fetch_collaborators(repository_id) do
    Watchman.benchmark("fetch_collaborators.duration", fn ->
      fetch_collaborators_(repository_id, [], nil)
    end)
  end

  defp fetch_collaborators_(_, list, "") do
    {:ok, map_collaborators(list)}
  end

  defp fetch_collaborators_(repository_id, list, page_token) do
    case fetch_collaborators_request(repository_id, page_token || "") do
      {:ok, {collaborators, next_page_token}} ->
        fetch_collaborators_(repository_id, list ++ collaborators, next_page_token)

      error ->
        error
    end
  end

  defp fetch_collaborators_request(repository_id, page_token) do
    req =
      %InternalApi.Repository.ListCollaboratorsRequest{
        repository_id: repository_id,
        page_token: page_token
      }

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:rbac, :repositoryhub_grpc_endpoint))

    case InternalApi.Repository.RepositoryService.Stub.list_collaborators(channel, req,
           timeout: 30_000
         ) do
      {:ok, res} ->
        {:ok, {res.collaborators, res.next_page_token}}

      {:error, %{status: 2, message: message}} ->
        {:error, message}

      {:error, %{status: 5, message: message}} ->
        {:skip, message}

      {:error, %{status: 9, message: message}} ->
        {:skip, message}

      error ->
        error
    end
  end

  defp map_collaborators(collaborators) when is_list(collaborators),
    do: Enum.map(collaborators, fn c -> map_collaborators(c) end)

  defp map_collaborators(collaborator) do
    %{
      "id" => collaborator.id,
      "login" => collaborator.login,
      "permissions" => map_permission(collaborator.permission)
    }
  end

  defp map_permission(permission) do
    %{
      "admin" => with_admin?(permission),
      "push" => with_push?(permission),
      "pull" => with_pull?(permission)
    }
  end

  def with_admin?(:ADMIN), do: true
  def with_admin?(_), do: false

  def with_push?(:ADMIN), do: true
  def with_push?(:WRITE), do: true
  def with_push?(_), do: false

  def with_pull?(_), do: true
end
