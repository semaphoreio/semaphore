defmodule Gofer.TargetTrigger.Engine.TargetTriggerProcess do
  @moduledoc """
  Represents execution of Target trigger. It tries to schedule pipilne defined in
  given target on Plumber service and records scheduling result in database.
  """

  use GenServer, restart: :transient

  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.PlumberClient
  alias Util.ToTuple
  alias LogTee, as: LT

  def start_link(params = {switch_trigger_id, target_name}) do
    ttp_id = switch_trigger_id <> target_name
    GenServer.start_link(__MODULE__, params, name: {:global, ttp_id})
  end

  def init({switch_trigger_id, target_name}) do
    send(self(), :schedule_pipeline)
    {:ok, %{switch_trigger_id: switch_trigger_id, target_name: target_name}}
  end

  def handle_info(:schedule_pipeline, state) do
    with %{switch_trigger_id: sw_tg_id, target_name: tg_name} <- state,
         {:ok, target_trigger} <- target_trigger_exist(sw_tg_id, tg_name),
         {:processed, false} <- {:processed, Map.get(target_trigger, :processed)},
         {:ok, msg = "Processed successfully."} <- process_target_trigger(target_trigger) do
      msg |> graceful_exit(state)
    else
      {:processed, true} ->
        "Allready processed." |> graceful_exit(state)

      {:in_queue, tg_before_count} ->
        retry_atfer(state, tg_before_count, 100)

      {:stop, message} ->
        message |> graceful_exit(state)

      error ->
        error |> restart(state)
    end
  end

  defp target_trigger_exist(sw_tg_id, tg_name) do
    case TargetTriggerQueries.get_by_id_and_name(sw_tg_id, tg_name) do
      {:ok, target_trigger} ->
        {:ok, target_trigger}

      {:error, message = "TargetTrigger " <> _rest} ->
        {:stop, message}
    end
  end

  defp process_target_trigger(target_trigger) do
    with {:ok, switch} <- SwitchQueries.get_by_id(target_trigger.switch_id),
         {:ok, target} <-
           TargetQueries.get_by_id_and_name(
             target_trigger.switch_id,
             target_trigger.target_name
           ),
         {:ok, sw_tg} <- SwitchTriggerQueries.get_by_id(target_trigger.switch_trigger_id),
         {:ok, maybe_dpl} <- check_deployment(target, target_trigger),
         {:ok, results} <-
           process_target_trigger_(switch, target, sw_tg, target_trigger, maybe_dpl),
         {:ok, _target_trigger} <- TargetTriggerQueries.update(target_trigger, results),
         {:ok, _target_trigger} <- check_and_cleanup_deployment(target, target_trigger) do
      {:ok, "Processed successfully."}
    end
  end

  defp check_deployment(%{deployment_target: nil}, _target_trigger),
    do: {:ok, :no_deployment}

  defp check_deployment(_target, target_trigger) do
    case DeploymentTriggerQueries.find_by_switch_trigger_and_target(
           target_trigger.switch_trigger_id,
           target_trigger.target_name
         ) do
      {:ok, trigger} -> {:ok, trigger.deployment}
      {:error, :not_found} -> {:ok, :no_deployment}
    end
  end

  defp check_and_cleanup_deployment(%{deployment_target: nil}, target_trigger),
    do: {:ok, target_trigger}

  defp check_and_cleanup_deployment(_target, target_trigger) do
    case Gofer.DeploymentTrigger.Engine.Supervisor.start_worker(
           target_trigger.switch_trigger_id,
           target_trigger.target_name
         ) do
      {:ok, _pid} -> {:ok, target_trigger}
      {:error, {:already_started, _pid}} -> {:ok, target_trigger}
      {:error, :not_found} -> {:ok, target_trigger}
      {:error, _reason} = error -> error
    end
  end

  defp process_target_trigger_(switch, target, sw_tg, targ_tg, maybe_dpl) do
    with {:ok, deadline} <- calcualte_deadline(sw_tg.triggered_at),
         deadline_reached <- DateTime.compare(deadline, DateTime.utc_now()) == :lt,
         {:ok, sch_params} <-
           form_schedule_params(switch, target, sw_tg, maybe_dpl, targ_tg.schedule_request_token) do
      schedule_ppl_or_wait_in_queue(targ_tg, sch_params, deadline_reached)
    end
  end

  defp calcualte_deadline(triggered_at) do
    triggered_at
    |> DateTime.to_naive()
    |> NaiveDateTime.add(target_trigger_ttl_ms(), :millisecond)
    |> DateTime.from_naive("Etc/UTC")
  end

  defp form_schedule_params(switch, target, switch_trigger, maybe_dpl, request_token) do
    %{
      ppl_id: switch.ppl_id,
      file_path: target.pipeline_path,
      request_token: request_token,
      prev_ppl_artefact_ids: switch.prev_ppl_artefact_ids,
      env_variables: switch_trigger.env_vars_for_target |> Map.get(target.name, []),
      secret_names: secret_names_from_deployment(maybe_dpl),
      promoted_by: switch_trigger.triggered_by,
      auto_promoted: switch_trigger.auto_triggered,
      deployment_target_id: deployment_target_id_from_deployment(maybe_dpl)
    }
    |> ToTuple.ok()
  end

  defp secret_names_from_deployment(:no_deployment), do: []

  defp secret_names_from_deployment(deployment) do
    deployment |> Map.get(:secret_name) |> List.wrap()
  end

  defp deployment_target_id_from_deployment(:no_deployment), do: ""
  defp deployment_target_id_from_deployment(deployment), do: deployment |> Map.get(:id, "")

  defp schedule_ppl_or_wait_in_queue(targ_tg, schedule_params, false) do
    case TargetTriggerQueries.get_older_unprocessed_triggers_count(targ_tg) do
      {:ok, 0} ->
        schedule_pipeline(schedule_params)

      {:ok, count} ->
        {:in_queue, count}

      error ->
        error
    end
  end

  defp schedule_ppl_or_wait_in_queue(_targ_tg, _schedule_params, true) do
    %{
      "error_response" => "Deadline reached",
      "scheduled_at" => DateTime.utc_now(),
      "processed" => true,
      "processing_result" => "failed"
    }
    |> ToTuple.ok()
  end

  defp retry_atfer(state, tg_count, time) do
    %{switch_trigger_id: id, target_name: name} = state

    LT.info(
      "",
      "Target_trigger process for id #{id} and name #{name} waits for #{tg_count} other triggers to finish"
    )

    Process.send_after(self(), :schedule_pipeline, time)
    {:noreply, state}
  end

  defp schedule_pipeline(schedule_params) do
    schedule_params
    |> PlumberClient.schedule_pipeline()
    |> prepare_target_trigger_update_params()
  end

  defp prepare_target_trigger_update_params({:ok, ppl_id}) do
    %{
      "scheduled_ppl_id" => ppl_id,
      "scheduled_at" => DateTime.utc_now(),
      "processed" => true,
      "processing_result" => "passed"
    }
    |> ToTuple.ok()
  end

  defp prepare_target_trigger_update_params({:error, {:bad_param, message}}) do
    %{
      "error_response" => to_str(message),
      "scheduled_at" => DateTime.utc_now(),
      "processed" => true,
      "processing_result" => "failed"
    }
    |> ToTuple.ok()
  end

  defp prepare_target_trigger_update_params(error), do: error

  defp graceful_exit(value, state) do
    %{switch_trigger_id: id, target_name: name} = state

    value
    |> LT.info("Target_trigger process for id #{id} and name #{name} exits: ")

    {:stop, :normal, state}
  end

  defp restart(error, state) do
    %{switch_trigger_id: id, target_name: name} = state

    error
    |> LT.warn("Target_trigger process for id #{id} and name #{name} failiure: ")

    {:stop, :restart, state}
  end

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  defp target_trigger_ttl_ms, do: Application.get_env(:gofer, :target_trigger_ttl_ms, 40_000)
end
