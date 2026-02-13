defimpl RepositoryHub.Server.DescribeRemoteRepositoryAction, for: RepositoryHub.GitlabAdapter do
  alias RepositoryHub.{
    GitlabAdapter,
    GitlabClient,
    Toolkit,
    Validator,
    Model.GitRepository
  }

  alias InternalApi.Repository.DescribeRemoteRepositoryResponse
  import Toolkit

  @impl true
  def execute(_adapter, request) do
    with {:ok, git_repository} <- GitRepository.from_gitlab(request.url),
         {:ok, gitlab_token} <- GitlabAdapter.fetch_token(request.user_id),
         {:ok, repository} <-
           GitlabClient.find_repository(
             %{
               repo_owner: git_repository.owner,
               repo_name: git_repository.repo
             },
             token: gitlab_token
           ) do
      addable = repository.with_admin_access?

      reason =
        if repository.with_admin_access? do
          ""
        else
          "The user does not have admin access to this repository."
        end

      %DescribeRemoteRepositoryResponse{
        remote_repository: %InternalApi.Repository.RemoteRepository{
          id: repository.id,
          name: repository.name,
          description: repository.description,
          url: repository.web_url,
          full_name: repository.full_name,
          addable: addable,
          reason: reason
        }
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
        chain: [
          {:from!, :url},
          any: [:is_gitlab_url],
          error_message: "only gitlab urls are allowed"
        ]
      ]
    )
  end
end
