defmodule Gofer.DeploymentTrigger.Model.MetricsQueries do
  @moduledoc """
  Gathers queries used for Deployment Target trigger metrics
  """
  import Ecto.Query
  require Ecto.Query

  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger
  alias Gofer.EctoRepo

  @metrics_prefix "Gofer.deployments.queries"

  def count_used_targets() do
    Watchman.benchmark("#{@metrics_prefix}.count_used_targets", fn ->
      EctoRepo.one(
        from(dt in DeploymentTrigger,
          select: count(dt.deployment_id, :distinct)
        )
      )
    end)
  end

  def count_stuck_triggers() do
    Watchman.benchmark("#{@metrics_prefix}.count_stuck_triggers", fn ->
      count_stuck_triggers(~w(INITIALIZING TRIGGERING STARTING)a)
    end)
  end

  def count_stuck_triggers(state) when is_atom(state) do
    EctoRepo.one(
      from(dt in DeploymentTrigger,
        where: dt.state == ^state,
        where: dt.updated_at < ago(1, "minute"),
        select: count(dt.id)
      )
    )
  end

  def count_stuck_triggers(states) when is_list(states) do
    EctoRepo.one(
      from(dt in DeploymentTrigger,
        where: dt.state in ^states,
        where: dt.updated_at < ago(1, "minute"),
        select: count(dt.id)
      )
    )
  end
end
