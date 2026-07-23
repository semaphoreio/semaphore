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

      assert {:ok, claimed} = RepoHostAccount.create(create_params(%{github_uid: "10002"}))

      assert claimed.github_uid == "10002"
      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(stale.user_id)
    end

    test "create/1 rejects the uid once it has been claimed away from a revoked link" do
      {:ok, stale} =
        Support.Members.insert_repo_host_account(github_uid: "10007", revoked: true)

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
end
