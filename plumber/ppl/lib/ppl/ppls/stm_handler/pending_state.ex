defmodule Ppl.Ppls.STMHandler.PendingState do
  @moduledoc """
  Handles running of pipelines
  """

  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.STMHandler.{PendingState, QueuingState, RunningState, Common}
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Util.Metrics

  @entry_metric_name "Ppl.pipeline_init_overhead"

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_pending_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "pending",
    allowed_states: ~w(pending queuing running done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_pending_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end,
    task_supervisor: PplsTaskSupervisor

  def initial_query(), do: Ppls

#######################

  def terminate_request_handler(ppl, result) when result in ["cancel", "stop"] do
    Common.terminate_pipeline(ppl, "done")
  end
  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl) do
    case PplsQueries.should_do_auto_cancel?(ppl) do
      {:ok, false} ->
         scheduling_handler_(ppl)
      {:ok, auto_cancel} ->
         Common.do_auto_cancel(ppl, auto_cancel, "done")
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  def scheduling_handler_(ppl) do
    trigger_auto_cancel?(ppl)
    handle_run({:ok, "queuing"}, ppl)
  end

  defp trigger_auto_cancel?(ppl = %{auto_cancel: ac}) when ac in ["stop", "cancel"] do
    import Ecto.Query

    {:ok, ppls} = PplsQueries.ppls_from_same_queue_in_states(ppl, ["pending", "queuing", "running"])

    ppls |> Enum.map(fn %{ppl_id: ppl_id} ->
      query_fun = fn query -> query |> where(ppl_id: ^ppl_id) end

      query_fun |> PendingState.execute_now_in_task()
      query_fun |> QueuingState.execute_now_with_predicate(:raw)
      query_fun |> RunningState.execute_now_in_task()
    end)
  end
  defp trigger_auto_cancel?(_ppl), do: :continue

  defp handle_run({:ok, "queuing"}, ppl) do
    PplTracesQueries.set_timestamp(ppl.ppl_id, :queuing_at)
    {:ok, fn _, _ -> {:ok, %{state: "queuing"}} end}
  end

  defp handle_run(error, _ppl) do
    desc = "#{inspect error}"
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "queuing"}}}) do
    # queuing state has custom 'enter_scheduling' query so it is not needed
    # nor possible here to call execute_now_with_predicate()
    Ppl.Ppls.STMHandler.QueuingState.execute_now()

    with ppl_id       <-  data.exit_transition.ppl_id,
         {:ok, trace} <- PplTracesQueries.get_by_id(ppl_id),
         diff <- DateTime.diff(trace.queuing_at, trace.created_at, :millisecond)
    do
       {@entry_metric_name, [Metrics.dot2dash(__MODULE__)]}
       |> Watchman.submit(diff, :timing)
    end
  end
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.trigger_ppl_block_loopers(data)
    Common.pipeline_done(data)
  end
  def epilogue_handler(_exit_state), do: :nothing
end
