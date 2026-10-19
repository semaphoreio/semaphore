defmodule RepositoryHub.GithubChecksClient do
  @moduledoc """
  Client for the GitHub Checks API (check-runs), built on `RepositoryHub.GithubApi`.

  Only usable with a GitHub App installation token (the `github_app`
  integration type). OAuth user tokens cannot create check-runs and receive a
  403, so `github_oauth_token` repositories stay on the legacy Commit Status
  API in `RepositoryHub.GithubClient`.
  """
  import RepositoryHub.Toolkit

  alias RepositoryHub.GithubApi

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

    GithubApi.with_client(opts[:token], params.repo_owner, :create_check_run, fn client ->
      client
      |> Tesla.post("/repos/#{params.repo_owner}/#{params.repo_name}/check-runs", body)
      |> GithubApi.handle_response(:create_check_run, params)
    end)
  end

  def update_check_run(params, opts \\ []) do
    body =
      %{}
      |> maybe_put(:status, Map.get(params, :status))
      |> maybe_put(:conclusion, Map.get(params, :conclusion))
      |> maybe_put(:completed_at, Map.get(params, :completed_at))
      |> maybe_put(:details_url, Map.get(params, :details_url))
      |> maybe_put(:output, Map.get(params, :output))

    GithubApi.with_client(opts[:token], params.repo_owner, :update_check_run, fn client ->
      client
      |> Tesla.patch("/repos/#{params.repo_owner}/#{params.repo_name}/check-runs/#{params.check_run_id}", body)
      |> GithubApi.handle_response(:update_check_run, params)
    end)
  end

  @doc """
  Finds the latest check-run with the given name and `external_id` on a commit.

  `app_id` limits the lookup to Semaphore's GitHub App on GitHub's side, so a
  same-named run from another app, which we could not update, is never
  picked. `external_id` (set by `create_check_run/2`) then selects the run of
  one pipeline.
  """
  def find_check_run(params, opts \\ []) do
    GithubApi.with_client(opts[:token], params.repo_owner, :find_check_run, fn client ->
      client
      |> Tesla.get(
        "/repos/#{params.repo_owner}/#{params.repo_name}/commits/#{params.commit_sha}/check-runs",
        query: [check_name: params.name, app_id: params.app_id, per_page: 100]
      )
      |> GithubApi.handle_response(:find_check_run, params)
    end)
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
