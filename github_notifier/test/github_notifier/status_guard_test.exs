defmodule GithubNotifier.StatusGuardTest do
  use ExUnit.Case

  alias GithubNotifier.StatusGuard

  setup do
    %{key: unique_status_key()}
  end

  describe "claim/3" do
    test "claims a fresh check", %{key: key} do
      assert {:ok, token} = StatusGuard.claim(key, "pending")
      assert is_binary(token)
    end

    test "reports busy with remaining lease while another claim is live", %{key: key} do
      assert {:ok, _token} = StatusGuard.claim(key, "success")
      assert {:busy, remaining} = StatusGuard.claim(key, "success")
      assert remaining > 0
    end

    test "claims after the lease expires", %{key: key} do
      assert {:ok, _token} = StatusGuard.claim(key, "success", lease_ms: 50)
      Process.sleep(80)

      assert {:ok, _new_token} = StatusGuard.claim(key, "success")
    end

    test "skips a pending after a terminal state was finalized", %{key: key} do
      assert {:ok, token} = StatusGuard.claim(key, "success")
      assert :ok = StatusGuard.finalize(key, "success", token)

      assert :skip = StatusGuard.claim(key, "pending")
    end

    test "allows a terminal state after pending was finalized", %{key: key} do
      assert {:ok, token} = StatusGuard.claim(key, "pending")
      assert :ok = StatusGuard.finalize(key, "pending", token)

      assert {:ok, _token} = StatusGuard.claim(key, "success")
    end

    test "allows a terminal state after a terminal state", %{key: key} do
      assert {:ok, token} = StatusGuard.claim(key, "success")
      assert :ok = StatusGuard.finalize(key, "success", token)

      assert {:ok, _token} = StatusGuard.claim(key, "failure")
    end

    test "guards checks independently per key", %{key: key} do
      assert {:ok, token} = StatusGuard.claim(key, "success")
      assert :ok = StatusGuard.finalize(key, "success", token)

      assert {:ok, _token} = StatusGuard.claim(unique_status_key(), "pending")
    end

    test "grants the lease to exactly one concurrent claimant", %{key: key} do
      results =
        1..20
        |> Enum.map(fn _ -> Task.async(fn -> StatusGuard.claim(key, "success") end) end)
        |> Task.await_many()

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:busy, _}, &1)) == 19
    end

    test "fails open when redis is unreachable", %{key: key} do
      stop_guard_connections()

      try do
        assert {:error, _reason} = StatusGuard.claim(key, "pending")
        assert StatusGuard.delivered?(key) == false
        assert :ok = StatusGuard.mark_delivered(key)
        assert :ok = StatusGuard.finalize(key, "success", "token")
        assert :ok = StatusGuard.release(key, "token")
      after
        restart_guard_connections()
      end
    end

    test "fails open while the guard is pinned by the health check", %{key: key} do
      StatusGuard.force_fail_open(true)

      try do
        assert {:error, :misconfigured} = StatusGuard.claim(key, "pending")
      after
        StatusGuard.force_fail_open(false)
      end
    end
  end

  describe "finalize/3" do
    test "a stale token does not overwrite newer state", %{key: key} do
      assert {:ok, stale_token} = StatusGuard.claim(key, "pending", lease_ms: 50)
      Process.sleep(80)

      assert {:ok, token} = StatusGuard.claim(key, "success")
      assert :ok = StatusGuard.finalize(key, "success", token)

      assert :ok = StatusGuard.finalize(key, "pending", stale_token)
      assert :skip = StatusGuard.claim(key, "pending")
    end
  end

  describe "release/2" do
    test "clears the lease without recording a delivery", %{key: key} do
      assert {:ok, token} = StatusGuard.claim(key, "pending")
      assert :ok = StatusGuard.release(key, token)

      assert {:ok, _token} = StatusGuard.claim(key, "pending")
    end

    test "a stale token does not clear another claimant's lease", %{key: key} do
      assert {:ok, stale_token} = StatusGuard.claim(key, "success", lease_ms: 50)
      Process.sleep(80)

      assert {:ok, _token} = StatusGuard.claim(key, "success")
      assert :ok = StatusGuard.release(key, stale_token)

      assert {:busy, _remaining} = StatusGuard.claim(key, "success")
    end
  end

  describe "dedupe" do
    test "mark_delivered/1 and delivered?/1 round-trip", %{key: key} do
      dedupe_key = "#{key}/success/All good"

      refute StatusGuard.delivered?(dedupe_key)
      assert :ok = StatusGuard.mark_delivered(dedupe_key)
      assert StatusGuard.delivered?(dedupe_key)
    end
  end

  defp unique_status_key do
    "repo-#{:erlang.unique_integer([:positive])}/sha/ppl/ci/test: Pipeline"
  end

  defp stop_guard_connections do
    for index <- 0..(StatusGuard.pool_size() - 1) do
      :ok = Supervisor.terminate_child(StatusGuard, {Redix, index})
    end
  end

  defp restart_guard_connections do
    for index <- 0..(StatusGuard.pool_size() - 1) do
      {:ok, _} = Supervisor.restart_child(StatusGuard, {Redix, index})
    end
  end
end
