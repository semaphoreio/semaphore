defmodule Gofer.CacheMetricsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  setup do
    start_supervised!(Gofer.Cache)

    watchman_pid = Process.whereis(Watchman.Server)
    Process.unregister(Watchman.Server)
    Process.register(self(), Watchman.Server)

    on_exit(fn ->
      Process.register(watchman_pid, Watchman.Server)
    end)

    :ok
  end

  test "handle_info/2 reports metrics" do
    state = %{metric_prefix: "Gofer.cache", module: Gofer.CacheMetrics}
    assert {:noreply, %{}} = Gofer.EngineMetrics.handle_info(:report_metrics, state)

    assert_metric_received("rbac_roles.size")
  end

  defp assert_metric_received(metric_name) do
    metric_key = "Gofer.cache.#{metric_name}"
    assert_receive {:"$gen_cast", {:send, ^metric_key, 0, :gauge}}
  end
end
