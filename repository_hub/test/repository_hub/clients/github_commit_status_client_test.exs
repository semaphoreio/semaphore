defmodule RepositoryHub.GithubCommitStatusClientTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias RepositoryHub.GithubCommitStatusClient

  @owner "renderedtext"
  @repo "semaphore"
  @sha "9bc99381f3242e0d4c0b1b2c3d4e5f6071829304"
  @context "ci/semaphoreci/push: build"
  @status_url "https://api.github.com/repos/#{@owner}/#{@repo}/commits/#{@sha}/status"

  @params %{repo_owner: @owner, repo_name: @repo, commit_sha: @sha, context: @context}

  # Every call first reads /rate_limit (GithubApi.with_client/4).
  defp mock_github(handler, remaining \\ 5000) do
    mock(fn
      %{method: :get, url: "https://api.github.com/rate_limit"} ->
        json(%{"rate" => %{"remaining" => remaining}})

      env ->
        handler.(env)
    end)
  end

  defp statuses(contexts), do: Enum.map(contexts, &%{"context" => &1, "state" => "success"})

  test "finds the context in the combined status" do
    mock_github(fn %{method: :get, url: @status_url, query: query} ->
      assert query[:page] == 1
      json(%{"statuses" => [%{"context" => @context, "state" => "failure"} | statuses(["other"])]})
    end)

    assert {:ok, %{"context" => @context, "state" => "failure"}} =
             GithubCommitStatusClient.find_commit_status(@params, token: "ghs_installation_token")
  end

  test "returns not_found when the commit has no status with the context" do
    mock_github(fn %{method: :get, url: @status_url} -> json(%{"statuses" => statuses(["other"])}) end)

    assert {:error, %{status: status}} =
             GithubCommitStatusClient.find_commit_status(@params, token: "ghs_installation_token")

    assert status == GRPC.Status.not_found()
  end

  test "follows pages until it finds the context" do
    mock_github(fn %{method: :get, url: @status_url, query: query} ->
      case query[:page] do
        1 -> json(%{"statuses" => statuses(Enum.map(1..100, &"ctx-#{&1}"))})
        2 -> json(%{"statuses" => statuses([@context])})
      end
    end)

    assert {:ok, %{"context" => @context}} =
             GithubCommitStatusClient.find_commit_status(@params, token: "ghs_installation_token")
  end

  test "stops after 10 full pages" do
    mock_github(fn %{method: :get, url: @status_url, query: query} ->
      assert query[:page] <= 10
      json(%{"statuses" => statuses(Enum.map(1..100, &"ctx-#{query[:page]}-#{&1}"))})
    end)

    assert {:error, %{status: status}} =
             GithubCommitStatusClient.find_commit_status(@params, token: "ghs_installation_token")

    assert status == GRPC.Status.not_found()
  end

  test "maps a GitHub failure through GithubApi" do
    mock_github(fn %{method: :get, url: @status_url} ->
      %Tesla.Env{status: 502, body: %{"message" => "Bad Gateway"}}
    end)

    assert {:error, %{status: status}} =
             GithubCommitStatusClient.find_commit_status(@params, token: "ghs_installation_token")

    assert status == GRPC.Status.unavailable()
  end

  test "makes no request when the rate limit is at the reserve" do
    mock_github(fn env -> flunk("unexpected request #{env.method} #{env.url}") end, 1000)

    assert {:error, :rate_limit} = GithubCommitStatusClient.find_commit_status(@params, token: "ghs_installation_token")
  end
end
