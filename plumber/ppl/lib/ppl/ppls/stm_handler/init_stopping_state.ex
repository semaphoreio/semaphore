defmodule Ppl.Ppls.STMHandler.InitStoppingState do
  @moduledoc """
  Handles pipelines in init-stopping state, waiting for PplSubInit to complete termination
  """

  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.Ppls.STMHandler.Common
  alias Ppl.Ppls.Model.Ppls

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_init_stopping_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "init-stopping",
    allowed_states: ~w(init-stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_init_stopping_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end,
    task_supervisor: PplsTaskSupervisor

  def initial_query(), do: Ppls

#######################

  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl) do
    with {:ok, psi} <- PplSubInitsQueries.get_by_id(ppl.ppl_id),
         is_done <- psi.state == "done"
    do
      if is_done do
        Common.terminate_pipeline(ppl, "done")
      else
        {:ok, fn _, _ -> {:ok, %{state: "init-stopping"}} end}
      end
    else
      {:error, _} ->
        Common.terminate_pipeline(ppl, "done")
    end
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.pipeline_done(data)
  end
  def epilogue_handler(_exit_state), do: :nothing
end
