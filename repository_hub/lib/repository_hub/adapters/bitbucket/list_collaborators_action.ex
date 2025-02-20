defimpl RepositoryHub.Server.ListCollaboratorsAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    BitbucketClient,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.ListCollaboratorsResponse
  import Toolkit

  @impl true
  def execute(adapter, request, _stream) do
    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn context ->
      BitbucketClient.list_repository_collaborators(
        %{
          repo_owner: context.repository.owner,
          repo_name: context.repository.name,
          page_token: request.page_token
        },
        token: context.bitbucket_token
      )
    end)
    |> unwrap(fn paged_result ->
      next_page_token = BitbucketAdapter.next_page_token(paged_result)
      {build_collaborators(paged_result), next_page_token}
    end)
    |> unwrap(fn {collaborators, next_page_token} ->
      %ListCollaboratorsResponse{collaborators: collaborators, next_page_token: next_page_token}
      |> wrap()
    end)
  end

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

  defp build_collaborators(%{"values" => results} = _response) do
    results
    |> Enum.map(fn %{
                     "permission" => permission,
                     "user" => %{
                       "uuid" => user_uuid,
                       "nickname" => nickname
                     }
                   } ->
      permission =
        permission
        |> case do
          "admin" -> :ADMIN
          "write" -> :WRITE
          "read" -> :READ
        end

      %InternalApi.Repository.Collaborator{
        id: user_uuid,
        login: nickname,
        permission: permission
      }
    end)
  end
end
