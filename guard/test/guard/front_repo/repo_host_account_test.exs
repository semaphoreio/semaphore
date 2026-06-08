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
