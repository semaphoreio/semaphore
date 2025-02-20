defmodule Scheduler.Workers.ScheduleTask do
  @moduledoc """
  It will try to schedule workflow and if that fails it will restart and try again.
  This goes on for configured duration after which the proces will be stopped and
  failure will be logged and submitted to grafana.
  """

  use GenServer, restart: :transient

  alias Scheduler.Periodics.Model.PeriodicsQueries, as: PQ
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries
  alias Scheduler.Actions
  alias LogTee, as: LT

  defp max_scheduling_duration() do
    Application.get_env(:scheduler, :max_scheduling_duration)
  end

  def start_link(args = {periodic, trigger}) do
    id = "#{periodic.id} #{trigger.triggered_at}"
    GenServer.start_link(__MODULE__, args, name: {:global, id})
  end

  def init({periodic, trigger}) do
    send(self(), :schedule_workflow)
    {:ok, %{periodic: periodic, trigger: trigger}}
  end

  def handle_info(:schedule_workflow, st = %{periodic: periodic, trigger: trigger}) do
    with {:active, true} <- periodic.id |> PQ.get_by_id() |> periodic_active?(trigger),
         {:ok, trigger} <- PeriodicsTriggersQueries.get_by_id(trigger.id),
         :continue <- deadline_reached?(trigger),
         {:ok, _message} <- schedule_workflow(periodic, trigger, st) do
      "Processed successfully." |> graceful_exit(st)
    else
      {:stop, reason, state} ->
        {:stop, reason, state}

      {:stop, message} ->
        message |> graceful_exit(st)

      error ->
        error |> restart(st)
    end
  end

  defp periodic_active?({:ok, %{suspended: true}}, trigger) do
    message = "Scheduler with id '#{trigger.periodic_id}' is suspended."
    params = %{scheduling_status: "failed", error_description: message}
    PeriodicsTriggersQueries.update(trigger, params)
    {:stop, message}
  end

  defp periodic_active?({:ok, %{paused: true}}, trigger) do
    message = "Scheduler with id '#{trigger.periodic_id}' is paused."
    params = %{scheduling_status: "failed", error_description: message}
    PeriodicsTriggersQueries.update(trigger, params)
    {:stop, message}
  end

  defp periodic_active?({:error, "Periodic with id: " <> _rest}, trigger) do
    {:stop, "Scheduler with id '#{trigger.periodic_id}' was deleted."}
  end

  defp periodic_active?(_response, _id), do: {:active, true}

  defp deadline_reached?(trigger = %{triggered_at: timestamp}) do
    started_at = timestamp |> DateTime.to_unix()
    now = DateTime.utc_now() |> DateTime.to_unix()

    if now - started_at > max_scheduling_duration() do
      Watchman.increment("PeriodicSch.schedule_wf_timeout")

      PeriodicsTriggersQueries.update(trigger, %{scheduling_status: "failed"})

      {:stop, "Deadline for scheduling the workflow was reached."}
    else
      :continue
    end
  end

  defp schedule_workflow(periodic, trigger, state) do
    case Actions.schedule_wf(periodic, trigger) do
      {:ok, message} ->
        {:ok, message}

      {:error, {:missing_project, reason}} ->
        PeriodicsTriggersQueries.update(trigger, %{scheduling_status: "failed"})
        LT.warn(reason, "Cannot find project '#{periodic.project_id}'.")
        "Cannot find project." |> graceful_exit(state)

      {:error, {:missing_revision, reason}} ->
        PeriodicsTriggersQueries.update(trigger, %{scheduling_status: "failed"})
        LT.warn(reason, "Cannot find revision for '#{periodic.id}'.")
        "Cannot find git commit reference." |> graceful_exit(state)

      {:error, %{code: :RESOURCE_EXHAUSTED, message: message}} ->
        LT.warn(message, "Resource exhausted for #{periodic.id}.")
        message |> restart_with_exp_backoff(%{state | trigger: trigger})

      error ->
        error
    end
  end

  defp graceful_exit(value, state = %{periodic: %{id: id}}) do
    value
    |> LT.info("ScheduleTask process for periodic #{id} exits: ")

    {:stop, :normal, state}
  end

  defp restart_with_exp_backoff(error, state = %{periodic: %{id: id}}) do
    backoff = calculate_backoff(state.trigger.attempts)
    LT.warn(error, "Sleeping for #{backoff} ms before retrying. [periodic ID: #{id}]")
    :timer.sleep(calculate_backoff(state.trigger.attempts))

    error
    |> LT.warn("ScheduleTask process for periodic #{id} failiure: ")

    {:stop, :restart, state}
  end

  defp restart(error, state = %{periodic: %{id: id}}) do
    # delay restart a bit
    :timer.sleep(1_000)

    error
    |> LT.warn("ScheduleTask process for periodic #{id} failiure: ")

    {:stop, :restart, state}
  end

  def calculate_backoff(nil), do: 1_000
  def calculate_backoff(0), do: 1_000

  def calculate_backoff(attempts) do
    backoff = round(5_000 * :math.pow(2, attempts - 1))
    (backoff > 60_000 && 60_000) || backoff
  end
end
