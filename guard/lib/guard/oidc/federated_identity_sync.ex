defmodule Guard.OIDC.FederatedIdentitySync do
  @moduledoc """
  Best-effort Keycloak sync when a GitHub account is claimed away from users
  whose revoked repo_host_accounts links were released.

  Removes the github federated identity from each losing user's Keycloak
  account and pushes the claiming user's github identity, so GitHub-brokered
  login routes to the claiming user. When any removal fails, the push is
  skipped — otherwise the same identity could end up attached to two Keycloak
  users.

  Keycloak is never mutated from inside an open database transaction: when a
  claim happens inside one (user creation), the sync is deferred in the
  calling process and must be released with `run_deferred/0` after commit, or
  discarded with `drop_deferred/0` on rollback.

  Fire-and-forget: runs in an unlinked task, never fails the claim, and is a
  no-op unless OIDC is enabled. Each Keycloak call gets a bounded number of
  retries; terminal outcomes are counted in Watchman metrics.
  """

  require Logger

  @provider "github"
  @success_metric "guard.federated_identity_sync.success"
  @failure_metric "guard.federated_identity_sync.failure"
  @max_attempts 3
  @pdict_key :federated_identity_sync_deferred

  @spec sync_github_claim(Guard.FrontRepo.RepoHostAccount.t(), [String.t()]) :: :ok
  def sync_github_claim(_account, []), do: :ok

  def sync_github_claim(account, released_user_ids) do
    cond do
      not Guard.OIDC.enabled?() -> :ok
      defer?() -> defer(account, released_user_ids)
      true -> start_task(account, released_user_ids)
    end
  end

  @doc """
  Starts the sync tasks deferred by claims that ran inside a database
  transaction. Call after the transaction committed.
  """
  @spec run_deferred() :: :ok
  def run_deferred do
    deferred = Process.delete(@pdict_key) || []

    deferred
    |> Enum.reverse()
    |> Enum.each(fn {account, released_user_ids} ->
      start_task(account, released_user_ids)
    end)

    :ok
  end

  @doc """
  Discards syncs deferred by claims whose transaction rolled back.
  """
  @spec drop_deferred() :: :ok
  def drop_deferred do
    Process.delete(@pdict_key)
    :ok
  end

  defp defer? do
    Guard.FrontRepo.in_transaction?()
  end

  defp defer(account, released_user_ids) do
    Process.put(@pdict_key, [
      {account, released_user_ids} | Process.get(@pdict_key, [])
    ])

    :ok
  end

  defp start_task(account, released_user_ids) do
    Task.start(fn -> do_sync(account, Enum.uniq(released_user_ids)) end)
    :ok
  end

  defp do_sync(account, released_user_ids) do
    removals_ok =
      released_user_ids
      |> Enum.map(&remove_github_identity(&1, account))
      |> Enum.all?(&(&1 == :ok))

    result =
      if removals_ok do
        push_github_identity(account)
      else
        Logger.error(
          "[FederatedIdentitySync] Skipping github identity push for user #{account.user_id}: not all identity removals succeeded"
        )

        :error
      end

    case result do
      :ok -> Watchman.increment({@success_metric, [@provider]})
      :error -> Watchman.increment({@failure_metric, [@provider]})
    end
  rescue
    error ->
      log_crash(account, error)
      Watchman.increment({@failure_metric, [@provider]})
  catch
    kind, reason ->
      log_crash(account, {kind, reason})
      Watchman.increment({@failure_metric, [@provider]})
  end

  defp remove_github_identity(user_id, account) do
    case Guard.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        with_retries(fn ->
          Guard.OIDC.User.remove_federated_identity(oidc_user.oidc_user_id, @provider)
        end)
        |> case do
          {:ok, _} ->
            Logger.info(
              "[FederatedIdentitySync] Removed github identity #{account.github_uid} from oidc user #{oidc_user.oidc_user_id} (user #{user_id})"
            )

            :ok

          {:error, error} ->
            Logger.error(
              "[FederatedIdentitySync] Failed to remove github identity #{account.github_uid} from oidc user #{oidc_user.oidc_user_id} (user #{user_id}): #{inspect(error)}"
            )

            :error
        end

      {:error, :not_found} ->
        Logger.info(
          "[FederatedIdentitySync] User #{user_id} has no OIDC user, skipping github identity removal"
        )

        :ok
    end
  end

  defp push_github_identity(account) do
    case Guard.Store.OIDCUser.fetch_by_user_id(account.user_id) do
      {:ok, oidc_user} ->
        identity = %{
          identityProvider: @provider,
          userId: account.github_uid,
          userName: account.login
        }

        with_retries(fn ->
          Guard.OIDC.User.set_federated_identity(oidc_user.oidc_user_id, identity)
        end)
        |> case do
          {:ok, _} ->
            Logger.info(
              "[FederatedIdentitySync] Pushed github identity #{account.github_uid} to oidc user #{oidc_user.oidc_user_id} (user #{account.user_id})"
            )

            :ok

          {:error, error} ->
            Logger.error(
              "[FederatedIdentitySync] Failed to push github identity #{account.github_uid} to oidc user #{oidc_user.oidc_user_id} (user #{account.user_id}): #{inspect(error)}"
            )

            :error
        end

      {:error, :not_found} ->
        Logger.info(
          "[FederatedIdentitySync] Claiming user #{account.user_id} has no OIDC user, skipping github identity push"
        )

        :ok
    end
  end

  defp with_retries(fun, attempt \\ 1) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, _} = error ->
        if attempt < @max_attempts do
          :timer.sleep(backoff_ms() * attempt)
          with_retries(fun, attempt + 1)
        else
          error
        end
    end
  end

  defp backoff_ms do
    Application.get_env(:guard, :federated_identity_sync_backoff_ms, 500)
  end

  defp log_crash(account, error) do
    Logger.error(
      "[FederatedIdentitySync] Keycloak sync crashed for github uid #{account.github_uid} claimed by user #{account.user_id}: #{inspect(error)}"
    )
  end
end
