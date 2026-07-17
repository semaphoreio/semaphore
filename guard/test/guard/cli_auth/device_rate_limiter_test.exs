defmodule Guard.CLIAuth.DeviceRateLimiterTest do
  use ExUnit.Case, async: false

  alias Guard.CLIAuth.DeviceRateLimiter

  setup do
    DeviceRateLimiter.reset()
    :ok
  end

  test "allows entries until the per-window threshold is reached" do
    assert :ok = DeviceRateLimiter.check()

    Enum.each(1..(DeviceRateLimiter.max_failures() - 1), fn _ ->
      DeviceRateLimiter.record_failure()
    end)

    assert :ok = DeviceRateLimiter.check()

    DeviceRateLimiter.record_failure()
    assert {:error, :rate_limited} = DeviceRateLimiter.check()
  end

  test "reset clears the counters" do
    Enum.each(1..DeviceRateLimiter.max_failures(), fn _ -> DeviceRateLimiter.record_failure() end)
    assert {:error, :rate_limited} = DeviceRateLimiter.check()

    DeviceRateLimiter.reset()
    assert :ok = DeviceRateLimiter.check()
  end

  describe "per-IP tier" do
    test "one IP hitting its own threshold is throttled without affecting other IPs" do
      Enum.each(1..DeviceRateLimiter.max_failures_per_ip(), fn _ ->
        DeviceRateLimiter.record_failure("203.0.113.7")
      end)

      assert {:error, :rate_limited} = DeviceRateLimiter.check("203.0.113.7")
      # A different IP is unaffected — this is the fix: one attacker can no
      # longer DoS every other device sign-in via the shared global budget.
      assert :ok = DeviceRateLimiter.check("203.0.113.8")
      # Callers with no IP (e.g. it couldn't be determined) still work,
      # falling back to the global-only check.
      assert :ok = DeviceRateLimiter.check()
    end

    test "an IP under its own threshold is allowed even if other IPs have failures" do
      Enum.each(1..(DeviceRateLimiter.max_failures_per_ip() - 1), fn _ ->
        DeviceRateLimiter.record_failure("203.0.113.7")
      end)

      assert :ok = DeviceRateLimiter.check("203.0.113.7")
    end

    test "the global backstop still trips for a distributed attacker rotating IPs" do
      # Each IP individually stays under its own per-IP threshold, but the
      # aggregate crosses the global backstop.
      per_ip = DeviceRateLimiter.max_failures_per_ip() - 1

      Enum.each(1..DeviceRateLimiter.max_failures(), fn i ->
        ip = "203.0.113.#{rem(i, per_ip) + 1}"
        DeviceRateLimiter.record_failure(ip)
      end)

      assert {:error, :rate_limited} = DeviceRateLimiter.check("203.0.113.250")
    end
  end
end
