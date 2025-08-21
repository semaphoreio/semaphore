defmodule Ppl.Ppls.STMHandler.InitializingState do
  @moduledoc """
  Handles pipeline definition validation
  """

  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.Model.Ppls
  alias Ppl.Ppls.STMHandler.Common
  alias Util.ToTuple

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_initializing_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "initializing",
    allowed_states: ~w(initializing pending done init-stopping),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_initializing_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end

  def initial_query(), do: Ppls

#######################

  def terminate_request_handler(ppl, result) when result in ["cancel", "stop"] do
    with {:ok, psi} <- PplSubInitsQueries.get_by_id(ppl.ppl_id),
         {:ok,  _}  <- PplSubInitsQueries.terminate(psi, "stop", ppl.terminate_request_desc)
    do
      {:ok, fn _, _ -> {:ok, %{state: "init-stopping"}} end}
    else
      error -> {:ok, fn _, _ -> {:error, %{error_description: "Error: #{inspect error}"}} end}
    end
  end
  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl) do
    with {:ok, psi}        <- PplSubInitsQueries.get_by_id(ppl.ppl_id),
         {:ok, psi_status} <- sub_init_status(psi),
         {:ok, ppl_status} <- determin_ppl_status(psi_status)
    do
      set_timestamp(ppl.ppl_id, ppl_status)
      {:ok, fn _, _ -> {:ok, ppl_status} end}
    end
  end

  defp sub_init_status(psi) do
    psi
    |> Map.from_struct()
    |> Map.take([:state, :result, :result_reason, :error_description])
    |> Enum.filter(fn {_key, value} -> is_binary(value) and value != "" end)
    |> Enum.into(%{})
    |> ToTuple.ok()
  end

  defp determin_ppl_status(psi_status) do
    case {psi_status.state, Map.get(psi_status, :result)}  do
      {"done", "passed"} -> %{state: "pending"}
      {"done", _result}  -> psi_status
      _other             -> %{state: "initializing"}
    end
    |> ToTuple.ok()
  end

  defp set_timestamp(ppl_id, ppl_status) do
    case ppl_status.state do
      "pending" -> PplTracesQueries.set_timestamp(ppl_id, :pending_at)
      "done"    -> PplTracesQueries.set_timestamp(ppl_id, :done_at)
      _other    -> :ok
    end
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "pending"}}}) do
    import Ecto.Query

    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.Ppls.STMHandler.PendingState.execute_now_with_predicate()
  end
  def epilogue_handler({:ok,  data = %{user_exit_function: %{state: "done"}}}) do
    Common.trigger_ppl_block_loopers(data)
    Common.pipeline_done(data)
  end
  def epilogue_handler(_exit_state), do: :nothing
end
