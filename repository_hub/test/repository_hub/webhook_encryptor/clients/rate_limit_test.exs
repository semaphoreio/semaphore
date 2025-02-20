defmodule RepositoryHub.WebhookEncryptor.RateLimitTest do
  use ExUnit.Case, async: true

  alias RepositoryHub.WebhookEncryptor.RateLimitError
  alias RepositoryHub.WebhookEncryptor.BitbucketClient
  alias RepositoryHub.WebhookEncryptor.GithubClient

  describe "wait_time/1" do
    test "when RateLimitError has reset_at and retry_after then returns retry_after value" do
      reset_at = (DateTime.utc_now() |> DateTime.to_unix()) + 120

      wait_time =
        RateLimitError.wait_time(%RateLimitError{
          reset_at: reset_at,
          retry_after: 180
        })

      assert 180 == wait_time
    end

    test "when RateLimitError has reset_at and retry_after is 0 then returns difference between reset_at and now" do
      reset_at = (DateTime.utc_now() |> DateTime.to_unix()) + 120

      wait_time =
        RateLimitError.wait_time(%RateLimitError{
          reset_at: reset_at,
          retry_after: 0
        })

      assert_in_delta 120, wait_time, 1
    end

    test "when RateLimitError has retry_after above 0 then returns retry_after" do
      wait_time =
        RateLimitError.wait_time(%RateLimitError{
          reset_at: nil,
          retry_after: 120
        })

      assert 120 == wait_time
    end

    test "when RateLimitError has retry_after equal to 0 then returns default wait time" do
      wait_time =
        RateLimitError.wait_time(%RateLimitError{
          reset_at: nil,
          retry_after: 0
        })

      assert 60 == wait_time
    end

    test "when RateLimitError has reset_at in the past then returns 0" do
      reset_at = (DateTime.utc_now() |> DateTime.to_unix()) - 120

      wait_time =
        RateLimitError.wait_time(%RateLimitError{
          reset_at: reset_at,
          retry_after: nil
        })

      assert_in_delta 0, wait_time, 1
    end

    test "when RateLimitError has reset_at in the future then returns the difference between reset_at and now" do
      reset_at = (DateTime.utc_now() |> DateTime.to_unix()) + 120

      wait_time =
        RateLimitError.wait_time(%RateLimitError{
          reset_at: reset_at,
          retry_after: nil
        })

      assert_in_delta 120, wait_time, 1
    end

    test "when RateLimitError has no reset_at or retry_after then returns default wait time" do
      wait_time = RateLimitError.wait_time(%RateLimitError{})
      assert 60 == wait_time
    end
  end

  test "when status is not 403 or 429 then returns {:ok, env}" do
    Tesla.Mock.mock(fn env -> %Tesla.Env{env | status: 201} end)
    assert {:ok, %{id: "", url: "url"}} = call_github()
  end

  test "when status == 403 and x-ratelimit-remaining is 0 then returns RateLimitError" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 403,
          headers: [
            {"x-ratelimit-remaining", "0"},
            {"x-ratelimit-reset", "1716807625"}
          ]
      }
    end)

    assert {:error, %RateLimitError{reset_at: 1_716_807_625, retry_after: nil}} = call_bitbucket()
  end

  test "when status == 403 and x-ratelimit-remaining is 1 then returns {:error, env}" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 403,
          body: %{error: "access_denied"},
          headers: [
            {"x-ratelimit-remaining", "1"},
            {"x-ratelimit-reset", "1716807625"}
          ]
      }
    end)

    assert {:error, {:forbidden, %{error: "access_denied"}}} = call_bitbucket()
  end

  test "when status == 403 and x-ratelimit-remaining is missing then returns {:error, {:forbidden, _body}}" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 403,
          body: %{error: "forbidden"},
          headers: [
            {"x-ratelimit-reset", "1716807625"}
          ]
      }
    end)

    assert {:error, {:forbidden, %{error: "forbidden"}}} = call_bitbucket()
  end

  test "when status == 429 is returned then returns RateLimitError with these values" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 429,
          headers: [
            {"x-ratelimit-reset", "1716807625"},
            {"retry-after", "120"}
          ]
      }
    end)

    assert {:error, %RateLimitError{reset_at: 1_716_807_625, retry_after: 120}} = call_github()
  end

  test "when status == 429 and retry-after is missing then returns RateLimitError without it" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 429,
          headers: [
            {"x-ratelimit-reset", "1716807625"}
          ]
      }
    end)

    assert {:error, %RateLimitError{reset_at: 1_716_807_625, retry_after: nil}} = call_github()
  end

  test "when status == 429 and rate limit reset is missing then returns RateLimitError without it" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 429,
          headers: [
            {"retry-after", "120"}
          ]
      }
    end)

    assert {:error, %RateLimitError{reset_at: nil, retry_after: 120}} = call_github()
  end

  test "when status == 429 and both retry-after and rate limit reset is missing then returns empty RateLimitError" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 429,
          headers: []
      }
    end)

    assert {:error, %RateLimitError{reset_at: nil, retry_after: nil}} = call_github()
  end

  test "when RateLimitError is returned then it contains `x-ratelimit` headers" do
    Tesla.Mock.mock(fn env ->
      %Tesla.Env{
        env
        | status: 429,
          headers: [
            {"x-ratelimit-reset", "1716807625"},
            {"x-ratelimit-remaining", "0"},
            {"x-ratelimit-limit", "5000"}
          ]
      }
    end)

    assert {:error,
            %RateLimitError{
              headers: [
                {"x-ratelimit-reset", "1716807625"},
                {"x-ratelimit-remaining", "0"},
                {"x-ratelimit-limit", "5000"}
              ],
              reset_at: 1_716_807_625,
              retry_after: nil
            }} = call_bitbucket()
  end

  defp dummy_payload do
    %{owner: "owner", repo: "repo", url: "url", events: ["push"], secret: "secret"}
  end

  defp call_github do
    GithubClient.new("token") |> GithubClient.create_webhook(dummy_payload())
  end

  defp call_bitbucket do
    BitbucketClient.new("token") |> BitbucketClient.create_webhook(dummy_payload())
  end
end
