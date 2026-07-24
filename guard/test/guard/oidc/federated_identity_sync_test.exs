defmodule Guard.OIDC.FederatedIdentitySyncTest do
  use Guard.RepoCase, async: false

  import Ecto.Query

  alias Guard.FrontRepo.FederatedIdentitySyncRequest
  alias Guard.FrontRepo.RepoHostAccount
  alias Guard.OIDC.FederatedIdentitySync

  @claimed_uid "77001"

  describe "claim with OIDC enabled" do
    setup do
      setup_oidc_connection()
      setup_tesla_mock()

      {loser, loser_rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: @claimed_uid,
          login: "previous-owner"
        )

      {:ok, _} = RepoHostAccount.update_revoke_status(loser_rha, true)
      :ok = Support.Members.age_repo_host_account(loser_rha)
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
    end

    test "create/1 claim removes loser identity and pushes claimer identity", %{
      loser: loser,
      claimer: claimer
    } do
      assert {:ok, _} =
               RepoHostAccount.create(%{
                 login: "new-login",
                 github_uid: @claimed_uid,
                 repo_host: "github",
                 user_id: claimer.id,
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(loser.id)

      assert_receive {:oidc_delete, loser_url}, 5_000
      assert loser_url =~ "/users/kc-loser/federated-identity/github"

      # set_federated_identity issues a delete before the authoritative post
      assert_receive {:oidc_delete, claimer_url}, 5_000
      assert claimer_url =~ "/users/kc-claimer/federated-identity/github"

      assert_receive {:oidc_post, post_url, body}, 5_000
      assert post_url =~ "/users/kc-claimer/federated-identity/github"

      body = decode_json_body(body)
      assert body["userId"] == @claimed_uid
      assert body["userName"] == "new-login"

      # the durable sync request is cleared once the sync fully succeeded
      Support.Wait.run("sync request to be completed", fn ->
        FederatedIdentitySyncRequest.pending_count() == 0
      end)
    end

    test "removal is skipped when the loser already holds a different github identity", %{
      claimer: claimer
    } do
      test_pid = self()

      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if url =~ "federated-identity" do
            {:ok,
             %Tesla.Env{
               status: 200,
               body: [
                 %{
                   "identityProvider" => "github",
                   "userId" => "88888",
                   "userName" => "reconnected-elsewhere"
                 }
               ]
             }}
          else
            {:ok, %Tesla.Env{status: 200, body: %{}}}
          end

        %{method: :delete, url: url} ->
          send(test_pid, {:oidc_delete, url})
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post, url: url, body: body} ->
          send(test_pid, {:oidc_post, url, body})
          {:ok, %Tesla.Env{status: 200, body: %{}}}

        %{method: :put} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, _} =
               RepoHostAccount.create(%{
                 login: "new-login",
                 github_uid: @claimed_uid,
                 repo_host: "github",
                 user_id: claimer.id,
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      # only the claimer's pre-push delete fires; the loser's foreign
      # identity is left untouched and the sync still completes
      assert_receive {:oidc_delete, claimer_url}, 5_000
      assert claimer_url =~ "kc-claimer"

      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"

      refute_receive {:oidc_delete, _}, 200

      Support.Wait.run("sync request to be completed", fn ->
        FederatedIdentitySyncRequest.pending_count() == 0
      end)
    end

    test "reset claim syncs identities too", %{claimer: claimer} do
      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: "77999",
          user_id: claimer.id,
          login: "old-login",
          name: "Claimer",
          permission_scope: "user:email"
        )

      assert {:ok, _} =
               RepoHostAccount.update_repo_host_account(
                 claimer.id,
                 :github,
                 %{
                   github_uid: @claimed_uid,
                   login: "new-login",
                   name: "Claimer",
                   permission_scope: "user:email"
                 },
                 reset: true
               )

      assert_receive {:oidc_delete, loser_url}, 5_000
      assert loser_url =~ "kc-loser"

      assert_receive {:oidc_delete, _claimer_pre_post}, 5_000
      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"
    end

    test "loser without an OIDC user is skipped, push still happens", %{
      loser: loser,
      claimer: claimer
    } do
      {1, _} =
        from(o in Guard.Repo.OIDCUser, where: o.user_id == ^loser.id)
        |> Guard.Repo.delete_all()

      assert {:ok, _} =
               RepoHostAccount.create(%{
                 login: "new-login",
                 github_uid: @claimed_uid,
                 repo_host: "github",
                 user_id: claimer.id,
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      assert_receive {:oidc_delete, url}, 5_000
      assert url =~ "kc-claimer"

      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"

      refute_receive {:oidc_delete, _}, 200
    end
  end

  describe "sync_github_claim/2" do
    test "with no released users is a no-op" do
      setup_tesla_mock()

      account = %RepoHostAccount{
        repo_host: "github",
        github_uid: @claimed_uid,
        user_id: Ecto.UUID.generate(),
        login: "x"
      }

      assert :ok = FederatedIdentitySync.sync_github_claim(account, [])

      refute_receive {:oidc_delete, _}, 200
      refute_receive {:oidc_post, _, _}, 200
    end
  end

  describe "run_request/1" do
    setup do
      setup_oidc_connection()
      setup_tesla_mock()

      {:ok, loser} = Support.Factories.RbacUser.insert()
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
    end

    test "skips the push when the claim was superseded, but completes the removals", %{
      loser: loser,
      claimer: claimer
    } do
      # the claimer holds no active link for the uid anymore
      request =
        FederatedIdentitySyncRequest.enqueue(
          %RepoHostAccount{
            repo_host: "github",
            github_uid: @claimed_uid,
            user_id: claimer.id,
            login: "new-login"
          },
          [loser.id]
        )

      assert :ok = FederatedIdentitySync.run_request(request)

      assert_receive {:oidc_delete, loser_url}, 5_000
      assert loser_url =~ "kc-loser"

      refute_receive {:oidc_post, _, _}, 200

      assert FederatedIdentitySyncRequest.pending_count() == 0
    end
  end

  describe "claim resilience" do
    setup do
      setup_oidc_connection()

      {loser, loser_rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: @claimed_uid,
          login: "previous-owner"
        )

      {:ok, _} = RepoHostAccount.update_revoke_status(loser_rha, true)
      :ok = Support.Members.age_repo_host_account(loser_rha)
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
    end

    test "Keycloak failures do not fail the claim, and skip the claimer push", %{
      loser: loser,
      claimer: claimer
    } do
      test_pid = self()

      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          send(test_pid, {:oidc_get, url})
          {:ok, %Tesla.Env{status: 200, body: loser_identities()}}

        %{method: :delete, url: url} ->
          send(test_pid, {:oidc_delete, url})
          {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}

        %{method: :post, url: url} ->
          send(test_pid, {:oidc_post, url})
          {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}

        %{method: :put} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, claimed} =
               RepoHostAccount.create(%{
                 login: "new-login",
                 github_uid: @claimed_uid,
                 repo_host: "github",
                 user_id: claimer.id,
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      assert claimed.github_uid == @claimed_uid
      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(loser.id)

      assert_receive {:oidc_delete, _}, 5_000

      # The loser's identity may still be attached in Keycloak; pushing the
      # claimer's identity anyway could attach it to two users. The push is
      # skipped until a later sync succeeds.
      refute_receive {:oidc_post, _}, 500

      # the durable request survives the failure, scheduled for a retry
      Support.Wait.run("sync request to record the failure", fn ->
        case Guard.FrontRepo.all(FederatedIdentitySyncRequest) do
          [request] -> request.attempts >= 1
          _ -> false
        end
      end)

      [request] = Guard.FrontRepo.all(FederatedIdentitySyncRequest)
      assert request.uid == @claimed_uid
      assert request.claiming_user_id == claimer.id
      assert request.released_user_ids == [loser.id]
      assert request.last_error != nil
      assert DateTime.compare(request.next_attempt_at, DateTime.utc_now()) == :gt
    end

    test "retries transient Keycloak failures before succeeding", %{claimer: claimer} do
      test_pid = self()
      counter = :counters.new(1, [:atomics])

      Tesla.Mock.mock_global(fn
        %{method: :get, url: _url} ->
          {:ok, %Tesla.Env{status: 200, body: loser_identities()}}

        %{method: :delete, url: url} ->
          send(test_pid, {:oidc_delete, url})

          if :counters.get(counter, 1) == 0 do
            :counters.add(counter, 1, 1)
            {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
          else
            {:ok, %Tesla.Env{status: 204, body: %{}}}
          end

        %{method: :post, url: url, body: body} ->
          send(test_pid, {:oidc_post, url, body})
          {:ok, %Tesla.Env{status: 200, body: %{}}}

        %{method: :put} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, _} =
               RepoHostAccount.create(%{
                 login: "new-login",
                 github_uid: @claimed_uid,
                 repo_host: "github",
                 user_id: claimer.id,
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      # first delete attempt fails, the retry succeeds, so the push happens
      assert_receive {:oidc_delete, _first_attempt}, 5_000
      assert_receive {:oidc_delete, _retry}, 5_000

      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"
    end
  end

  describe "claims inside a database transaction" do
    setup do
      {loser, loser_rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: @claimed_uid,
          login: "previous-owner"
        )

      {:ok, _} = RepoHostAccount.update_revoke_status(loser_rha, true)
      :ok = Support.Members.age_repo_host_account(loser_rha)
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
    end

    test "sync is deferred until run_deferred/0 releases it", %{claimer: claimer} do
      setup_oidc_connection()
      setup_tesla_mock()

      {:ok, _} =
        Guard.FrontRepo.transaction(fn ->
          {:ok, account} =
            RepoHostAccount.create(%{
              login: "new-login",
              github_uid: @claimed_uid,
              repo_host: "github",
              user_id: claimer.id,
              name: "Claimer",
              permission_scope: "user:email"
            })

          account
        end)

      # the claim ran inside a transaction, so nothing may touch Keycloak yet
      refute_receive {:oidc_delete, _}, 300

      assert :ok = FederatedIdentitySync.run_deferred()

      assert_receive {:oidc_delete, loser_url}, 5_000
      assert loser_url =~ "kc-loser"

      assert_receive {:oidc_delete, _claimer_pre_post}, 5_000
      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"
    end

    test "drop_deferred/0 discards pending syncs", %{claimer: claimer} do
      oidc_env = Application.get_env(:guard, :oidc)

      Application.put_env(:guard, :oidc, %{
        discovery_url: "http://localhost/dummy",
        manage_url: "http://localhost/manage/"
      })

      on_exit(fn -> Application.put_env(:guard, :oidc, oidc_env) end)

      setup_tesla_mock()

      {:ok, _} =
        Guard.FrontRepo.transaction(fn ->
          {:ok, account} =
            RepoHostAccount.create(%{
              login: "new-login",
              github_uid: @claimed_uid,
              repo_host: "github",
              user_id: claimer.id,
              name: "Claimer",
              permission_scope: "user:email"
            })

          account
        end)

      assert :ok = FederatedIdentitySync.drop_deferred()
      assert :ok = FederatedIdentitySync.run_deferred()

      refute_receive {:oidc_delete, _}, 300
      refute_receive {:oidc_post, _, _}, 300
    end

    test "user-creation rollback leaves Keycloak untouched and restores the loser's row", %{
      loser: loser
    } do
      setup_oidc_connection()

      test_pid = self()

      Tesla.Mock.mock_global(fn
        %{method: :delete, url: url} ->
          send(test_pid, {:oidc_delete, url})
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post, url: url, body: body} ->
          if url =~ "federated-identity" do
            send(test_pid, {:oidc_post, url, body})
            {:ok, %Tesla.Env{status: 200, body: %{}}}
          else
            # Keycloak user creation fails -> Actions.create rolls back after
            # the claim already released the loser's row inside the transaction
            {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "kc down"}}}
          end

        %{method: :put} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:error, _} =
               Guard.User.Actions.create(%{
                 email: "rollback@example.com",
                 name: "Rollback",
                 repository_providers: [
                   %{
                     type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
                     uid: @claimed_uid,
                     login: "new-login"
                   }
                 ]
               })

      # rollback restored the released row; Keycloak was never mutated and
      # the sync request rolled back with the claim
      assert {:ok, restored} = RepoHostAccount.get_for_github_user(loser.id)
      assert restored.github_uid == @claimed_uid

      refute_receive {:oidc_delete, _}, 300
      refute_receive {:oidc_post, _, _}, 300

      assert FederatedIdentitySyncRequest.pending_count() == 0
    end
  end

  describe "claim with OIDC disabled" do
    setup do
      oidc_env = Application.get_env(:guard, :oidc)
      Application.put_env(:guard, :oidc, nil)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc_env)
      end)

      setup_tesla_mock()

      {loser, loser_rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: @claimed_uid,
          login: "previous-owner"
        )

      {:ok, _} = RepoHostAccount.update_revoke_status(loser_rha, true)
      :ok = Support.Members.age_repo_host_account(loser_rha)

      {:ok, loser: loser}
    end

    test "claim succeeds without touching Keycloak", %{loser: loser} do
      assert {:ok, _} =
               RepoHostAccount.create(%{
                 login: "new-login",
                 github_uid: @claimed_uid,
                 repo_host: "github",
                 user_id: Ecto.UUID.generate(),
                 name: "Claimer",
                 permission_scope: "user:email"
               })

      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(loser.id)

      refute_receive {:oidc_delete, _}, 200
      refute_receive {:oidc_post, _, _}, 200

      # no Keycloak to sync -> no durable request either
      assert FederatedIdentitySyncRequest.pending_count() == 0
    end
  end

  #
  # Helpers
  #

  defp setup_oidc_connection do
    oidc_env = Application.get_env(:guard, :oidc)
    Guard.Mocks.OpenIDConnect.stub_oidc_connection()

    on_exit(fn ->
      Application.put_env(:guard, :oidc, oidc_env)
    end)
  end

  defp setup_tesla_mock do
    test_pid = self()

    Tesla.Mock.mock_global(fn
      %{method: :get, url: url} ->
        if url =~ "federated-identity" do
          {:ok, %Tesla.Env{status: 200, body: loser_identities()}}
        else
          {:ok, %Tesla.Env{status: 200, body: %{}}}
        end

      %{method: :delete, url: url} ->
        send(test_pid, {:oidc_delete, url})
        {:ok, %Tesla.Env{status: 204, body: %{}}}

      %{method: :post, url: url, body: body} ->
        send(test_pid, {:oidc_post, url, body})
        {:ok, %Tesla.Env{status: 200, body: %{}}}

      %{method: :put} ->
        {:ok, %Tesla.Env{status: 200, body: %{}}}
    end)
  end

  defp loser_identities do
    [
      %{
        "identityProvider" => "github",
        "userId" => @claimed_uid,
        "userName" => "previous-owner"
      }
    ]
  end

  defp decode_json_body(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_json_body(body), do: body
end
