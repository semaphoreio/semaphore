defmodule Guard.Api.GithubTest do
  use Guard.RepoCase, async: false

  alias Guard.Api.Github

  setup do
    Application.put_env(:guard, :include_instance_config, false)

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
        repo_host: "github",
        refresh_token: "example_refresh_token",
        user_id: user.id,
        token: "token",
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, repo_host_account: repo_host_account}
  end

  describe "user_token/1" do
    test "returns current token when valid", %{repo_host_account: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, {"token", _}} = Github.user_token(rha)
    end

    test "refreshes token when the current one is expired", %{repo_host_account: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok,
           %Tesla.Env{status: 200, body: %{"access_token" => "new_token", "expires_in" => 3600}}}

        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}
      end)

      assert {:ok, {"new_token", _}} = Github.user_token(rha)

      updated_rha =
        Guard.FrontRepo.RepoHostAccount
        |> Guard.FrontRepo.get!(rha.id)

      assert updated_rha.token == "new_token"
    end
  end
end
