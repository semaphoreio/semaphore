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
  @success_metric "guard.github_profile_sync.success"

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

  # 404 — GitHub account genuinely deleted upstream. Expected, no signal needed.
  defp log_fetch_failure(_user_id, :not_found), do: :ok

  # Auth / rate-limit failures are operationally distinct:
  # 401 — token revoked between validate_token and user/{uid} fetch
  # 403 — org-restricted token or secondary rate limit
  # 429 — primary rate limit
  # Tag each separately so alerts can route on the dimension.
  defp log_fetch_failure(user_id, {:http, status} = reason) when status in [401, 403, 429] do
    Logger.warning("GitHub profile sync auth/limit failure for #{user_id}: #{inspect(reason)}")

    Watchman.increment({@failure_metric, ["http_#{status}"]})
  end

  defp log_fetch_failure(user_id, {:http, status} = reason) when status >= 500 do
    Logger.warning(
      "Skipping GitHub profile sync for #{user_id}: profile fetch failed (#{inspect(reason)})"
    )

    Watchman.increment({@failure_metric, ["http_5xx"]})
  end

  # Transport errors and any other unknown shape — silent by policy.
  defp log_fetch_failure(_user_id, _reason), do: :ok

  defp apply_diff(account, profile, user_id) do
    # `update_profile` is a strict writer: nil/"" → `:required` error. GitHub
    # may return `name: null` for users with no display name set; here we
    # treat that as "no opinion" rather than "clear the field". Filter blanks
    # at this boundary so the schema stays a strict writer.
    attrs =
      profile
      |> Map.take(@profile_fields)
      |> Map.reject(fn {_k, v} -> v in [nil, ""] end)

    case FrontRepo.RepoHostAccount.update_profile(account, attrs) do
      {:ok, ^account} ->
        Watchman.increment({@success_metric, ["no_change"]})
        {:ok, account}

      {:ok, updated} ->
        Guard.Events.UserUpdated.publish(user_id, @user_exchange, @updated_routing_key)
        Watchman.increment({@success_metric, ["changed"]})
        {:ok, updated}

      {:error, :stale} ->
        Logger.info(
          "Skipping GitHub profile publish for #{user_id}: concurrent writer already updated the row"
        )

        Watchman.increment({@success_metric, ["concurrent_skip"]})
        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to sync GitHub profile for #{user_id}: #{format_update_error(error)}"
        )

        Watchman.increment({@failure_metric, ["changeset"]})
        {:ok, account}
    end
  end

  # Logs only changeset errors (field + message), never the underlying
  # `:data` struct — which carries the user's OAuth `:token` / `:refresh_token`.
  defp format_update_error(%Ecto.Changeset{errors: errors}),
    do: Enum.map_join(errors, ",", fn {field, {msg, _opts}} -> "#{field}:#{msg}" end)

  defp format_update_error(other), do: inspect(other)
end
