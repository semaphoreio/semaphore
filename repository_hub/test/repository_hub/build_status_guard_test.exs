defmodule RepositoryHub.BuildStatusGuardTest do
  use RepositoryHub.Case, async: false

  alias RepositoryHub.{BuildStatusGuard, InternalApiFactory, Repo}

  setup do
    %{
      request:
        InternalApiFactory.create_build_status_request(
          repository_id: Ecto.UUID.generate(),
          context: "ci/semaphoreci/push: Pipeline",
          source_id: Ecto.UUID.generate(),
          status: :PENDING
        )
    }
  end

  describe "claim/1" do
    test "claims a fresh check", %{request: request} do
      assert {:ok, %DateTime{}} = BuildStatusGuard.claim(request)
    end

    test "reports busy while another claim is live", %{request: request} do
      assert {:ok, _fence} = BuildStatusGuard.claim(request)
      assert :busy = BuildStatusGuard.claim(request)
    end

    test "takes over an expired lease", %{request: request} do
      assert {:ok, _fence} = BuildStatusGuard.claim(request)
      backdate_claim(request, BuildStatusGuard.lease_seconds() + 1)

      assert {:ok, _new_fence} = BuildStatusGuard.claim(request)
    end

    test "skips a pending after a terminal state was delivered", %{request: request} do
      success = %{request | status: :SUCCESS}
      assert {:ok, fence} = BuildStatusGuard.claim(success)
      assert :ok = BuildStatusGuard.finalize(success, fence)

      assert :skip = BuildStatusGuard.claim(%{request | status: :PENDING})
    end

    test "allows a terminal state after pending was delivered", %{request: request} do
      assert {:ok, fence} = BuildStatusGuard.claim(request)
      assert :ok = BuildStatusGuard.finalize(request, fence)

      assert {:ok, _fence} = BuildStatusGuard.claim(%{request | status: :SUCCESS})
    end

    test "skips a pending after a stopped state was delivered", %{request: request} do
      stopped = %{request | status: :STOPPED}
      assert {:ok, fence} = BuildStatusGuard.claim(stopped)
      assert :ok = BuildStatusGuard.finalize(stopped, fence)

      assert :skip = BuildStatusGuard.claim(%{request | status: :PENDING})
    end

    test "allows a terminal state after a terminal state", %{request: request} do
      success = %{request | status: :SUCCESS}
      assert {:ok, fence} = BuildStatusGuard.claim(success)
      assert :ok = BuildStatusGuard.finalize(success, fence)

      assert {:ok, _fence} = BuildStatusGuard.claim(%{request | status: :FAILURE})
    end

    test "suppresses a pending when the caller asked for suppression", %{request: request} do
      assert :suppressed = BuildStatusGuard.claim(%{request | suppress: true})
    end

    test "suppresses a terminal state when nothing is outstanding", %{request: request} do
      assert :suppressed = BuildStatusGuard.claim(%{request | status: :SUCCESS, suppress: true})
    end

    test "delivers a suppressed terminal state that reconciles an outstanding pending",
         %{request: request} do
      assert {:ok, fence} = BuildStatusGuard.claim(request)
      assert :ok = BuildStatusGuard.finalize(request, fence)

      assert {:ok, _fence} = BuildStatusGuard.claim(%{request | status: :SUCCESS, suppress: true})
    end

    test "suppresses a terminal state once the pending has been reconciled",
         %{request: request} do
      assert {:ok, pending_fence} = BuildStatusGuard.claim(request)
      assert :ok = BuildStatusGuard.finalize(request, pending_fence)

      success = %{request | status: :SUCCESS, suppress: true}
      assert {:ok, fence} = BuildStatusGuard.claim(success)
      assert :ok = BuildStatusGuard.finalize(success, fence)

      assert :suppressed = BuildStatusGuard.claim(success)
    end

    test "claims a check whose context exceeds 255 characters", %{request: request} do
      request = %{request | context: "ci/semaphoreci/push: " <> String.duplicate("b", 300)}

      assert {:ok, %DateTime{}} = BuildStatusGuard.claim(request)
    end

    test "returns invalid_key for a malformed repository_id", %{request: request} do
      request = %{request | repository_id: "not-a-uuid"}

      assert {:error, :invalid_key} = BuildStatusGuard.claim(request)
    end

    test "reports guard_unavailable while the table is missing", %{request: request} do
      Repo.query!("ALTER TABLE build_status_guards RENAME TO build_status_guards_hidden")

      try do
        assert {:error, :guard_unavailable} = BuildStatusGuard.claim(request)
      after
        Repo.query!("ALTER TABLE build_status_guards_hidden RENAME TO build_status_guards")
      end
    end

    test "guards checks independently per source_id", %{request: request} do
      success = %{request | status: :SUCCESS}
      assert {:ok, fence} = BuildStatusGuard.claim(success)
      assert :ok = BuildStatusGuard.finalize(success, fence)

      rerun = %{request | status: :PENDING, source_id: Ecto.UUID.generate()}
      assert {:ok, _fence} = BuildStatusGuard.claim(rerun)
    end
  end

  describe "release/2" do
    test "no-ops on a malformed repository_id", %{request: request} do
      request = %{request | repository_id: "not-a-uuid"}

      assert :ok = BuildStatusGuard.release(request, DateTime.utc_now())
    end

    test "clears the lease without recording a delivery", %{request: request} do
      assert {:ok, fence} = BuildStatusGuard.claim(request)
      assert :ok = BuildStatusGuard.release(request, fence)

      assert {:ok, _fence} = BuildStatusGuard.claim(request)
      assert [[nil]] = select_field(request, "last_state")
    end
  end

  describe "finalize/2" do
    test "no-ops on a malformed repository_id", %{request: request} do
      request = %{request | repository_id: "not-a-uuid"}

      assert :ok = BuildStatusGuard.finalize(request, DateTime.utc_now())
    end

    test "records the delivered state and clears the lease", %{request: request} do
      success = %{request | status: :SUCCESS}
      assert {:ok, fence} = BuildStatusGuard.claim(success)
      assert :ok = BuildStatusGuard.finalize(success, fence)

      assert [["SUCCESS", nil]] = select_fields(success, "last_state, claimed_at")
    end

    test "a stale fence does not overwrite newer state", %{request: request} do
      assert {:ok, stale_fence} = BuildStatusGuard.claim(request)
      backdate_claim(request, BuildStatusGuard.lease_seconds() + 1)

      success = %{request | status: :SUCCESS}
      assert {:ok, fence} = BuildStatusGuard.claim(success)
      assert :ok = BuildStatusGuard.finalize(success, fence)

      assert :ok = BuildStatusGuard.finalize(%{request | status: :PENDING}, stale_fence)

      assert [["SUCCESS"]] = select_field(request, "last_state")
    end
  end

  defp backdate_claim(request, seconds) do
    Repo.query!(
      "UPDATE build_status_guards SET claimed_at = now() - make_interval(secs => $5) " <>
        "WHERE repository_id = $1 AND commit_sha = $2 AND context = $3 AND source_id = $4",
      key_params(request) ++ [seconds]
    )
  end

  defp select_field(request, field), do: select_fields(request, field)

  defp select_fields(request, fields) do
    Repo.query!(
      "SELECT #{fields} FROM build_status_guards " <>
        "WHERE repository_id = $1 AND commit_sha = $2 AND context = $3 AND source_id = $4",
      key_params(request)
    ).rows
  end

  defp key_params(request) do
    [
      Ecto.UUID.dump!(request.repository_id),
      request.commit_sha,
      request.context,
      request.source_id
    ]
  end
end
