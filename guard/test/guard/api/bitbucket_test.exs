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

  describe "refresh-token rotation persistence (single-use rotation)" do
    setup %{repo_host_account: rha} do
      # Force the refresh path (stored token already expired).
      {:ok, rha: Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())}
    end

    test "persists the NEW rotated refresh_token from a raw JSON string 2xx body", %{rha: rha} do
      # PROD SHAPE: the refresh client has no JSON middleware, so the body is
      # a raw JSON string, and it carries a rotated refresh_token.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "access_token" => "rotated_access",
                 "refresh_token" => "rotated_refresh",
                 "expires_in" => 3600
               })
           }}
      end)

      assert {:ok, {"rotated_access", _}} = Bitbucket.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "rotated_refresh"
    end

    test "a 2xx WITHOUT a refresh_token leaves the stored refresh_token unchanged", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: Jason.encode!(%{"access_token" => "rotated_access", "expires_in" => 3600})
           }}
      end)

      assert {:ok, {"rotated_access", _}} = Bitbucket.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.token == "rotated_access"
      # Not nulled, not clobbered - left exactly as it was.
      assert reloaded.refresh_token == "example_refresh_token"
    end

    test "a 2xx with a MISSING expires_in STILL persists the rotated refresh_token", %{rha: rha} do
      # Regression for the old valid_token? gate that silently dropped the
      # rotation when expires_in was absent/short - guaranteeing a reuse burn.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body:
               Jason.encode!(%{
                 "access_token" => "rotated_access",
                 "refresh_token" => "rotated_refresh"
               })
           }}
      end)

      assert {:ok, {"rotated_access", _}} = Bitbucket.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.refresh_token == "rotated_refresh"
      # token_expires_at must be refreshed to a conservative future value, not
      # left at the old expired timestamp (which would force a refresh on
      # every request - churn against the single-use endpoint).
      assert DateTime.compare(reloaded.token_expires_at, DateTime.utc_now()) == :gt
    end

    test "a transient 4xx does NOT null or rotate the stored token", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok, %Tesla.Env{status: 403, body: ""}}
      end)

      assert {:error, :transient} = Bitbucket.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.token == "token"
      assert reloaded.refresh_token == "example_refresh_token"
      assert reloaded.revoked == false
    end

    test "a genuine invalid_grant revokes", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://bitbucket.org/site/oauth2/access_token"} ->
          {:ok,
           %Tesla.Env{
             status: 400,
             body: Jason.encode!(%{"error" => "invalid_grant"})
           }}
      end)

      assert {:error, :revoked} = Bitbucket.user_token(rha)
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
