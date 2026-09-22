defmodule Guard.FrontRepo.FederatedIdentitySyncRequestTest do
  use Guard.RepoCase, async: true

  alias Guard.FrontRepo.FederatedIdentitySyncRequest, as: Request
  alias Guard.FrontRepo.RepoHostAccount

  # enqueue/2 schedules a request one lease ahead so the in-process sync owns
  # the first attempt. The drainer only ever sees rows that have become due, so
  # tests of due_ids/1 and lease/1 have to age them first.
  defp make_due(request) do
    import Ecto.Query

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {1, _} =
      from(r in Request, where: r.id == ^request.id)
      |> Guard.FrontRepo.update_all(set: [next_attempt_at: now])

    request
  end

  # One failure short of the ceiling, so the next record_failure/2 dead-letters.
  defp at_last_attempt(request) do
    %{request | attempts: Request.max_attempts() - 1}
  end

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
    test "an enqueued request is pending but not immediately due" do
      released = [Ecto.UUID.generate()]

      request = Request.enqueue(account(), released)

      assert request.attempts == 0
      assert request.released_user_ids == released
      assert Request.pending?("github", "55001")
      refute Request.pending?("github", "99999")
      refute Request.pending?("bitbucket", "55001")
      assert Request.pending_count() == 1

      # The claim starts an in-process sync that holds no lease, so the row
      # must not be leasable until that task has had a full lease to finish.
      # Otherwise the next drainer tick runs the same Keycloak move twice.
      assert DateTime.compare(request.next_attempt_at, DateTime.utc_now()) == :gt
      assert Request.due_ids(10) == []
      assert Request.lease(request.id) == nil
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

  describe "dead lettering" do
    test "a row short of the ceiling is still pending, due and leasable" do
      import Ecto.Query

      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()

      {1, _} =
        from(r in Request, where: r.id == ^request.id)
        |> Guard.FrontRepo.update_all(set: [attempts: Request.max_attempts() - 1])

      assert Request.pending?("github", "55001")
      assert Request.pending_count() == 1
      assert Request.dead_letter_count() == 0
      assert [_] = Request.due_ids(10)
      assert %Request{} = Request.lease(request.id)
    end

    test "the failure that reaches the ceiling stops the row blocking SSO" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> at_last_attempt()

      assert :ok = Request.record_failure(request, "identity removal failed")

      # The row survives - it records a claim Keycloak never reconciled - but
      # it must no longer gate the claiming user's identity push.
      assert Request.dead_letter_count() == 1
      refute Request.pending?("github", "55001")
      assert Request.pending_count() == 0
    end

    test "a dead-lettered row is never retried again" do
      import Ecto.Query

      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> at_last_attempt()
      :ok = Request.record_failure(request, "boom")

      # even once its backoff elapses
      {1, _} =
        from(r in Request, where: r.id == ^request.id)
        |> Guard.FrontRepo.update_all(
          set: [next_attempt_at: DateTime.utc_now() |> DateTime.truncate(:second)]
        )

      assert Request.due_ids(10) == []
      assert Request.lease(request.id) == nil
    end

    test "max_attempts matches rbac's, which enqueues into this shared table" do
      # rbac writes rows this drainer picks up. If the two ceilings drift,
      # one service gates identity pushes on rows the other has abandoned.
      assert Request.max_attempts() == 20
    end

    test "dead lettering one row leaves another claim's row alone" do
      doomed = Request.enqueue(account(), [Ecto.UUID.generate()]) |> at_last_attempt()

      other =
        Request.enqueue(account(%{github_uid: "55002"}), [Ecto.UUID.generate()]) |> make_due()

      :ok = Request.record_failure(doomed, "boom")

      refute Request.pending?("github", "55001")
      assert Request.pending?("github", "55002")
      assert Request.due_ids(10) == [other.id]
    end
  end

  describe "due_ids/1" do
    test "returns due requests" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()

      assert [id] = Request.due_ids(10)
      assert id == request.id
    end

    test "skips requests scheduled in the future" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])
      :ok = Request.record_failure(request, "boom")

      assert Request.due_ids(10) == []
    end

    test "respects the batch limit, oldest first" do
      import Ecto.Query

      first = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()

      _second =
        Request.enqueue(account(%{github_uid: "55002"}), [Ecto.UUID.generate()]) |> make_due()

      # break the same-second tie in insertion order
      earlier = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)

      {1, _} =
        from(r in Request, where: r.id == ^first.id)
        |> Guard.FrontRepo.update_all(set: [inserted_at: earlier])

      assert [id] = Request.due_ids(1)
      assert id == first.id
    end
  end

  describe "lease/1" do
    test "returns the row and makes it invisible to the next lease" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()

      assert leased = Request.lease(request.id)
      assert leased.id == request.id

      # the lease pushed next_attempt_at into the future
      assert Request.lease(request.id) == nil
      assert Request.due_ids(10) == []
      assert Request.pending?("github", "55001")
    end

    test "returns nil for a row that is not due" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()])
      :ok = Request.record_failure(request, "boom")

      assert Request.lease(request.id) == nil
    end

    test "returns nil for a row that no longer exists" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()
      :ok = Request.complete(request)

      assert Request.lease(request.id) == nil
    end

    test "only one of two leases on the same id wins" do
      request = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()

      # A second drainer racing for the same candidate id: the row is already
      # leased, so this one must skip rather than process it twice.
      assert %Request{} = Request.lease(request.id)
      assert Request.lease(request.id) == nil
    end

    test "leasing one row leaves the others due" do
      first = Request.enqueue(account(), [Ecto.UUID.generate()]) |> make_due()

      second =
        Request.enqueue(account(%{github_uid: "55002"}), [Ecto.UUID.generate()]) |> make_due()

      assert %Request{} = Request.lease(first.id)

      assert Request.due_ids(10) == [second.id]
    end
  end
end
