defmodule Gofer.DeploymentTrigger.Engine.Worker do
  @moduledoc """
  Worker logic for synchronizing DT secrets with Secrethub
  """
  use GenServer, restart: :transient
  require Logger

  alias Gofer.DeploymentTrigger.Model
  alias Model.DeploymentTriggerQueries, as: Queries
  alias Model.DeploymentTrigger, as: Trigger

  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Switch.Model.Switch
  alias Gofer.Deployment.Guardian

  @metric_prefix "Gofer.deployment_triggers.engine"
  @retry_sleep_period 3_000
  @deadline_seconds 60

  def start_link({switch, deployment, params}) do
    name = {:global, {__MODULE__, params["request_token"]}}
    args = {switch, deployment, params}
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def start_link(trigger) do
    name = {:global, {__MODULE__, trigger.request_token}}
    GenServer.start_link(__MODULE__, trigger, name: name)
  end

  # GenServer callbacks

  def init({switch = %Switch{}, deployment = %Deployment{}, params}) do
    case Queries.create(switch, deployment, params) do
      {:ok, trigger = %Trigger{}} -> init(trigger)
      {:error, reason} -> {:stop, reason}
    end
  end

  def init(trigger = %Trigger{}) do
    Kernel.send(self(), :run)
    {:ok, trigger}
  end

  def handle_info(:run, trigger = %Trigger{state: :INITIALIZING}) do
    with {:ok, trigger} <- check_deadline(trigger),
         {:ok, metadata} <- check_access(trigger),
         {:ok, trigger} <- Queries.transition_to(trigger, :TRIGGERING) do
      log(:debug, "deployment trigger triggered", trigger, metadata)
      report_engine_events(~w(initialized))
      continue_running(trigger)
    else
      {:error, {:forbidden, metadata}} ->
        reason = Keyword.get(metadata, :reason, "forbidden_access")
        Queries.finalize(trigger, "failed", reason)

        log(:error, "deployment trigger denied", trigger, metadata)
        report_engine_events(~w(denied done))
        report_resolution_time(trigger)

        stop_running(trigger)

      {:error, {:not_found, metadata = [deployment_id: _id]}} ->
        log(:error, "deployment not found", trigger, metadata)
        Queries.finalize(trigger, "failed", "missing_deployment")

        report_engine_events(~w(pruned))
        stop_running(trigger)

      {:error, {:not_found, metadata = [switch_id: _id]}} ->
        log(:error, "switch not found", trigger, metadata)
        Queries.finalize(trigger, "failed", "missing_switch")

        report_engine_events(~w(pruned))
        stop_running(trigger)

      {:error, :deadline_reached} ->
        log(:error, "deployment trigger reached deadline", trigger)
        Queries.finalize(trigger, "failed", "deadline_reached")

        report_engine_events(~w(deadline))
        stop_running(trigger)

      {:error, %Ecto.StaleEntryError{}} ->
        log(:error, "deployment trigger pruned", trigger)

        report_engine_events(~w(pruned))
        stop_running(trigger)

      {:error, reason} ->
        log(:error, inspect(reason), trigger)
        report_engine_events(~w(failed))
        sleep_and_retry(trigger)
    end
  end

  def handle_info(:run, trigger = %Trigger{state: :TRIGGERING}) do
    with {:ok, trigger} <- check_deadline(trigger),
         {:ok, _pid} <- trigger_switch(trigger.switch_trigger_params),
         {:ok, trigger} <- Queries.transition_to(trigger, :STARTING) do
      log(:debug, "deployment trigger started", trigger)
      report_engine_events(~w(triggered))
      continue_running(trigger)
    else
      {:error, :deadline_reached} ->
        log(:error, "deployment trigger reached deadline", trigger)
        Queries.finalize(trigger, "failed", "deadline_reached")

        report_engine_events(~w(deadline))
        stop_running(trigger)

      {:error, %Ecto.StaleEntryError{}} ->
        log(:error, "deployment trigger pruned", trigger)
        report_engine_events(~w(pruned))
        stop_running(trigger)

      {:error, reason} ->
        log(:error, inspect(reason), trigger)
        report_engine_events(~w(failed))
        sleep_and_retry(trigger)
    end
  end

  def handle_info(:run, trigger = %Trigger{state: :STARTING}) do
    with {:ok, trigger} <- check_deadline(trigger),
         {:ok, target_trigger} <- check_target_trigger(trigger),
         {:ok, trigger} <- Queries.finalize(trigger, target_trigger) do
      log(:debug, "deployment trigger finalized", trigger)
      report_engine_events(~w(started done))
      report_resolution_time(trigger)

      stop_running(trigger)
    else
      {:error, :unprocessed} ->
        log(:info, "target trigger not processed", trigger)
        sleep_and_retry(trigger)

      {:error, :not_found} ->
        log(:info, "target trigger not found", trigger)
        sleep_and_retry(trigger)

      {:error, :deadline_reached} ->
        log(:error, "deployment trigger reached deadline", trigger)
        Queries.finalize(trigger, "failed", "deadline_reached")

        report_engine_events(~w(deadline))
        stop_running(trigger)

      {:error, %Ecto.StaleEntryError{}} ->
        log(:error, "deployment trigger pruned", trigger)
        report_engine_events(~w(pruned))
        stop_running(trigger)

      {:error, reason} ->
        log(:error, inspect(reason), trigger)
        report_engine_events(~w(failed))
        sleep_and_retry(trigger)
    end
  end

  def handle_info(:run, trigger = %Trigger{state: :DONE}) do
    log(:info, "deployment trigger already finalized", trigger)
    stop_running(trigger)
  end

  def handle_info(:run, trigger = %Trigger{}) do
    log(:error, "unknown trigger state", trigger)
    stop_running(trigger)
  end

  def handle_info(message, trigger = %Trigger{}) do
    log(:error, "unknown message: #{inspect(message)}", trigger)
    stop_running(trigger)
  end

  def handle_info(_message, state) do
    log(:error, "invalid state: #{inspect(state)}", [])
    {:stop, :normal, state}
  end

  # handle_info/2 convenience helpers

  defp sleep_and_retry(trigger) do
    Process.sleep(@retry_sleep_period)
    flush_and_run(trigger)
  end

  defp flush_and_run(trigger) do
    receive do
      _ -> flush_and_run(trigger)
    after
      0 -> continue_running(trigger)
    end
  end

  defp continue_running(trigger) do
    Process.send(self(), :run, [])
    {:noreply, trigger}
  end

  defp stop_running(trigger) do
    {:stop, :normal, trigger}
  end

  # helpers

  defp check_deadline(trigger = %Trigger{updated_at: updated_at}) do
    elapsed_seconds = NaiveDateTime.utc_now() |> NaiveDateTime.diff(updated_at)

    if elapsed_seconds <= @deadline_seconds,
      do: {:ok, trigger},
      else: {:error, :deadline_reached}
  end

  defp check_access(trigger = %Trigger{}) do
    with {:ok, deployment} <- DeploymentQueries.find_by_id(trigger.deployment_id),
         {:ok, switch} <- SwitchQueries.get_by_id(trigger.switch_id),
         {:ok, metadata} <- Guardian.verify(deployment, switch, trigger.triggered_by) do
      {:ok, metadata}
    else
      {:error, :not_found} ->
        {:error, {:not_found, [deployment_id: trigger.deployment_id]}}

      {:error, msg} when is_binary(msg) ->
        {:error, {:not_found, [switch_id: trigger.switch_id]}}

      {:error, {reason, metadata}} ->
        reason = reason |> Atom.to_string() |> String.downcase()
        {:error, {:forbidden, Keyword.put(metadata, :reason, reason)}}
    end
  end

  defp trigger_switch(params) do
    alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSup

    case STSup.start_switch_trigger_process(params["id"], params) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _reason} = error -> error
      {:ok, pid} -> {:ok, pid}
    end
  end

  defp check_target_trigger(trigger) do
    alias Gofer.TargetTrigger.Model.TargetTriggerQueries
    %Trigger{switch_trigger_id: id, target_name: name} = trigger

    case TargetTriggerQueries.get_by_id_and_name(id, name) do
      {:ok, target_trigger = %{processed: true}} -> {:ok, target_trigger}
      {:ok, _target_trigger = %{processed: false}} -> {:error, :unprocessed}
      {:error, message} when is_binary(message) -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp log(level, message, metadata) when is_list(metadata) do
    Logger.log(level, "#{__MODULE__}: #{message}", extra: inspect(metadata))
  end

  defp log(level, message, trigger = %Trigger{}, metadata \\ []) do
    trigger_metadata = [
      switch_trigger_id: trigger.switch_trigger_id,
      target_name: trigger.target_name,
      state: trigger.state
    ]

    log(level, message, Keyword.merge(trigger_metadata, metadata))
  end

  defp report_engine_events(events) do
    for event <- events, do: Watchman.increment("#{@metric_prefix}.#{event}")
  end

  defp report_resolution_time(trigger = %Trigger{triggered_at: triggered_at}) do
    finalized_at = trigger.scheduled_at || DateTime.utc_now()
    resolution_time = DateTime.diff(finalized_at, triggered_at, :millisecond)
    Watchman.submit("#{@metric_prefix}.resolution", resolution_time, :timing)
  end
end
