defmodule Guard.FrontRepo.RepoHostAccountTest do
  use Guard.RepoCase, async: false

  alias Guard.FrontRepo
  alias Guard.FrontRepo.RepoHostAccount
  alias Guard.Utils.OAuth

  # Mock FrontRepo (passthrough) and guarantee it is unloaded after the test,
  # even if the test raises before its own unload.
  defp mock_front_repo! do
    :meck.new(Guard.FrontRepo, [:passthrough])

    on_exit(fn ->
      try do
        :meck.unload(Guard.FrontRepo)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end)
  end

  # Every locked Repo.update loses the optimistic lock (StaleEntryError). Used to
  # drive the token-persist re-apply loop to its terminal compare-and-set path.
  defp stub_repo_update_always_stale! do
    mock_front_repo!()

    :meck.expect(Guard.FrontRepo, :update, fn changeset ->
      raise Ecto.StaleEntryError, action: :update, changeset: changeset
    end)
  end

  defp advisory_lock_count do
    %{rows: [[count]]} =
      Guard.FrontRepo.query!(
        "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid()"
      )

    count
  end

  defp persist_rotated!(rha) do
    RepoHostAccount.persist_refreshed_token(
      rha,
      "rotated_access",
      "rotated_refresh",
      Support.Members.valid_expires_at()
    )
  end

  # Shared setup: a bitbucket RHA with a valid (not-yet-expired) stored token,
  # used by the token-persistence and stale-scoping describes.
  defp create_bitbucket_rha(_context) do
    {:ok, user} = Support.Factories.RbacUser.insert()
    {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

    {:ok, rha} =
      Support.Members.insert_repo_host_account(
        login: "example",
        name: "example",
        repo_host: "bitbucket",
        refresh_token: "stored_refresh",
        user_id: user.id,
        token: "stored_token",
        token_expires_at: Support.Members.valid_expires_at(),
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, rha: rha}
  end

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

  describe "writes to a row a claim deleted after it was read" do
    setup do
      {user, rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: "10301",
          permission_scope: "repo,user:email"
        )

      {:ok, user: user, rha: rha}
    end

    # The caller reads the row, then a claim deletes it before the write. The
    # delete is committed up front and the read is served the stale row.
    defp serve_stale_read!(rha) do
      FrontRepo.delete!(rha)
      mock_front_repo!()

      :meck.expect(Guard.FrontRepo, :one, fn query ->
        if Process.get(:stale_read_served) do
          :meck.passthrough([query])
        else
          Process.put(:stale_read_served, true)
          rha
        end
      end)
    end

    defp oauth_data(rha) do
      %{
        github_uid: rha.github_uid,
        login: rha.login,
        name: rha.name,
        token: "reconnected-token",
        permission_scope: "repo,user:email"
      }
    end

    test "update_repo_host_account/4 reports the uid as taken when the claimer holds it",
         %{user: user, rha: rha} do
      {:ok, _claimer} =
        Support.Members.insert_repo_host_account(
          github_uid: rha.github_uid,
          login: "claimer",
          name: "Claimer",
          permission_scope: "user:email"
        )

      serve_stale_read!(rha)

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.update_repo_host_account(user.id, :github, oauth_data(rha),
                 reset: false
               )

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "update_repo_host_account/4 recreates the link when the uid is free",
         %{user: user, rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

      serve_stale_read!(rha)

      assert {:ok, account} =
               RepoHostAccount.update_repo_host_account(user.id, :github, oauth_data(rha),
                 reset: false
               )

      :meck.unload(Guard.FrontRepo)

      assert account.id != rha.id
      assert account.user_id == user.id
      assert account.github_uid == rha.github_uid
      refute account.revoked
    end

    test "update_repo_host_account/4 handles the row vanishing under a uid reset",
         %{user: user, rha: rha} do
      serve_stale_read!(rha)

      assert {:ok, account} =
               RepoHostAccount.update_repo_host_account(
                 user.id,
                 :github,
                 %{oauth_data(rha) | github_uid: "10302"},
                 reset: true
               )

      :meck.unload(Guard.FrontRepo)

      assert account.github_uid == "10302"
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
      Support.Members.stub_dead_github_token()

      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)
      :ok = Support.Members.age_repo_host_account(rha)

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

    test "a freshly revoked link is not claimable during the grace period", %{rha: rha} do
      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)

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

      # the transiently revoked link is untouched
      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.revoked == true
    end

    # `updated_at` is nullable with no backfill. NULL fails both `>` and `<=`,
    # so before the is_nil/1 guard such a row neither blocked a claim nor was
    # released by it, leaving a duplicate with no sync request enqueued.
    test "a revoked link with no updated_at is claimable and is released", %{rha: rha} do
      Support.Members.stub_dead_github_token()

      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)

      :ok = Support.Members.clear_repo_host_account_timestamp(rha)

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
      Support.Members.stub_dead_github_token()

      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)
      :ok = Support.Members.age_repo_host_account(rha)

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
      Support.Members.stub_dead_github_token()

      {:ok, _} = RepoHostAccount.update_revoke_status(rha, true)
      :ok = Support.Members.age_repo_host_account(rha)

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

    test "a claim holds an advisory lock on its (repo_host, uid) for the transaction" do
      uid = "20002"

      Guard.FrontRepo.transaction(fn ->
        {:ok, _} =
          RepoHostAccount.create(%{
            login: "locker",
            github_uid: uid,
            repo_host: "github",
            user_id: Ecto.UUID.generate(),
            name: "Locker",
            permission_scope: "user:email"
          })

        %{rows: [[count]]} =
          Guard.FrontRepo.query!(
            "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid()"
          )

        assert count > 0
      end)
    end

    test "a revoked link whose token still works is not released" do
      # `revoked` carries false positives latched by an older write path on any
      # 4xx, and those rows still hold working credentials. Deleting one would
      # strand a live account, so a claim must refuse instead.
      {_owner, live} = Support.Members.insert_user_with_github_account(github_uid: "40001")
      {:ok, live} = RepoHostAccount.update_revoke_status(live, true)
      :ok = Support.Members.age_repo_host_account(live)

      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com" <> _} ->
        {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(%{
                 login: "claimer",
                 github_uid: "40001",
                 repo_host: "github",
                 user_id: Ecto.UUID.generate(),
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      assert RepoHostAccount.uid_taken_error?(changeset)
      assert RepoHostAccount.reload(live)
    end

    test "a revoked link is not released when the provider answer is transient" do
      {_owner, unknown} = Support.Members.insert_user_with_github_account(github_uid: "40002")
      {:ok, unknown} = RepoHostAccount.update_revoke_status(unknown, true)
      :ok = Support.Members.age_repo_host_account(unknown)

      # 500 and 403 both classify as transient; neither confirms a dead grant.
      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com" <> _} ->
        {:ok, %Tesla.Env{status: 500, body: %{}}}
      end)

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(%{
                 login: "claimer",
                 github_uid: "40002",
                 repo_host: "github",
                 user_id: Ecto.UUID.generate(),
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      assert RepoHostAccount.uid_taken_error?(changeset)
      assert RepoHostAccount.reload(unknown)
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
    setup do
      {user, rha} = Support.Members.insert_user_with_github_account(github_uid: "10101")
      {:ok, user: user, rha: rha}
    end

    test "update_revoke_status/2 rejects re-activation when the uid is actively held by another user",
         %{rha: rha} do
      {:ok, revoked} = RepoHostAccount.update_revoke_status(rha, true)

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: rha.github_uid,
          login: "current-holder",
          name: "Current Holder",
          permission_scope: "user:email"
        )

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.update_revoke_status(revoked, false)

      assert RepoHostAccount.uid_taken_error?(changeset)

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.revoked == true
    end

    test "update_revoke_status/2 re-activates when the uid is free", %{rha: rha} do
      {:ok, revoked} = RepoHostAccount.update_revoke_status(rha, true)

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false
    end

    test "update_revoke_status/2 re-activation claims a uid held only by revoked links", %{
      rha: rha
    } do
      Support.Members.stub_dead_github_token()

      {:ok, revoked} = RepoHostAccount.update_revoke_status(rha, true)

      {:ok, stale} =
        Support.Members.insert_repo_host_account(
          github_uid: rha.github_uid,
          login: "stale-owner",
          name: "Stale Owner",
          permission_scope: "user:email",
          revoked: true
        )

      :ok = Support.Members.age_repo_host_account(stale)

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false

      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(stale.user_id)
    end

    test "token refresh on a pre-existing active duplicate is not blocked" do
      {user, rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: "10102",
          login: "dup-owner",
          permission_scope: "repo,user:email"
        )

      # tolerated legacy state: two active rows share the uid
      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: rha.github_uid,
          login: "legacy-duplicate",
          name: "Legacy Duplicate",
          permission_scope: "user:email"
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

      assert updated.token == "refreshed-token"
      assert updated.revoked == false
    end

    test "bitbucket links can re-activate even when the uid is actively held" do
      shared_uid = "{30000000-0000-4000-8000-000000000001}"

      {:ok, revoked} =
        Support.Members.insert_repo_host_account(
          github_uid: shared_uid,
          repo_host: "bitbucket",
          login: "bb-revoked",
          name: "BB Revoked",
          permission_scope: "user:email",
          revoked: true
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: shared_uid,
          repo_host: "bitbucket",
          login: "bb-holder",
          name: "BB Holder",
          permission_scope: "user:email"
        )

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false
    end

    test "gitlab links can re-activate even when the uid is actively held" do
      {:ok, revoked} =
        Support.Members.insert_repo_host_account(
          github_uid: "40001",
          repo_host: "gitlab",
          login: "gl-revoked",
          name: "GL Revoked",
          permission_scope: "user:email",
          revoked: true
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: "40001",
          repo_host: "gitlab",
          login: "gl-holder",
          name: "GL Holder",
          permission_scope: "user:email"
        )

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(revoked, false)
      assert updated.revoked == false
    end
  end

  describe "get_github_token/1 revoke classification" do
    test "does not revoke the link when the token refresh is rate-limited" do
      {_user, rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: "10201",
          login: "rate-limited"
        )

      rha = %{rha | refresh_token: "refresh-token"}

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 429, body: %{}}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_github_token(rha)

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.revoked == false
    end

    test "revokes the link when the token refresh is rejected" do
      {_user, rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: "10202",
          login: "rejected",
          # Must be PERSISTED, not just set in memory: the reuse-loser check
          # compares the reloaded row against this snapshot, so an in-memory
          # only refresh_token looks exactly like a concurrent winner having
          # rotated the credential, and the refusal is recovered instead of
          # revoking.
          refresh_token: "refresh-token"
        )

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_github_token(rha)

      {:ok, reloaded} = RepoHostAccount.get_for_github_user(rha.user_id)
      assert reloaded.revoked == true
    end
  end

  describe "get_bitbucket_token/1 (refresh failure classification regression coverage)" do
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

    test "FIXED: bare 403 is transient, row stays unrevoked (was a permanent " <>
           "revoke pre-fix)",
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

    test "FIXED: bare 401 / invalid_client is transient (our client credentials, " <>
           "not a user revoke): row stays unrevoked",
         %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 401, body: %{"error" => "invalid_client"}}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "already-revoked row is not gated: the refresh is attempted and the token returned",
         %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "fresh_token", "expires_in" => 3600}}}
      end)

      assert {:ok, {"fresh_token", _}} = RepoHostAccount.get_bitbucket_token(rha)
    end

    test "already-revoked row with a genuinely dead grant stays revoked", %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
    end

    test "negative cache: a second call within the TTL does not hit the provider",
         %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          flunk("refresh endpoint must not be called again while the negative cache is warm")
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
    end

    test "negative cache: a successful write (reconnect / refresh recovery) invalidates " <>
           "the stale cached failure immediately",
         %{rha: rha} do
      # Warm the negative cache with a transient failure.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      # Simulate a successful write through the same chokepoint reconnect and
      # refresh-self-heal both go through (update_account/2 via update_token/4).
      # Keep the new token already-expired so the next lookup is forced to hit
      # the provider again, instead of short-circuiting on a still-valid token.
      {:ok, healed_rha} =
        RepoHostAccount.update_token(
          rha,
          "healed_token",
          "healed_refresh_token",
          Support.Members.invalid_expires_at()
        )

      # If the stale cache entry weren't purged, this would return the cached
      # {:error, :transient} without ever reaching the mock below.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "fresh_token", "expires_in" => 3600}}}
      end)

      assert {:ok, {"fresh_token", _}} = RepoHostAccount.get_bitbucket_token(healed_rha)
    end

    test "reuse-loser: invalid_grant while a concurrent winner rotated the token does NOT " <>
           "revoke - the winner's token is returned",
         %{rha: rha} do
      # A sibling worker (the winner) rotates the token first.
      {:ok, _winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      # This worker (the loser) still holds the pre-rotation snapshot and its
      # refresh reuses the now-burned old token, so Bitbucket answers
      # invalid_grant. That must NOT revoke a healthy account.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:ok, {"winner_token", _}} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
      assert reloaded.token == "winner_token"
      assert reloaded.refresh_token == "winner_refresh"
    end

    test "genuine invalid_grant with NO concurrent winner STILL revokes", %{rha: rha} do
      # No sibling rotated anything - the stored token is the same one the
      # provider just rejected, so this is a real revocation.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
    end

    test "revoke race: a winner committing AFTER the loser's reload (locked revoke stales) " <>
           "does NOT revoke - the loser recovers the winner's token",
         %{rha: rha} do
      # The loser's refresh classifies invalid_grant. Simulate a winner
      # committing in the gap between the loser's reload and its LOCKED revoke
      # write: intercept the revoke write, commit the winner's rotation, then
      # fail the write exactly as the optimistic lock would on a concurrent
      # commit. The loser must re-evaluate once, see the rotation, and recover
      # instead of flipping revoked:true or returning :revoked.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      mock_front_repo!()

      # The only FrontRepo.update/1 in this flow is the locked revoke write.
      # Commit the winner's rotation via raw SQL (bypasses the mocked update),
      # then fail this write exactly as the optimistic lock would.
      :meck.expect(Guard.FrontRepo, :update, fn revoke_changeset ->
        Ecto.Adapters.SQL.query!(
          Guard.FrontRepo,
          "UPDATE repo_host_accounts SET token = $1, refresh_token = $2, " <>
            "token_expires_at = now() + interval '1 hour', updated_at = now() " <>
            "WHERE id::text = $3",
          ["winner_token", "winner_refresh", rha.id]
        )

        raise Ecto.StaleEntryError, action: :update, changeset: revoke_changeset
      end)

      assert {:ok, {"winner_token", _}} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
      assert reloaded.token == "winner_token"
      assert reloaded.refresh_token == "winner_refresh"
    end

    test "a FAILED revoke persist reports :transient, not :revoked (write result " <>
           "must not be discarded)",
         %{rha: rha} do
      # Genuine invalid_grant, no concurrent winner -> a real revocation is
      # attempted. But the revoke DB write fails (non-stale changeset error).
      # We must NOT report {:error, :revoked}: that signals a permanent
      # disconnect (gRPC NOT_FOUND) the DB never actually recorded. The failed
      # write result must not be discarded - degrade to :transient.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      mock_front_repo!()

      # The only FrontRepo.update/1 in this flow is the locked revoke write.
      # Fail it with a changeset error (not StaleEntryError).
      :meck.expect(Guard.FrontRepo, :update, fn revoke_changeset ->
        {:error, Ecto.Changeset.add_error(revoke_changeset, :revoked, "boom")}
      end)

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      # The revoke never persisted, so the row must stay unrevoked.
      refute reloaded.revoked
    end
  end

  describe "update_token/4 self-heal (clears a stale revoked flag on success)" do
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

    test "refreshed credentials are persisted even when the unrevoke is refused" do
      # Another user actively holds the uid, so this revoked github row may not
      # self-heal. The credentials must still be stored: GitHub rotates refresh
      # tokens, and dropping the new one replays a stale token until the grant
      # dies for good.
      {:ok, holder} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Members.insert_user(id: holder.id, email: holder.email, name: holder.name)

      {:ok, _active} =
        Support.Members.insert_repo_host_account(
          login: "holder",
          name: "holder",
          repo_host: "github",
          github_uid: "91001",
          user_id: holder.id,
          token: "holder_token",
          revoked: false,
          permission_scope: "repo"
        )

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "github",
          github_uid: "91001",
          refresh_token: "stale_refresh_token",
          user_id: user.id,
          token: "expired_token",
          token_expires_at: Support.Members.invalid_expires_at(),
          revoked: true,
          permission_scope: "repo"
        )

      assert {:ok, updated} =
               RepoHostAccount.update_token(
                 rha,
                 "new_token",
                 "rotated_refresh_token",
                 DateTime.utc_now()
               )

      # the flag stays latched, but the new credentials are on the row
      assert updated.revoked == true
      assert updated.token == "new_token"
      assert updated.refresh_token == "rotated_refresh_token"

      reloaded = Guard.FrontRepo.get(RepoHostAccount, rha.id)
      assert reloaded.revoked == true
      assert reloaded.token == "new_token"
      assert reloaded.refresh_token == "rotated_refresh_token"
    end
  end

  describe "update_token/4 refresh-token safety (single-use rotation)" do
    setup :create_bitbucket_rha

    test "rotates the stored refresh_token when a new one is supplied", %{rha: rha} do
      {:ok, _} =
        RepoHostAccount.update_token(
          rha,
          "rotated_token",
          "rotated_refresh",
          Support.Members.valid_expires_at()
        )

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_token"
      assert reloaded.refresh_token == "rotated_refresh"
    end

    test "leaves the stored refresh_token UNTOUCHED when refresh_token is nil", %{rha: rha} do
      {:ok, _} =
        RepoHostAccount.update_token(
          rha,
          "rotated_token",
          nil,
          Support.Members.valid_expires_at()
        )

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_token"
      # The stored refresh_token must NOT be nulled or clobbered.
      assert reloaded.refresh_token == "stored_refresh"
    end

    test "leaves the stored refresh_token UNTOUCHED when refresh_token is empty string",
         %{rha: rha} do
      {:ok, _} =
        RepoHostAccount.update_token(rha, "rotated_token", "", Support.Members.valid_expires_at())

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.refresh_token == "stored_refresh"
    end

    test "optimistic lock: a stale writer does NOT overwrite the winner's rotated token",
         %{rha: rha} do
      # Winner commits a rotation first through the same locked writer, so the
      # optimistic-lock bump on :updated_at fires.
      {:ok, winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      assert winner.updated_at != rha.updated_at

      # Loser writes with its now-stale snapshot (original updated_at) and must
      # lose the race rather than clobber the freshly-rotated token.
      assert {:error, :stale} =
               RepoHostAccount.update_token(
                 rha,
                 "loser_token",
                 "loser_refresh",
                 Support.Members.valid_expires_at()
               )

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "winner_token"
      assert reloaded.refresh_token == "winner_refresh"
    end

    test "handle_ok_token_response recovers the winner's token after losing the write race",
         %{rha: rha} do
      # Winner rotates first; row's updated_at advances past the loser's snapshot.
      {:ok, _winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      # The loser processes its (older) 2xx response using the stale rha
      # struct. The write hits StaleEntryError, the loser DISCARDS its own
      # response, re-reads, and returns the winner's still-valid token.
      loser_body =
        Jason.encode!(%{
          "access_token" => "loser_token",
          "refresh_token" => "loser_refresh",
          "expires_in" => 3600
        })

      assert {:ok, {"winner_token", _expires_at}} =
               OAuth.handle_ok_token_response(rha, loser_body)

      # The winner's rotated refresh_token survived; the loser's was discarded.
      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "winner_token"
      assert reloaded.refresh_token == "winner_refresh"
    end

    test "unrelated column write (bumps :updated_at) does NOT strand the rotated " <>
           "refresh_token - it is re-applied, not discarded",
         %{rha: rha} do
      # The bug: the write is optimistic-locked on :updated_at, so ANY unrelated
      # writer (profile sync, revoke flip) that advances :updated_at while a
      # refresh is in flight makes the token write lose the lock. Pre-fix, the
      # freshly-rotated single-use refresh_token was then DISCARDED and the
      # reload returned the already-burned old token = a permanent strand.
      #
      # Here an unrelated profile write commits first, advancing :updated_at.
      # `rha` is now a stale snapshot. Persisting our rotation with it must
      # re-apply the new token (credential unchanged vs our snapshot), never
      # discard it.
      {:ok, profile_winner} = RepoHostAccount.update_profile(rha, %{login: "profile-updated"})
      assert profile_winner.updated_at != rha.updated_at

      rotated_body =
        Jason.encode!(%{
          "access_token" => "rotated_access",
          "refresh_token" => "rotated_refresh",
          "expires_in" => 3600
        })

      assert {:ok, {"rotated_access", _}} = OAuth.handle_ok_token_response(rha, rotated_body)

      reloaded = RepoHostAccount.reload(rha)
      # The rotated single-use refresh_token survived the lost lock.
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "rotated_refresh"
      # The unrelated write was preserved, not clobbered.
      assert reloaded.login == "profile-updated"
      refute reloaded.revoked
    end

    test "terminal fallback persists the rotated token via credential CAS after repeated " <>
           "lock losses",
         %{rha: rha} do
      # Force the bounded re-apply to exhaust (>= @max_token_persist_attempts):
      # every locked Repo.update loses the optimistic lock, while the credential
      # stays unchanged at each reload. The terminal compare-and-set (update_all,
      # left to pass through) must then persist the rotated token.
      stub_repo_update_always_stale!()

      assert {:ok, {"rotated_access", _}} = persist_rotated!(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "rotated_refresh"
      refute reloaded.revoked
    end

    test "terminal fallback: a reconnect winning the CAS gap is NOT clobbered - recover it",
         %{rha: rha} do
      # Same exhaustion, but a reconnect commits a brand-new (independent-family)
      # credential in the gap between the final reload and the CAS. The CAS is
      # scoped to the reloaded credential, so it matches zero rows: we must
      # recover the winner's token, never clobber it with our now-superseded one.
      stub_repo_update_always_stale!()

      :meck.expect(Guard.FrontRepo, :update_all, fn query, opts ->
        Ecto.Adapters.SQL.query!(
          Guard.FrontRepo,
          "UPDATE repo_host_accounts SET token = $1, refresh_token = $2, " <>
            "token_expires_at = now() + interval '1 hour', updated_at = now() " <>
            "WHERE id::text = $3",
          ["winner_token", "winner_refresh", rha.id]
        )

        :meck.passthrough([query, opts])
      end)

      assert {:ok, {"winner_token", _}} = persist_rotated!(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = RepoHostAccount.reload(rha)
      # The reconnect's credential survived; our old rotation did not clobber it.
      assert reloaded.token == "winner_token"
      assert reloaded.refresh_token == "winner_refresh"
      refute reloaded.revoked
    end
  end

  describe "terminal compare-and-set fallback and GitHub uid uniqueness" do
    setup do
      {_user, rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: "10201",
          token: "stored_token",
          refresh_token: "stored_refresh",
          token_expires_at: Support.Members.valid_expires_at()
        )

      {:ok, rha: rha}
    end

    defp insert_other_link(rha, attrs) do
      {:ok, other} =
        Support.Members.insert_repo_host_account(
          Keyword.merge(
            [
              github_uid: rha.github_uid,
              login: "other-owner",
              name: "Other Owner",
              permission_scope: "user:email"
            ],
            attrs
          )
        )

      other
    end

    test "keeps a revoked row revoked when another user actively holds the uid", %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)
      holder = insert_other_link(rha, revoked: false)

      stub_repo_update_always_stale!()

      assert {:ok, {"rotated_access", _}} = persist_rotated!(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "rotated_refresh"
      assert reloaded.revoked
      refute RepoHostAccount.reload(holder).revoked
    end

    test "a compare-and-set that is not un-revoking takes no uid lock" do
      # The refresh hot path must stay lock-free.
      {_user, rha} = Support.Members.insert_user_with_github_account(github_uid: "50002")
      refute rha.revoked

      stub_repo_update_always_stale!()

      Guard.FrontRepo.transaction(fn ->
        before = advisory_lock_count()
        assert {:ok, {"rotated_access", _}} = persist_rotated!(rha)

        assert advisory_lock_count() == before
      end)
    end

    test "keeps a revoked row revoked and releases nothing when only a stale revoked link " <>
           "shares the uid",
         %{rha: rha} do
      Support.Members.stub_dead_github_token()

      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)
      stale = insert_other_link(rha, revoked: true)
      :ok = Support.Members.age_repo_host_account(stale)

      stub_repo_update_always_stale!()

      assert {:ok, {"rotated_access", _}} = persist_rotated!(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_access"
      assert reloaded.revoked
      assert %RepoHostAccount{revoked: true} = RepoHostAccount.reload(stale)
    end

    test "un-revokes a revoked row whose uid is free", %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

      stub_repo_update_always_stale!()

      assert {:ok, {"rotated_access", _}} = persist_rotated!(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_access"
      refute reloaded.revoked
    end

    test "a pre-existing active duplicate stays active", %{rha: rha} do
      duplicate = insert_other_link(rha, revoked: false)

      stub_repo_update_always_stale!()

      assert {:ok, {"rotated_access", _}} = persist_rotated!(rha)

      :meck.unload(Guard.FrontRepo)

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_access"
      refute reloaded.revoked
      refute RepoHostAccount.reload(duplicate).revoked
    end
  end

  describe "StaleEntryError translation is scoped to LOCKED writes" do
    setup :create_bitbucket_rha

    test "a LOCKED write returns {:error, :stale} when the row vanished under it", %{rha: rha} do
      # A locked writer (the token path) expects and handles {:error, :stale}.
      FrontRepo.delete!(rha)

      assert {:error, :stale} =
               RepoHostAccount.update_token(
                 rha,
                 "rotated_token",
                 "rotated_refresh",
                 Support.Members.valid_expires_at()
               )
    end

    test "an UNLOCKED write to a deleted row returns {:error, :not_found}, not :stale",
         %{rha: rha} do
      # A claim deletes other users' revoked rows, so an unlocked writer can
      # lose its row between read and write. That is not a lost lock race.
      FrontRepo.delete!(rha)

      assert {:error, :not_found} = RepoHostAccount.update_revoke_status(rha, true)
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

    test "reuse-loser: invalid_grant while a concurrent winner rotated the token does NOT " <>
           "revoke - the winner's token is returned" do
      # GitHub tokens do not expire, so token_expires_at is nil and counts as
      # valid - insert such a row explicitly to exercise the recover branch.
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, rha} =
        Support.Members.insert_repo_host_account(
          login: "example",
          name: "example",
          repo_host: "github",
          refresh_token: "dead_refresh",
          user_id: user.id,
          token: "dead_token",
          token_expires_at: nil,
          revoked: false,
          permission_scope: "repo"
        )

      # A sibling worker rotates the token first (still non-expiring).
      {:ok, _winner} = RepoHostAccount.update_token(rha, "winner_token", "winner_refresh", nil)

      Tesla.Mock.mock_global(fn
        # The loser's stale token fails validation, forcing a refresh...
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        # ...and the refresh reuses the burned token -> invalid_grant. That
        # must NOT revoke a healthy account.
        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:ok, {"winner_token", nil}} = RepoHostAccount.get_github_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
      assert reloaded.token == "winner_token"
      assert reloaded.refresh_token == "winner_refresh"
    end
  end

  describe "get_github_token/1 (revoked flag must not gate the fetch)" do
    test "revoked:true row whose stored token still validates returns that token" do
      {_user, rha} =
        Support.Members.insert_user_with_github_account(revoked: true, token: "stored_token")

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          flunk("must not attempt a refresh while the stored token still validates")
      end)

      assert {:ok, {"stored_token", nil}} = RepoHostAccount.get_github_token(rha)
    end

    test "revoked:true row with a genuinely dead grant still returns :revoked and stays revoked" do
      {_user, rha} =
        Support.Members.insert_user_with_github_account(
          revoked: true,
          token: "dead_token",
          refresh_token: "dead_refresh_token"
        )

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
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

    test "reuse-loser: invalid_grant while a concurrent winner rotated the token does NOT " <>
           "revoke - the winner's token is returned",
         %{rha: rha} do
      # GitLab does strict single-use rotation with reuse-detection, so a
      # concurrent loser gets invalid_grant on the burned token now.
      {:ok, _winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:ok, {"winner_token", _}} = RepoHostAccount.get_gitlab_token(rha)

      reloaded = FrontRepo.get!(RepoHostAccount, rha.id)
      refute reloaded.revoked
      assert reloaded.token == "winner_token"
    end

    test "already-revoked row is not gated: the refresh is attempted and the token returned",
         %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "fresh_token", "expires_in" => 3600}}}
      end)

      assert {:ok, {"fresh_token", _}} = RepoHostAccount.get_gitlab_token(rha)
    end

    test "already-revoked row with a genuinely dead grant stays revoked", %{rha: rha} do
      {:ok, rha} = RepoHostAccount.update_revoke_status(rha, true)

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
