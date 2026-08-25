defimpl RepositoryHub.SyncRepositoryAction, for: RepositoryHub.GithubAdapter do
  alias RepositoryHub.{
    Toolkit,
    GithubAdapter,
    GithubClient,
    Model
  }

  import Toolkit

  @impl true
  def execute(adapter, repository_id) do
    with {:ok, context} <- get_github_context(adapter, repository_id),
         {:ok, github_repository} <- get_github_repository(context.repository, context.github_token),
         {:ok, repository} <- sync_repository_data(context.repository, github_repository) do
      repository
      |> wrap()
    end
  end

  defp get_github_context(adapter, repository_id) do
    GithubAdapter.context(adapter, repository_id)
    |> unwrap_error(fn error ->
      if disconnect_error?(error) do
        Model.RepositoryQuery.set_not_connected(repository_id)
      end

      error(error)
    end)
  end

  defp disconnect_error?(error) when is_binary(error) do
    error == "Token for not found." or
      (String.starts_with?(error, "User with id ") and
         String.ends_with?(error, " not found")) or
      (String.starts_with?(error, "project ") and
         String.ends_with?(error, " not found"))
  end

  defp disconnect_error?(_), do: false

  defp get_github_repository(repository, github_token) do
    GithubClient.find_repository(
      %{
        repo_owner: repository.owner,
        repo_name: repository.name
      },
      token: github_token
    )
    |> unwrap_error(fn error ->
      # Disconnect only on 401/404. Everything else (403, 5xx, rate limit, transport) is transient or
      # ambiguous and must NOT disconnect: the worker never retries connected==false rows, so a wrong
      # disconnect strands the repo until a webhook reconnects it (real removals come via the webhook).
      unless keep_connected?(error) do
        Model.RepositoryQuery.set_not_connected(repository.id)
      end

      error(error)
    end)
  rescue
    e ->
      # Transport-level failure (timeout/DNS) — transient, never disconnect. Logged with the
      # stacktrace so real bugs stay visible.
      log_error([
        "transport error while syncing repository #{repository.id}",
        inspect(e),
        inspect(__STACKTRACE__)
      ])

      error(%{status: GRPC.Status.unavailable(), message: "GitHub is unavailable (transport error)."})
  end

  # :rate_limit is the pre-call quota atom; find_repository errors carry :http_status. Disconnect only
  # on 401/404; unknown shapes stay connected (conservative default).
  defp keep_connected?(:rate_limit), do: true
  defp keep_connected?(%{http_status: http_status}), do: http_status not in [401, 404]
  defp keep_connected?(_), do: true

  defp sync_repository_data(repository, github_repository) do
    params = %{
      # sync data
      name: github_repository.name,
      owner: github_repository.owner,
      private: github_repository.is_private?,
      url: github_repository.ssh_url,
      connected: true,
      default_branch: github_repository.default_branch,
      remote_id: github_repository.id
    }

    repository
    |> Model.RepositoryQuery.update(
      params,
      returning: true
    )
    |> wrap()
  end
end
