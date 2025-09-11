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
      reference_type: "branch",
      reference_value: "master",
      at: "0 0 * * *",
      name: "Periodic",
      id: UUID.uuid4()
    }

    params = Map.take(Map.new(extra), Map.keys(defaults))
    params = Map.merge(defaults, params)
    
    # Handle backward compatibility - if branch is provided, use it for reference_value
    params = if extra[:branch] do
      params
      |> Map.put(:reference_type, "branch") 
      |> Map.put(:reference_value, extra[:branch])
    else
      params
    end

    {:ok,
     periodic:
       %Periodics{}
       |> Periodics.changeset("v1.1", params)
       |> PeriodicsRepo.insert!()}
  end

  def insert_trigger(context, extra) do
    # Determine reference values - use provided branch or fall back to periodic's reference
    {reference_type, reference_value} = case extra[:branch] do
      nil -> 
        {context.periodic.reference_type || "branch", 
         context.periodic.reference_value || Periodics.branch_name(context.periodic) || "master"}
      branch_value -> 
        {"branch", branch_value}
    end
    
    # Insert params (fields allowed in changeset_insert)
    insert_params = %{
      periodic_id: context.periodic.id,
      project_id: context.periodic.project_id,
      recurring: context.periodic.recurring,
      reference_type: reference_type,
      reference_value: reference_value,
      pipeline_file: extra[:pipeline_file] || context.periodic.pipeline_file,
      scheduling_status: extra[:scheduling_status] || "passed",
      run_now_requester_id: extra[:triggered_by] || UUID.uuid4(),
      triggered_at: extra[:triggered_at] || DateTime.utc_now()
    }

    # Create the trigger first
    trigger = %PeriodicsTriggers{}
    |> PeriodicsTriggers.changeset_insert(insert_params)
    |> PeriodicsRepo.insert!()

    # Update with fields only allowed in changeset_update
    update_params = %{
      scheduling_status: extra[:scheduling_status] || "passed",
      scheduled_workflow_id: extra[:workflow_id] || UUID.uuid4(),
      scheduled_at: extra[:scheduled_at] || DateTime.utc_now()
    }

    trigger
    |> PeriodicsTriggers.changeset_update(update_params)
    |> PeriodicsRepo.update!()
  end
end
