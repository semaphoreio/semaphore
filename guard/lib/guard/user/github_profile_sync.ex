defmodule Guard.User.GithubProfileSync do
  @moduledoc """
  Sync GitHub `:login` and `:name` onto a `RepoHostAccount` after token
  validation. Best-effort: returns its input tuple unchanged on any
  non-github, revoked, or fetch-failure path.
  """

  require Logger

  alias Guard.FrontRepo

  @profile_fields [:login, :name]
  @user_exchange "user_exchange"
  @updated_routing_key "updated"
  @failure_metric "guard.github_profile_sync.failure"

  @doc """
  Sync the GitHub profile for the account contained in `result`.

  `result` is the value produced by token validation:
  `{:ok, %RepoHostAccount{}}`, `{:error, term()}`, or any other tuple.
  Anything other than `{:ok, %{repo_host: "github", revoked: false}}` is
  returned untouched.
  """
  @spec sync(any(), String.t(), String.t() | nil) :: any()
  def sync({:ok, %{repo_host: "github", revoked: false} = account}, user_id, token) do
    case Guard.Api.Github.user(account.github_uid, token) do
      {:ok, profile} ->
        apply_diff(account, profile, user_id)

      {:error, reason} ->
        log_fetch_failure(user_id, reason)
        {:ok, account}
    end
  end

  def sync(result, _user_id, _token), do: result

  defp log_fetch_failure(user_id, :revoked) do
    Logger.warning("Skipping GitHub profile sync for #{user_id}: token revoked")
    Watchman.increment(@failure_metric)
  end

  defp log_fetch_failure(user_id, {:http, status} = reason) when status >= 500 do
    Logger.warning(
      "Skipping GitHub profile sync for #{user_id}: profile fetch failed (#{inspect(reason)})"
    )

    Watchman.increment(@failure_metric)
  end

  defp log_fetch_failure(_user_id, _reason), do: :ok

  defp apply_diff(account, profile, user_id) do
    case FrontRepo.RepoHostAccount.update_profile(account, Map.take(profile, @profile_fields)) do
      {:ok, ^account} ->
        {:ok, account}

      {:ok, updated} ->
        Guard.Events.UserUpdated.publish(user_id, @user_exchange, @updated_routing_key)
        {:ok, updated}

      {:error, error} ->
        Logger.error("Failed to sync GitHub profile for #{user_id}: #{inspect(error)}")
        Watchman.increment(@failure_metric)
        {:ok, account}
    end
  end
end
