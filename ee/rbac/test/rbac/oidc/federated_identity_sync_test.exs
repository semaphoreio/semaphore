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

      {:ok, _loser_rha} =
        Support.Members.insert_repo_host_account(
          github_uid: @claimed_uid,
          user_id: loser.id,
          login: "previous-owner",
          name: "Previous Owner",
          permission_scope: "user:email",
          revoked: true
        )

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
      assert_receive {:oidc_post, _}, 5_000
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

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          github_uid: @claimed_uid,
          user_id: loser.id,
          login: "previous-owner",
          name: "Previous Owner",
          permission_scope: "user:email",
          revoked: true
        )

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
