defmodule Rbac.FrontRepo.FederatedIdentitySyncRequestTest do
  use Rbac.RepoCase, async: true

  alias Rbac.FrontRepo.FederatedIdentitySyncRequest, as: Request

  # guard owns this table - it enqueues, drains and dead-letters. rbac only
  # reads it, so rows are inserted directly here rather than through a writer
  # rbac does not have.
  defp insert_request(attrs \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Request{
      repo_host: "github",
      uid: "55001",
      claiming_user_id: Ecto.UUID.generate(),
      released_user_ids: [Ecto.UUID.generate()],
      login: "claimer",
      attempts: Keyword.get(attrs, :attempts, 0),
      next_attempt_at: now
    }
    |> Rbac.FrontRepo.insert!()
  end

  describe "pending?/2" do
    test "is true while a sync is outstanding for the identity" do
      insert_request()

      assert Request.pending?("github", "55001")
      refute Request.pending?("github", "99999")
      refute Request.pending?("bitbucket", "55001")
    end

    test "is false with no row at all" do
      refute Request.pending?("github", "55001")
    end

    test "is false once the row is dead-lettered" do
      # guard has stopped retrying it, so it must stop gating pushes here too -
      # otherwise the claiming user can never sign in through this provider
      # again, with no recovery path.
      insert_request(attempts: Request.max_attempts())

      refute Request.pending?("github", "55001")
    end

    test "is still true one attempt short of the ceiling" do
      insert_request(attempts: Request.max_attempts() - 1)

      assert Request.pending?("github", "55001")
    end
  end

  describe "max_attempts/0" do
    test "matches guard's, which writes the rows rbac reads" do
      # The table is shared. If the two ceilings drift, rbac gates pushes on
      # rows guard has already abandoned, or stops gating on rows guard is
      # still retrying.
      assert Request.max_attempts() == 20
    end
  end
end
