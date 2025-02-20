defmodule Gofer.DeploymentMetricsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  setup do
    {:ok, %Postgrex.Result{}} = Gofer.EctoRepo.query("TRUNCATE TABLE switches CASCADE;")
    {:ok, %Postgrex.Result{}} = Gofer.EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")

    watchman_pid = Process.whereis(Watchman.Server)
    Process.unregister(Watchman.Server)
    Process.register(self(), Watchman.Server)

    on_exit(fn ->
      Process.register(watchman_pid, Watchman.Server)
    end)

    :ok
  end

  test "handle_info/2 reports metrics" do
    state = %{metric_prefix: "Gofer.deployments.usage", module: Gofer.DeploymentMetrics}
    assert {:noreply, %{}} = Gofer.DeploymentMetrics.handle_info(:report_metrics, state)

    assert_metric_received("organizations")
    assert_metric_received("projects")
    assert_metric_received("total_targets")
    assert_metric_received("used_targets")
  end

  describe "schedule_interval/1" do
    test "before 3 AM schedules the report the same day" do
      assert 30 * 60 * 1_000 ==
               Gofer.DeploymentMetrics.schedule_interval(~U[2023-01-05 02:30:00Z])
    end

    test "at 3 AM schedules the report the next day" do
      assert 24 * 60 * 60 * 1_000 ==
               Gofer.DeploymentMetrics.schedule_interval(~U[2023-01-05 03:00:00Z])
    end

    test "after 3 AM schedules the report the next day" do
      assert (24 * 60 - 30) * 60 * 1_000 ==
               Gofer.DeploymentMetrics.schedule_interval(~U[2023-01-05 03:30:00Z])
    end
  end

  defp assert_metric_received(metric_name) do
    metric_key = "Gofer.deployments.usage.#{metric_name}"
    assert_receive {:"$gen_cast", {:send, ^metric_key, 0, :count}}
  end
end
