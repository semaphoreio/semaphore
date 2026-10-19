defimpl RepositoryHub.Server.CreateBuildStatusAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{GithubAdapter, GithubAppId, GithubClient, GithubChecksClient}
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

  # Known rollout gap, accepted: the API is chosen per request, so a pipeline
  # running while the flag or the installation's Checks permission changes
  # can send its PENDING as a commit status and its result as a check-run
  # (or the reverse). The same-named pending commit status then stays on the
  # commit and can keep a required check pending until the next push.
  defp report_build_status(%{integration_type: "github_app"}, request, context) do
    case checks_api_enabled?(context) do
      {:ok, true} ->
        request
        |> report_via_check_run(context)
        |> fallback_to_status_when_checks_forbidden(request, context)

      {:ok, false} ->
        create_build_status(request, context.repository, context.github_token)

      error ->
        error
    end
  end

  defp report_build_status(_adapter, request, context) do
    create_build_status(request, context.repository, context.github_token)
  end

  # A flag that can't be evaluated fails the request so the notifier retries.
  # Reading it as "disabled" would send this status as a commit status while
  # the pipeline's earlier ones went out as a check-run, leaving the run
  # in_progress. Only a flag that doesn't exist counts as disabled: a provider
  # failure behind the cache also comes back as {:not_found, {fun, org_id}}.
  defp checks_api_enabled?(context) do
    org_id = context.project.metadata.org_id

    case FeatureProvider.find_feature(:github_checks_api, param: org_id) do
      {:ok, feature} ->
        {:ok, FeatureProvider.Feature.enabled?(feature)}

      {:error, {:not_found, :github_checks_api}} ->
        {:ok, false}

      {:error, reason} ->
        Watchman.increment("set_check_run.flag_unavailable")

        log_error([
          "Can't evaluate the github_checks_api feature flag",
          "org_id: #{org_id}",
          "project_id: #{context.project.metadata.id}",
          "reason: #{inspect(reason)}"
        ])

        fail_with(:unavailable, "Can't evaluate the github_checks_api feature flag")
    end
  end

  # An installation without the Checks permission gets a 403 on every call.
  # Nothing was written, so report through the Commit Status API instead.
  defp fallback_to_status_when_checks_forbidden({:error, %{status: status}} = error, request, context) do
    if status == GRPC.Status.permission_denied() do
      Watchman.increment("set_check_run.fallback_to_status")

      log_warn([
        "GitHub App installation is missing the Checks permission, falling back to commit status",
        "org_id: #{context.project.metadata.org_id}",
        "project_id: #{context.project.metadata.id}",
        "repo: #{context.repository.owner}/#{context.repository.name}"
      ])

      create_build_status(request, context.repository, context.github_token)
    else
      error
    end
  end

  defp fallback_to_status_when_checks_forbidden(result, _request, _context), do: result

  defp report_via_check_run(request, context) do
    result =
      with {:ok, app_id} <- GithubAppId.get(),
           {:ok, existing} <- find_existing_check_run(request, context, app_id) do
        upsert_check_run(request, existing, context)
      end

    record_check_run(result, request, context)
  end

  # Only a confirmed "no such run" means create. Any other lookup failure must
  # fail the request, otherwise we'd create a duplicate run.
  defp find_existing_check_run(request, context, app_id) do
    not_found = GRPC.Status.not_found()

    GithubChecksClient.find_check_run(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: request.commit_sha,
        name: request.context,
        app_id: app_id,
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

  # The run is this pipeline's own (matched by external_id), so a PENDING
  # after it completed is stale: delivering it would leave a fresh run
  # in_progress with nothing left to complete it. Without a source_id every
  # pipeline shares one external_id, so there the PENDING may be a new
  # pipeline and gets a fresh run (run_to_update/2).
  defp upsert_check_run(%{status: :PENDING, source_id: source_id}, %{"status" => "completed"} = run, _context)
       when source_id != "" do
    Watchman.increment("set_check_run.skipped_stale_pending")
    {:ok, run}
  end

  defp upsert_check_run(request, existing, context) do
    params =
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        details_url: request.url,
        output: %{title: request.description, summary: request.description}
      }
      |> Map.merge(check_run_state(request.status))

    case run_to_update(request.status, existing) do
      nil ->
        params
        |> Map.merge(%{name: request.context, head_sha: request.commit_sha, external_id: external_id(request)})
        |> GithubChecksClient.create_check_run(token: context.github_token)

      id ->
        params
        |> Map.put(:check_run_id, id)
        |> GithubChecksClient.update_check_run(token: context.github_token)
    end
  end

  # A completed run is never reopened: a PENDING after completion without a
  # source_id (possibly another pipeline) starts a fresh run.
  defp run_to_update(:PENDING, %{"status" => "completed"}), do: nil
  defp run_to_update(_status, %{"id" => id}), do: id
  defp run_to_update(_status, nil), do: nil

  defp check_run_state(:PENDING), do: %{status: "in_progress"}
  defp check_run_state(terminal), do: %{status: "completed", conclusion: check_run_conclusion(terminal)}

  defp record_check_run({:ok, _} = result, _request, _context) do
    Watchman.increment("set_check_run.success")
    result
  end

  defp record_check_run({:error, _} = result, request, context) do
    log_error([
      "GitHub Checks API write failed",
      "org_id: #{context.project.metadata.org_id}",
      "project_id: #{context.project.metadata.id}",
      "source_id: #{request.source_id}",
      "repo: #{context.repository.owner}/#{context.repository.name}",
      "context: #{request.context}"
    ])

    Watchman.increment("set_check_run.failure")
    result
  end

  # Ties a run to one pipeline (source_id is the pipeline id), so a rebuild of
  # the same commit gets its own run and one pipeline's result never completes
  # another pipeline's run.
  defp external_id(request), do: "semaphore:#{request.source_id}"

  defp check_run_conclusion(:SUCCESS), do: "success"
  defp check_run_conclusion(:FAILURE), do: "failure"
  defp check_run_conclusion(:STOPPED), do: "cancelled"
end
