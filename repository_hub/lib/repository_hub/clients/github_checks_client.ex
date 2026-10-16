defmodule RepositoryHub.GithubChecksClient do
  @moduledoc """
  Tesla client for the GitHub Checks API (check-runs).

  Only usable with a GitHub App installation token (the `github_app`
  integration type). OAuth user tokens cannot create check-runs and receive a
  403, so `github_oauth_token` repositories stay on the legacy Commit Status
  API in `RepositoryHub.GithubClient`.
  """
  import RepositoryHub.Toolkit

  @api_url "https://api.github.com"
  @api_version "2022-11-28"

  # Same reserve as GithubClient's :create_build_status, so status reporting
  # never drains the quota other GitHub calls need.
  @rate_limit_reserve 1000

  @doc """
  Returns `:ok` when the token has more than #{@rate_limit_reserve} API calls
  left, `{:error, :rate_limit}` otherwise. Mirrors `GithubClient`'s gate: when
  the limit can't be read it is assumed to be low.
  """
  def check_rate_limit(params, opts \\ []) do
    opts[:token]
    |> client()
    |> Tesla.get("/rate_limit")
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"rate" => %{"remaining" => remaining}}}} ->
        rate_limit_decision(remaining, params.repo_owner)

      {:ok, %Tesla.Env{status: 401}} ->
        fail_with(:precondition, "GitHub Checks API token is not authorized")

      other ->
        log_error("Failed to get the rate limit for #{params.repo_owner}: #{inspect(other)}")
        rate_limit_decision(0, params.repo_owner)
    end
  end

  defp rate_limit_decision(remaining, owner) when remaining > @rate_limit_reserve do
    Watchman.increment({"github_api.rate_limit.ok", [owner]})
    :ok
  end

  defp rate_limit_decision(remaining, owner) do
    Watchman.increment({"github_api.rate_limit.error", [owner]})

    log_error(
      "Failed to connect to GitHub. purpose=check_run owner=#{owner} limit=#{@rate_limit_reserve} remaining_rate_limit=#{remaining}"
    )

    {:error, :rate_limit}
  end

  def create_check_run(params, opts \\ []) do
    body =
      %{
        name: params.name,
        head_sha: params.head_sha,
        status: params.status
      }
      |> maybe_put(:external_id, Map.get(params, :external_id))
      |> maybe_put(:details_url, Map.get(params, :details_url))
      |> maybe_put(:conclusion, Map.get(params, :conclusion))
      |> maybe_put(:started_at, Map.get(params, :started_at))
      |> maybe_put(:completed_at, Map.get(params, :completed_at))
      |> maybe_put(:output, Map.get(params, :output))

    opts[:token]
    |> client()
    |> Tesla.post("/repos/#{params.repo_owner}/#{params.repo_name}/check-runs", body)
    |> handle_response(:create_check_run, params)
  end

  def update_check_run(params, opts \\ []) do
    body =
      %{}
      |> maybe_put(:status, Map.get(params, :status))
      |> maybe_put(:conclusion, Map.get(params, :conclusion))
      |> maybe_put(:completed_at, Map.get(params, :completed_at))
      |> maybe_put(:details_url, Map.get(params, :details_url))
      |> maybe_put(:output, Map.get(params, :output))

    opts[:token]
    |> client()
    |> Tesla.patch(
      "/repos/#{params.repo_owner}/#{params.repo_name}/check-runs/#{params.check_run_id}",
      body
    )
    |> handle_response(:update_check_run, params)
  end

  @doc """
  Finds the latest check-run with the given name and `external_id` on a commit.

  `app_id` limits the lookup to Semaphore's GitHub App on GitHub's side, so a
  same-named run from another app, which we could not update, is never
  picked. `external_id` (set by `create_check_run/2`) then selects the run of
  one pipeline.
  """
  def find_check_run(params, opts \\ []) do
    opts[:token]
    |> client()
    |> Tesla.get(
      "/repos/#{params.repo_owner}/#{params.repo_name}/commits/#{params.commit_sha}/check-runs",
      query: [check_name: params.name, app_id: params.app_id, per_page: 100]
    )
    |> handle_response(:find_check_run, params)
    |> unwrap(fn body ->
      body
      |> Map.get("check_runs", [])
      |> Enum.filter(&(&1["external_id"] == params.external_id))
      |> case do
        [] ->
          fail_with(:not_found, "No check-run named #{params.name} on #{params.commit_sha}")

        runs ->
          runs |> Enum.max_by(&(&1["id"] || 0)) |> wrap()
      end
    end)
  end

  defp client(token) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @api_url},
      {Tesla.Middleware.Headers,
       [
         {"authorization", "Bearer #{token}"},
         {"accept", "application/vnd.github+json"},
         {"x-github-api-version", @api_version},
         {"user-agent", "SemaphoreCI-RepositoryHub"}
       ]},
      Tesla.Middleware.JSON
    ])
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}, _purpose, _params)
       when status in 200..299 do
    wrap(body)
  end

  # The installation hasn't granted the Checks permission. Callers fall back
  # to the Commit Status API on permission_denied.
  defp handle_response(
         {:ok, %Tesla.Env{status: 403, body: %{"message" => "Resource not accessible by integration"}}},
         purpose,
         params
       ) do
    log_warn([
      "github checks api permission missing",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}"
    ])

    error(%{
      status: GRPC.Status.permission_denied(),
      message: "GitHub App installation is missing the Checks permission"
    })
  end

  # The write may still have landed on GitHub. Report unavailable so callers
  # don't treat it as a definitive rejection.
  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}, purpose, params)
       when status >= 500 do
    log_error([
      "github checks api error",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}",
      "status: #{status}",
      "body: #{inspect(body)}"
    ])

    fail_with(:unavailable, "GitHub Checks API #{purpose} failed (status #{status}): #{message_from(body)}")
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}, purpose, params) do
    log_error([
      "github checks api error",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}",
      "status: #{status}",
      "body: #{inspect(body)}"
    ])

    fail_with(
      :precondition,
      "GitHub Checks API #{purpose} failed (status #{status}): #{message_from(body)}"
    )
  end

  defp handle_response({:error, reason}, purpose, params) do
    log_error([
      "github checks api transport error",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}",
      "reason: #{inspect(reason)}"
    ])

    fail_with(:unavailable, "GitHub Checks API #{purpose} transport error")
  end

  defp message_from(%{"message" => message}) when is_binary(message), do: message
  defp message_from(_), do: "unknown error"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
