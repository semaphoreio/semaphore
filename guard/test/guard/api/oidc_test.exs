defmodule Guard.Api.OIDCTest do
  use Guard.RepoCase, async: true

  alias Guard.Api.OIDC

  @base_url "http://keycloak/manage"
  @oidc_user_id "kc-1"
  @identity %{identityProvider: "github", userId: "10001", userName: "octocat"}

  defp client do
    Tesla.client([{Tesla.Middleware.BaseUrl, @base_url}, Tesla.Middleware.JSON])
  end

  describe "remove_federated_identity/3" do
    test "returns ok on 204" do
      Tesla.Mock.mock(fn %{method: :delete, url: url} ->
        assert url == "#{@base_url}/users/#{@oidc_user_id}/federated-identity/github"
        {:ok, %Tesla.Env{status: 204, body: %{}}}
      end)

      assert {:ok, @oidc_user_id} =
               OIDC.remove_federated_identity(client(), @oidc_user_id, "github")
    end

    test "treats 404 as success (identity already absent)" do
      Tesla.Mock.mock(fn %{method: :delete} ->
        {:ok, %Tesla.Env{status: 404, body: %{"errorMessage" => "not found"}}}
      end)

      assert {:ok, @oidc_user_id} =
               OIDC.remove_federated_identity(client(), @oidc_user_id, "github")
    end

    test "returns error on server failure" do
      Tesla.Mock.mock(fn %{method: :delete} ->
        {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      assert {:error, "boom"} = OIDC.remove_federated_identity(client(), @oidc_user_id, "github")
    end

    test "returns error on transport failure" do
      Tesla.Mock.mock(fn %{method: :delete} -> {:error, :econnrefused} end)

      assert {:error, :econnrefused} =
               OIDC.remove_federated_identity(client(), @oidc_user_id, "github")
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

      assert {:ok, @oidc_user_id} =
               OIDC.set_federated_identity(client(), @oidc_user_id, @identity)

      assert_received {:delete, delete_url}
      assert_received {:post, post_url, post_body}

      assert delete_url == "#{@base_url}/users/#{@oidc_user_id}/federated-identity/github"
      assert post_url == delete_url
      assert Jason.decode!(post_body)["userId"] == "10001"
    end

    test "still posts when the delete fails" do
      test_pid = self()

      Tesla.Mock.mock(fn
        %{method: :delete} ->
          {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}

        %{method: :post, url: url} ->
          send(test_pid, {:post, url})
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, @oidc_user_id} =
               OIDC.set_federated_identity(client(), @oidc_user_id, @identity)

      assert_received {:post, _url}
    end

    test "returns error when the post fails" do
      Tesla.Mock.mock(fn
        %{method: :delete} -> {:ok, %Tesla.Env{status: 204, body: %{}}}
        %{method: :post} -> {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      assert {:error, "boom"} = OIDC.set_federated_identity(client(), @oidc_user_id, @identity)
    end
  end

  describe "get_federated_identities/2" do
    test "returns the identity list on 200" do
      identities = [
        %{"identityProvider" => "github", "userId" => "10001", "userName" => "octocat"}
      ]

      Tesla.Mock.mock(fn %{method: :get, url: url} ->
        assert url == "#{@base_url}/users/#{@oidc_user_id}/federated-identity"
        {:ok, %Tesla.Env{status: 200, body: identities}}
      end)

      assert {:ok, ^identities} = OIDC.get_federated_identities(client(), @oidc_user_id)
    end

    test "returns error on server failure" do
      Tesla.Mock.mock(fn %{method: :get} ->
        {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      assert {:error, "boom"} = OIDC.get_federated_identities(client(), @oidc_user_id)
    end
  end

  describe "get_oidc_federeted_identities/1" do
    test "skips identities with a pending claim sync request" do
      user_id = Ecto.UUID.generate()

      {:ok, github_rha} =
        Support.Members.insert_repo_host_account(
          user_id: user_id,
          repo_host: "github",
          github_uid: "70001",
          login: "octocat"
        )

      {:ok, _gitlab_rha} =
        Support.Members.insert_repo_host_account(
          user_id: user_id,
          repo_host: "gitlab",
          github_uid: "70002",
          login: "octocat-gl"
        )

      identities = OIDC.get_oidc_federeted_identities(%{id: user_id})
      assert identities |> Enum.map(& &1.identityProvider) |> Enum.sort() == ["github", "gitlab"]

      # a pending claim sync means the identity removals are not yet
      # confirmed in Keycloak: the identity must not be pushed from here
      Guard.FrontRepo.FederatedIdentitySyncRequest.enqueue(github_rha, [Ecto.UUID.generate()])

      identities = OIDC.get_oidc_federeted_identities(%{id: user_id})
      assert Enum.map(identities, & &1.identityProvider) == ["gitlab"]
    end
  end
end
