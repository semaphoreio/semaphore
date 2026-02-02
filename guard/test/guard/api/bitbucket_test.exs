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
          url: "https://api.bitbucket.org/2.0/repositories?access_token=token"
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
end
