defmodule Rbac.OIDC.FederatedIdentitySync do
  @moduledoc """
  Best-effort Keycloak sync when a GitHub account is claimed away from users
  whose revoked repo_host_accounts links were released.

  Removes the github federated identity from each losing user's Keycloak
  account and pushes the claiming user's github identity, so GitHub-brokered
  login routes to the claiming user.

  Fire-and-forget: runs in an unlinked task, never fails the claim, and is a
  no-op unless OIDC is enabled. If the surrounding DB transaction rolls back
  after the task is spawned, Keycloak may briefly diverge; the released links
  were revoked, so this is tolerated.
  """

  require Logger

  @provider "github"

  @spec sync_github_claim(Rbac.FrontRepo.RepoHostAccount.t(), [String.t()]) :: :ok
  def sync_github_claim(_account, []), do: :ok

  def sync_github_claim(account, released_user_ids) do
    if Rbac.OIDC.enabled?() do
      Task.start(fn -> do_sync(account, Enum.uniq(released_user_ids)) end)
    end

    :ok
  end

  defp do_sync(account, released_user_ids) do
    Enum.each(released_user_ids, &remove_github_identity(&1, account))
    push_github_identity(account)
  rescue
    error -> log_crash(account, error)
  catch
    kind, reason -> log_crash(account, {kind, reason})
  end

  defp remove_github_identity(user_id, account) do
    case Rbac.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        case Rbac.OIDC.User.remove_federated_identity(oidc_user.oidc_user_id, @provider) do
          {:ok, _} ->
            Logger.info(
              "[FederatedIdentitySync] Removed github identity #{account.github_uid} from oidc user #{oidc_user.oidc_user_id} (user #{user_id})"
            )

          {:error, error} ->
            Logger.error(
              "[FederatedIdentitySync] Failed to remove github identity #{account.github_uid} from oidc user #{oidc_user.oidc_user_id} (user #{user_id}): #{inspect(error)}"
            )
        end

      {:error, :not_found} ->
        Logger.info(
          "[FederatedIdentitySync] User #{user_id} has no OIDC user, skipping github identity removal"
        )
    end
  end

  defp push_github_identity(account) do
    case Rbac.Store.OIDCUser.fetch_by_user_id(account.user_id) do
      {:ok, oidc_user} ->
        identity = %{
          identityProvider: @provider,
          userId: account.github_uid,
          userName: account.login
        }

        case Rbac.OIDC.User.set_federated_identity(oidc_user.oidc_user_id, identity) do
          {:ok, _} ->
            Logger.info(
              "[FederatedIdentitySync] Pushed github identity #{account.github_uid} to oidc user #{oidc_user.oidc_user_id} (user #{account.user_id})"
            )

          {:error, error} ->
            Logger.error(
              "[FederatedIdentitySync] Failed to push github identity #{account.github_uid} to oidc user #{oidc_user.oidc_user_id} (user #{account.user_id}): #{inspect(error)}"
            )
        end

      {:error, :not_found} ->
        Logger.info(
          "[FederatedIdentitySync] Claiming user #{account.user_id} has no OIDC user, skipping github identity push"
        )
    end
  end

  defp log_crash(account, error) do
    Logger.error(
      "[FederatedIdentitySync] Keycloak sync crashed for github uid #{account.github_uid} claimed by user #{account.user_id}: #{inspect(error)}"
    )
  end
end
