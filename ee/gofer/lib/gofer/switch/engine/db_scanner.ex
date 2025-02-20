defmodule Gofer.Switch.Engine.DbScanner do
  @moduledoc """
  Serves to scan database on Application start and to start SwitchProcesses
  for all unprocessed switch db entries.
  """
  use GenServer, restart: :transient

  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
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
    with {:ok, switches} <- SwitchQueries.get_older_not_done(timestamp, batch_no),
         {:switches_found, true} <- {:switches_found, length(switches) > 0},
         {:ok, _sps} <- start_processes(switches) do
      scann_batch(timestamp, batch_no + 1, state)
    else
      {:switches_found, false} ->
        {:stop, :normal, state}

      error ->
        error |> restart(state)
    end
  end

  defp start_processes(switches) do
    switches
    |> Enum.reduce_while({:ok, []}, fn switch, {:ok, acc} ->
      with {:ok, switch_def} <- form_switch_def(switch),
           {:ok, targets_def} <- form_targets_defs(switch),
           {:ok, pid} <- SSupervisor.start_switch_process(switch.id, {switch_def, targets_def}) do
        {:cont, {:ok, acc ++ [pid]}}
      else
        {:error, {:already_started, pid}} -> {:cont, {:ok, acc ++ [pid]}}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp form_switch_def(switch) do
    %{
      "id" => switch.id,
      "ppl_id" => switch.ppl_id,
      "prev_ppl_artefact_ids" => switch.prev_ppl_artefact_ids,
      "branch_name" => switch.branch_name
    }
    |> ToTuple.ok()
  end

  defp form_targets_defs(switch) do
    {:ok, targets} = TargetQueries.get_all_targets_for_switch(switch.id)

    targets
    |> Enum.reduce([], fn target, targets ->
      targets ++ [form_target_def(target)]
    end)
    |> ToTuple.ok()
  end

  defp form_target_def(target) do
    %{
      "switch_id" => target.switch_id,
      "name" => target.name,
      "pipeline_path" => target.pipeline_path,
      "auto_trigger_on" => target.auto_trigger_on
    }
  end

  defp restart(error, state) do
    error
    |> LT.warn("Error while performing db_scann for unprocesed Switches")

    {:stop, :restart, state}
  end
end
