defmodule Rbac.SyncUsernames do
  @moduledoc """
  Propagates repo host login (a.k.a. nickname/username) changes from the
  authoritative `repo_host_accounts` table (Front DB, owned by Guard) into the
  per-project `collaborators` cache that RBAC maintains.

  Triggered from `Rbac.Services.UserUpdater` on every `user_updated` event.
  Only rows whose `github_uid` matches the user's repo host account UID **and**
  whose stored `github_username` is out of date are updated, so this is a
  cheap no-op for the common case where the user did not actually rename.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Rbac.Repo
  alias Rbac.Repo.Collaborator

  @doc """
  Loads the user's current repo host accounts and updates any `collaborators`
  rows whose stored `github_username` is stale (matching by `github_uid`).

  Returns `{:ok, n}` where `n` is the total number of collaborator rows that
  were updated across all providers, or `{:error, reason}` if the user lookup
  fails.
  """
  @spec propagate(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def propagate(user_id) when is_binary(user_id) do
    case Rbac.Store.User.Front.fetch_user_with_repo_account_details(user_id) do
      nil ->
        Logger.warning("[SyncUsernames] User #{user_id} not found - skipping")
        {:error, :user_not_found}

      user ->
        total =
          user.providers
          |> Enum.reduce(0, fn provider, acc ->
            acc + update_for_provider(user_id, provider)
          end)

        if total > 0 do
          Logger.info("[SyncUsernames] Updated #{total} collaborator row(s) for user #{user_id}")
        end

        Watchman.submit("rbac.sync_usernames.rows_updated", total, :gauge)

        {:ok, total}
    end
  end

  defp update_for_provider(user_id, provider) do
    uid = Map.get(provider, "uid")
    login = Map.get(provider, "login")
    provider_name = Map.get(provider, "provider")

    cond do
      is_nil(uid) or uid == "" ->
        0

      is_nil(login) or login == "" ->
        0

      true ->
        {count, _} =
          from(c in Collaborator,
            where: c.github_uid == ^uid and c.github_username != ^login
          )
          |> Repo.update_all(set: [github_username: login, updated_at: now()])

        if count > 0 do
          Logger.info(
            "[SyncUsernames] user=#{user_id} provider=#{provider_name} uid=#{uid} " <>
              "new_login=#{login} rows_updated=#{count}"
          )
        end

        count
    end
  end

  defp now, do: NaiveDateTime.utc_now()
end
