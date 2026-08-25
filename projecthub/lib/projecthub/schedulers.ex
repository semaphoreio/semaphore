defmodule Projecthub.Schedulers do
  alias Projecthub.Models.PeriodicTask.Definition
  alias Projecthub.Models.PeriodicTask.GRPC, as: PeriodicSchedulerClient
  alias Projecthub.Models.Scheduler

  require Logger

  def update(project, schedulers, requester_id) do
    if System.get_env("SKIP_SCHEDULERS") == "true" do
      Logger.info("Schedulers.update skipped: SKIP_SCHEDULERS=true project_id=#{project.id}")
      {:ok, nil}
    else
      do_update(project, schedulers, requester_id)
    end
  end

  defp do_update(project, schedulers, requester_id) do
    stored_flags = stored_notification_flags(project.id)
    definitions = Enum.map(schedulers, &to_periodic_definition(&1, stored_flags))

    Logger.info(
      "Schedulers.update dispatching to bulk_upsert_and_prune: project_id=#{project.id} " <>
        "requester_id=#{requester_id} schedulers=#{length(definitions)}"
    )

    case PeriodicSchedulerClient.bulk_upsert_and_prune(
           project.id,
           project.organization_id,
           requester_id,
           definitions
         ) do
      {:ok, _} ->
        Logger.info("Schedulers.update succeeded: project_id=#{project.id}")
        {:ok, nil}

      {:error, reason} = err ->
        Logger.error("Schedulers.update failed: project_id=#{project.id} reason=#{inspect(reason)}")

        err

      err ->
        Logger.error("Schedulers.update failed: project_id=#{project.id} reason=#{inspect(err)}")
        err
    end
  end

  def delete_all(project, requester_id) do
    Logger.info(
      "Schedulers.delete_all listing existing schedulers: project_id=#{project.id} " <>
        "requester_id=#{requester_id}"
    )

    {:ok, existing_schedulers} = Scheduler.list(project)

    Logger.info(
      "Schedulers.delete_all deleting #{length(existing_schedulers)} schedulers: " <>
        "project_id=#{project.id}"
    )

    Enum.each(existing_schedulers, fn scheduler ->
      Scheduler.delete(scheduler, requester_id)
    end)

    {:ok, nil}
  end

  # The legacy scheduler struct has no notification flags, so carry the stored
  # values forward - otherwise a project update through this path would reset
  # every task's commit status settings.
  defp stored_notification_flags(project_id) do
    case PeriodicSchedulerClient.list(project_id) do
      {:ok, periodics} ->
        Map.new(periodics, fn periodic ->
          {periodic.id,
           {periodic.skip_scheduled_run_notifications == true, periodic.skip_manual_run_notifications == true}}
        end)

      _ ->
        %{}
    end
  end

  defp to_periodic_definition(scheduler, stored_flags) do
    {skip_scheduled, skip_manual} = Map.get(stored_flags, scheduler.id, {false, false})

    %{
      id: scheduler.id || "",
      name: scheduler.name || "",
      description: "",
      recurring: true,
      reference: Definition.format_branch_as_reference(scheduler.branch),
      at: scheduler.at || "",
      pipeline_file: scheduler.pipeline_file || "",
      parameters: [],
      state: Definition.status_to_state(scheduler.status),
      skip_scheduled_run_notifications: skip_scheduled,
      skip_manual_run_notifications: skip_manual
    }
  end
end
