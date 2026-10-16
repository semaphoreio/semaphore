defmodule RepositoryHub.GithubChecksClientTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias RepositoryHub.GithubChecksClient

  @owner "renderedtext"
  @repo "semaphore"
  @sha "9bc99381f3242e0d4c0b1b2c3d4e5f6071829304"
  @name "ci/semaphoreci/push: build"

  describe "create_check_run/2" do
    test "posts an in_progress check-run and returns the decoded body on 201" do
      mock(fn
        %{method: :post, url: url, body: body} ->
          assert url == "https://api.github.com/repos/#{@owner}/#{@repo}/check-runs"
          decoded = Jason.decode!(body)
          assert decoded["name"] == @name
          assert decoded["head_sha"] == @sha
          assert decoded["status"] == "in_progress"
          assert decoded["details_url"] == "https://semaphore.test/wf/1"
          refute Map.has_key?(decoded, "conclusion")

          json(%{"id" => 42, "name" => @name, "status" => "in_progress"}, status: 201)
      end)

      assert {:ok, %{"id" => 42}} =
               GithubChecksClient.create_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   head_sha: @sha,
                   name: @name,
                   status: "in_progress",
                   details_url: "https://semaphore.test/wf/1"
                 },
                 token: "ghs_installation_token"
               )
    end

    test "returns a precondition error on a 4xx response" do
      mock(fn %{method: :post} ->
        json(%{"message" => "Resource not accessible by integration"}, status: 403)
      end)

      assert {:error, %{message: message}} =
               GithubChecksClient.create_check_run(
                 %{repo_owner: @owner, repo_name: @repo, head_sha: @sha, name: @name, status: "in_progress"},
                 token: "oauth_token_cannot_do_checks"
               )

      assert message =~ "403"
    end
  end

  describe "update_check_run/2" do
    test "patches the run to completed with a conclusion" do
      mock(fn %{method: :patch, url: url, body: body} ->
        assert url == "https://api.github.com/repos/#{@owner}/#{@repo}/check-runs/42"
        decoded = Jason.decode!(body)
        assert decoded["status"] == "completed"
        assert decoded["conclusion"] == "success"

        json(%{"id" => 42, "status" => "completed", "conclusion" => "success"}, status: 200)
      end)

      assert {:ok, %{"conclusion" => "success"}} =
               GithubChecksClient.update_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   check_run_id: 42,
                   status: "completed",
                   conclusion: "success"
                 },
                 token: "ghs_installation_token"
               )
    end
  end

  describe "find_check_run/2" do
    test "returns the first run matching a sha and check name" do
      mock(fn %{method: :get, url: url, query: query} ->
        assert url == "https://api.github.com/repos/#{@owner}/#{@repo}/commits/#{@sha}/check-runs"
        assert query[:check_name] == @name

        json(
          %{"total_count" => 1, "check_runs" => [%{"id" => 99, "name" => @name}]},
          status: 200
        )
      end)

      assert {:ok, %{"id" => 99}} =
               GithubChecksClient.find_check_run(
                 %{repo_owner: @owner, repo_name: @repo, commit_sha: @sha, name: @name},
                 token: "ghs_installation_token"
               )
    end

    test "returns not_found when no run matches" do
      mock(fn %{method: :get} ->
        json(%{"total_count" => 0, "check_runs" => []}, status: 200)
      end)

      assert {:error, %{message: message}} =
               GithubChecksClient.find_check_run(
                 %{repo_owner: @owner, repo_name: @repo, commit_sha: @sha, name: "missing"},
                 token: "ghs_installation_token"
               )

      assert message =~ "No check-run"
    end

    test "returns the most-recent run (max id) when several share the name" do
      mock(fn %{method: :get} ->
        json(
          %{
            "total_count" => 3,
            "check_runs" => [
              %{"id" => 7, "name" => @name},
              %{"id" => 99, "name" => @name},
              %{"id" => 42, "name" => @name}
            ]
          },
          status: 200
        )
      end)

      assert {:ok, %{"id" => 99}} =
               GithubChecksClient.find_check_run(
                 %{repo_owner: @owner, repo_name: @repo, commit_sha: @sha, name: @name},
                 token: "ghs_installation_token"
               )
    end
  end
end
