defmodule Guard.Api.GitlabTest do
  use Guard.RepoCase, async: false

  alias Guard.Api.Gitlab

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
        repo_host: "gitlab",
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
      assert {:ok, {token, _}} = Gitlab.user_token(rha)
      assert token == rha.token
    end

    test "refreshes token when current one is expired", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "new_token", "expires_in" => 3600}}}

        %{method: :get, url: "https://gitlab.com/oauth/token/info"} ->
          {:ok, %Tesla.Env{status: 404, body: %{}}}
      end)

      assert {:ok, {"new_token", _}} = Gitlab.user_token(rha)

      updated_rha =
        Guard.FrontRepo.RepoHostAccount
        |> Guard.FrontRepo.get!(rha.id)

      assert updated_rha.token == "new_token"
    end

    test "rate-limited token refresh is a transient failure, not a revocation",
         %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      for status <- [408, 429] do
        Tesla.Mock.mock_global(fn
          %{method: :post, url: "https://gitlab.com/oauth/token"} ->
            {:ok, %Tesla.Env{status: status, body: %{}}}
        end)

        assert {:error, :failed} = Gitlab.user_token(rha)
      end
    end

    test "rejected token refresh still classifies as revoked", %{repo_host_account: rha} do
      rha = Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())

      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{}}}
      end)

      assert {:error, :revoked} = Gitlab.user_token(rha)
    end
  end

  describe "validate_token/1" do
    test "returns valid for successful responses with a live expiry" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://gitlab.com/oauth/token/info"} ->
          {:ok, %Tesla.Env{status: 200, body: %{"expires_in" => 3600}}}
      end)

      assert {:ok, true} = Gitlab.validate_token("token")
    end

    test "returns invalid only for auth errors" do
      for status <- [401, 403] do
        Tesla.Mock.mock_global(fn
          %{method: :get, url: "https://gitlab.com/oauth/token/info"} ->
            {:ok, %Tesla.Env{status: status, body: %{}}}
        end)

        assert {:ok, false} = Gitlab.validate_token("token")
      end
    end

    test "returns transient error for provider-side failures" do
      for status <- [429, 500, 503] do
        Tesla.Mock.mock_global(fn
          %{method: :get, url: "https://gitlab.com/oauth/token/info"} ->
            {:ok, %Tesla.Env{status: status, body: %{}}}
        end)

        assert {:error, :transient} = Gitlab.validate_token("token")
      end
    end

    test "returns transient error for transport failures" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://gitlab.com/oauth/token/info"} ->
          {:error, :timeout}
      end)

      assert {:error, :transient} = Gitlab.validate_token("token")
    end
  end
end
