defmodule Ppl.PplSubInits.STMHandler.StoppingState do
  @moduledoc """
  Waits for compile task to be stopped or finished on Zebra
  """

  import Ecto.Query


  alias Ppl.TaskClient
  alias Ppl.PplSubInits.Model.PplSubInits
  alias Ppl.PplSubInits.STMHandler.Common

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_sub_init_stopping_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.PplSubInits.Model.PplSubInits,
    observed_state: "stopping",
    allowed_states: ~w(stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_sub_init_stopping_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id]

  def initial_query(), do: PplSubInits

  def terminate_request_handler(_pple, _), do: {:ok, :continue}

  def scheduling_handler(psi) do
    with {:ok, state, _result} <- TaskClient.describe(psi.compile_task_id),
         {:ok, exit_func}      <- transition_to_state(psi, state)
    do
     {:ok, exit_func}
    else
     error  ->  handle_error(error)
    end
  end

  defp transition_to_state(psi, "done") do
    reason = determin_reason(psi)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "stopped", result_reason: reason}} end}
  end
  # If it is not "done" we treat task as "running"
  defp transition_to_state(_psi, _state),
    do: {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

  defp handle_error(e = {:error, _error}), do: {:ok, fn _, _ -> e end}
  defp handle_error(error), do: {:ok, fn _, _ -> {:error, error} end}

  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.Ppls.STMHandler.InitializingState.execute_now_with_predicate()

    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
