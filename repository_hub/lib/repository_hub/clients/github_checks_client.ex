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

  def create_check_run(params, opts \\ []) do
    body =
      %{
        name: params.name,
        head_sha: params.head_sha,
        status: params.status
      }
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

  def find_check_run(params, opts \\ []) do
    opts[:token]
    |> client()
    |> Tesla.get(
      "/repos/#{params.repo_owner}/#{params.repo_name}/commits/#{params.commit_sha}/check-runs",
      query: [check_name: params.name]
    )
    |> handle_response(:find_check_run, params)
    |> unwrap(fn body ->
      body
      |> Map.get("check_runs", [])
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
