defmodule Rbac.FrontRepo.FederatedIdentitySyncRequestTest do
  use Rbac.RepoCase, async: true

  alias Rbac.FrontRepo.FederatedIdentitySyncRequest, as: Request
  alias Rbac.FrontRepo.RepoHostAccount

  defp account(overrides \\ %{}) do
    Map.merge(
      %RepoHostAccount{
        repo_host: "github",
        github_uid: "55001",
        user_id: Ecto.UUID.generate(),
        login: "claimer"
      },
      overrides
    )
  end

  describe "enqueue/2 and pending?/2" do
    test "an enqueued request is immediately due and pending" do
      released = [Ecto.UUID.generate()]

      request = Request.enqueue(account(), released)

      assert request.attempts == 0
      assert request.released_user_ids == released
      assert Request.pending?("github", "55001")
      refute Request.pending?("github", "99999")
      refute Request.pending?("bitbucket", "55001")
      assert Request.pending_count() == 1
    end
  end

  describe "complete/1" do
    test "deletes the request" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])

      assert :ok = Request.complete(request)
      refute Request.pending?("github", "55001")
    end

    test "is a no-op for nil" do
      assert :ok = Request.complete(nil)
    end
  end

  describe "record_failure/2" do
    test "increments attempts and schedules a backed-off retry" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])

      assert :ok = Request.record_failure(request, "identity push failed")

      [reloaded] = Rbac.FrontRepo.all(Request)
      assert reloaded.attempts == 1
      assert reloaded.last_error == "identity push failed"
      assert DateTime.compare(reloaded.next_attempt_at, DateTime.utc_now()) == :gt
    end

    test "truncates oversized errors and caps the backoff" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])
      request = %{request | attempts: 50}

      assert :ok = Request.record_failure(request, String.duplicate("x", 2_000))

      [reloaded] = Rbac.FrontRepo.all(Request)
      assert reloaded.attempts == 51
      assert String.length(reloaded.last_error) == 500

      max_retry = DateTime.add(DateTime.utc_now(), 3_700, :second)
      assert DateTime.compare(reloaded.next_attempt_at, max_retry) == :lt
    end

    test "is a no-op for nil" do
      assert :ok = Request.record_failure(nil, "boom")
    end
  end
end
