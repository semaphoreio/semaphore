defmodule Gofer.SwitchTrigger.Engine.SwitchTriggerProcess do
  @moduledoc """
  Represents execution of switch trigger. Creates target_trigger db entries and
  processes for all trigger targets and then exits with :normal
  """

  use GenServer, restart: :transient

  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias LogTee, as: LT
  alias Util.ToTuple

  def start_link(args = {id, _params}) do
    GenServer.start_link(__MODULE__, args, name: {:global, id})
  end

  def init({id, params}) do
    case SwitchTriggerQueries.insert(params) do
      # on initial start switch_trigger is inserted
      {:ok, _switch} -> schedule_job_and_respond_ok(id)
      # on restarts switch_trigger is already in db
      {:error, {:switch_trigger_id_exists, _e}} -> schedule_job_and_respond_ok(id)
      # something went wrong
      {:error, e} -> {:stop, e}
      error -> {:stop, error}
    end
  end

  defp schedule_job_and_respond_ok(id) do
    send(self(), :trigger_targets)
    {:ok, %{id: id}}
  end

  def handle_info(:trigger_targets, %{id: id}) do
    with {:ok, switch_trigger} <- switch_trigger_exist(id),
         {:processed, false} <- {:processed, Map.get(switch_trigger, :processed)},
         {:ok, _ttps} <- triger_targets_for_switch_trigger(switch_trigger),
         {:ok, _switch_triger} <- SwitchTriggerQueries.mark_as_processed(switch_trigger) do
      "Processed successfully." |> graceful_exit(%{id: id})
    else
      {:processed, true} ->
        "Allready processed." |> graceful_exit(%{id: id})

      {:stop, message} ->
        message |> graceful_exit(%{id: id})

      error ->
        error |> restart(%{id: id})
    end
  end

  defp switch_trigger_exist(id) do
    case SwitchTriggerQueries.get_by_id(id) do
      {:ok, switch_trigger} ->
        {:ok, switch_trigger}

      {:error, message = "SwitchTrigger with id" <> _rest} ->
        {:stop, message}
    end
  end

  defp triger_targets_for_switch_trigger(switch_trigger) do
    switch_trigger.target_names
    |> Enum.reduce_while({:ok, []}, fn target_name, {:ok, acc} ->
      with {:ok, params} <- form_params(switch_trigger, target_name),
           {:ok, _target_trigger} <- TargetTriggerQueries.insert(params),
           {:ok, pid} <-
             TTSupervisor.start_target_trigger_process(
               switch_trigger.id,
               target_name
             ) do
        {:cont, {:ok, acc ++ [pid]}}
      else
        {:error, {:already_started, pid}} -> {:cont, {:ok, acc ++ [pid]}}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp form_params(switch_trigger, target_name) do
    %{
      "switch_id" => switch_trigger.switch_id,
      "switch_trigger_id" => switch_trigger.id,
      "target_name" => target_name
    }
    |> ToTuple.ok()
  end

  defp graceful_exit(value, %{id: id}) do
    value
    |> LT.info("Switch_trigger process for id #{id} exits: ")

    {:stop, :normal, %{id: id}}
  end

  defp restart(error, %{id: id}) do
    error
    |> LT.warn("Switch_trigger process for id #{id} failiure: ")

    {:stop, :restart, %{id: id}}
  end
end
