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
      request
      |> report_via_check_run(context)
      |> fallback_to_status_when_checks_forbidden(request, context)
    else
      create_build_status(request, context.repository, context.github_token)
    end
  end

  defp report_build_status(_adapter, request, context) do
    create_build_status(request, context.repository, context.github_token)
  end

  # An installation without the Checks permission gets a 403 on every call.
  # Nothing was written, so report through the Commit Status API instead.
  defp fallback_to_status_when_checks_forbidden({:error, %{status: status}} = error, request, context) do
    if status == GRPC.Status.permission_denied() do
      Watchman.increment("set_check_run.fallback_to_status")
      create_build_status(request, context.repository, context.github_token)
    else
      error
    end
  end

  defp fallback_to_status_when_checks_forbidden(result, _request, _context), do: result

  defp report_via_check_run(request, context) do
    repo_owner = context.repository.owner
    repo_name = context.repository.name

    result =
      with :ok <-
             GithubChecksClient.check_rate_limit(%{repo_owner: repo_owner}, token: context.github_token),
           {:ok, existing} <- find_existing_check_run(request, context) do
        upsert_check_run(request.status, existing, request, context)
      end

    record_check_run(result, repo_owner, repo_name, request.context)
  end

  # Only a confirmed "no such run" means create. Any other lookup failure must
  # fail the request, otherwise we'd create a duplicate run.
  defp find_existing_check_run(request, context) do
    not_found = GRPC.Status.not_found()

    GithubChecksClient.find_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: request.commit_sha,
        name: request.context,
        external_id: external_id(request)
      },
      token: context.github_token
    )
    |> case do
      {:ok, run} -> {:ok, run}
      {:error, %{status: ^not_found}} -> {:ok, nil}
      error -> error
    end
  end

  defp upsert_check_run(:PENDING, %{"id" => id, "status" => status}, request, context)
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
        external_id: external_id(request),
        status: "in_progress",
        details_url: request.url
      },
      token: context.github_token
    )
  end

  defp upsert_check_run(terminal, %{"id" => id}, request, context) do
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

  defp upsert_check_run(terminal, nil, request, context) do
    GithubChecksClient.create_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        name: request.context,
        head_sha: request.commit_sha,
        external_id: external_id(request),
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

  # Marks runs as ours and ties them to one pipeline (source_id is the
  # pipeline id), so a rebuild of the same commit gets its own run and one
  # pipeline's result never completes another pipeline's run.
  defp external_id(request), do: "semaphore:#{request.source_id}"

  defp check_run_conclusion(:SUCCESS), do: "success"
  defp check_run_conclusion(:FAILURE), do: "failure"
  defp check_run_conclusion(:STOPPED), do: "cancelled"
end
