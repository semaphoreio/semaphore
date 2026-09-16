defmodule Guard.Api.BitbucketTest do
  use Guard.RepoCase, async: false

  alias Guard.Api.Bitbucket

  setup do
    include_instance_config = Application.get_env(:guard, :include_instance_config)
    Application.put_env(:guard, :include_instance_config, false)

    on_exit(fn ->
      Application.put_env(:guard, :include_instance_config, include_instance_config)
    end)

    {:ok, user} = Support.Factories.RbacUser.insert()
    {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user.id)

    {:ok, _} =
      Support.Members.insert_user(
        id: user.id,
        email: user.email,
        name: user.name
      )

    {:ok, repo_host_account} =
      Support.Members.insert_repo_host_account(
        login: "example",
        name: "example",
        repo_host: "bitbucket",
        refresh_token: "example_refresh_token",
        user_id: user.id,
        token: "token",
        token_expires_at: Support.Members.valid_expires_at(),
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, repo_host_account: repo_host_account}
  end

  describe "user_token/1" do
    test "returns current token when valid", %{repo_host_account: rha} do
      assert {:ok, {stored_token, _}} = Bitbucket.user_token(rha)
      assert stored_token == rha.token
    end

    test "refreshes token when current one is expired", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "new_token", "expires_in" => 3600}}}

        %{
          method: :get,
          url: "https://api.bitbucket.org/2.0/user/workspaces"
        } ->
          {:ok, %Tesla.Env{status: 404, body: %{}}}
      end)

      assert {:ok, {"new_token", _}} = Bitbucket.user_token(rha)

      updated_rha =
        Guard.FrontRepo.RepoHostAccount
        |> Guard.FrontRepo.get!(rha.id)

      assert updated_rha.token == "new_token"
    end
  end

  describe "refresh request headers" do
    test "sends the default user-agent and accept header on the refresh POST", %{
      repo_host_account: rha
    } do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())
      test_pid = self()

      Tesla.Mock.mock_global(fn
        %{
          method: :post,
          url: "https://bitbucket.org/site/oauth2/access_token",
          headers: headers
        } ->
          send(test_pid, {:refresh_headers, headers})

          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "new_token", "expires_in" => 3600}}}

        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 404, body: %{}}}
      end)

      assert {:ok, {"new_token", _}} = Bitbucket.user_token(rha)

      assert_received {:refresh_headers, headers}
      hmap = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)
      assert hmap["user-agent"] == "Semaphore-Bitbucket-Integration/1.0"
      assert hmap["accept"] == "application/json"
    end

    test "honors a configured user-agent override", %{repo_host_account: rha} do
      Application.put_env(:guard, :oauth_refresh_user_agent, "Semaphore-Edge-Probe/2.0")
      on_exit(fn -> Application.delete_env(:guard, :oauth_refresh_user_agent) end)

      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())
      test_pid = self()

      Tesla.Mock.mock_global(fn
        %{
          method: :post,
          url: "https://bitbucket.org/site/oauth2/access_token",
          headers: headers
        } ->
          send(test_pid, {:refresh_headers, headers})

          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "new_token", "expires_in" => 3600}}}

        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 404, body: %{}}}
      end)

      assert {:ok, {"new_token", _}} = Bitbucket.user_token(rha)

      assert_received {:refresh_headers, headers}
      hmap = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)
      assert hmap["user-agent"] == "Semaphore-Edge-Probe/2.0"
    end
  end

  describe "AtlassianEdge-shaped refresh failures" do
    setup do
      Application.put_env(:guard, :oauth_refresh_retry_base_ms, 0)
      Application.put_env(:guard, :oauth_refresh_retry_jitter_ms, 0)
      Application.put_env(:guard, :oauth_refresh_max_attempts, 3)

      on_exit(fn ->
        Application.delete_env(:guard, :oauth_refresh_retry_base_ms)
        Application.delete_env(:guard, :oauth_refresh_retry_jitter_ms)
        Application.delete_env(:guard, :oauth_refresh_max_attempts)
      end)

      :ok
    end

    test "retries an empty-body AtlassianEdge 403 and returns :transient without discarding the refresh token",
         %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          Agent.update(counter, &(&1 + 1))
          {:ok, %Tesla.Env{status: 403, body: "", headers: [{"server", "AtlassianEdge"}]}}
      end)

      assert {:error, :transient} = Bitbucket.user_token(rha)
      assert Agent.get(counter, & &1) == 3

      updated_rha = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert updated_rha.refresh_token == "example_refresh_token"
      refute updated_rha.revoked
    end

    test "does NOT retry a genuine invalid_grant and revokes on the first response",
         %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          Agent.update(counter, &(&1 + 1))

          {:ok,
           %Tesla.Env{
             status: 400,
             body: %{"error" => "invalid_grant"},
             headers: [{"server", "AtlassianEdge"}]
           }}
      end)

      assert {:error, :revoked} = Bitbucket.user_token(rha)
      assert Agent.get(counter, & &1) == 1
    end
  end

  describe "successful refresh" do
    test "persists the rotated refresh token and still sends the user-agent", %{
      repo_host_account: rha
    } do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())
      test_pid = self()

      Tesla.Mock.mock_global(fn
        %{
          method: :post,
          url: "https://bitbucket.org/site/oauth2/access_token",
          headers: headers
        } ->
          send(test_pid, {:refresh_headers, headers})

          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{
               "access_token" => "new_token",
               "refresh_token" => "rotated_refresh_token",
               "expires_in" => 3600
             }
           }}

        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 404, body: %{}}}
      end)

      assert {:ok, {"new_token", _}} = Bitbucket.user_token(rha)

      updated_rha = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert updated_rha.token == "new_token"
      assert updated_rha.refresh_token == "rotated_refresh_token"

      assert_received {:refresh_headers, headers}
      hmap = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)
      assert hmap["user-agent"] == "Semaphore-Bitbucket-Integration/1.0"
    end
  end

  describe "validate_token/1" do
    test "returns valid for successful responses" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, true} = Bitbucket.validate_token("valid_token")
    end

    test "returns invalid only for auth errors" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}
      end)

      assert {:ok, false} = Bitbucket.validate_token("expired_token")
    end

    test "returns transient error for provider-side failures" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.bitbucket.org/2.0/user/workspaces"} ->
          {:ok, %Tesla.Env{status: 503, body: %{}}}
      end)

      assert {:error, :transient} = Bitbucket.validate_token("token")
    end
  end
end
