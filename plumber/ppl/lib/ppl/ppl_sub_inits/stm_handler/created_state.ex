defmodule Ppl.PplSubInits.STMHandler.CreatedState do
  @moduledoc """
  Moves PplSubInit to either regular_init or rebuild_init state.
  """

  import Ecto.Query

  alias Ppl.PplSubInits.Model.PplSubInits
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.STMHandler.Common
  alias Ppl.RepoProxyClient

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_sub_init_created_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.PplSubInits.Model.PplSubInits,
    observed_state: "created",
    allowed_states: ~w(fetching done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_sub_init_created_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id]

  def initial_query(), do: PplSubInits

  def terminate_request_handler(psi, result) when result in ["cancel", "stop"] do
    reason = determin_reason(psi)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_psi, _), do: {:ok, :continue}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

  def scheduling_handler(psi) do
    with {:ok, ppl_req}     <- PplRequestsQueries.get_by_id(psi.ppl_id),
         :ok                <- validate_ppl_count_on_workflow(ppl_req),
         hook_id            <- ppl_req.request_args |> Map.get("hook_id", ""),
         {:ok, source_args} <- RepoProxyClient.describe(hook_id),
         {:ok, _ppl_req}    <- PplRequestsQueries.insert_source(ppl_req, source_args)
    do
      {:ok, fn _, _ -> {:ok, %{state: "fetching"}} end}
    else
      error  ->  handle_error(error)
    end
  end

  defp validate_ppl_count_on_workflow(ppl_req) do
    case PplRequestsQueries.count_pipelines_in_workflow(ppl_req.wf_id) do
      {:ok, count} when count <= 1000 -> :ok

      {:ok, count} when count > 1000 ->
        {:error, {:limit, "The limit of 1000 pipelines in same workflow reached."}}

      error -> error
    end
  end

  defp handle_error({:error, {:limit, msg}}) do
    desc = "Error: #{inspect(msg)}"
    {:ok, fn _, _ ->
      {:ok, %{state: "done", error_description: desc, result: "failed", result_reason: "internal"}}
    end}
  end
  defp handle_error(e = {:error, _error}), do: {:ok, fn _, _ -> e end}
  defp handle_error(error), do: {:ok, fn _, _ -> {:error, error} end}

  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.Ppls.STMHandler.InitializingState.execute_now_with_predicate()

    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler({:ok, data}) do
    import Ecto.Query

    ppl_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:ppl_id)

    fn query -> query |> where(ppl_id: ^ppl_id) end
    |> Ppl.PplSubInits.STMHandler.FetchingState.execute_now_with_predicate()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
