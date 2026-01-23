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
      Model.RepositoryQuery.set_not_connected(repository.id)

      error(error)
    end)
  end

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
