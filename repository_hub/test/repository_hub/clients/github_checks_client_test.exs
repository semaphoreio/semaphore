defmodule RepositoryHub.GithubChecksClientTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias RepositoryHub.GithubChecksClient

  @owner "renderedtext"
  @repo "semaphore"
  @sha "9bc99381f3242e0d4c0b1b2c3d4e5f6071829304"
  @name "ci/semaphoreci/push: build"
  @external_id "semaphore:ppl-1"
  @app_id "90709"

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
        json(%{"message" => "Validation Failed"}, status: 422)
      end)

      assert {:error, %{status: status, message: message}} =
               GithubChecksClient.create_check_run(
                 %{repo_owner: @owner, repo_name: @repo, head_sha: @sha, name: @name, status: "in_progress"},
                 token: "ghs_installation_token"
               )

      assert status == GRPC.Status.failed_precondition()
      assert message =~ "422"
    end

    test "returns permission_denied when the installation lacks the Checks permission" do
      mock(fn %{method: :post} ->
        json(%{"message" => "Resource not accessible by integration"}, status: 403)
      end)

      assert {:error, %{status: status}} =
               GithubChecksClient.create_check_run(
                 %{repo_owner: @owner, repo_name: @repo, head_sha: @sha, name: @name, status: "in_progress"},
                 token: "ghs_installation_token"
               )

      assert status == GRPC.Status.permission_denied()
    end

    test "any other 403 stays a precondition error" do
      mock(fn %{method: :post} ->
        json(%{"message" => "API rate limit exceeded"}, status: 403)
      end)

      assert {:error, %{status: status}} =
               GithubChecksClient.create_check_run(
                 %{repo_owner: @owner, repo_name: @repo, head_sha: @sha, name: @name, status: "in_progress"},
                 token: "ghs_installation_token"
               )

      assert status == GRPC.Status.failed_precondition()
    end

    test "returns an unavailable error on a 5xx response" do
      mock(fn %{method: :post} ->
        json(%{"message" => "Server Error"}, status: 502)
      end)

      assert {:error, %{status: status, message: message}} =
               GithubChecksClient.create_check_run(
                 %{repo_owner: @owner, repo_name: @repo, head_sha: @sha, name: @name, status: "in_progress"},
                 token: "ghs_installation_token"
               )

      assert status == GRPC.Status.unavailable()
      assert message =~ "502"
    end
  end

  describe "check_rate_limit/2" do
    defp rate_limit_response(remaining) do
      json(%{"rate" => %{"remaining" => remaining}}, status: 200)
    end

    test "ok when remaining is above the reserve" do
      mock(fn %{method: :get, url: "https://api.github.com/rate_limit"} -> rate_limit_response(1001) end)

      assert :ok = GithubChecksClient.check_rate_limit(%{repo_owner: @owner}, token: "ghs_installation_token")
    end

    test "rate_limit error when remaining is at or below the reserve" do
      mock(fn %{method: :get} -> rate_limit_response(1000) end)

      assert {:error, :rate_limit} =
               GithubChecksClient.check_rate_limit(%{repo_owner: @owner}, token: "ghs_installation_token")
    end

    test "rate_limit error when the limit can't be read" do
      mock(fn %{method: :get} -> json(%{"message" => "Server Error"}, status: 500) end)

      assert {:error, :rate_limit} =
               GithubChecksClient.check_rate_limit(%{repo_owner: @owner}, token: "ghs_installation_token")
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
        assert query[:per_page] == 100
        assert query[:app_id] == @app_id

        json(
          %{"total_count" => 1, "check_runs" => [%{"id" => 99, "name" => @name, "external_id" => @external_id}]},
          status: 200
        )
      end)

      assert {:ok, %{"id" => 99}} =
               GithubChecksClient.find_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   commit_sha: @sha,
                   name: @name,
                   external_id: @external_id,
                   app_id: @app_id
                 },
                 token: "ghs_installation_token"
               )
    end

    test "returns not_found when no run matches" do
      mock(fn %{method: :get} ->
        json(%{"total_count" => 0, "check_runs" => []}, status: 200)
      end)

      assert {:error, %{status: status, message: message}} =
               GithubChecksClient.find_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   commit_sha: @sha,
                   name: "missing",
                   external_id: @external_id,
                   app_id: @app_id
                 },
                 token: "ghs_installation_token"
               )

      assert status == GRPC.Status.not_found()
      assert message =~ "No check-run"
    end

    test "returns the most-recent run (max id) when several share the name" do
      mock(fn %{method: :get} ->
        json(
          %{
            "total_count" => 3,
            "check_runs" => [
              %{"id" => 7, "name" => @name, "external_id" => @external_id},
              %{"id" => 99, "name" => @name, "external_id" => @external_id},
              %{"id" => 42, "name" => @name, "external_id" => @external_id}
            ]
          },
          status: 200
        )
      end)

      assert {:ok, %{"id" => 99}} =
               GithubChecksClient.find_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   commit_sha: @sha,
                   name: @name,
                   external_id: @external_id,
                   app_id: @app_id
                 },
                 token: "ghs_installation_token"
               )
    end

    test "ignores runs created by other apps or pipelines" do
      mock(fn %{method: :get} ->
        json(
          %{
            "check_runs" => [
              %{"id" => 7, "name" => @name, "external_id" => @external_id},
              %{"id" => 99, "name" => @name, "external_id" => "another-app"},
              %{"id" => 98, "name" => @name, "external_id" => "semaphore:ppl-2"},
              %{"id" => 97, "name" => @name}
            ]
          },
          status: 200
        )
      end)

      assert {:ok, %{"id" => 7}} =
               GithubChecksClient.find_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   commit_sha: @sha,
                   name: @name,
                   external_id: @external_id,
                   app_id: @app_id
                 },
                 token: "ghs_installation_token"
               )
    end

    test "returns not_found when only other apps have a run with the name" do
      mock(fn %{method: :get} ->
        json(%{"check_runs" => [%{"id" => 99, "name" => @name, "external_id" => "another-app"}]}, status: 200)
      end)

      assert {:error, %{status: status}} =
               GithubChecksClient.find_check_run(
                 %{
                   repo_owner: @owner,
                   repo_name: @repo,
                   commit_sha: @sha,
                   name: @name,
                   external_id: @external_id,
                   app_id: @app_id
                 },
                 token: "ghs_installation_token"
               )

      assert status == GRPC.Status.not_found()
    end
  end
end
