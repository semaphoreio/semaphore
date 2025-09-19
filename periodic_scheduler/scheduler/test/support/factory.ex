defmodule Test.Support.Factory do
  @moduledoc """
  Common test factory functions
  """

  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.PeriodicsRepo

  def truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = PeriodicsRepo.query("TRUNCATE TABLE periodics CASCADE;")
    {:ok, %Postgrex.Result{}} = PeriodicsRepo.query("TRUNCATE TABLE periodics_triggers CASCADE;")
    {:ok, now: DateTime.utc_now()}
  end

  def setup_periodic(_context, extra \\ []) do
    defaults = %{
      organization_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      project_name: "Project",
      recurring: true,
      pipeline_file: "deploy.yml",
      reference: "master",
      at: "0 0 * * *",
      name: "Periodic",
      id: UUID.uuid4()
    }

    params = Map.take(Map.new(extra), Map.keys(defaults))
    params = Map.merge(defaults, params)

    {:ok,
     periodic:
       %Periodics{}
       |> Periodics.changeset("v1.1", params)
       |> PeriodicsRepo.insert!()}
  end

  def insert_trigger(context, extra) do
    params = %{
      periodic_id: context.periodic.id,
      project_id: context.periodic.project_id,
      recurring: context.periodic.recurring,
      reference: extra[:reference] || context.periodic.reference,
      pipeline_file: extra[:pipeline_file] || context.periodic.pipeline_file,
      scheduling_status: extra[:scheduling_status] || "passed",
      run_now_requester_id: extra[:triggered_by] || UUID.uuid4(),
      scheduled_workflow_id: extra[:workflow_id] || UUID.uuid4(),
      scheduled_at: extra[:scheduled_at] || DateTime.utc_now(),
      triggered_at: extra[:triggered_at] || DateTime.utc_now()
    }

    PeriodicsRepo.insert!(struct!(PeriodicsTriggers, params))
  end
end
