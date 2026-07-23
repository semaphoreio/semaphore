defmodule Rbac.OIDC.FederatedIdentitySyncTest do
  use Rbac.RepoCase, async: false

  alias Rbac.FrontRepo.RepoHostAccount
  alias Rbac.OIDC.FederatedIdentitySync

  @claimed_uid "77001"

  describe "claim with OIDC enabled" do
    setup do
      setup_oidc_connection()
      setup_tesla_mock()

      {:ok, loser} = Support.Factories.RbacUser.insert()

      {:ok, loser_rha} =
        Support.Members.insert_repo_host_account(
          github_uid: @claimed_uid,
          user_id: loser.id,
          login: "previous-owner",
          name: "Previous Owner",
          permission_scope: "user:email",
          revoked: true
        )

      :ok = Support.Members.age_repo_host_account(loser_rha)

      {:ok, _} = Rbac.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Rbac.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
    end

    test "claim removes loser identity and pushes claimer identity", %{
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
    end

    test "Keycloak failures do not fail the claim", %{loser: loser, claimer: claimer} do
      test_pid = self()

      Tesla.Mock.mock_global(fn
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

    test "retries transient Keycloak failures before succeeding", %{claimer: claimer} do
      test_pid = self()
      counter = :counters.new(1, [:atomics])

      Tesla.Mock.mock_global(fn
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

    test "re-activating a revoked link claims the uid and syncs identities", %{
      loser: loser,
      claimer: claimer
    } do
      {:ok, claimer_rha} =
        Support.Members.insert_repo_host_account(
          github_uid: @claimed_uid,
          user_id: claimer.id,
          login: "new-login",
          name: "Claimer",
          permission_scope: "user:email",
          revoked: true
        )

      assert {:ok, updated} = RepoHostAccount.update_revoke_status(claimer_rha, false)
      assert updated.revoked == false

      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(loser.id)

      assert_receive {:oidc_delete, loser_url}, 5_000
      assert loser_url =~ "kc-loser"

      assert_receive {:oidc_delete, _claimer_pre_post}, 5_000
      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"
    end
  end

  describe "claims inside a database transaction" do
    setup do
      {:ok, loser} = Support.Factories.RbacUser.insert()

      {:ok, loser_rha} =
        Support.Members.insert_repo_host_account(
          github_uid: @claimed_uid,
          user_id: loser.id,
          login: "previous-owner",
          name: "Previous Owner",
          permission_scope: "user:email",
          revoked: true
        )

      :ok = Support.Members.age_repo_host_account(loser_rha)

      {:ok, _} = Rbac.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Rbac.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
    end

    test "sync is deferred until run_deferred/0 releases it", %{claimer: claimer} do
      setup_oidc_connection()
      setup_tesla_mock()

      {:ok, _} =
        Rbac.FrontRepo.transaction(fn ->
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
      oidc_env = Application.get_env(:rbac, :oidc)

      Application.put_env(:rbac, :oidc, %{
        discovery_url: "http://localhost/dummy",
        manage_url: "http://localhost/manage/"
      })

      on_exit(fn -> Application.put_env(:rbac, :oidc, oidc_env) end)

      setup_tesla_mock()

      {:ok, _} =
        Rbac.FrontRepo.transaction(fn ->
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
  end

  describe "claim with OIDC disabled" do
    setup do
      oidc_env = Application.get_env(:rbac, :oidc)
      Application.put_env(:rbac, :oidc, nil)

      on_exit(fn ->
        Application.put_env(:rbac, :oidc, oidc_env)
      end)

      setup_tesla_mock()

      {:ok, loser} = Support.Factories.RbacUser.insert()

      {:ok, loser_rha} =
        Support.Members.insert_repo_host_account(
          github_uid: @claimed_uid,
          user_id: loser.id,
          login: "previous-owner",
          name: "Previous Owner",
          permission_scope: "user:email",
          revoked: true
        )

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

  #
  # Helpers
  #

  defp setup_oidc_connection do
    oidc_env = Application.get_env(:rbac, :oidc)
    Rbac.Mocks.OpenIDConnect.stub_oidc_connection()

    on_exit(fn ->
      Application.put_env(:rbac, :oidc, oidc_env)
    end)
  end

  defp setup_tesla_mock do
    test_pid = self()

    Tesla.Mock.mock_global(fn
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

  defp decode_json_body(body) when is_binary(body), do: Jason.decode!(body)
  defp decode_json_body(body), do: body
end
