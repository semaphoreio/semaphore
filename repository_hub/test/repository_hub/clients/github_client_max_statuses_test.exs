defmodule RepositoryHub.GithubClientMaxStatusesTest do
  @moduledoc """
  Regression tests for the GitHub "max statuses per SHA+context" handling.

  GitHub returns the 422 with `errors` as a *string* (not a list of objects),
  and once a SHA+context combo is maxed, every subsequent POST also costs
  rate-limit even though it will be rejected. We must:

    1. Recognise the real response shape.
    2. Short-circuit subsequent calls via `MaxStatusesCache` so no further
       HTTP requests are issued.
  """
  use ExUnit.Case, async: false

  import Mock

  alias RepositoryHub.{GithubClient, MaxStatusesCache}

  @real_422_body %{
    "documentation_url" => "https://docs.github.com/rest/commits/statuses#create-a-commit-status",
    "errors" => "Validation failed: This SHA and context has reached the maximum number of statuses.",
    "message" => "Validation Failed",
    "status" => "422"
  }

  setup do
    # Cache is per-pod, named ETS. Ensure clean state between tests.
    :ets.delete_all_objects(:gh_max_statuses_cache)
    :ok
  end

  defp params do
    %{
      repo_owner: "confluentinc",
      repo_name: "semaphore-test",
      commit_sha: "5b048357141306568fd7ce5c9c17b6225a240c8d",
      status: "pending",
      url: "https://semaphore.example/wf/x",
      description: "The build is pending on Semaphore 2.0.",
      context: "ci/semaphoreci-staging/push: semaphore-test"
    }
  end

  defp tentacat_422 do
    response = %HTTPoison.Response{
      status_code: 422,
      body: @real_422_body,
      request: %HTTPoison.Request{url: "https://api.github.com", headers: []}
    }

    {422, @real_422_body, response}
  end

  # `with_client` does a pre-flight rate-limit check via `Tentacat.get/2`.
  # All tests here use a real-looking healthy rate-limit response so the
  # check passes and our create_build_status branch is exercised.
  defp healthy_rate_limit_response do
    body = %{"rate" => %{"remaining" => 14_999, "limit" => 15_000}}
    {200, body, %HTTPoison.Response{status_code: 200, body: body}}
  end

  test "recognises GitHub's real max-statuses 422 (errors as string) and returns :ok" do
    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [],
       create: fn _client, _owner, _repo, _sha, _payload -> tentacat_422() end}
    ]) do
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")
      assert_called(Tentacat.Repositories.Statuses.create(:_, :_, :_, :_, :_))
    end
  end

  test "after the first 422, subsequent calls short-circuit and never hit Tentacat" do
    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [],
       create: fn _client, _owner, _repo, _sha, _payload -> tentacat_422() end}
    ]) do
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")
      assert statuses_create_count() == 1

      # The cache should now mark this SHA+context as maxed, so the second
      # call must not invoke Tentacat.Repositories.Statuses.create at all.
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")
      assert statuses_create_count() == 1

      assert MaxStatusesCache.maxed?(
               params().repo_owner,
               params().repo_name,
               params().commit_sha,
               params().context
             )
    end
  end

  test "a 422 for a different reason is NOT cached and still fails" do
    other_422 = %{
      "documentation_url" => "https://docs.github.com/",
      "errors" => "Validation failed: something else went wrong",
      "message" => "Validation Failed",
      "status" => "422"
    }

    response = %HTTPoison.Response{
      status_code: 422,
      body: other_422,
      request: %HTTPoison.Request{url: "https://api.github.com", headers: []}
    }

    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [],
       create: fn _client, _owner, _repo, _sha, _payload -> {422, other_422, response} end}
    ]) do
      assert {:error, %{status: 9}} = GithubClient.create_build_status(params(), token: "abc")

      refute MaxStatusesCache.maxed?(
               params().repo_owner,
               params().repo_name,
               params().commit_sha,
               params().context
             )
    end
  end

  defp statuses_create_count do
    Tentacat.Repositories.Statuses
    |> :meck.history()
    |> length()
  end
end
