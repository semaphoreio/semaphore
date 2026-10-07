defmodule Rbac.Api.OIDCTest do
  use Rbac.RepoCase

  import Mock

  setup do
    Support.Rbac.Store.clear!()
    Rbac.FrontRepo.delete_all(Rbac.FrontRepo.RepoHostAccount)

    :ok
  end

  test "includes gitlab federated identity for connected gitlab account" do
    {:ok, user} = Support.Factories.RbacUser.insert()

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "gitlab_user",
        github_uid: "123",
        user_id: user.id,
        repo_host: "gitlab"
      )

    data = Rbac.Api.OIDC.get_oidc_data(user)

    assert Enum.any?(data.federatedIdentities, fn identity ->
             identity.identityProvider == "gitlab" and identity.userId == "123"
           end)
  end

  test "includes github and bitbucket federated identities when bitbucket is connected" do
    {:ok, user} = Support.Factories.RbacUser.insert()

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "radwo",
        github_uid: "184065",
        user_id: user.id,
        repo_host: "github"
      )

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "radwo",
        github_uid: "bitbucket-uid",
        user_id: user.id,
        repo_host: "bitbucket"
      )

    with_mock Rbac.Api.Bitbucket, [:passthrough],
      user: fn "bitbucket-uid" -> {:ok, %{account_id: "bitbucket-account"}} end do
      data = Rbac.Api.OIDC.get_oidc_data(user)

      assert Enum.any?(data.federatedIdentities, fn identity ->
               identity.identityProvider == "github" and identity.userId == "184065"
             end)

      assert Enum.any?(data.federatedIdentities, fn identity ->
               identity.identityProvider == "bitbucket" and
                 identity.userId == "bitbucket-account"
             end)
    end
  end

  describe "remove_federated_identity/3" do
    test "returns ok on 204 and treats 404 as already absent" do
      Tesla.Mock.mock(fn %{method: :delete, url: url} ->
        assert url == "http://keycloak/manage/users/kc-1/federated-identity/github"
        {:ok, %Tesla.Env{status: 204, body: %{}}}
      end)

      assert {:ok, "kc-1"} =
               Rbac.Api.OIDC.remove_federated_identity(tesla_client(), "kc-1", "github")

      Tesla.Mock.mock(fn %{method: :delete} ->
        {:ok, %Tesla.Env{status: 404, body: %{"errorMessage" => "not found"}}}
      end)

      assert {:ok, "kc-1"} =
               Rbac.Api.OIDC.remove_federated_identity(tesla_client(), "kc-1", "github")
    end

    test "returns error on server failure" do
      Tesla.Mock.mock(fn %{method: :delete} ->
        {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      assert {:error, "boom"} =
               Rbac.Api.OIDC.remove_federated_identity(tesla_client(), "kc-1", "github")
    end
  end

  describe "set_federated_identity/3" do
    test "deletes then posts the identity" do
      test_pid = self()

      Tesla.Mock.mock(fn
        %{method: :get} ->
          {:ok, %Tesla.Env{status: 200, body: []}}

        %{method: :delete, url: url} ->
          send(test_pid, {:delete, url})
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post, url: url, body: body} ->
          send(test_pid, {:post, url, body})
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      identity = %{identityProvider: "github", userId: "10001", userName: "octocat"}

      assert {:ok, "kc-1"} =
               Rbac.Api.OIDC.set_federated_identity(tesla_client(), "kc-1", identity)

      assert_received {:delete, delete_url}
      assert_received {:post, post_url, post_body}

      assert delete_url == "http://keycloak/manage/users/kc-1/federated-identity/github"
      assert post_url == delete_url
      assert Jason.decode!(post_body)["userId"] == "10001"
    end

    test "returns error when the post fails" do
      Tesla.Mock.mock(fn
        %{method: :get} -> {:ok, %Tesla.Env{status: 200, body: []}}
        %{method: :delete} -> {:ok, %Tesla.Env{status: 204, body: %{}}}
        %{method: :post} -> {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      identity = %{identityProvider: "github", userId: "10001", userName: "octocat"}

      assert {:error, "boom"} =
               Rbac.Api.OIDC.set_federated_identity(tesla_client(), "kc-1", identity)
    end

    test "refuses to post when another keycloak user already holds the identity" do
      test_pid = self()

      Tesla.Mock.mock(fn
        %{method: :get, url: url, query: query} ->
          send(test_pid, {:get, url, query})
          {:ok, %Tesla.Env{status: 200, body: [%{"id" => "kc-someone-else"}]}}

        %{method: :delete} ->
          send(test_pid, :delete)
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post} ->
          send(test_pid, :post)
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      identity = %{identityProvider: "github", userId: "10001", userName: "octocat"}

      assert {:error, :held_by_other} =
               Rbac.Api.OIDC.set_federated_identity(tesla_client(), "kc-1", identity)

      assert_received {:get, get_url, query}
      assert get_url == "http://keycloak/manage/users"
      assert query[:idpAlias] == "github"
      assert query[:idpUserId] == "10001"

      # the whole point: the identity is left where it is
      refute_received :post
      refute_received :delete
    end

    test "posts when the only holder is this same user" do
      test_pid = self()

      Tesla.Mock.mock(fn
        %{method: :get} ->
          {:ok, %Tesla.Env{status: 200, body: [%{"id" => "kc-1"}]}}

        %{method: :delete} ->
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post} ->
          send(test_pid, :post)
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      identity = %{identityProvider: "github", userId: "10001", userName: "octocat"}

      assert {:ok, "kc-1"} =
               Rbac.Api.OIDC.set_federated_identity(tesla_client(), "kc-1", identity)

      assert_received :post
    end

    test "posts when the holder lookup cannot be read (fails open)" do
      test_pid = self()

      for body <- [%{"errorMessage" => "boom"}, [%{"identityProvider" => "github"}]] do
        Tesla.Mock.mock(fn
          %{method: :get} ->
            {:ok, %Tesla.Env{status: 500, body: body}}

          %{method: :delete} ->
            {:ok, %Tesla.Env{status: 204, body: %{}}}

          %{method: :post} ->
            send(test_pid, :post)
            {:ok, %Tesla.Env{status: 200, body: %{}}}
        end)

        identity = %{identityProvider: "github", userId: "10001", userName: "octocat"}

        assert {:ok, "kc-1"} =
                 Rbac.Api.OIDC.set_federated_identity(tesla_client(), "kc-1", identity)

        assert_received :post
      end
    end
  end

  describe "get_oidc_federeted_identities/1" do
    test "skips identities with a pending claim sync request" do
      {:ok, user} = Support.Factories.RbacUser.insert()

      {:ok, github_rha} =
        Support.Members.insert_repo_host_account(
          user_id: user.id,
          repo_host: "github",
          github_uid: "70001",
          login: "octocat",
          name: "Octo",
          permission_scope: "user:email"
        )

      {:ok, _gitlab_rha} =
        Support.Members.insert_repo_host_account(
          user_id: user.id,
          repo_host: "gitlab",
          github_uid: "70002",
          login: "octocat-gl",
          name: "Octo",
          permission_scope: "user:email"
        )

      identities = Rbac.Api.OIDC.get_oidc_federeted_identities(user)
      assert identities |> Enum.map(& &1.identityProvider) |> Enum.sort() == ["github", "gitlab"]

      # a pending claim sync means the identity removals are not yet
      # confirmed in Keycloak: the identity must not be pushed from here
      # guard owns the writes to this table; rbac only reads it
      %Rbac.FrontRepo.FederatedIdentitySyncRequest{
        repo_host: github_rha.repo_host,
        uid: github_rha.github_uid,
        claiming_user_id: github_rha.user_id,
        released_user_ids: [Ecto.UUID.generate()],
        login: github_rha.login,
        attempts: 0,
        next_attempt_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
      |> Rbac.FrontRepo.insert!()

      identities = Rbac.Api.OIDC.get_oidc_federeted_identities(user)
      assert Enum.map(identities, & &1.identityProvider) == ["gitlab"]
    end
  end

  describe "create_oidc_user/3 with a conflicting identity" do
    test "creates the user without the identity another keycloak user holds" do
      test_pid = self()
      {:ok, user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "octocat",
          github_uid: "70001",
          user_id: user.id,
          repo_host: "github"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "octocat-gl",
          github_uid: "70002",
          user_id: user.id,
          repo_host: "gitlab"
        )

      Tesla.Mock.mock(fn
        %{method: :get, query: query} ->
          if query[:idpAlias] == "github" do
            {:ok, %Tesla.Env{status: 200, body: [%{"id" => "kc-someone-else"}]}}
          else
            {:ok, %Tesla.Env{status: 200, body: []}}
          end

        %{method: :post, url: url, body: body} ->
          send(test_pid, {:post, url, body})

          {:ok,
           %Tesla.Env{
             status: 201,
             headers: [{"location", "http://keycloak/manage/users/kc-1"}],
             body: %{}
           }}
      end)

      assert {:ok, "kc-1"} = Rbac.Api.OIDC.create_oidc_user(tesla_client(), user)

      assert_received {:post, "http://keycloak/manage/users", post_body}

      identities = Jason.decode!(post_body)["federatedIdentities"]
      assert Enum.map(identities, & &1["identityProvider"]) == ["gitlab"]
    end
  end

  describe "update_oidc_user/4 with a conflicting identity" do
    test "skips the held identity, still pushes the others, and succeeds" do
      test_pid = self()
      {:ok, user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "octocat",
          github_uid: "70001",
          user_id: user.id,
          repo_host: "github"
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "octocat-gl",
          github_uid: "70002",
          user_id: user.id,
          repo_host: "gitlab"
        )

      Tesla.Mock.mock(fn
        # only the github identity is held by somebody else
        %{method: :get, url: url, query: query} ->
          if url =~ "federated-identity" do
            {:ok, %Tesla.Env{status: 200, body: []}}
          else
            if query[:idpAlias] == "github" do
              {:ok, %Tesla.Env{status: 200, body: [%{"id" => "kc-someone-else"}]}}
            else
              {:ok, %Tesla.Env{status: 200, body: []}}
            end
          end

        %{method: :put} ->
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :delete} ->
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post, url: url, body: body} ->
          send(test_pid, {:post, url, body})
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      # A pre-existing conflict on one identity must not fail the whole update.
      assert {:ok, "kc-1"} = Rbac.Api.OIDC.update_oidc_user(tesla_client(), "kc-1", user)

      assert_received {:post, post_url, post_body}
      assert post_url =~ "/federated-identity/gitlab"
      assert Jason.decode!(post_body)["userId"] == "70002"

      # the conflicting github identity was never pushed
      refute_received {:post, _url, _body}
    end
  end

  defp tesla_client do
    Tesla.client([{Tesla.Middleware.BaseUrl, "http://keycloak/manage"}, Tesla.Middleware.JSON])
  end
end
