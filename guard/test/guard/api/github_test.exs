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

    test "returns current token on transient validate failure without refresh attempt",
         %{repo_host_account: rha} do
      rha = %{rha | refresh_token: nil}

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 500, body: %{"message" => "boom"}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          raise "must not attempt refresh on transient validate failure"
      end)

      assert {:ok, {"token", nil}} = Github.user_token(rha)
    end

    test "returns current token on transient validate failure even with refresh_token",
         %{repo_host_account: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 503, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          raise "must not attempt refresh on transient validate failure"
      end)

      assert {:ok, {"token", nil}} = Github.user_token(rha)
    end

    test "returns :revoked when token is rejected and refresh_token is missing",
         %{repo_host_account: rha} do
      rha = %{rha | refresh_token: nil}

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          raise "must not attempt refresh without refresh_token"
      end)

      assert {:error, :revoked} = Github.user_token(rha)
    end

    test "rate-limited token refresh is a transient failure, not a revocation",
         %{repo_host_account: rha} do
      for status <- [408, 429] do
        Tesla.Mock.mock_global(fn
          %{method: :get, url: "https://api.github.com"} ->
            {:ok, %Tesla.Env{status: 401, body: %{}}}

          %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
            {:ok, %Tesla.Env{status: status, body: %{}}}
        end)

        assert {:error, :failed} = Github.user_token(rha)
      end
    end

    test "rejected token refresh still classifies as revoked", %{repo_host_account: rha} do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{}}}

        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          {:ok, %Tesla.Env{status: 400, body: %{}}}
      end)

      assert {:error, :revoked} = Github.user_token(rha)
    end
  end

  describe "validate_token/1" do
    test "2xx returns {:ok, true}" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, true} = Github.validate_token("token")
    end

    test "401 returns {:ok, false}" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 401, body: %{"message" => "denied"}}}
      end)

      assert {:ok, false} = Github.validate_token("token")
    end

    for status <- [403, 429, 500, 502, 503] do
      test "#{status} returns {:error, :transient}" do
        status = unquote(status)

        Tesla.Mock.mock_global(fn
          %{method: :get, url: "https://api.github.com"} ->
            {:ok, %Tesla.Env{status: status, body: %{"message" => "boom"}}}
        end)

        assert {:error, :transient} = Github.validate_token("token")
      end
    end

    test "unexpected 4xx returns {:error, :transient}" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:ok, %Tesla.Env{status: 418, body: %{}}}
      end)

      assert {:error, :transient} = Github.validate_token("token")
    end

    test "network error returns {:error, :transient}" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com"} ->
          {:error, :timeout}
      end)

      assert {:error, :transient} = Github.validate_token("token")
    end

    test "empty token returns {:ok, false} without issuing HTTP request" do
      Tesla.Mock.mock_global(fn _ ->
        raise "unexpected HTTP call for validate_token(\"\")"
      end)

      assert {:ok, false} = Github.validate_token("")
    end

    test "sends Authorization: Bearer <token> header" do
      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com", headers: headers} ->
        assert {"Authorization", "Bearer my-secret-token"} =
                 List.keyfind(headers, "Authorization", 0)

        {:ok, %Tesla.Env{status: 200, body: %{}}}
      end)

      assert {:ok, true} = Github.validate_token("my-secret-token")
    end
  end

  describe "user/2" do
    test "sends Authorization: Bearer <token> header when token is supplied" do
      Tesla.Mock.mock_global(fn %{
                                  method: :get,
                                  url: "https://api.github.com/user/583231",
                                  headers: headers
                                } ->
        assert {"Authorization", "Bearer my-secret-token"} =
                 List.keyfind(headers, "Authorization", 0)

        Tesla.Mock.json(%{"id" => 583_231, "login" => "octocat", "name" => "The Octocat"})
      end)

      assert {:ok, %{id: "583231", login: "octocat", name: "The Octocat"}} =
               Github.user("583231", "my-secret-token")
    end

    test "sends NO Authorization header when token is nil" do
      Tesla.Mock.mock_global(fn %{
                                  method: :get,
                                  url: "https://api.github.com/user/583231",
                                  headers: headers
                                } ->
        refute List.keyfind(headers, "Authorization", 0)
        Tesla.Mock.json(%{"id" => 583_231, "login" => "octocat", "name" => "The Octocat"})
      end)

      assert {:ok, _} = Github.user("583231", nil)
    end

    test "sends NO Authorization header when token is empty string" do
      Tesla.Mock.mock_global(fn %{
                                  method: :get,
                                  url: "https://api.github.com/user/583231",
                                  headers: headers
                                } ->
        refute List.keyfind(headers, "Authorization", 0)
        Tesla.Mock.json(%{"id" => 583_231, "login" => "octocat", "name" => "The Octocat"})
      end)

      assert {:ok, _} = Github.user("583231", "")
    end

    test "returns :name from the response body" do
      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com/user/583231"} ->
        Tesla.Mock.json(%{"id" => 583_231, "login" => "octocat", "name" => "The Octocat"})
      end)

      assert {:ok, %{name: "The Octocat"}} = Github.user("583231", "tok")
    end

    test "404 returns {:error, :not_found}" do
      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com/user/583231"} ->
        {:ok, %Tesla.Env{status: 404, body: %{"message" => "Not Found"}}}
      end)

      assert {:error, :not_found} = Github.user("583231", "tok")
    end

    test "5xx returns {:error, {:http, status}}" do
      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com/user/583231"} ->
        {:ok, %Tesla.Env{status: 500, body: %{"message" => "boom"}}}
      end)

      assert {:error, {:http, 500}} = Github.user("583231", "tok")
    end

    test "transport error returns {:error, {:transport, reason}}" do
      Tesla.Mock.mock_global(fn %{method: :get, url: "https://api.github.com/user/583231"} ->
        {:error, :timeout}
      end)

      assert {:error, {:transport, :timeout}} = Github.user("583231", "tok")
    end
  end
end
