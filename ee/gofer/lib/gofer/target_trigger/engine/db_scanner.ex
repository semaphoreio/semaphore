defmodule Gofer.TargetTrigger.Engine.DbScanner do
  @moduledoc """
  Serves to scan database on Application start and to create TargetTriggerProcesses
  for all unprocessed target_trigger db entries.
  """

  use GenServer, restart: :transient

  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias LogTee, as: LT

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
    with {:ok, target_triggers} <-
           TargetTriggerQueries.get_older_unprocessed(timestamp, batch_no),
         {:triggers_found, true} <- {:triggers_found, length(target_triggers) > 0},
         {:ok, _sps} <- start_processes(target_triggers) do
      scann_batch(timestamp, batch_no + 1, state)
    else
      {:triggers_found, false} ->
        {:stop, :normal, state}

      error ->
        error |> restart(state)
    end
  end

  defp start_processes(target_triggers) do
    target_triggers
    |> Enum.reduce_while({:ok, []}, fn targ_tg, {:ok, acc} ->
      case TTSupervisor.start_target_trigger_process(
             targ_tg.switch_trigger_id,
             targ_tg.target_name
           ) do
        {:ok, pid} -> {:cont, {:ok, acc ++ [pid]}}
        {:error, {:already_started, pid}} -> {:cont, {:ok, acc ++ [pid]}}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp restart(error, state) do
    error
    |> LT.warn("Error while performing db_scann for unprocesed TargetTriggers")

    {:stop, :restart, state}
  end
end
