defmodule Ppl.TimeLimits.STMHandler.PplTrackingState do
  @moduledoc """
  Handles terminating pipelines when time_limt deadline is reached
  """

  import Ecto.Query

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.Ppls.STMHandler.RunningState, as: PplRunningState
  alias Ppl.TimeLimits.Model.{TimeLimits, TrackingStateScheduling}
  alias LogTee, as: LT

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :tl_tracking_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.TimeLimits.Model.TimeLimits,
    observed_state: "tracking",
    allowed_states: ~w(done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :tl_tracking_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id]

  def initial_query(), do: TimeLimits

#######################
  def enter_scheduling(_) do
    with {:ok, [{old, new}]} <- TrackingStateScheduling.get_deadline_reached("pipeline"),
         true                <- time_limit_in_tracking_state(old)
    do
      {:ok, {old, new}}
    else
      {:ok, []}   -> {:ok, {nil, nil}}
      :skip_scheduling -> {:ok, {nil, nil}}
      err         -> err |> LT.error("Error in tracking scheduling")
    end
  end

  defp time_limit_in_tracking_state(%{state: "tracking"}), do: true
  defp time_limit_in_tracking_state(tl) do
    tl |> LT.info("Race in tracking STM, selected time_limit was already processed")
    execute_now()
    :skip_scheduling
  end

#######################

  def terminate_request_handler(tl, result) when result in ["cancel", "stop"] do
    reason = determin_reason(tl)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

#######################

  def scheduling_handler(tl) do
    with {:ok, ppl}  <- PplsQueries.get_by_id(tl.ppl_id),
         {:ok, _ppl} <- start_termination(ppl)
    do
      {:ok, fn _, _ -> {:ok, %{state: "done", result: "enforced"}} end}
    else
      {:error, :ppl_done} ->
        {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: "ppl done"}} end}

      error -> {:ok, fn _, _ -> {:error, %{description: "#{inspect error}"}} end}
    end
  end

  defp start_termination(ppl = %{state: "running"}) do
    with {:ok, ppl} <- PplsQueries.terminate(ppl, "stop", "time_limit_exceeded"),
         query_fun  <- fn query -> query |> where(ppl_id: ^ppl.ppl_id) end
    do
      query_fun |> PplRunningState.execute_now_in_task()
    end
  end

  defp start_termination(%{state: state})
    when state in ["stopping", "done"], do: {:error, :ppl_done}

  defp start_termination(error),
    do: {:error, "Can not terminate pipeline #{inspect(error)}"}

#######################

  def epilogue_handler(_exit_state), do: :nothing

end
