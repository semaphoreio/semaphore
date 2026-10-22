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

  # Every call first reads /rate_limit (GithubApi.with_client/4).
  defp mock_github(handler, remaining \\ 5000) do
    mock(fn
      %{method: :get, url: "https://api.github.com/rate_limit"} ->
        json(%{"rate" => %{"remaining" => remaining}})

      env ->
        handler.(env)
    end)
  end

  test "makes no request when the rate limit is at the reserve" do
    mock_github(fn env -> flunk("unexpected request #{env.method} #{env.url}") end, 1000)

    assert {:error, :rate_limit} =
             GithubChecksClient.create_check_run(
               %{repo_owner: @owner, repo_name: @repo, head_sha: @sha, name: @name, status: "in_progress"},
               token: "ghs_installation_token"
             )
  end

  describe "create_check_run/2" do
    test "posts an in_progress check-run and returns the decoded body on 201" do
      mock_github(fn
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
  end

  describe "update_check_run/2" do
    test "patches the run to completed with a conclusion" do
      mock_github(fn %{method: :patch, url: url, body: body} ->
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
      mock_github(fn %{method: :get, url: url, query: query} ->
        assert url == "https://api.github.com/repos/#{@owner}/#{@repo}/commits/#{@sha}/check-runs"
        assert query[:check_name] == @name
        assert query[:per_page] == 100
        assert query[:page] == 1
        assert query[:app_id] == @app_id
        assert query[:filter] == "all"

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
      mock_github(fn %{method: :get} ->
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
      mock_github(fn %{method: :get} ->
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
      mock_github(fn %{method: :get} ->
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

    test "follows pages until a short one and finds a run on a later page" do
      other_runs = fn from -> Enum.map(from..(from + 99), &%{"id" => &1, "external_id" => "semaphore:other"}) end

      mock_github(fn %{method: :get, query: query} ->
        case query[:page] do
          1 -> json(%{"check_runs" => other_runs.(1)}, status: 200)
          2 -> json(%{"check_runs" => other_runs.(101)}, status: 200)
          3 -> json(%{"check_runs" => [%{"id" => 500, "external_id" => @external_id}]}, status: 200)
        end
      end)

      assert {:ok, %{"id" => 500}} =
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

    test "stops after 10 full pages" do
      test_pid = self()

      mock_github(fn %{method: :get, query: query} ->
        send(test_pid, {:page, query[:page]})
        json(%{"check_runs" => Enum.map(1..100, &%{"id" => &1, "external_id" => "semaphore:other"})}, status: 200)
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
      assert_received {:page, 10}
      refute_received {:page, 11}
    end

    test "fails when a later page fails, without returning a partial lookup" do
      mock_github(fn %{method: :get, query: query} ->
        case query[:page] do
          1 ->
            json(%{"check_runs" => Enum.map(1..100, &%{"id" => &1, "external_id" => "semaphore:other"})}, status: 200)

          2 ->
            json(%{"message" => "Server Error"}, status: 502)
        end
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

      assert status == GRPC.Status.unavailable()
    end

    test "list_check_runs/2 returns every same-named run, whatever its external_id" do
      mock_github(fn %{method: :get} ->
        json(
          %{
            "check_runs" => [
              %{"id" => 7, "name" => @name, "external_id" => @external_id},
              %{"id" => 98, "name" => @name, "external_id" => "semaphore:ppl-2"}
            ]
          },
          status: 200
        )
      end)

      assert {:ok, [%{"id" => 7}, %{"id" => 98}]} =
               GithubChecksClient.list_check_runs(
                 %{repo_owner: @owner, repo_name: @repo, commit_sha: @sha, name: @name, app_id: @app_id},
                 token: "ghs_installation_token"
               )
    end

    test "returns not_found when only other apps have a run with the name" do
      mock_github(fn %{method: :get} ->
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
