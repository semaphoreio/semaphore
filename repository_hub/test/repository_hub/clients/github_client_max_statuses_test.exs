defmodule RepositoryHub.GithubClientMaxStatusesTest do
  @moduledoc """
  Regression tests for the GitHub "max statuses per SHA+context" handling.

  GitHub returns the 422 with `errors` as a *string* (not a list of objects),
  and once a SHA+context combo is maxed, every subsequent POST also costs
  rate-limit even though it will be rejected. We must:

    1. Recognise the real response shape (string and list forms).
    2. Short-circuit subsequent calls via `MaxStatusesCache` so no further
       HTTP requests are issued — including no pre-flight rate-limit GET.
    3. Only cache true max-statuses 422s — never 403/404/307 or non-canonical
       Validation-Failed 422s.
  """
  use ExUnit.Case, async: false

  import Mock

  alias RepositoryHub.{GithubClient, MaxStatusesCache}

  @max_statuses_msg "Validation failed: This SHA and context has reached the maximum number of statuses."

  @real_422_body %{
    "documentation_url" => "https://docs.github.com/rest/commits/statuses#create-a-commit-status",
    "errors" => @max_statuses_msg,
    "message" => "Validation Failed",
    "status" => "422"
  }

  # Older shape: errors as a list of {message: "..."} objects.
  @legacy_422_body %{
    "documentation_url" => "https://docs.github.com/rest/commits/statuses#create-a-commit-status",
    "errors" => [
      %{
        "resource" => "Status",
        "code" => "custom",
        "field" => "context",
        "message" => "This SHA and context has reached the maximum number of statuses."
      }
    ],
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
      repo_owner: "owner",
      repo_name: "repo",
      commit_sha: "abc1234567890abcdef1234567890abcdef12345",
      status: "pending",
      url: "https://semaphore.example/wf/x",
      description: "The build is pending on Semaphore 2.0.",
      context: "ci/semaphoreci/push: repo"
    }
  end

  defp tentacat_response(status_code, body) do
    response = %HTTPoison.Response{
      status_code: status_code,
      body: body,
      request: %HTTPoison.Request{url: "https://api.github.com", headers: []}
    }

    {status_code, body, response}
  end

  defp tentacat_422, do: tentacat_response(422, @real_422_body)
  defp tentacat_422_legacy, do: tentacat_response(422, @legacy_422_body)

  # `with_client` does a pre-flight rate-limit check via `Tentacat.get/2`.
  # All tests here use a real-looking healthy rate-limit response so the
  # check passes and our create_build_status branch is exercised.
  defp healthy_rate_limit_response do
    body = %{"rate" => %{"remaining" => 14_999, "limit" => 15_000}}
    {200, body, %HTTPoison.Response{status_code: 200, body: body}}
  end

  defp statuses_create_count do
    Tentacat.Repositories.Statuses
    |> :meck.history()
    |> Enum.count(fn
      {_pid, {Tentacat.Repositories.Statuses, :create, _args}, _ret} -> true
      _ -> false
    end)
  end

  defp tentacat_rate_limit_count do
    Tentacat
    |> :meck.history()
    |> Enum.count(fn
      {_pid, {Tentacat, :get, ["rate_limit" | _]}, _ret} -> true
      _ -> false
    end)
  end

  test "recognises GitHub's real max-statuses 422 (errors as string) and returns :ok" do
    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [], create: fn _client, _owner, _repo, _sha, _payload -> tentacat_422() end}
    ]) do
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")
      assert_called(Tentacat.Repositories.Statuses.create(:_, :_, :_, :_, :_))

      assert MaxStatusesCache.maxed?(
               params().repo_owner,
               params().repo_name,
               params().commit_sha,
               params().context
             )
    end
  end

  test "recognises the legacy max-statuses 422 (errors as list of objects)" do
    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [],
       create: fn _client, _owner, _repo, _sha, _payload -> tentacat_422_legacy() end}
    ]) do
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")

      assert MaxStatusesCache.maxed?(
               params().repo_owner,
               params().repo_name,
               params().commit_sha,
               params().context
             )
    end
  end

  test "after the first 422, subsequent calls short-circuit before Tentacat AND before the rate-limit pre-flight" do
    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [], create: fn _client, _owner, _repo, _sha, _payload -> tentacat_422() end}
    ]) do
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")
      assert statuses_create_count() == 1
      first_rate_limit_calls = tentacat_rate_limit_count()
      assert first_rate_limit_calls >= 1

      # The cache should now short-circuit, so the second call must not
      # invoke Tentacat.Repositories.Statuses.create AND must skip the
      # `Tentacat.get("rate_limit", _)` pre-flight — the whole point of
      # the fix is to spare every rate-limit unit.
      assert {:ok, _} = GithubClient.create_build_status(params(), token: "abc")
      assert statuses_create_count() == 1
      assert tentacat_rate_limit_count() == first_rate_limit_calls
    end
  end

  test "a 422 for a different reason is NOT cached and still fails" do
    other_422 = %{
      "documentation_url" => "https://docs.github.com/",
      "errors" => "Validation failed: something else went wrong",
      "message" => "Validation Failed",
      "status" => "422"
    }

    with_mocks([
      {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
      {Tentacat.Repositories.Statuses, [],
       create: fn _client, _owner, _repo, _sha, _payload -> tentacat_response(422, other_422) end}
    ]) do
      assert {:error, error} = GithubClient.create_build_status(params(), token: "abc")
      assert error.message =~ "Can't create a commit status on GitHub"

      refute MaxStatusesCache.maxed?(
               params().repo_owner,
               params().repo_name,
               params().commit_sha,
               params().context
             )
    end
  end

  # A 403/404 in the same caller branch as 422 must NOT be put through the
  # max-statuses matcher and must NOT populate the cache, even if its body
  # somehow contained the canonical substring.
  for {status_code, label} <- [{403, "403 Forbidden"}, {404, "404 Not Found"}] do
    test "a #{label} is not cached even with a max-statuses-looking body" do
      misleading_body = %{
        "message" => "Validation Failed",
        "errors" => @max_statuses_msg,
        "status" => to_string(unquote(status_code))
      }

      with_mocks([
        {Tentacat, [:passthrough], get: fn "rate_limit", _client -> healthy_rate_limit_response() end},
        {Tentacat.Repositories.Statuses, [],
         create: fn _client, _owner, _repo, _sha, _payload ->
           tentacat_response(unquote(status_code), misleading_body)
         end}
      ]) do
        assert {:error, _} = GithubClient.create_build_status(params(), token: "abc")

        refute MaxStatusesCache.maxed?(
                 params().repo_owner,
                 params().repo_name,
                 params().commit_sha,
                 params().context
               )
      end
    end
  end
end
