defmodule Gofer.DeploymentMetrics do
  @moduledoc """
  Periodically reports Deployment Targets business metrics to Grafana
  """
  use Gofer.GenericMetrics
  alias Gofer.DeploymentTrigger.Model.MetricsQueries, as: TriggerQueries
  alias Gofer.Deployment.Model.MetricsQueries, as: DeploymentQueries

  @metric_prefix "Gofer.deployments.usage"
  @metrics_time ~T[03:00:00]

  def start_link(_args) do
    Gofer.GenericMetrics.start_link(__MODULE__,
      metric_prefix: @metric_prefix,
      module: __MODULE__
    )
  end

  def metrics do
    [
      organizations: {&DeploymentQueries.count_organizations/0, :count},
      projects: {&DeploymentQueries.count_projects/0, :count},
      total_targets: {&DeploymentQueries.count_all_targets/0, :count},
      used_targets: {&TriggerQueries.count_used_targets/0, :count}
    ]
  end

  def schedule_interval(now) do
    before_metrics_time = Time.compare(DateTime.to_time(now), @metrics_time) == :lt

    date =
      if before_metrics_time,
        do: DateTime.to_date(now),
        else: DateTime.to_date(now) |> Date.add(1)

    measure_time = DateTime.new!(date, @metrics_time)
    DateTime.diff(measure_time, now, :millisecond)
  end
end
