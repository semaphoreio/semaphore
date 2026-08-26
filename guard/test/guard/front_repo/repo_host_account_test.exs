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

  describe "get_bitbucket_token/1 (Bitbucket refresh - transient vs revoked; see bitbucket-oauth incident doc)" do
    setup do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "expired_token",
          token_expires_at: Support.Members.invalid_expires_at(),
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, rha: rha}
    end

    test "FIXED: a bare 403 with empty body on refresh is transient, row stays " <>
           "unrevoked (used to be a permanent revoke pre-fix)",
         %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end
  end

  describe "get_bitbucket_token/1 desired post-fix behavior (regression coverage)" do
    setup do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "expired_token",
          token_expires_at: Support.Members.invalid_expires_at(),
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, rha: rha}
    end

    test "bare 403 (Atlassian identity-proxy block, no OAuth error body) is " <>
           "transient: row stays unrevoked",
         %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "429 (rate limited) is transient: row stays unrevoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 429, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "network error talking to Bitbucket is transient: row stays unrevoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:error, :timeout}
      end)

      assert {:error, :network_error} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "genuine 400 invalid_grant IS a real revocation: row gets revoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 400,
             body: %{"error" => "invalid_grant", "error_description" => "Invalid refresh_token"}
           }}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
    end

    test "401 unauthorized IS a real revocation: row gets revoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 401, body: %{"error" => "invalid_client"}}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
    end

    test "already-revoked row short-circuits: no refresh call is made", %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          flunk("refresh endpoint must not be called for an already-revoked account")
      end)

      assert {:error, :revoked} = RepoHostAccount.get_bitbucket_token(rha)
    end
  end

  describe "update_token/4 self-heal (see bitbucket-oauth incident doc)" do
    test "a successful token write clears a previously-latched revoked flag" do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "bitbucket",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "expired_token",
          token_expires_at: Support.Members.invalid_expires_at(),
          revoked: true,
          permission_scope: "repo"
        )

      assert rha.revoked == true

      {:ok, updated} =
        RepoHostAccount.update_token(rha, "new_token", "new_refresh_token", DateTime.utc_now())

      assert updated.revoked == false
    end
  end

  describe "get_github_token/1 (GitHub refresh - transient vs revoked)" do
    setup do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "github",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "expired_token",
          token_expires_at: Support.Members.invalid_expires_at(),
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, rha: rha}
    end

    test "bare 403 on refresh is transient: row stays unrevoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_github_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "genuine 401 on refresh IS a real revocation: row gets revoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 401, body: %{"error" => "bad_refresh_token"}}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_github_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
    end
  end

  describe "get_gitlab_token/1 (GitLab refresh - transient vs revoked)" do
    setup do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "gitlab",
          refresh_token: "example_refresh_token",
          user_id: user.id,
          token: "expired_token",
          token_expires_at: Support.Members.invalid_expires_at(),
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, rha: rha}
    end

    test "bare 403 on refresh is transient: row stays unrevoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_gitlab_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "genuine 400 invalid_grant IS a real revocation: row gets revoked", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_gitlab_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
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
