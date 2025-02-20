defmodule Gofer.EngineMetrics do
  @moduledoc """
  Periodically reports number of different engine processes as a metric on Grafana
  """
  use Gofer.GenericMetrics

  @metric_prefix "Gofer"
  @metrics [
    :switch_process,
    :switch_trigger_process,
    :target_trigger_process,
    :deployment_workers,
    :deployment_triggers,
    :stuck_deployment_triggers,
    :stuck_deployment_targets,
    :failed_deployment_targets
  ]

  def start_link(_args) do
    Gofer.GenericMetrics.start_link(__MODULE__,
      metric_prefix: @metric_prefix,
      module: __MODULE__
    )
  end

  def schedule_interval(_now), do: Application.get_env(:gofer, :engine_metrics_pool_period)
  def metrics, do: Enum.into(@metrics, [], &{&1, {fn -> fetch_metric_value(&1) end, :count}})

  defp fetch_metric_value(:switch_process),
    do: count_children(Gofer.Switch.Engine.SwitchSupervisor)

  defp fetch_metric_value(:switch_trigger_process),
    do: count_children(Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor)

  defp fetch_metric_value(:target_trigger_process),
    do: count_children(Gofer.TargetTrigger.Engine.TargetTriggerSupervisor)

  defp fetch_metric_value(:deployment_workers),
    do: count_children(Gofer.Deployment.Engine.Supervisor)

  defp fetch_metric_value(:deployment_triggers),
    do: count_children(Gofer.DeploymentTrigger.Engine.Supervisor)

  defp fetch_metric_value(:stuck_deployment_triggers),
    do: Gofer.DeploymentTrigger.Model.MetricsQueries.count_stuck_triggers()

  defp fetch_metric_value(:stuck_deployment_targets),
    do: Gofer.Deployment.Model.MetricsQueries.count_stuck_targets()

  defp fetch_metric_value(:failed_deployment_targets),
    do: Gofer.Deployment.Model.MetricsQueries.count_failed_targets()

  defp count_children(supervisor),
    do: DynamicSupervisor.count_children(supervisor) |> Map.fetch!(:active)
end
