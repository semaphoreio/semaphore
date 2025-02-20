defmodule Gofer.Deployment.Model.MetricsQueries do
  @moduledoc """
  Gathers queries used for Deployment Target metrics
  """
  import Ecto.Query
  require Ecto.Query

  alias Gofer.Deployment.Model.Deployment
  alias Gofer.EctoRepo

  @metrics_prefix "Gofer.deployments.queries"

  def count_organizations() do
    Watchman.benchmark("#{@metrics_prefix}.count_organizations", fn ->
      EctoRepo.one(
        from(d in Deployment,
          select: count(d.organization_id, :distinct)
        )
      )
    end)
  end

  def count_projects() do
    Watchman.benchmark("#{@metrics_prefix}.count_projects", fn ->
      EctoRepo.one(
        from(d in Deployment,
          select: count(d.project_id, :distinct)
        )
      )
    end)
  end

  def count_all_targets() do
    Watchman.benchmark("#{@metrics_prefix}.count_all_targets", fn ->
      EctoRepo.one(
        from(d in Deployment,
          select: count(d.id)
        )
      )
    end)
  end

  def count_stuck_targets() do
    Watchman.benchmark("#{@metrics_prefix}.count_stuck_targets", fn ->
      EctoRepo.one(
        from(d in Deployment,
          where: d.state == :SYNCING,
          where: d.result in [:SUCCESS, :FAILURE],
          where: d.updated_at < ago(1, "minute"),
          select: count(d.id)
        )
      )
    end)
  end

  def count_failed_targets() do
    Watchman.benchmark("#{@metrics_prefix}.count_failed_targets", fn ->
      EctoRepo.one(
        from(d in Deployment,
          where: d.state == :FINISHED,
          where: d.result == :FAILURE,
          select: count(d.id)
        )
      )
    end)
  end
end
