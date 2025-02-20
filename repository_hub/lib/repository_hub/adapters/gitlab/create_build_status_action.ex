defimpl RepositoryHub.Server.CreateBuildStatusAction, for: RepositoryHub.GitlabAdapter do
  require Logger
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GitlabAdapter, GitlabClient}
  alias InternalApi.Repository.CreateBuildStatusResponse
  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GitlabAdapter.context(adapter, request.repository_id),
         {:ok, _status} <- create_status(context.repository, request, context.gitlab_token) do
      %CreateBuildStatusResponse{code: :OK}
      |> wrap()
    end
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :commit_sha}, :is_sha],
        chain: [{:from!, :status}, any: Enum.flat_map(valid_statuses(), &[eq: &1])],
        chain: [{:from!, :context}, :is_string, :is_not_empty],
        chain: [{:from!, :url}, :is_url],
        chain: [{:from!, :description}, :is_string, :is_not_empty]
      ]
    )
  end

  defp create_status(repository, request, gitlab_token) do
    GitlabClient.create_build_status(
      %{
        repository_id: repository.remote_id,
        commit_sha: request.commit_sha,
        state: from_grpc_status(request.status),
        url: request.url,
        context: request.context,
        description: request.description
      },
      token: gitlab_token
    )
  end

  # defp valid_statuses, do: [:SUCCESS, :PENDING, :FAILURE, :STOPPED]
  defp valid_statuses, do: InternalApi.Repository.CreateBuildStatusRequest.Status.mapping() |> Map.keys()

  defp from_grpc_status(status) do
    status
    |> case do
      :SUCCESS ->
        "success"

      :PENDING ->
        "pending"

      :FAILURE ->
        "failed"

      :STOPPED ->
        "canceled"
    end
  end
end
