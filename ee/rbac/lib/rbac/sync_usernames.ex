defmodule Rbac.SyncUsernames do
  @moduledoc """
  Propagates repo host login changes from the
  authoritative `repo_host_accounts` table (Front DB, owned by Guard) into the
  per-project `collaborators` cache that RBAC maintains.

  Triggered from `Rbac.Services.UserUpdater` on every `user_updated` event.
  Only rows whose `github_uid` matches the user's repo host account UID **and**
  whose stored `github_username` is out of date are updated.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Rbac.Repo
  alias Rbac.Repo.{Collaborator, Project}

  @doc """
  Loads the user's current repo host accounts and updates any `collaborators`
  rows whose stored `github_username` is stale (matching by `github_uid`).

  Returns `{:ok, updated_collaborators_count}` if successful,
  or `{:error, reason}` if the user lookup fails.
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

  # only handle GitHub provider for now.
  defp update_for_provider(
         _user_id,
         %{"provider" => provider_name, "uid" => uid, "login" => login}
       )
       when provider_name != "github"
       when is_nil(login) or login == ""
       when is_nil(uid) or uid == "",
       do: 0

  defp update_for_provider(user_id, provider) do
    uid = Map.get(provider, "uid")
    login = Map.get(provider, "login")
    provider_name = Map.get(provider, "provider")

    {count, _} =
      from(c in Collaborator,
        join: p in Project,
        on: p.project_id == c.project_id,
        where:
          c.github_uid == ^uid and
            c.github_username != ^login and
            p.provider == ^provider_name
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

  defp now, do: NaiveDateTime.utc_now()
end
