defmodule Rbac.FrontRepo.RepoHostAccountTest do
  use Rbac.RepoCase, async: true

  alias Rbac.FrontRepo.RepoHostAccount

  defp create_params(overrides) do
    Map.merge(
      %{
        login: "octocat",
        github_uid: "10001",
        repo_host: "github",
        user_id: Ecto.UUID.generate(),
        name: "The Octocat",
        permission_scope: "user:email"
      },
      overrides
    )
  end

  defp insert_full_rha(overrides) do
    defaults = [
      login: "octocat",
      name: "The Octocat",
      permission_scope: "user:email"
    ]

    Support.Members.insert_repo_host_account(Keyword.merge(defaults, overrides))
  end

  describe "GitHub account uniqueness" do
    test "create/1 rejects a GitHub uid already connected to another user" do
      {:ok, existing} = Support.Members.insert_repo_host_account(github_uid: "10001")

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(create_params(%{github_uid: existing.github_uid}))

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "create/1 claims the uid and deletes the stale link when the existing one is revoked" do
      {:ok, stale} =
        Support.Members.insert_repo_host_account(github_uid: "10002", revoked: true)

      :ok = Support.Members.age_repo_host_account(stale)

      assert {:ok, claimed} = RepoHostAccount.create(create_params(%{github_uid: "10002"}))

      assert claimed.github_uid == "10002"
      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(stale.user_id)
    end

    test "a freshly revoked link is not claimable during the grace period" do
      {:ok, fresh} =
        Support.Members.insert_repo_host_account(github_uid: "10011", revoked: true)

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(create_params(%{github_uid: "10011"}))

      assert RepoHostAccount.uid_taken_error?(changeset)

      # the transiently revoked link is untouched
      {:ok, reloaded} = RepoHostAccount.get_for_github_user(fresh.user_id)
      assert reloaded.revoked == true
    end

    test "create/1 rejects the uid once it has been claimed away from a revoked link" do
      {:ok, stale} =
        Support.Members.insert_repo_host_account(github_uid: "10007", revoked: true)

      :ok = Support.Members.age_repo_host_account(stale)

      {:ok, _claimed} = RepoHostAccount.create(create_params(%{github_uid: "10007"}))

      # The original owner reconnecting must not revive the duplicate.
      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(
                 create_params(%{github_uid: "10007", user_id: stale.user_id})
               )

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "create/1 allows the same uid under a different repo_host" do
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "10003")

      assert {:ok, _} =
               RepoHostAccount.create(
                 create_params(%{github_uid: "10003", repo_host: "bitbucket"})
               )
    end

    test "update_repo_host_account/4 with reset rejects switching to another user's uid" do
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "10004")

      {:ok, mine} =
        Support.Members.insert_repo_host_account(
          github_uid: "10005",
          login: "mine",
          name: "Mine",
          permission_scope: "user:email"
        )

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.update_repo_host_account(
                 mine.user_id,
                 :github,
                 %{
                   github_uid: "10004",
                   login: "mine",
                   name: "Mine",
                   permission_scope: "user:email"
                 },
                 reset: true
               )

      assert RepoHostAccount.uid_taken_error?(changeset)

      {:ok, unchanged} = RepoHostAccount.get_for_github_user(mine.user_id)
      assert unchanged.github_uid == "10005"
    end

    test "update_repo_host_account/4 with reset claims a uid held only by a revoked link" do
      {:ok, stale} =
        Support.Members.insert_repo_host_account(
          github_uid: "10008",
          login: "previous-owner",
          name: "Previous Owner",
          permission_scope: "user:email",
          revoked: true
        )

      :ok = Support.Members.age_repo_host_account(stale)

      {:ok, mine} =
        Support.Members.insert_repo_host_account(
          github_uid: "10010",
          login: "claimer",
          name: "Claimer",
          permission_scope: "user:email"
        )

      assert {:ok, updated} =
               RepoHostAccount.update_repo_host_account(
                 mine.user_id,
                 :github,
                 %{
                   github_uid: stale.github_uid,
                   login: "claimer",
                   name: "Claimer",
                   permission_scope: "user:email"
                 },
                 reset: true
               )

      assert updated.github_uid == stale.github_uid
      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(stale.user_id)
    end

    test "update_repo_host_account/4 allows reconnecting the user's own uid" do
      {:ok, mine} =
        Support.Members.insert_repo_host_account(
          github_uid: "10006",
          login: "reconnect",
          name: "Reconnect",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      assert {:ok, updated} =
               RepoHostAccount.update_repo_host_account(
                 mine.user_id,
                 :github,
                 %{
                   github_uid: "10006",
                   login: "reconnect",
                   name: "Reconnect",
                   token: "refreshed-token",
                   permission_scope: "repo,user:email"
                 },
                 reset: true
               )

      assert updated.github_uid == "10006"
      assert updated.token == "refreshed-token"
    end

    test "uid_taken_error?/1 is false for other changeset errors" do
      changeset =
        %RepoHostAccount{}
        |> Ecto.Changeset.cast(%{}, [:login])
        |> Ecto.Changeset.validate_required([:login])

      refute RepoHostAccount.uid_taken_error?(changeset)
      refute RepoHostAccount.uid_taken_error?(:invalid_data)
    end
  end

  describe "un-revoking a link" do
    test "update_revoke_status/2 rejects re-activation when the uid is actively held by another user" do
      {:ok, revoked} = insert_full_rha(github_uid: "30001", revoked: true)
      {:ok, _active} = insert_full_rha(github_uid: "30001", login: "current-holder")

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.update_revoke_status(revoked, false)

      assert RepoHostAccount.uid_taken_error?(changeset)

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(revoked.user_id)
      assert reloaded.revoked == true
    end

    test "update_revoke_status/2 re-activates when the uid is free" do
      {:ok, revoked} = insert_full_rha(github_uid: "30002", revoked: true)

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false
    end

    test "update_revoke_status/2 re-activation claims a uid held only by revoked links" do
      {:ok, revoked} = insert_full_rha(github_uid: "30003", revoked: true)

      {:ok, stale} =
        insert_full_rha(github_uid: "30003", login: "stale-owner", revoked: true)

      :ok = Support.Members.age_repo_host_account(stale)

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false

      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(stale.user_id)
    end

    test "token refresh on a pre-existing active duplicate is not blocked" do
      {:ok, mine} =
        insert_full_rha(
          github_uid: "30004",
          login: "dup-owner",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      # tolerated legacy state: two active rows share the uid
      {:ok, _} = insert_full_rha(github_uid: "30004", login: "legacy-duplicate")

      assert {:ok, updated} =
               RepoHostAccount.update_repo_host_account(
                 mine.user_id,
                 :github,
                 %{
                   github_uid: "30004",
                   login: "dup-owner",
                   name: "The Octocat",
                   token: "refreshed-token",
                   permission_scope: "repo,user:email"
                 },
                 reset: true
               )

      assert updated.token == "refreshed-token"
      assert updated.revoked == false
    end

    test "bitbucket links can re-activate even when the uid is actively held" do
      shared_uid = "{30000000-0000-4000-8000-000000000002}"

      {:ok, revoked} =
        insert_full_rha(github_uid: shared_uid, repo_host: "bitbucket", revoked: true)

      {:ok, _} =
        insert_full_rha(github_uid: shared_uid, repo_host: "bitbucket", login: "bb-holder")

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false
    end
  end

  # Ecto's query logger prints bound parameters, so a captured log always
  # contains the raw token. These assertions cover this module's own messages.
  defp app_log(log) do
    log
    |> String.split("\n")
    |> Enum.filter(&(&1 =~ "RepoHostAccount"))
    |> Enum.join("\n")
  end

  describe "logging" do
    import ExUnit.CaptureLog

    test "a token refresh logs the changed field names, never the token" do
      {:ok, mine} =
        insert_full_rha(
          github_uid: "10020",
          login: "logger",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      log =
        capture_log(fn ->
          assert {:ok, _} =
                   RepoHostAccount.update_repo_host_account(
                     mine.user_id,
                     :github,
                     %{
                       github_uid: "10020",
                       login: "logger",
                       name: "The Octocat",
                       token: "gho_supersecrettoken",
                       refresh_token: "ghr_supersecretrefresh",
                       permission_scope: "repo,user:email"
                     },
                     reset: true
                   )
        end)

      assert app_log(log) =~ "Successfully updated RepoHostAccount for #{mine.user_id}"
      assert app_log(log) =~ ":token"
      refute app_log(log) =~ "gho_supersecrettoken"
      refute app_log(log) =~ "ghr_supersecretrefresh"
      refute app_log(log) =~ "old-token"
    end

    test "a reset logs the real uid and login transition" do
      {:ok, mine} =
        insert_full_rha(
          github_uid: "10021",
          login: "before",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      log =
        capture_log(fn ->
          assert {:ok, _} =
                   RepoHostAccount.update_repo_host_account(
                     mine.user_id,
                     :github,
                     %{
                       github_uid: "10022",
                       login: "after",
                       name: "The Octocat",
                       token: "gho_supersecrettoken",
                       permission_scope: "repo,user:email"
                     },
                     reset: true
                   )
        end)

      assert app_log(log) =~ "uid 10021 -> 10022"
      assert app_log(log) =~ "login before -> after"
      refute app_log(log) =~ "gho_supersecrettoken"
      refute app_log(log) =~ "old-token"
    end

    test "a rejected reset logs the changeset errors and the attempted transition" do
      {:ok, _} = insert_full_rha(github_uid: "10023", login: "holder")

      {:ok, mine} =
        insert_full_rha(
          github_uid: "10024",
          login: "claimer",
          permission_scope: "repo,user:email"
        )

      log =
        capture_log(fn ->
          assert {:error, %Ecto.Changeset{}} =
                   RepoHostAccount.update_repo_host_account(
                     mine.user_id,
                     :github,
                     %{
                       github_uid: "10023",
                       login: "claimer",
                       name: "The Octocat",
                       token: "gho_supersecrettoken",
                       permission_scope: "repo,user:email"
                     },
                     reset: true
                   )
        end)

      assert app_log(log) =~ "Failed to reset RepoHostAccount for #{mine.user_id}"
      assert app_log(log) =~ "uid 10024 -> 10023"
      assert app_log(log) =~ "already connected to another Semaphore user"
      refute app_log(log) =~ "gho_supersecrettoken"
    end

    test "a link missing required identity fields logs which ones are missing" do
      log =
        capture_log(fn ->
          assert {:error, :invalid_data} =
                   RepoHostAccount.update_repo_host_account(
                     Ecto.UUID.generate(),
                     :github,
                     %{github_uid: nil, login: nil, token: "gho_supersecrettoken"},
                     reset: true
                   )
        end)

      assert app_log(log) =~ "missing [:github_uid, :login]"
      refute app_log(log) =~ "gho_supersecrettoken"
    end
  end

  describe "inspecting a link" do
    test "credentials are redacted" do
      account = %RepoHostAccount{
        login: "octocat",
        github_uid: "10001",
        token: "gho_supersecrettoken",
        refresh_token: "ghr_supersecretrefresh"
      }

      inspected = inspect(account)

      refute inspected =~ "gho_supersecrettoken"
      refute inspected =~ "ghr_supersecretrefresh"
      assert inspected =~ "octocat"
      assert inspected =~ "10001"
    end

    test "credentials are redacted when nested in a changeset" do
      account = %RepoHostAccount{login: "octocat", github_uid: "10001"}

      changeset =
        Ecto.Changeset.cast(account, %{token: "gho_supersecrettoken"}, [:token, :login])

      refute inspect(changeset) =~ "gho_supersecrettoken"
    end
  end
end
