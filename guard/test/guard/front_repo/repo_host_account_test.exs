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

  defp persist_rotated!(rha) do
    RepoHostAccount.persist_refreshed_token(
      rha,
      "rotated_access",
      "rotated_refresh",
      Support.Members.valid_expires_at()
    )
  end

  # Shared factory for the token-fetch describes: one user plus one
  # repo_host_account with the given credential shape. Kept in one place so the
  # per-describe setups stay a single line of intent.
  defp insert_rha!(overrides) do
    {:ok, user} = Support.Factories.RbacUser.insert()
    {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

    defaults = [
      login: "example",
      name: "example",
      user_id: user.id,
      revoked: false,
      permission_scope: "repo"
    ]

    {:ok, rha} = Support.Members.insert_repo_host_account(Keyword.merge(defaults, overrides))

    rha
  end

  # A stored bitbucket account for the reconnect tests, plus the reconnect call
  # itself (the shape Guard.Id.Api's OAuth callback makes: reset: false).
  defp insert_stored_account!(user_id, overrides) do
    {:ok, account} =
      Support.Members.insert_repo_host_account(
        Keyword.merge(
          [
            login: "example",
            name: "example",
            repo_host: "bitbucket",
            user_id: user_id,
            token: "dead_token",
            refresh_token: "dead_refresh",
            token_expires_at: Support.Members.invalid_expires_at()
          ],
          overrides
        )
      )

    account
  end

  defp reconnect(user_id, github_uid) do
    RepoHostAccount.update_repo_host_account(
      user_id,
      :bitbucket,
      %{
        github_uid: github_uid,
        login: "example",
        name: "example",
        token: "reconnected_token",
        refresh_token: "reconnected_refresh",
        token_expires_at: Support.Members.valid_expires_at()
      },
      reset: false
    )
  end

  defp expired_credentials(repo_host, refresh_token) do
    [
      repo_host: repo_host,
      refresh_token: refresh_token,
      token: "expired_token",
      token_expires_at: Support.Members.invalid_expires_at()
    ]
  end

  # Shared setup: a bitbucket RHA with a valid (not-yet-expired) stored token,
  # used by the token-persistence and stale-scoping describes.
  defp create_bitbucket_rha(_context) do
    rha =
      insert_rha!(
        repo_host: "bitbucket",
        refresh_token: "stored_refresh",
        token: "stored_token",
        token_expires_at: Support.Members.valid_expires_at()
      )

    {:ok, rha: rha}
  end

  defp safe_unload(mod) do
    :meck.unload(mod)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  # Replace the cross-replica refresh lock with `impl`, so the winner / waiter
  # branches can be driven deterministically from a single test connection
  # (advisory locks are re-entrant within one Postgres session, so a second
  # checkout here would always win).
  defp mock_advisory_lock!(impl) do
    :meck.new(Guard.FrontRepo.AdvisoryLock, [:passthrough])
    on_exit(fn -> safe_unload(Guard.FrontRepo.AdvisoryLock) end)
    :meck.expect(Guard.FrontRepo.AdvisoryLock, :transaction, impl)
  end

  # Lose the lock for the first `busy_attempts` tries, then behave normally.
  defp mock_advisory_lock_busy_then_passthrough!(busy_attempts) do
    counter = :counters.new(1, [])

    mock_advisory_lock!(fn key, fun ->
      :counters.add(counter, 1, 1)

      if :counters.get(counter, 1) <= busy_attempts do
        :busy
      else
        :meck.passthrough([key, fun])
      end
    end)
  end

  # Any POST to a provider token endpoint fails the test. Used to prove a call
  # path reached a token WITHOUT presenting a refresh token upstream - which is
  # the reuse that gets the whole token family revoked.
  defp refuse_provider_call! do
    Tesla.Mock.mock_global(fn %{method: method, url: url} ->
      flunk("unexpected provider call: #{method} #{url}")
    end)
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

  describe "get_bitbucket_token/1 (refresh failure classification regression coverage)" do
    setup do
      {:ok, rha: insert_rha!(expired_credentials("bitbucket", "example_refresh_token"))}
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

      # This worker (the loser) still holds the pre-rotation snapshot. Before
      # the refresh single-flight it would reuse the now-burned old token and
      # have to recover from the resulting invalid_grant; now the in-lock
      # re-read sees the winner's token and the reuse never reaches Bitbucket
      # at all - which is what stops the whole token family being revoked
      # minutes later. Either way the account must NOT be revoked.
      refuse_provider_call!()

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

  describe "get_bitbucket_token/1 single-flight (one provider POST per account)" do
    setup do
      rha = insert_rha!(expired_credentials("bitbucket", "stored_refresh"))

      # Drive the waiter loop without real sleeps.
      previous = Application.get_env(:guard, :oauth_refresh_wait_backoff_ms)
      Application.put_env(:guard, :oauth_refresh_wait_backoff_ms, [1, 1, 1])

      on_exit(fn ->
        if is_nil(previous) do
          Application.delete_env(:guard, :oauth_refresh_wait_backoff_ms)
        else
          Application.put_env(:guard, :oauth_refresh_wait_backoff_ms, previous)
        end
      end)

      {:ok, rha: rha}
    end

    test "a usable stored token is served without taking the lock at all", %{rha: rha} do
      # The hot path must not pay for a lock - which would mean holding one of
      # the few pooled Front-DB connections - when nothing needs refreshing.
      usable = Map.put(rha, :token_expires_at, Support.Members.valid_expires_at())

      mock_advisory_lock!(fn _key, _fun -> flunk("must not lock on the hot path") end)
      refuse_provider_call!()

      assert {:ok, {"expired_token", _}} = RepoHostAccount.get_bitbucket_token(usable)
    end

    test "the in-lock re-read serves a winner's token WITHOUT a second provider POST",
         %{rha: rha} do
      # This is the fix. Our snapshot is stale, so we contend for the lock -
      # but by the time we hold it a sibling worker has already stored a fresh
      # token. Presenting our own (already-rotated) refresh_token at this point
      # is the reuse that makes Bitbucket revoke the whole token family minutes
      # later, so the re-read has to short-circuit before any POST.
      {:ok, _winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      refuse_provider_call!()

      assert {:ok, {"winner_token", _}} = RepoHostAccount.get_bitbucket_token(rha)
    end

    test "two refreshes of the same account make exactly ONE provider POST", %{rha: rha} do
      # The direct form of the assertion the other tests make indirectly: count
      # the calls. Every extra POST here is one reuse of an already-rotated
      # refresh token, and Bitbucket answers reuse with 200 before revoking the
      # whole family minutes later.
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          Agent.update(calls, &(&1 + 1))

          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "access_token" => "rotated_token",
                 "refresh_token" => "rotated_refresh_token",
                 "expires_in" => 7200
               })
           }}
      end)

      assert {:ok, {"rotated_token", _}} = RepoHostAccount.get_bitbucket_token(rha)

      # The caller still holds the stale struct carrying the expired expiry, so
      # it contends for the lock again - and the in-lock re-read has to hand
      # back what the first call persisted rather than rotate a second time.
      assert {:ok, {"rotated_token", _}} = RepoHostAccount.get_bitbucket_token(rha)

      assert Agent.get(calls, & &1) == 1

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_token"
      assert reloaded.refresh_token == "rotated_refresh_token"
      refute reloaded.revoked
    end

    test "a waiter that loses the lock releases it, backs off, and serves the winner's token",
         %{rha: rha} do
      # The lock is held elsewhere for the whole call, so we never run under
      # it: the only way to a token is the post-backoff re-read.
      mock_advisory_lock!(fn _key, _fun -> :busy end)
      refuse_provider_call!()

      {:ok, _winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      assert {:ok, {"winner_token", _}} = RepoHostAccount.get_bitbucket_token(rha)
    end

    test "a waiter becomes the winner when the lock frees up but no token was published",
         %{rha: rha} do
      # A winner that died mid-refresh must not strand every waiter behind it:
      # the next attempt takes the lock and does the POST itself.
      mock_advisory_lock_busy_then_passthrough!(1)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "access_token" => "rotated_access",
                 "refresh_token" => "rotated_refresh",
                 "expires_in" => 3600
               })
           }}
      end)

      assert {:ok, {"rotated_access", _}} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = RepoHostAccount.reload(rha)
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "rotated_refresh"
    end

    test "a waiter that never sees a usable token degrades to :transient, never :revoked",
         %{rha: rha} do
      mock_advisory_lock!(fn _key, _fun -> :busy end)
      refuse_provider_call!()

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      # Losing a lock race says nothing about the grant.
      refute RepoHostAccount.reload(rha).revoked
    end

    test "a failed lock transaction reports :transient, never :revoked", %{rha: rha} do
      # An infrastructure failure (pool checkout, lock_timeout, dropped
      # connection) must not surface as gRPC NOT_FOUND, which repository_hub
      # treats as a permanent disconnect.
      mock_advisory_lock!(fn _key, _fun -> {:error, :rollback} end)
      refuse_provider_call!()

      assert {:error, :transient} = RepoHostAccount.get_bitbucket_token(rha)

      refute RepoHostAccount.reload(rha).revoked
    end

    test "a genuine revocation is still detected and persisted under the lock", %{rha: rha} do
      # The revoke write now runs inside the locked transaction - it must still
      # commit.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: Jason.encode!(%{"error" => "invalid_grant"})}}
      end)

      assert {:error, :revoked} = RepoHostAccount.get_bitbucket_token(rha)
      assert RepoHostAccount.reload(rha).revoked == true
    end

    test "a writer that commits AFTER the in-lock re-read is still recovered, not revoked",
         %{rha: rha} do
      # Reconnect (Guard.Id.Api) does not go through this lock, so it can still
      # land a new credential while a refresh is in flight. That residual race
      # is what revoke_or_recover/1 exists for - assert it survives the
      # single-flight change.
      :meck.new(Guard.Api.Bitbucket, [:passthrough])
      on_exit(fn -> safe_unload(Guard.Api.Bitbucket) end)

      :meck.expect(Guard.Api.Bitbucket, :user_token, fn _rha ->
        Ecto.Adapters.SQL.query!(
          Guard.FrontRepo,
          "UPDATE repo_host_accounts SET token = $1, refresh_token = $2, " <>
            "token_expires_at = now() + interval '1 hour', updated_at = now() " <>
            "WHERE id::text = $3",
          ["reconnect_token", "reconnect_refresh", rha.id]
        )

        {:error, :revoked}
      end)

      assert {:ok, {"reconnect_token", _}} = RepoHostAccount.get_bitbucket_token(rha)

      reloaded = RepoHostAccount.reload(rha)
      refute reloaded.revoked
      assert reloaded.token == "reconnect_token"
    end
  end

  describe "get_github_token/1 is deliberately not single-flighted" do
    setup do
      rha =
        insert_rha!(
          repo_host: "github",
          refresh_token: "example_refresh_token",
          token: "token",
          token_expires_at: nil
        )

      {:ok, rha: rha}
    end

    test "never takes the refresh lock", %{rha: rha} do
      # GitHub does not rotate the refresh token on an ordinary refresh, so
      # there is no token family to lose - and its user_token/1 validates
      # against the API on EVERY call, so locking it would hold a pooled
      # connection on the hot path for no benefit.
      mock_advisory_lock!(fn _key, _fun -> flunk("github must not take the refresh lock") end)

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, {"token", nil}} = RepoHostAccount.get_github_token(rha)
    end
  end

  describe "pool-checkout failures degrade to :transient (never INTERNAL)" do
    setup :create_bitbucket_rha

    test "a raising persistence path is caught and negative-cached", %{rha: rha} do
      # The persistence path raises this under fan-out. Left to propagate it
      # crosses the gRPC boundary as INTERNAL and escapes BEFORE the negative
      # cache entry is written, so repository_hub retries straight back into an
      # already saturated pool.
      Cachex.del(:oauth_refresh_failure_cache, rha.id)

      :meck.new(Guard.Api.Github, [:passthrough])
      on_exit(fn -> safe_unload(Guard.Api.Github) end)

      :meck.expect(Guard.Api.Github, :user_token, fn _rha ->
        raise DBConnection.ConnectionError, "connection not available"
      end)

      github = Map.put(rha, :repo_host, "github")

      assert {:error, :transient} = RepoHostAccount.get_github_token(github)

      # The point of catching it: the failure is now cached, so the next call
      # backs off instead of re-entering the pool.
      assert {:ok, {:error, :transient}} = Cachex.get(:oauth_refresh_failure_cache, rha.id)
    end

    test "an unrelated exception still propagates", %{rha: rha} do
      # The rescue is scoped to connection failures on purpose - a bug must not
      # be silently downgraded to a retry.
      Cachex.del(:oauth_refresh_failure_cache, rha.id)

      :meck.new(Guard.Api.Github, [:passthrough])
      on_exit(fn -> safe_unload(Guard.Api.Github) end)
      :meck.expect(Guard.Api.Github, :user_token, fn _rha -> raise "boom" end)

      github = Map.put(rha, :repo_host, "github")

      assert_raise RuntimeError, "boom", fn -> RepoHostAccount.get_github_token(github) end
    end
  end

  describe "update_token/4 self-heal (clears a stale revoked flag on success)" do
    test "a successful token write clears a previously-latched revoked flag" do
      rha =
        insert_rha!(expired_credentials("bitbucket", "example_refresh_token") ++ [revoked: true])

      assert rha.revoked == true

      {:ok, updated} =
        RepoHostAccount.update_token(rha, "new_token", "new_refresh_token", DateTime.utc_now())

      assert updated.revoked == false
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

    test "an UNLOCKED write does NOT return {:error, :stale} - it re-raises, so the " <>
           "unlocked callers' changeset contract is preserved",
         %{rha: rha} do
      # update_revoke_status/2 (and update_existing_account/3) are unlocked. They
      # pattern-match {:ok, _} | {:error, changeset}; leaking an undeclared
      # {:error, :stale} would be mishandled downstream (e.g. actions.ex does
      # changeset.errors). The rescue must NOT translate for them - it re-raises
      # exactly as before this PR.
      FrontRepo.delete!(rha)

      assert_raise Ecto.StaleEntryError, fn ->
        RepoHostAccount.update_revoke_status(rha, true)
      end
    end
  end

  describe "get_github_token/1 (GitHub refresh - transient vs revoked)" do
    setup do
      {:ok, rha: insert_rha!(expired_credentials("github", "example_refresh_token"))}
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
      rha =
        insert_rha!(
          repo_host: "github",
          refresh_token: "dead_refresh",
          token: "dead_token",
          token_expires_at: nil
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
      {:ok, rha: insert_rha!(expired_credentials("gitlab", "example_refresh_token"))}
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
      # concurrent loser that reused the burned token would get invalid_grant.
      # With the refresh single-flight in place the in-lock re-read serves the
      # winner's token and the reuse is never presented upstream.
      {:ok, _winner} =
        RepoHostAccount.update_token(
          rha,
          "winner_token",
          "winner_refresh",
          Support.Members.valid_expires_at()
        )

      refuse_provider_call!()

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

  describe "skip_credentials?/2" do
    test "skips only a genuine narrowing of the stored scope" do
      assert RepoHostAccount.skip_credentials?("repo,user:email", "public_repo,user:email")
      assert RepoHostAccount.skip_credentials?("public_repo,user:email", "user:email")

      refute RepoHostAccount.skip_credentials?("user:email", "repo,user:email")
      refute RepoHostAccount.skip_credentials?("repo,user:email", "repo,user:email")
    end

    test "never skips when either scope is unrecognised" do
      # `Enum.find_index/2` returns nil for an unknown scope and `nil > 0` is
      # true in Erlang term order, so this used to answer "skip" for any row
      # whose stored scope was outside the (GitHub-vocabulary) known set -
      # silently discarding the freshly minted token, refresh_token and expiry
      # while the connect callback still redirected with status=success.
      refute RepoHostAccount.skip_credentials?("account repository webhook", "repo,user:email")
      refute RepoHostAccount.skip_credentials?("repo", "repo,user:email")
      refute RepoHostAccount.skip_credentials?("repo,user:email", "account")
    end
  end

  describe "update_repo_host_account/4 credential persistence on reconnect" do
    setup do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

      {:ok, user_id: user.id}
    end

    test "a reconnect STORES the new credentials on a row holding a provider-native scope",
         %{user_id: user_id} do
      # The regression this guards: @scopes_in_order is GitHub vocabulary, so a
      # bitbucket row carrying a bitbucket scope string had no rank and the
      # nil-vs-integer comparison dropped the whole credential set from the
      # write - while the caller still saw {:ok, _} and the user was told the
      # reconnect succeeded.
      insert_stored_account!(user_id,
        github_uid: "bb-uid",
        permission_scope: "account repository webhook",
        revoked: true
      )

      {:ok, _} = reconnect(user_id, "bb-uid")

      {:ok, reloaded} = RepoHostAccount.get_for_user_by_repo_host(user_id, "bitbucket")
      assert reloaded.token == "reconnected_token"
      assert reloaded.refresh_token == "reconnected_refresh"
      refute reloaded.revoked
    end

    test "a reconnect whose uid does not match is still a silent no-op, but now logs it",
         %{user_id: user_id} do
      # Behaviour deliberately unchanged: reset: false drops the write and the
      # callback still reports success. Asserted here so the no-op is on the
      # record, with a log line to find it by - deciding between failing the
      # callback and adopting the new uid needs production data first.
      insert_stored_account!(user_id,
        github_uid: "old-uid",
        permission_scope: "repo,user:email",
        revoked: false
      )

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          {:ok, _} = reconnect(user_id, "new-uid")
        end)

      assert log =~ "credentials from this OAuth exchange were NOT stored"
      assert log =~ "stored_uid="

      {:ok, reloaded} = RepoHostAccount.get_for_user_by_repo_host(user_id, "bitbucket")
      assert reloaded.token == "dead_token"
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
