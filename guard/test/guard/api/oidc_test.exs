defmodule Guard.Api.OIDCTest do
  use ExUnit.Case, async: true

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
end
