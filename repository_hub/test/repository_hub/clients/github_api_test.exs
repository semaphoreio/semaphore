defmodule RepositoryHub.GithubApiTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias RepositoryHub.GithubApi

  @params %{repo_owner: "renderedtext", repo_name: "semaphore"}
  @token "ghs_installation_token"

  defp mock_github(rate_limit_response, handler \\ fn _env -> json(%{"id" => 1}) end) do
    mock(fn
      %{method: :get, url: "https://api.github.com/rate_limit"} -> rate_limit_response
      env -> handler.(env)
    end)
  end

  defp remaining(count), do: json(%{"rate" => %{"remaining" => count}})

  defp call(purpose \\ :create_check_run) do
    GithubApi.with_client(@token, @params.repo_owner, purpose, fn client ->
      client
      |> Tesla.get("/repos/renderedtext/semaphore/check-runs/1")
      |> GithubApi.handle_response(purpose, @params)
    end)
  end

  describe "with_client/4" do
    test "runs the call when remaining is above the purpose's reserve" do
      mock_github(remaining(1001))

      assert {:ok, %{"id" => 1}} = call()
    end

    test "refuses the call when remaining is at the reserve" do
      mock_github(remaining(1000), fn env -> flunk("unexpected request #{env.url}") end)

      assert {:error, :rate_limit} = call()
    end

    test "assumes a low limit when it can't be read" do
      mock_github(json(%{"message" => "Server Error"}, status: 500), fn env ->
        flunk("unexpected request #{env.url}")
      end)

      assert {:error, :rate_limit} = call()
    end

    test "fails as precondition when the token is not authorized" do
      mock_github(json(%{"message" => "Bad credentials"}, status: 401))

      assert {:error, %{status: status}} = call()
      assert status == GRPC.Status.failed_precondition()
    end

    test "sends GitHub API headers with the token" do
      mock_github(remaining(5000), fn env ->
        assert Tesla.get_header(env, "authorization") == "Bearer #{@token}"
        assert Tesla.get_header(env, "accept") == "application/vnd.github+json"
        assert Tesla.get_header(env, "x-github-api-version") == "2022-11-28"
        json(%{"id" => 1})
      end)

      assert {:ok, _} = call()
    end
  end

  describe "handle_response/3" do
    defp respond(status, body), do: mock_github(remaining(5000), fn _ -> json(body, status: status) end)

    test "returns the body on 2xx" do
      respond(201, %{"id" => 42})

      assert {:ok, %{"id" => 42}} = call()
    end

    test "maps a missing App permission to permission_denied" do
      respond(403, %{"message" => "Resource not accessible by integration"})

      assert {:error, %{status: status}} = call()
      assert status == GRPC.Status.permission_denied()
    end

    test "maps any other 403 to failed_precondition" do
      respond(403, %{"message" => "Must have admin rights to Repository."})

      assert {:error, %{status: status}} = call()
      assert status == GRPC.Status.failed_precondition()
    end

    test "maps a primary rate limit 403 to rate_limit" do
      mock_github(remaining(5000), fn _ ->
        %Tesla.Env{
          status: 403,
          headers: [{"x-ratelimit-remaining", "0"}],
          body: %{"message" => "Forbidden"}
        }
      end)

      assert {:error, :rate_limit} = call()
    end

    test "maps a secondary rate limit 403 to rate_limit" do
      mock_github(remaining(5000), fn _ ->
        %Tesla.Env{status: 403, headers: [{"retry-after", "60"}], body: %{"message" => "Forbidden"}}
      end)

      assert {:error, :rate_limit} = call()
    end

    test "maps a 403 with a rate limit message to rate_limit" do
      respond(403, %{"message" => "You have exceeded a secondary rate limit. Please wait a few minutes."})

      assert {:error, :rate_limit} = call()
    end

    test "maps 429 to rate_limit" do
      respond(429, %{"message" => "Too Many Requests"})

      assert {:error, :rate_limit} = call()
    end

    test "maps 4xx to failed_precondition" do
      respond(422, %{"message" => "Validation Failed"})

      assert {:error, %{status: status, message: message}} = call()
      assert status == GRPC.Status.failed_precondition()
      assert message =~ "422"
    end

    test "maps 5xx to unavailable" do
      respond(502, %{"message" => "Server Error"})

      assert {:error, %{status: status, message: message}} = call()
      assert status == GRPC.Status.unavailable()
      assert message =~ "502"
    end

    test "maps a transport error to unavailable" do
      mock_github(remaining(5000), fn _ -> {:error, :econnrefused} end)

      assert {:error, %{status: status}} = call()
      assert status == GRPC.Status.unavailable()
    end
  end
end
