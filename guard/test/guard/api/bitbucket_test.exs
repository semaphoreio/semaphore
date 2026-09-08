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

    test "persists the rotated refresh token", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{
               "access_token" => "new_token",
               "refresh_token" => "rotated_refresh_token",
               "expires_in" => 7200
             }
           }}
      end)

      assert {:ok, {"new_token", _}} = Bitbucket.user_token(rha)

      updated_rha = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)

      # Bitbucket expires the previous refresh token shortly after a refresh, so
      # losing the rotated one here breaks every later refresh for this account.
      assert updated_rha.refresh_token == "rotated_refresh_token"
    end

    test "reports invalid_grant as revoked", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:error, :revoked} = Bitbucket.user_token(rha)
    end

    test "reports a 403 as transient, not revoked", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      # A 403 is what Bitbucket answers for a refresh token superseded by a
      # rotation. Calling it revoked disconnects the whole organization.
      assert {:error, :transient} = Bitbucket.user_token(rha)
    end

    test "reports throttling as transient, not revoked", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 429, body: %{}}}
      end)

      assert {:error, :transient} = Bitbucket.user_token(rha)
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
