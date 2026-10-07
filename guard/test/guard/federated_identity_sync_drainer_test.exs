defmodule Guard.FederatedIdentitySyncDrainerTest do
  use Guard.RepoCase, async: false

  import Ecto.Query

  alias Guard.FederatedIdentitySyncDrainer
  alias Guard.FrontRepo.FederatedIdentitySyncRequest, as: Request
  alias Guard.FrontRepo.RepoHostAccount

  @claimed_uid "66001"

  describe "process/0 with OIDC enabled" do
    setup do
      oidc_env = Application.get_env(:guard, :oidc)
      Guard.Mocks.OpenIDConnect.stub_oidc_connection()
      on_exit(fn -> Application.put_env(:guard, :oidc, oidc_env) end)

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

    test "repairs a sync that failed past its in-process retries", %{
      loser: loser,
      claimer: claimer
    } do
      test_pid = self()

      # Keycloak is down: the claim commits, the immediate sync fails
      Tesla.Mock.mock_global(fn
        %{method: :get} ->
          {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "kc down"}}}

        %{method: :delete} ->
          {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "kc down"}}}

        %{method: :post} ->
          {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "kc down"}}}

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

      assert {:error, :not_found} = RepoHostAccount.get_for_github_user(loser.id)

      Support.Wait.run("immediate sync to record its failure", fn ->
        match?([%{attempts: attempts}] when attempts >= 1, Guard.FrontRepo.all(Request))
      end)

      # Keycloak recovers
      Tesla.Mock.mock_global(fn
        %{method: :get, url: url} ->
          if url =~ "federated-identity" do
            {:ok,
             %Tesla.Env{
               status: 200,
               body: [
                 %{
                   "identityProvider" => "github",
                   "userId" => @claimed_uid,
                   "userName" => "previous-owner"
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

      make_due()

      assert :ok = FederatedIdentitySyncDrainer.process()

      # the drainer detached the loser and attached the claimer
      assert_receive {:oidc_delete, loser_url}, 5_000
      assert loser_url =~ "kc-loser"

      assert_receive {:oidc_delete, claimer_pre_post}, 5_000
      assert claimer_pre_post =~ "kc-claimer"

      assert_receive {:oidc_post, post_url, _body}, 5_000
      assert post_url =~ "kc-claimer"

      assert Request.pending_count() == 0
    end
  end

  describe "process/0 scheduling" do
    setup do
      oidc_env = Application.get_env(:guard, :oidc)

      Application.put_env(:guard, :oidc, %{
        discovery_url: "http://localhost/dummy",
        manage_url: "http://localhost/manage/"
      })

      on_exit(fn -> Application.put_env(:guard, :oidc, oidc_env) end)

      :ok
    end

    test "leaves rows scheduled in the future alone" do
      test_pid = self()

      Tesla.Mock.mock_global(fn env ->
        send(test_pid, {:oidc_call, env.method})
        {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      request =
        Request.enqueue(
          %RepoHostAccount{
            repo_host: "github",
            github_uid: @claimed_uid,
            user_id: Ecto.UUID.generate(),
            login: "new-login"
          },
          []
        )

      :ok = Request.record_failure(request, "not due yet")

      assert :ok = FederatedIdentitySyncDrainer.process()

      refute_receive {:oidc_call, _}, 200
      assert Request.pending_count() == 1
    end
  end

  describe "process/0 with OIDC disabled" do
    setup do
      oidc_env = Application.get_env(:guard, :oidc)
      Application.put_env(:guard, :oidc, nil)
      on_exit(fn -> Application.put_env(:guard, :oidc, oidc_env) end)

      :ok
    end

    test "is a no-op" do
      assert :ok = FederatedIdentitySyncDrainer.process()
    end
  end

  defp make_due do
    past = DateTime.utc_now() |> DateTime.add(-1) |> DateTime.truncate(:second)

    Request
    |> from()
    |> Guard.FrontRepo.update_all(set: [next_attempt_at: past])
  end
end
