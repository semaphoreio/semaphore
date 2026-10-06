defmodule Guard.Api.OIDCTest do
  use Guard.RepoCase, async: true

  alias Guard.Api.OIDC

  @base_url "http://keycloak/manage"
  @oidc_user_id "kc-1"
  @identity %{identityProvider: "github", userId: "10001", userName: "octocat"}

  defp client do
    Tesla.client([{Tesla.Middleware.BaseUrl, @base_url}, Tesla.Middleware.JSON])
  end

  describe "create_oidc_user/3 failure logging" do
    test "a rejected creation does not log the credential payload" do
      # The payload carries secretData: the password's argon2id hash and
      # base64 salt. The parameters are in the source, so logging it makes a
      # weak password crackable offline.
      password = "correct-horse-battery-staple"
      user = %{id: Ecto.UUID.generate(), name: "Octo Cat", email: "octo@example.com"}

      Tesla.Mock.mock(fn %{method: :post} ->
        {:ok,
         %Tesla.Env{status: 409, body: %{"errorMessage" => "User exists with same username"}}}
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:error, _} =
                   OIDC.create_oidc_user(client(), user, password_data: [password: password])
        end)

      assert log =~ "octo@example.com"
      refute log =~ "secretData"
      refute log =~ password
    end
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
        %{method: :get} ->
          {:ok, %Tesla.Env{status: 200, body: []}}

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
        %{method: :get} ->
          {:ok, %Tesla.Env{status: 200, body: []}}

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
        %{method: :get} -> {:ok, %Tesla.Env{status: 200, body: []}}
        %{method: :delete} -> {:ok, %Tesla.Env{status: 204, body: %{}}}
        %{method: :post} -> {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      assert {:error, "boom"} = OIDC.set_federated_identity(client(), @oidc_user_id, @identity)
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

      assert {:error, :held_by_other} =
               OIDC.set_federated_identity(client(), @oidc_user_id, @identity)

      assert_received {:get, get_url, query}
      assert get_url == "#{@base_url}/users"
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
          {:ok, %Tesla.Env{status: 200, body: [%{"id" => @oidc_user_id}]}}

        %{method: :delete} ->
          {:ok, %Tesla.Env{status: 204, body: %{}}}

        %{method: :post} ->
          send(test_pid, :post)
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, @oidc_user_id} =
               OIDC.set_federated_identity(client(), @oidc_user_id, @identity)

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

        assert {:ok, @oidc_user_id} =
                 OIDC.set_federated_identity(client(), @oidc_user_id, @identity)

        assert_received :post
      end
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

    test "treats 404 as holding no identities" do
      # The Keycloak user is gone. Returning an error here strands the caller:
      # a claim whose loser was deleted can never complete its removals, so it
      # retries to the attempt ceiling and dead-letters for something no retry
      # can fix. 404 means "holds nothing", same as remove_federated_identity/3.
      Tesla.Mock.mock(fn %{method: :get} ->
        {:ok, %Tesla.Env{status: 404, body: %{"error" => "User not found"}}}
      end)

      assert {:ok, []} = OIDC.get_federated_identities(client(), @oidc_user_id)
    end

    test "returns error on server failure" do
      Tesla.Mock.mock(fn %{method: :get} ->
        {:ok, %Tesla.Env{status: 500, body: %{"errorMessage" => "boom"}}}
      end)

      assert {:error, "boom"} = OIDC.get_federated_identities(client(), @oidc_user_id)
    end
  end

  describe "update_oidc_user/4 with a conflicting identity" do
    test "skips the held identity, still pushes the others, and succeeds" do
      test_pid = self()
      user_id = Ecto.UUID.generate()

      {:ok, _github_rha} =
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

      # A pre-existing conflict on one identity must not fail the whole update:
      # Guard.User.Actions.change_email/2 turns any error here into a
      # user-visible failure and rolls back both repos.
      assert {:ok, @oidc_user_id} =
               OIDC.update_oidc_user(client(), @oidc_user_id, %{
                 id: user_id,
                 name: "Octo Cat",
                 email: "octo@example.com"
               })

      assert_received {:post, post_url, post_body}
      assert post_url =~ "/federated-identity/gitlab"
      assert Jason.decode!(post_body)["userId"] == "70002"

      # the conflicting github identity was never pushed
      refute_received {:post, _url, _body}
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
