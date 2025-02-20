defimpl RepositoryHub.Server.ListCollaboratorsAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{GitlabAdapter, GitlabClient, Toolkit, Validator}
  alias InternalApi.Repository.{ListCollaboratorsResponse, Collaborator}
  import Toolkit

  @impl true
  def execute(adapter, request, _stream) do
    with {:ok, context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, response} <-
           GitlabClient.list_repository_collaborators(
             %{
               repository_id: context.repository.remote_id,
               page_token: request.page_token
             },
             token: context.gitlab_token
           ) do
      %ListCollaboratorsResponse{
        collaborators: Enum.map(response.items, &build_collaborator/1),
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
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :page_token}, :is_string]
      ]
    )
  end

  defp build_collaborator(collaborator) do
    %Collaborator{
      id: collaborator["id"] |> Integer.to_string(),
      login: collaborator["username"],
      permission: GitlabClient.Permissions.map_collaborator_role(collaborator["access_level"])
    }
  end
end
