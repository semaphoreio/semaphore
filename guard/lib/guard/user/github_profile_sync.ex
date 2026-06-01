defmodule Guard.User.GithubProfileSync do
  @moduledoc """
  Sync GitHub profile fields (`:login`, `:name`) onto a `RepoHostAccount`
  after a successful token validation.

  Designed to slot into the `handle_update_repo_status` pipe in
  `Guard.GrpcServers.UserServer` — accepts the `{:ok, account}` /
  `{:error, _}` / passthrough tuple shape produced by `handle_validate_token`
  and returns the same shape.

  - Non-`github` providers and revoked accounts pass through untouched.
  - Profile fetch failures are logged and the original `{:ok, account}` is
    returned (best-effort sync, never block the caller).
  - Field values are kept out of logs (PII).
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

  # Warn + bump metric on signals an operator may want to investigate: token
  # revoked at the provider, or upstream 5xx (GitHub-side outage / our service
  # degraded).
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

  # Everything else (404, 4xx other than revoked, transport blips) is expected
  # noise — demote to debug, no metric.
  defp log_fetch_failure(user_id, reason) do
    Logger.debug(
      "Skipping GitHub profile sync for #{user_id}: profile fetch failed (#{inspect(reason)})"
    )
  end

  defp apply_diff(account, profile, user_id) do
    diff =
      Enum.reduce(@profile_fields, %{}, fn field, acc ->
        fresh = Map.get(profile, field)
        stored = Map.get(account, field)

        if is_binary(fresh) and fresh != "" and fresh != stored do
          Map.put(acc, field, fresh)
        else
          acc
        end
      end)

    if diff == %{} do
      {:ok, account}
    else
      case FrontRepo.RepoHostAccount.update_profile(account, diff) do
        {:ok, updated} ->
          Logger.info("GitHub profile changed for user #{user_id}: fields=#{describe_diff(diff)}")

          Guard.Events.UserUpdated.publish(user_id, @user_exchange, @updated_routing_key)

          {:ok, updated}

        {:error, error} ->
          Logger.error("Failed to sync GitHub profile for #{user_id}: #{inspect(error)}")
          Watchman.increment(@failure_metric)
          {:ok, account}
      end
    end
  end

  defp describe_diff(diff) do
    diff
    |> Map.keys()
    |> Enum.sort()
    |> Enum.join(",")
  end
end
