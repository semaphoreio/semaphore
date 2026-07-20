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
        %{method: :delete} -> {:ok, %Tesla.Env{status: 204, body: %{}}}
        %{method: :post} -> {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      identity = %{identityProvider: "github", userId: "10001", userName: "octocat"}

      assert {:error, "boom"} =
               Rbac.Api.OIDC.set_federated_identity(tesla_client(), "kc-1", identity)
    end
  end

  defp tesla_client do
    Tesla.client([{Tesla.Middleware.BaseUrl, "http://keycloak/manage"}, Tesla.Middleware.JSON])
  end
end
