defmodule RepositoryHub.GithubApi do
  @moduledoc """
  Tesla base for GitHub REST API clients.

  The Tesla counterpart of `RepositoryHub.GithubClient.with_client/4`
  (Tentacat): same arguments, same per-purpose rate-limit reserve, same
  metrics and the same `{:error, :rate_limit}` result. Clients build requests
  inside `with_client/4` and map the result with `handle_response/3`.
  """
  import RepositoryHub.Toolkit

  @api_url "https://api.github.com"
  @api_version "2022-11-28"

  # Calls are refused when the token has this many API calls left or fewer,
  # so they never drain the quota other GitHub calls need. Check-runs use the
  # same reserve as GithubClient's :create_build_status.
  @limits %{
    create_check_run: 1000,
    update_check_run: 1000,
    find_check_run: 1000
  }

  @err_not_authorized "It looks like you haven't authorized Semaphore with GitHub, please visit https://docs.semaphoreci.com/using-semaphore/connect-github#troubleshooting-guide to read more."

  @spec with_client(String.t(), String.t(), atom(), (Tesla.Client.t() -> result)) :: result | {:error, any}
        when result: var
  def with_client(token, owner, purpose, fun) do
    client = client(token)

    case get_remaining_rate_limit(client) do
      {:ok, remaining_rate_limit} ->
        limit = Map.fetch!(@limits, purpose)

        # Mirrors GithubClient.with_client/4 on purpose, so both clients gate
        # the same way until the Tentacat client is retired.
        # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
        if remaining_rate_limit > limit do
          Watchman.increment({"github_api.rate_limit.ok", [owner]})
          fun.(client)
        else
          Watchman.increment({"github_api.rate_limit.error", [owner]})

          log_error(
            "Failed to connect to GitHub. purpose=#{purpose} owner=#{owner} limit=#{limit} remaining_rate_limit=#{remaining_rate_limit}"
          )

          {:error, :rate_limit}
        end

      e ->
        e
    end
  end

  @doc """
  Maps a Tesla result to the service's error convention:

  - 2xx → `{:ok, body}`
  - 403 "Resource not accessible by integration" → `permission_denied`
    (the GitHub App installation lacks a permission)
  - 5xx or a transport error → `unavailable` (a write may still have landed,
    so callers must not treat it as a definitive rejection)
  - 429, or a 403 from a primary or secondary rate limit → `{:error, :rate_limit}`,
    the same result as the pre-call reserve check: GitHub didn't write
    anything, so the delivery lease is released and the notifier retries
  - any other status → `failed_precondition`
  """
  def handle_response({:ok, %Tesla.Env{status: status, body: body}}, _purpose, _params)
      when status in 200..299 do
    wrap(body)
  end

  def handle_response(
        {:ok, %Tesla.Env{status: 403, body: %{"message" => "Resource not accessible by integration"}}},
        purpose,
        params
      ) do
    log_warn([
      "github api permission missing",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}"
    ])

    error(%{
      status: GRPC.Status.permission_denied(),
      message: "GitHub App installation is missing the permission for #{purpose}"
    })
  end

  def handle_response({:ok, %Tesla.Env{status: status, body: body}}, purpose, params) when status >= 500 do
    log_response_error(status, body, purpose, params)
    fail_with(:unavailable, "GitHub API #{purpose} failed (status #{status}): #{message_from(body)}")
  end

  def handle_response({:ok, %Tesla.Env{status: status, body: body} = env}, purpose, params) do
    log_response_error(status, body, purpose, params)

    if rate_limited?(env) do
      Watchman.increment({"github_api.rate_limit.error", [params.repo_owner]})
      {:error, :rate_limit}
    else
      fail_with(:precondition, "GitHub API #{purpose} failed (status #{status}): #{message_from(body)}")
    end
  end

  def handle_response({:error, reason}, purpose, params) do
    log_error([
      "github api transport error",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}",
      "reason: #{inspect(reason)}"
    ])

    fail_with(:unavailable, "GitHub API #{purpose} transport error")
  end

  defp log_response_error(status, body, purpose, params) do
    log_error([
      "github api error",
      "purpose: #{purpose}",
      "repo: #{params.repo_owner}/#{params.repo_name}",
      "status: #{status}",
      "body: #{inspect(body)}"
    ])
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

  defp get_remaining_rate_limit(client) do
    case Tesla.get(client, "/rate_limit") do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, get_in(body, ["rate", "remaining"])}

      {:ok, %Tesla.Env{status: 401}} ->
        fail_with(:precondition, @err_not_authorized)

      other ->
        log_error("Failed to get the rate limit #{inspect(other)}")

        # if we can't find the limit, assume something very low
        {:ok, 100}
    end
  end

  # GitHub signals both primary and secondary rate limits with a 403 or 429,
  # marked by an exhausted x-ratelimit-remaining, a retry-after header or the
  # message. See https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api#rate-limit-errors
  defp rate_limited?(%Tesla.Env{status: 429}), do: true

  defp rate_limited?(%Tesla.Env{status: 403, body: body} = env) do
    Tesla.get_header(env, "x-ratelimit-remaining") == "0" or
      Tesla.get_header(env, "retry-after") != nil or
      message_from(body) =~ ~r/rate limit/i
  end

  defp rate_limited?(_env), do: false

  defp message_from(%{"message" => message}) when is_binary(message), do: message
  defp message_from(_), do: "unknown error"
end
