defmodule Guard.FrontRepo.RepoHostAccountTest do
  use Guard.RepoCase, async: false

  alias Guard.FrontRepo
  alias Guard.FrontRepo.RepoHostAccount

  describe "update_profile/2" do
    setup do
      {user, rha} = Support.Members.insert_user_with_github_account()
      {:ok, user: user, rha: rha}
    end

    test "no-op on empty diff", %{rha: rha} do
      assert {:ok, ^rha} = RepoHostAccount.update_profile(rha, %{})
    end

    test "ignores keys outside [:login, :name]", %{rha: rha} do
      {:ok, updated} =
        RepoHostAccount.update_profile(rha, %{
          token: "leaked",
          permission_scope: "admin",
          revoked: true
        })

      assert updated.token == "token"
      assert updated.permission_scope == "repo"
      assert updated.revoked == false
    end

    test "persists login change", %{rha: rha} do
      {:ok, updated} = RepoHostAccount.update_profile(rha, %{login: "new-login"})
      assert updated.login == "new-login"
      assert updated.name == "The Octocat"
    end

    test "persists name change", %{rha: rha} do
      {:ok, updated} = RepoHostAccount.update_profile(rha, %{name: "Octo Cat"})
      assert updated.login == "octocat"
      assert updated.name == "Octo Cat"
    end

    test "persists login change when stored name is nil (legacy row)", %{rha: rha} do
      {:ok, legacy_rha} =
        rha
        |> Ecto.Changeset.change(%{name: nil})
        |> FrontRepo.update(force: true)

      assert legacy_rha.name == nil

      {:ok, updated} = RepoHostAccount.update_profile(legacy_rha, %{login: "new-login"})

      assert updated.login == "new-login"
      assert updated.name == nil

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.login == "new-login"
      assert reloaded.name == nil
    end

    test "rejects blank values with a :required changeset error (strict writer)", %{rha: rha} do
      assert {:error, %Ecto.Changeset{valid?: false, errors: errors}} =
               RepoHostAccount.update_profile(rha, %{login: ""})

      assert {"can't be blank", _} = errors[:login]

      assert {:error, %Ecto.Changeset{valid?: false, errors: errors}} =
               RepoHostAccount.update_profile(rha, %{name: nil})

      assert {"can't be blank", _} = errors[:name]
    end

    test "returns {:error, :stale} when another writer updated the row first", %{rha: rha} do
      # Simulate concurrent writer T1 via the same locked writer so the
      # optimistic-lock bump fires (avoid Repo autogen-on-same-second pitfall).
      {:ok, winner} = RepoHostAccount.update_profile(rha, %{login: "concurrent-winner"})

      assert winner.updated_at != rha.updated_at

      # T2 attempts a write with its stale snapshot — optimistic lock on
      # :updated_at must reject and leave the persisted row untouched.
      assert {:error, :stale} = RepoHostAccount.update_profile(rha, %{login: "stale-loser"})

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.login == "concurrent-winner"
      assert reloaded.updated_at == winner.updated_at
    end
  end

  describe "update_revoke_status/2" do
    setup do
      {user, rha} = Support.Members.insert_user_with_github_account()
      {:ok, user: user, rha: rha}
    end

    test "succeeds on a legacy row where :name is nil (only writes :revoked)", %{rha: rha} do
      {:ok, legacy_rha} =
        rha
        |> Ecto.Changeset.change(%{name: nil})
        |> FrontRepo.update(force: true)

      assert legacy_rha.name == nil
      assert legacy_rha.revoked == false

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(legacy_rha, true)
      assert updated.revoked == true
      assert updated.name == nil

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.revoked == true
      assert reloaded.name == nil
    end
  end

  describe "GitHub account uniqueness" do
    setup do
      {user, rha} = Support.Members.insert_user_with_github_account(github_uid: "10001")
      {:ok, user: user, rha: rha}
    end

    test "create/1 rejects a GitHub uid already connected to another user", %{rha: rha} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(%{
                 login: "other-login",
                 github_uid: rha.github_uid,
                 repo_host: "github",
                 user_id: Ecto.UUID.generate(),
                 name: "Other User",
                 permission_scope: "user:email"
               })

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "create/1 claims the uid and deletes the stale link when the existing one is revoked",
         %{rha: rha} do
      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)

      assert {:ok, claimed} =
               RepoHostAccount.create(%{
                 login: "other-login",
                 github_uid: rha.github_uid,
                 repo_host: "github",
                 user_id: Ecto.UUID.generate(),
                 name: "Other User",
                 permission_scope: "user:email"
               })

      assert claimed.github_uid == rha.github_uid
      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(rha.user_id)
    end

    test "create/1 rejects the uid once it has been claimed away from a revoked link", %{
      rha: rha
    } do
      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)

      {:ok, _claimed} =
        RepoHostAccount.create(%{
          login: "other-login",
          github_uid: rha.github_uid,
          repo_host: "github",
          user_id: Ecto.UUID.generate(),
          name: "Other User",
          permission_scope: "user:email"
        })

      # The original owner reconnecting must not revive the duplicate.
      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(%{
                 login: rha.login,
                 github_uid: rha.github_uid,
                 repo_host: "github",
                 user_id: rha.user_id,
                 name: rha.name,
                 permission_scope: "user:email"
               })

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "update_repo_host_account/4 with reset claims a uid held only by a revoked link", %{
      rha: rha
    } do
      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)

      {other_user, _other_rha} =
        Support.Members.insert_user_with_github_account(github_uid: "10009", login: "claimer")

      assert {:ok, updated} =
               RepoHostAccount.update_repo_host_account(
                 other_user.id,
                 :github,
                 %{
                   github_uid: rha.github_uid,
                   login: "claimer",
                   name: "Claimer",
                   permission_scope: "user:email"
                 },
                 reset: true
               )

      assert updated.github_uid == rha.github_uid
      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(rha.user_id)
    end

    test "create/1 allows the same uid under a different repo_host", %{rha: rha} do
      assert {:ok, _} =
               RepoHostAccount.create(%{
                 login: "other-login",
                 github_uid: rha.github_uid,
                 repo_host: "bitbucket",
                 user_id: Ecto.UUID.generate(),
                 name: "Other User",
                 permission_scope: "user:email"
               })
    end

    test "update_repo_host_account/4 with reset rejects switching to another user's uid", %{
      rha: rha
    } do
      {other_user, _other_rha} =
        Support.Members.insert_user_with_github_account(github_uid: "10002", login: "other")

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.update_repo_host_account(
                 other_user.id,
                 :github,
                 %{
                   github_uid: rha.github_uid,
                   login: "other",
                   name: "Other User",
                   permission_scope: "user:email"
                 },
                 reset: true
               )

      assert RepoHostAccount.uid_taken_error?(changeset)

      {:ok, unchanged} = RepoHostAccount.get_for_github_user(other_user.id)
      assert unchanged.github_uid == "10002"
    end

    test "update_repo_host_account/4 allows reconnecting the user's own uid" do
      {user, rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: "10003",
          login: "reconnect",
          permission_scope: "repo,user:email"
        )

      assert {:ok, updated} =
               RepoHostAccount.update_repo_host_account(
                 user.id,
                 :github,
                 %{
                   github_uid: rha.github_uid,
                   login: rha.login,
                   name: rha.name,
                   token: "refreshed-token",
                   permission_scope: "repo,user:email"
                 },
                 reset: true
               )

      assert updated.github_uid == rha.github_uid
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

  describe "Inspect implementation" do
    test "redacts :token and :refresh_token from inspect output" do
      rha = %RepoHostAccount{
        login: "octocat",
        token: "ghp_super_secret_oauth_token",
        refresh_token: "ghr_super_secret_refresh_token"
      }

      rendered = inspect(rha)

      refute rendered =~ "ghp_super_secret_oauth_token"
      refute rendered =~ "ghr_super_secret_refresh_token"
      assert rendered =~ "octocat"
    end
  end
end
