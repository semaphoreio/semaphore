defmodule Notifications.Egress.UrlGuardResolverTimeoutTest do
  # async: false - this swaps the process-global :egress_resolver, so it must not
  # run alongside other modules that rely on the default test resolver.
  use ExUnit.Case, async: false

  alias Notifications.Egress.UrlGuard

  describe "verify/1 - fail-closed on a hung resolver" do
    setup do
      previous = Application.get_env(:notifications, :egress_resolver)
      Application.put_env(:notifications, :egress_resolver, {Support.HangingResolver, :resolve})
      on_exit(fn -> Application.put_env(:notifications, :egress_resolver, previous) end)
      :ok
    end

    test "a resolver that never returns fails closed within bounded time" do
      task = Task.async(fn -> UrlGuard.verify("https://hang.example.test/hook") end)

      # The guard bounds resolution at ~2s; allow generous slack and require the
      # call to return a fail-closed result rather than hang forever.
      result = Task.yield(task, 6_000) || Task.shutdown(task)

      assert result == {:ok, {:error, :unresolvable}}
    end
  end
end
