defmodule Ppl.AfterPplTasks.STMHandler.RunningState do
  @moduledoc """
  Running state transition for AfterPplTasks.
  """

  alias Ppl.AfterPplTasks.Model.AfterPplTasks
  alias Ppl.AfterPplTasks.STMHandler.Common

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_after_task_running_sp),
    repo: Ppl.EctoRepo,
    schema: AfterPplTasks,
    observed_state: "running",
    allowed_states: ~w(running done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_after_task_running_ct),
    publisher_cb: fn params -> Common.publisher_callback(params) end,
    columns_to_log: [:state, :ppl_id]

  def initial_query(), do: AfterPplTasks

  #######################

  def scheduling_handler(after_ppl_task) do
    with %{after_task_id: after_task_id} <- after_ppl_task,
         {:ok, state, result} <- Ppl.TaskClient.describe(after_task_id) do
      state
      |> case do
        "done" ->
          {:ok, fn _, _ -> {:ok, %{state: "done", result: result}} end}

        "running" ->
          {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

        _ ->
          {:ok, fn _, _ -> {:ok, %{state: "done", result: "failed", result_reason: "stuck"}} end}
      end
    else
      error -> handle_error(error)
    end
  end

  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

  defp handle_error(e = {:error, _error}), do: {:ok, fn _, _ -> e end}
  defp handle_error(error), do: {:ok, fn _, _ -> {:error, error} end}
end
