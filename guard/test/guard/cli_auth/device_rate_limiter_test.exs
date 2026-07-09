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
end
