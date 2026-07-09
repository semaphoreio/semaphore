defmodule Guard.OIDC.FederatedIdentitySyncTest do
  use Guard.RepoCase, async: false

  import Ecto.Query

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

  describe "claim resilience" do
    setup do
      setup_oidc_connection()

      {loser, loser_rha} =
        Support.Members.insert_user_with_github_account(
          github_uid: @claimed_uid,
          login: "previous-owner"
        )

      {:ok, _} = RepoHostAccount.update_revoke_status(loser_rha, true)
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-loser", loser.id)

      {:ok, claimer} = Support.Factories.RbacUser.insert()
      {:ok, _} = Guard.Store.OIDCUser.connect_user("kc-claimer", claimer.id)

      {:ok, loser: loser, claimer: claimer}
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
