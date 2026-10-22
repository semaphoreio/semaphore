defmodule RepositoryHub.GithubCommitStatusClient do
  @moduledoc """
  Reads commit statuses through `RepositoryHub.GithubApi`. Writing them stays in
  `RepositoryHub.GithubClient.create_build_status/2`.
  """
  import RepositoryHub.Toolkit

  alias RepositoryHub.GithubApi

  @per_page 100
  @max_pages 10

  @doc """
  Finds the latest commit status with the given context on a commit.

  Reads the combined status, which holds one entry (the latest) per context,
  so a context with many statuses is still a single entry. Pages are followed
  until the context is found or a short page, up to `@max_pages`.
  """
  def find_commit_status(params, opts \\ []) do
    GithubApi.with_client(opts[:token], params.repo_owner, :find_commit_status, fn client ->
      find_in_pages(client, params, 1)
    end)
  end

  defp find_in_pages(client, params, page) do
    client
    |> Tesla.get(
      "/repos/#{params.repo_owner}/#{params.repo_name}/commits/#{params.commit_sha}/status",
      query: [per_page: @per_page, page: page]
    )
    |> GithubApi.handle_response(:find_commit_status, params)
    |> unwrap(fn body ->
      statuses = Map.get(body, "statuses", [])

      case Enum.find(statuses, &(&1["context"] == params.context)) do
        nil when length(statuses) < @per_page or page >= @max_pages ->
          fail_with(:not_found, "No commit status #{params.context} on #{params.commit_sha}")

        nil ->
          find_in_pages(client, params, page + 1)

        status ->
          wrap(status)
      end
    end)
  end
end
