defmodule Guard.Api.BitbucketTest do
  use Guard.RepoCase

  alias Guard.Api.Bitbucket
  alias Guard.Utils.OAuth

  setup do
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
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, repo_host_account: repo_host_account}
  end

  describe "user_token/1" do
    test "returns cached token when valid", %{repo_host_account: rha} do
      cache_key = OAuth.token_cache_key(rha)
      Cachex.put(:token_cache, cache_key, {"cached_token", valid_expires_at()})

      assert {:ok, {"cached_token", _}} = Bitbucket.user_token(rha)
    end

    test "refreshes token when cache is expired", %{repo_host_account: rha} do
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

  defp valid_expires_at do
    (DateTime.utc_now() |> DateTime.to_unix()) + 3600
  end
end
