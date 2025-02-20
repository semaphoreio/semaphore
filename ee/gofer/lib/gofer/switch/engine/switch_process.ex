defmodule Gofer.Switch.Engine.SwitchProcess do
  @moduledoc """
  Serves to monitor execution of pipeline to which switch belongs. It pools pipeline's
  state every n seconds and updates switch db record with pipeline's execution result
  once pipeline is finished an then exits with :normal.
  """

  use GenServer, restart: :transient

  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.PlumberClient
  alias Gofer.Actions
  alias LogTee, as: LT

  defp auto_trigger_deadline() do
    Application.get_env(:gofer, :auto_trigger_deadline)
  end

  defp describe_pool_period() do
    Application.get_env(:gofer, :pipeline_describe_pool_period)
  end

  def start_link(args = {id, _params}) do
    GenServer.start_link(__MODULE__, args, name: {:global, id})
  end

  def init({id, {switch_def, targets_defs}}) do
    switch_def
    |> Actions.persist_switch_and_targets_def(targets_defs)
    |> case do
      # on initial start switch and targets are inserted, on restarts this is ignored
      {:ok, _message} ->
        Process.send_after(self(), :describe_pipeline, describe_pool_period())
        {:ok, %{id: id}}

      # something went wrong
      {:error, e} ->
        {:stop, e} |> LT.warn("Switch process for id #{id} failed to start")

      error ->
        {:stop, error} |> LT.warn("Switch process for id #{id} failed to start")
    end
  end

  def handle_info(:describe_pipeline, %{id: id}) do
    with {:ok, switch} <- switch_exist(id),
         {:ok, "done", result, reason, done_at} <- PlumberClient.describe(switch.ppl_id),
         :continue <- deadline_reached(switch, result, reason, done_at),
         {:ok, _message} <- Actions.update_switch_and_start_trigger(id, result, reason) do
      "Processed successfully." |> graceful_exit(%{id: id})
    else
      {:ok, _state, _result, _reason, _done_at} ->
        Process.send_after(self(), :describe_pipeline, describe_pool_period())
        {:noreply, %{id: id}}

      {:error, {:grpc_error, _error}} ->
        Process.send_after(self(), :describe_pipeline, describe_pool_period())
        {:noreply, %{id: id}}

      {:error, {:OK, "Pipeline execution result received and processed."}} ->
        "Processed successfully." |> graceful_exit(%{id: id})

      {:stop, message} ->
        message |> graceful_exit(%{id: id})

      error ->
        error |> restart(%{id: id})
    end
  end

  defp switch_exist(id) do
    case SwitchQueries.get_by_id(id) do
      {:ok, switch} ->
        {:ok, switch}

      {:error, message = "Switch with id " <> _rest} ->
        {:stop, message}
    end
  end

  defp deadline_reached(_switch, _result, _reason, 0), do: :continue

  defp deadline_reached(switch, result, reason, done_at) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    if now - done_at > auto_trigger_deadline() do
      Watchman.increment("Gofer.failed-switch-process")

      SwitchQueries.update(switch, %{
        "ppl_done" => true,
        "ppl_result" => result,
        "ppl_result_reason" => reason
      })

      {:stop, "Deadline for auto-triggering reached."}
    else
      :continue
    end
  end

  defp graceful_exit(value, %{id: id}) do
    value
    |> LT.info("Switch process for id #{id} exits: ")

    {:stop, :normal, %{id: id}}
  end

  defp restart(error, %{id: id}) do
    error
    |> LT.warn("Switch process for id #{id} failiure: ")

    {:stop, :restart, %{id: id}}
  end
end
