defimpl RepositoryHub.Server.CreateBuildStatusAction, for: RepositoryHub.BitbucketAdapter do
  alias RepositoryHub.{
    BitbucketAdapter,
    BitbucketClient,
    Toolkit,
    Validator
  }

  alias InternalApi.Repository.CreateBuildStatusResponse

  import Toolkit

  @context_character_limit 40

  @impl true
  def execute(adapter, request) do
    alias Ecto.Multi

    adapter
    |> BitbucketAdapter.multi(request.repository_id)
    |> Multi.run(:create_build_status, fn _repo, context ->
      BitbucketClient.create_build_status(
        %{
          repo_owner: context.repository.owner,
          repo_name: context.repository.name,
          commit_sha: request.commit_sha,
          status: from_grpc_status(request.status),
          url: request.url,
          context: truncate_context(request.context),
          description: request.description
        },
        token: context.bitbucket_token
      )
    end)
    |> RepositoryHub.Repo.transaction()
    |> unwrap(fn _ ->
      %CreateBuildStatusResponse{code: :OK}
      |> wrap()
    end)
  end

  @impl true
  def validate(_adapter, request) do
    request
    |> Validator.validate(
      all: [
        chain: [{:from!, :repository_id}, :is_uuid],
        chain: [{:from!, :commit_sha}, :is_sha],
        chain: [{:from!, :status}, any: Enum.flat_map(valid_statuses(), &[eq: &1])],
        chain: [{:from!, :url}, :is_url],
        chain: [{:from!, :description}, :is_string, :is_not_empty],
        chain: [{:from!, :context}, :is_string, :is_not_empty]
      ]
    )
  end

  #
  # BitBucket has a 40-character limit on the context used for the build status.
  #
  defp truncate_context(context) do
    String.slice(context, 0..(@context_character_limit - 1))
  end

  defp valid_statuses, do: [:SUCCESS, :PENDING, :FAILURE, :STOPPED]

  defp from_grpc_status(status) do
    status
    |> case do
      :SUCCESS ->
        "SUCCESSFUL"

      :PENDING ->
        "INPROGRESS"

      :FAILURE ->
        "FAILED"

      :STOPPED ->
        "STOPPED"
    end
  end
end
