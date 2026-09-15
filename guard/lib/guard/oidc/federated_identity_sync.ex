defmodule Guard.OIDC.FederatedIdentitySync do
  @moduledoc """
  Keycloak sync when a GitHub account is claimed away from users whose
  revoked repo_host_accounts links were released.

  Removes the github federated identity from each losing user's Keycloak
  account and pushes the claiming user's github identity, so GitHub-brokered
  login routes to the claiming user. When any removal fails, the push is
  skipped — otherwise the same identity could end up attached to two Keycloak
  users. Removals are uid-aware: a loser who has since connected a different
  GitHub account keeps that identity untouched.

  Durability: each claim writes a `Guard.FrontRepo.FederatedIdentitySyncRequest`
  outbox row in the transaction that released the losing links. The row is
  deleted only when the sync fully succeeds; failures and process crashes
  leave it behind for `Guard.FederatedIdentitySyncDrainer` to retry with
  backoff, so a lost task never results in permanent misrouting.

  Keycloak is never mutated from inside an open database transaction: when a
  claim happens inside one (user creation), the sync is deferred in the
  calling process and must be released with `run_deferred/0` after commit, or
  discarded with `drop_deferred/0` on rollback (the outbox row rolls back
  with the transaction).

  The immediate sync runs in an unlinked task, never fails the claim, and is
  a no-op unless OIDC is enabled. Each Keycloak call gets a bounded number of
  retries; terminal outcomes are counted in Watchman metrics.
  """

  require Logger

  alias Guard.FrontRepo.FederatedIdentitySyncRequest
  alias Guard.FrontRepo.RepoHostAccount

  @provider "github"
  @success_metric "guard.federated_identity_sync.success"
  @failure_metric "guard.federated_identity_sync.failure"
  @max_attempts 3
  @pdict_key :federated_identity_sync_deferred

  @spec sync_github_claim(
          RepoHostAccount.t(),
          [String.t()],
          FederatedIdentitySyncRequest.t() | nil
        ) ::
          :ok
  def sync_github_claim(account, released_user_ids, request \\ nil)

  def sync_github_claim(_account, [], _request), do: :ok

  def sync_github_claim(account, released_user_ids, request) do
    cond do
      not Guard.OIDC.enabled?() -> :ok
      defer?() -> defer(account, released_user_ids, request)
      true -> start_task(account, released_user_ids, request)
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
    |> Enum.each(fn {account, released_user_ids, request} ->
      start_task(account, released_user_ids, request)
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

  @doc """
  Synchronously processes an outbox row leased by the drainer.
  """
  @spec run_request(FederatedIdentitySyncRequest.t()) :: :ok
  def run_request(%FederatedIdentitySyncRequest{} = request) do
    account = %RepoHostAccount{
      repo_host: request.repo_host,
      github_uid: request.uid,
      user_id: request.claiming_user_id,
      login: request.login
    }

    do_sync(account, request.released_user_ids, request)
  end

  defp defer? do
    Guard.FrontRepo.in_transaction?()
  end

  defp defer(account, released_user_ids, request) do
    Process.put(@pdict_key, [
      {account, released_user_ids, request} | Process.get(@pdict_key, [])
    ])

    :ok
  end

  defp start_task(account, released_user_ids, request) do
    Task.start(fn -> do_sync(account, Enum.uniq(released_user_ids), request) end)
    :ok
  end

  defp do_sync(account, released_user_ids, request) do
    removals_ok =
      released_user_ids
      |> Enum.map(&remove_github_identity(&1, account))
      |> Enum.all?(&(&1 == :ok))

    result =
      cond do
        not removals_ok ->
          Logger.error(
            "[FederatedIdentitySync] Skipping github identity push for user #{account.user_id}: not all identity removals succeeded"
          )

          {:error, "identity removal failed"}

        not RepoHostAccount.holds_uid?(account.repo_host, account.github_uid, account.user_id) ->
          # A later claim superseded this one; that flow owns the push. The
          # removals this row required are done, so it is complete.
          Logger.info(
            "[FederatedIdentitySync] Skipping github identity push for user #{account.user_id}: no longer the holder of uid #{account.github_uid}"
          )

          :ok

        true ->
          case push_github_identity(account) do
            :ok -> :ok
            :error -> {:error, "identity push failed"}
          end
      end

    case result do
      :ok ->
        FederatedIdentitySyncRequest.complete(request)
        Watchman.increment({@success_metric, [@provider]})

      {:error, reason} ->
        FederatedIdentitySyncRequest.record_failure(request, reason)
        Watchman.increment({@failure_metric, [@provider]})
    end
  rescue
    error ->
      log_crash(account, error)
      FederatedIdentitySyncRequest.record_failure(request, inspect(error))
      Watchman.increment({@failure_metric, [@provider]})
  catch
    kind, reason ->
      log_crash(account, {kind, reason})
      FederatedIdentitySyncRequest.record_failure(request, inspect({kind, reason}))
      Watchman.increment({@failure_metric, [@provider]})
  end

  defp remove_github_identity(user_id, account) do
    case Guard.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        with_retries(fn -> detach_if_holding(oidc_user.oidc_user_id, account) end)
        |> case do
          {:ok, :removed} ->
            Logger.info(
              "[FederatedIdentitySync] Removed github identity #{account.github_uid} from oidc user #{oidc_user.oidc_user_id} (user #{user_id})"
            )

            :ok

          {:ok, :skipped} ->
            Logger.info(
              "[FederatedIdentitySync] Oidc user #{oidc_user.oidc_user_id} (user #{user_id}) no longer holds github identity #{account.github_uid}, skipping removal"
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

  # Only detach the github identity if it still points at the claimed uid: a
  # retried sync may run long after the loser connected a different GitHub
  # account, and that identity must not be removed.
  defp detach_if_holding(oidc_user_id, account) do
    with {:ok, identities} <- Guard.OIDC.User.get_federated_identities(oidc_user_id) do
      github = Enum.find(identities, &(&1["identityProvider"] == @provider))

      cond do
        is_nil(github) ->
          {:ok, :skipped}

        github["userId"] != account.github_uid ->
          {:ok, :skipped}

        true ->
          with {:ok, _} <- Guard.OIDC.User.remove_federated_identity(oidc_user_id, @provider) do
            {:ok, :removed}
          end
      end
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
