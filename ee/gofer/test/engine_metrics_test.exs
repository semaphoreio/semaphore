defmodule Gofer.EngineMetricsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  setup do
    start_supervised!(Gofer.Switch.Engine.SwitchSupervisor)
    start_supervised!(Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor)
    start_supervised!(Gofer.TargetTrigger.Engine.TargetTriggerSupervisor)
    start_supervised!(Gofer.Deployment.Engine.Supervisor)
    start_supervised!(Gofer.DeploymentTrigger.Engine.Supervisor)

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
    state = %{metric_prefix: "Gofer", module: Gofer.EngineMetrics}
    assert {:noreply, %{}} = Gofer.EngineMetrics.handle_info(:report_metrics, state)

    assert_metric_received("switch_process")
    assert_metric_received("switch_trigger_process")
    assert_metric_received("target_trigger_process")
    assert_metric_received("deployment_workers")
    assert_metric_received("deployment_triggers")
    assert_metric_received("stuck_deployment_triggers")
    assert_metric_received("stuck_deployment_targets")
    assert_metric_received("failed_deployment_targets")
  end

  defp assert_metric_received(metric_name) do
    metric_key = "Gofer.#{metric_name}"
    assert_receive {:"$gen_cast", {:send, ^metric_key, 0, :count}}
  end
end
