defimpl RepositoryHub.Server.CreateBuildStatusAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.Toolkit
  alias RepositoryHub.Validator

  alias RepositoryHub.{
    CheckRunCache,
    GithubAdapter,
    GithubApi,
    GithubAppId,
    GithubClient,
    GithubChecksClient,
    GithubCommitStatusClient
  }

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

  # The API is chosen per request, so one commit can end up with a check-run
  # and a commit status of the same name: the flag is switched on or off, a
  # FeatureHub outage reads it as off, or a commit is rebuilt after the switch.
  # GitHub requires both to pass, so a stale one blocks the PR. A terminal
  # status therefore also goes to the other API whenever the commit already
  # has a same-named entry there (mirror_to_commit_status/3,
  # mirror_to_check_run/3), and the newest result wins on both.
  defp report_build_status(%{integration_type: "github_app"}, request, context) do
    if checks_api_enabled?(context) do
      context
      |> with_github_client(:create_check_run, fn context ->
        request
        |> report_via_check_run(context)
        |> mirror_to_commit_status(request, context)
      end)
      |> fallback_to_commit_status(request, context)
    else
      request
      |> create_build_status(context.repository, context.github_token)
      |> mirror_to_check_run(request, context)
    end
  end

  defp report_build_status(_adapter, request, context) do
    create_build_status(request, context.repository, context.github_token)
  end

  # A flag that can't be evaluated counts as off, so a FeatureHub outage
  # doesn't stop status delivery for orgs that never had it on. For an org
  # that has it on, the mirroring in report_build_status/3 completes whatever
  # the pipeline already sent as a check-run. A provider failure behind the
  # cache comes back as {:not_found, {fun, org_id}}, not as the flag missing.
  defp checks_api_enabled?(context) do
    org_id = context.project.metadata.org_id

    case FeatureProvider.find_feature(:github_checks_api, param: org_id) do
      {:ok, feature} ->
        FeatureProvider.Feature.enabled?(feature)

      {:error, {:not_found, :github_checks_api}} ->
        false

      {:error, reason} ->
        Watchman.increment("set_check_run.flag_unavailable")

        log_warn([
          "Can't evaluate the github_checks_api feature flag, reporting as a commit status",
          "org_id: #{org_id}",
          "project_id: #{context.project.metadata.id}",
          "reason: #{inspect(reason)}"
        ])

        false
    end
  end

  # Check-run path: the commit got a same-named commit status before the
  # switch (or while the flag couldn't be read), so the result is written
  # there too. A failed lookup or write fails the request: the check-run
  # write is an idempotent update on retry, and only orgs with the flag on
  # get here.
  defp mirror_to_commit_status({:ok, _} = result, %{status: status} = request, context) when status != :PENDING do
    GithubCommitStatusClient.find_commit_status(
      %{
        repo_owner: context.repository.owner,
        repo_name: context.repository.name,
        commit_sha: request.commit_sha,
        context: request.context
      },
      client: context.github_client
    )
    |> case do
      {:ok, _status} ->
        Watchman.increment("set_check_run.mirrored_to_status")

        with {:ok, _} <- create_build_status(request, context.repository, context.github_token) do
          result
        end

      {:error, %{status: status} = error} ->
        if status == GRPC.Status.not_found(), do: result, else: {:error, error}

      error ->
        error
    end
  end

  defp mirror_to_commit_status(result, _request, _context), do: result

  # Commit-status path: the commit has a same-named check-run from Semaphore,
  # left by this pipeline (flag turned off or unreadable mid-pipeline) or an
  # earlier one (a rebuild after the flag was turned off). The result is
  # written to this pipeline's run, created if needed, so it is the newest
  # run of that name. Best effort: the status itself is delivered, and every
  # App repo gets here, so a failure is logged rather than retried.
  defp mirror_to_check_run({:ok, _} = result, %{status: status, source_id: source_id} = request, context)
       when status != :PENDING and source_id != "" do
    case GithubAppId.get() do
      {:ok, app_id} ->
        context
        |> with_github_client(:find_check_run, &write_to_check_run(request, &1, app_id))
        |> log_mirror_failure(request, context)

        result

      # No app id means no check-run was ever created.
      _ ->
        result
    end
  end

  defp mirror_to_check_run(result, _request, _context), do: result

  defp write_to_check_run(request, context, app_id) do
    cache_key = CheckRunCache.key(request, context.repository)
    permission_denied = GRPC.Status.permission_denied()

    with {:ok, run} <- check_run_to_mirror(request, context, app_id, cache_key),
         {:ok, _} = written <- upsert_check_run(request, run, context) do
      remember_check_run(written, cache_key)
      Watchman.increment("set_check_run.mirrored_to_check_run")
      :ok
    else
      :none ->
        :ok

      # The installation can't use the Checks API, so it has no check-runs.
      {:error, %{status: ^permission_denied}} ->
        :ok

      error ->
        CheckRunCache.delete(cache_key)
        error
    end
  end

  defp log_mirror_failure(:ok, _request, _context), do: :ok

  defp log_mirror_failure(error, request, context) do
    Watchman.increment("set_check_run.mirror_failure")

    log_warn([
      "Can't write the build status to the commit's check-run",
      "org_id: #{context.project.metadata.org_id}",
      "project_id: #{context.project.metadata.id}",
      "source_id: #{request.source_id}",
      "repo: #{context.repository.owner}/#{context.repository.name}",
      "context: #{request.context}",
      "reason: #{inspect(error)}"
    ])
  end

  # One rate-limit check for all the GitHub calls of one path: fun gets the
  # context with a checked client, which the Checks and commit-status clients
  # reuse. Every purpose has the same reserve.
  defp with_github_client(context, purpose, fun) do
    GithubApi.with_client(context.github_token, context.repository.owner, purpose, fn client ->
      context |> Map.put(:github_client, client) |> fun.()
    end)
  end

  # {:ok, run} for this pipeline's run, {:ok, nil} when only other pipelines
  # have a same-named run, :none when the commit has none.
  defp check_run_to_mirror(request, context, app_id, cache_key) do
    case CheckRunCache.get(cache_key) do
      {:ok, run} ->
        {:ok, run}

      :miss ->
        params = check_run_lookup_params(request, context, app_id)

        case GithubChecksClient.list_check_runs(params, client: context.github_client) do
          {:ok, []} -> :none
          {:ok, runs} -> runs |> GithubChecksClient.latest_run(params) |> own_run()
          error -> error
        end
    end
  end

  defp own_run({:ok, run}), do: {:ok, run}
  defp own_run({:error, _}), do: {:ok, nil}

  # When the Checks API can't be used at all, a retry wouldn't help and
  # nothing was written, so report through the Commit Status API instead.
  defp fallback_to_commit_status({:error, reason} = error, request, context) do
    case fallback_reason(reason) do
      nil ->
        error

      message ->
        Watchman.increment("set_check_run.fallback_to_status")

        log_warn([
          "#{message}, falling back to commit status",
          "org_id: #{context.project.metadata.org_id}",
          "project_id: #{context.project.metadata.id}",
          "repo: #{context.repository.owner}/#{context.repository.name}"
        ])

        create_build_status(request, context.repository, context.github_token)
    end
  end

  defp fallback_to_commit_status(result, _request, _context), do: result

  # An installation without the Checks permission gets a 403 on every call.
  # Without a GitHub App id, no check-run was ever created for the commit.
  defp fallback_reason(:github_app_id_not_configured), do: "GitHub App id is not configured"

  defp fallback_reason(%{status: status}) do
    if status == GRPC.Status.permission_denied(), do: "GitHub App installation is missing the Checks permission"
  end

  defp fallback_reason(_reason), do: nil

  defp report_via_check_run(request, context) do
    cache_key = CheckRunCache.key(request, context.repository)

    result =
      with {:ok, existing} <- existing_check_run(request, context, cache_key) do
        upsert_check_run(request, existing, context)
      end
      |> remember_check_run(cache_key)

    record_check_run(result, request, context)
  end

  # A cached run skips the lookup, so an update costs one GitHub call.
  defp existing_check_run(request, context, cache_key) do
    case CheckRunCache.get(cache_key) do
      {:ok, run} ->
        Watchman.increment("set_check_run.cache_hit")
        {:ok, run}

      :miss ->
        with {:ok, app_id} <- github_app_id() do
          find_existing_check_run(request, context, app_id)
        end
    end
  end

  # A missing configuration is told apart from instance_config being
  # unreachable: the first falls back to a commit status
  # (fallback_to_commit_status/3), the second fails so the notifier retries,
  # since the pipeline may already have a run that needs completing.
  defp github_app_id do
    precondition = GRPC.Status.failed_precondition()

    case GithubAppId.get() do
      {:error, %{status: ^precondition}} -> {:error, :github_app_id_not_configured}
      result -> result
    end
  end

  # Any failure drops the entry, so the retry looks the run up again instead
  # of trusting an id GitHub may have rejected (e.g. a deleted run).
  defp remember_check_run({:ok, %{"id" => id, "status" => status}} = result, cache_key) do
    CheckRunCache.put(cache_key, id, status)
    result
  end

  defp remember_check_run({:ok, _} = result, _cache_key), do: result

  defp remember_check_run(error, cache_key) do
    CheckRunCache.delete(cache_key)
    error
  end

  # Only a confirmed "no such run" means create. Any other lookup failure must
  # fail the request, otherwise we'd create a duplicate run.
  defp find_existing_check_run(request, context, app_id) do
    not_found = GRPC.Status.not_found()

    request
    |> check_run_lookup_params(context, app_id)
    |> GithubChecksClient.find_check_run(client: context.github_client)
    |> case do
      {:ok, run} -> {:ok, run}
      {:error, %{status: ^not_found}} -> {:ok, nil}
      error -> error
    end
  end

  defp check_run_lookup_params(request, context, app_id) do
    %{
      repo_owner: context.repository.owner,
      repo_name: context.repository.name,
      commit_sha: request.commit_sha,
      name: request.context,
      app_id: app_id,
      external_id: external_id(request)
    }
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
        |> GithubChecksClient.create_check_run(client: context.github_client)

      id ->
        params
        |> Map.put(:check_run_id, id)
        |> GithubChecksClient.update_check_run(client: context.github_client)
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
