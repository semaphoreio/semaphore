defimpl RepositoryHub.Server.ListCollaboratorsAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, GithubClient}

  alias InternalApi.Repository.ListCollaboratorsResponse

  import Toolkit

  @impl true
  def execute(adapter, request, stream) do
    with {:ok, context} <- GithubAdapter.context(adapter, request.repository_id, stream),
         {:ok, {collaborators, headers}} <-
           get_collaborators(request, context.repository, context.github_token, context.etag),
         grpc_collaborators <- build_collaborators(collaborators) do
      set_headers(stream, headers)

      %ListCollaboratorsResponse{
        collaborators: grpc_collaborators,
        next_page_token: ""
      }
      |> wrap()
    end
  end

  defp build_collaborators(collaborators) do
    collaborators
    |> Enum.map(fn collaborator ->
      permission =
        collaborator["permissions"]
        |> case do
          %{"admin" => true} -> :ADMIN
          %{"push" => true} -> :WRITE
          %{"pull" => true} -> :READ
        end

      %InternalApi.Repository.Collaborator{
        id: "#{collaborator["id"]}",
        login: collaborator["login"],
        permission: permission
      }
    end)
  end

  defp get_collaborators(request, repository, github_token, etag) do
    GithubClient.list_repository_collaborators(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name,
        page_token: request.page_token
      },
      token: github_token,
      etag: etag
    )
  end

  defp set_headers(stream, headers) do
    set_no_content_header(stream, headers)
    set_etag_header(stream, headers)
  end

  defp set_etag_header(stream, etag: etag),
    do: GRPC.Server.set_headers(stream, %{"etag" => etag})

  defp set_etag_header(_, _), do: nil

  defp set_no_content_header(stream, no_content: true),
    do: GRPC.Server.set_headers(stream, %{"x-semaphore-status" => "no-content"})

  defp set_no_content_header(_, _), do: nil

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :page_token}, :is_string]
      ]
    )
  end
end
