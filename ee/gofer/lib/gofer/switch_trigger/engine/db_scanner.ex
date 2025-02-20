defmodule Gofer.SwitchTrigger.Engine.DbScanner do
  @moduledoc """
  Serves to scan database on Application start and to start SwitchTriggerProcesses
  for all unprocessed switch_trigger db entries.
  """
  use GenServer, restart: :transient

  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias LogTee, as: LT
  alias Util.ToTuple

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_params) do
    send(self(), :scann_db)
    {:ok, %{}}
  end

  def handle_info(:scann_db, state) do
    scann_batch(NaiveDateTime.utc_now(), 0, state)
  end

  defp scann_batch(timestamp, batch_no, state) do
    with {:ok, switch_triggers} <-
           SwitchTriggerQueries.get_older_unprocessed(timestamp, batch_no),
         {:triggers_found, true} <- {:triggers_found, length(switch_triggers) > 0},
         {:ok, _sps} <- start_processes(switch_triggers) do
      scann_batch(timestamp, batch_no + 1, state)
    else
      {:triggers_found, false} ->
        {:stop, :normal, state}

      error ->
        error |> restart(state)
    end
  end

  defp start_processes(switch_triggers) do
    switch_triggers
    |> Enum.reduce_while({:ok, []}, fn sw_tg, {:ok, acc} ->
      with {:ok, params} <- form_switch_trigger_params(sw_tg),
           {:ok, pid} <- STSupervisor.start_switch_trigger_process(sw_tg.id, params) do
        {:cont, {:ok, acc ++ [pid]}}
      else
        {:error, {:already_started, pid}} -> {:cont, {:ok, acc ++ [pid]}}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp form_switch_trigger_params(sw_tg) do
    %{
      "id" => sw_tg.id,
      "switch_id" => sw_tg.switch_id,
      "request_token" => sw_tg.request_token,
      "target_names" => sw_tg.target_names,
      "triggered_by" => sw_tg.triggered_by,
      "triggered_at" => sw_tg.triggered_at,
      "auto_triggered" => sw_tg.auto_triggered,
      "override" => sw_tg.override,
      "processed" => sw_tg.processed
    }
    |> ToTuple.ok()
  end

  defp restart(error, state) do
    error
    |> LT.warn("Error while performing db_scann for unprocesed SwitchTriggers")

    {:stop, :restart, state}
  end
end
