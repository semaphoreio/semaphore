defimpl RepositoryHub.Server.CreateBuildStatusAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, GithubClient, GithubChecksClient}
  alias InternalApi.Repository.CreateBuildStatusResponse

  import Toolkit

  @impl true
  def execute(adapter, request) do
    with {:ok, context} <- GithubAdapter.context(adapter, request.repository_id),
         {:ok, _} <- report_build_status(adapter, request, context) do
      %CreateBuildStatusResponse{code: :OK} |> wrap()
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
        chain: [{:from!, :url}, :is_url],
        chain: [{:from!, :description}, :is_string, :is_not_empty],
        chain: [{:from!, :context}, :is_string, :is_not_empty]
      ]
    )
  end

  defp valid_statuses, do: [:SUCCESS, :PENDING, :FAILURE, :STOPPED]

  defp from_grpc_status(status) do
    status
    |> case do
      :SUCCESS ->
        "success"

      :PENDING ->
        "pending"

      :FAILURE ->
        "failure"

      :STOPPED ->
        "error"
    end
  end

  defp create_build_status(request, repository, github_token) do
    GithubClient.create_build_status(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name,
        commit_sha: request.commit_sha,
        status: from_grpc_status(request.status),
        url: request.url,
        context: request.context,
        description: request.description
      },
      token: github_token
    )
  end

  defp report_build_status(%{integration_type: "github_app"}, request, context) do
    if FeatureProvider.feature_enabled?(:github_checks_api, param: context.project.metadata.owner_id) do
      report_via_check_run(request, context)
    else
      create_build_status(request, context.repository, context.github_token)
    end
  end

  defp report_build_status(_adapter, request, context) do
    create_build_status(request, context.repository, context.github_token)
  end

  defp report_via_check_run(request, context) do
    repo_owner = context.repository.owner
    repo_name = context.repository.name

    existing =
      GithubChecksClient.find_check_run(
        %{
          repo_owner: repo_owner,
          repo_name: repo_name,
          commit_sha: request.commit_sha,
          name: request.context
        },
        token: context.github_token
      )

    request.status
    |> upsert_check_run(existing, request, context)
    |> record_check_run(repo_owner, repo_name, request.context)
  end

  defp upsert_check_run(:PENDING, {:ok, %{"id" => id, "status" => status}}, request, context)
       when status != "completed" do
    GithubChecksClient.update_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        check_run_id: id,
        status: "in_progress",
        details_url: request.url
      },
      token: context.github_token
    )
  end

  defp upsert_check_run(:PENDING, _existing, request, context) do
    GithubChecksClient.create_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        name: request.context,
        head_sha: request.commit_sha,
        status: "in_progress",
        details_url: request.url
      },
      token: context.github_token
    )
  end

  defp upsert_check_run(terminal, {:ok, %{"id" => id}}, request, context) do
    GithubChecksClient.update_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        check_run_id: id,
        status: "completed",
        conclusion: check_run_conclusion(terminal),
        details_url: request.url
      },
      token: context.github_token
    )
  end

  defp upsert_check_run(terminal, _existing, request, context) do
    GithubChecksClient.create_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        name: request.context,
        head_sha: request.commit_sha,
        status: "completed",
        conclusion: check_run_conclusion(terminal),
        details_url: request.url
      },
      token: context.github_token
    )
  end

  defp record_check_run({:ok, _} = result, _repo_owner, _repo_name, _name) do
    Watchman.increment("set_check_run.success")
    result
  end

  defp record_check_run({:error, _} = result, repo_owner, repo_name, name) do
    log_error("GitHub Checks API write failed for #{repo_owner}/#{repo_name} #{name}")
    Watchman.increment("set_check_run.failure")
    result
  end

  defp check_run_conclusion(:SUCCESS), do: "success"
  defp check_run_conclusion(:FAILURE), do: "failure"
  defp check_run_conclusion(:STOPPED), do: "cancelled"
end
