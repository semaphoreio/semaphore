defmodule Guard.FrontRepo.FederatedIdentitySyncRequestTest do
  use Guard.RepoCase, async: true

  alias Guard.FrontRepo.FederatedIdentitySyncRequest, as: Request
  alias Guard.FrontRepo.RepoHostAccount

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

      [reloaded] = Guard.FrontRepo.all(Request)
      assert reloaded.attempts == 1
      assert reloaded.last_error == "identity push failed"
      assert DateTime.compare(reloaded.next_attempt_at, DateTime.utc_now()) == :gt
    end

    test "truncates oversized errors and caps the backoff" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])
      request = %{request | attempts: 50}

      assert :ok = Request.record_failure(request, String.duplicate("x", 2_000))

      [reloaded] = Guard.FrontRepo.all(Request)
      assert reloaded.attempts == 51
      assert String.length(reloaded.last_error) == 500

      max_retry = DateTime.add(DateTime.utc_now(), 3_700, :second)
      assert DateTime.compare(reloaded.next_attempt_at, max_retry) == :lt
    end

    test "is a no-op for nil" do
      assert :ok = Request.record_failure(nil, "boom")
    end
  end

  describe "lease_due/1" do
    test "returns due requests and makes them invisible to the next lease" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])

      assert [leased] = Request.lease_due(10)
      assert leased.id == request.id

      # the lease pushed next_attempt_at into the future
      assert Request.lease_due(10) == []
      assert Request.pending?("github", "55001")
    end

    test "skips requests scheduled in the future" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])
      :ok = Request.record_failure(request, "boom")

      assert Request.lease_due(10) == []
    end

    test "respects the batch limit, oldest first" do
      import Ecto.Query

      first = Request.enqueue(account(), [Ecto.UUID.generate()])
      _second = Request.enqueue(account(%{github_uid: "55002"}), [Ecto.UUID.generate()])

      # break the same-second tie in insertion order
      earlier = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)

      {1, _} =
        from(r in Request, where: r.id == ^first.id)
        |> Guard.FrontRepo.update_all(set: [inserted_at: earlier])

      assert [leased] = Request.lease_due(1)
      assert leased.id == first.id
    end
  end
end
