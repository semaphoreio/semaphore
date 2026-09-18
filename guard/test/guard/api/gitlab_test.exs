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
  end

  describe "refresh-token rotation persistence (single-use rotation)" do
    setup %{repo_host_account: rha} do
      {:ok, rha: Map.put(rha, :token_expires_at, Support.Members.invalid_expires_at())}
    end

    test "persists the NEW rotated refresh_token from a raw JSON string 2xx body", %{rha: rha} do
      # GitLab also rotates. The handler accepts a raw JSON string body (as
      # well as a decoded map) - assert the rotation is stored either way.
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
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

      assert {:ok, {"rotated_access", _}} = Gitlab.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "rotated_refresh"
    end

    test "a 2xx WITHOUT a refresh_token leaves the stored refresh_token unchanged", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{"access_token" => "rotated_access", "expires_in" => 3600}
           }}
      end)

      assert {:ok, {"rotated_access", _}} = Gitlab.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.token == "rotated_access"
      assert reloaded.refresh_token == "example_refresh_token"
    end

    test "a 2xx with a MISSING expires_in STILL persists the rotated refresh_token", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok,
           %Tesla.Env{
             status: 200,
             body: %{"access_token" => "rotated_access", "refresh_token" => "rotated_refresh"}
           }}
      end)

      assert {:ok, {"rotated_access", _}} = Gitlab.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.refresh_token == "rotated_refresh"
      # token_expires_at must be refreshed to a conservative future value, not
      # left at the old expired timestamp (churn against the single-use
      # endpoint).
      assert DateTime.compare(reloaded.token_expires_at, DateTime.utc_now()) == :gt
    end

    test "a transient 4xx does NOT null or rotate the stored token", %{rha: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          {:ok, %Tesla.Env{status: 503, body: %{}}}
      end)

      assert {:error, :transient} = Gitlab.user_token(rha)

      reloaded = Guard.FrontRepo.get!(Guard.FrontRepo.RepoHostAccount, rha.id)
      assert reloaded.token == "token"
      assert reloaded.refresh_token == "example_refresh_token"
    end
  end
end
