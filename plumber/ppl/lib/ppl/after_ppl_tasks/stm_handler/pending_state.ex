defmodule Ppl.AfterPplTasks.STMHandler.PendingState do
  @moduledoc """
  Pending state transition for AfterPplTasks.
  """

  alias Ppl.AfterPplTasks.Model.{AfterPplTasks}
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplRequests.Model.{PplRequestsQueries}
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.AfterPplTasks.STMHandler.Common
  alias Ppl.EctoRepo, as: Repo

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_after_task_pending_sp),
    repo: Ppl.EctoRepo,
    schema: AfterPplTasks,
    observed_state: "pending",
    allowed_states: ~w(pending running done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_after_task_pending_ct),
    publisher_cb: fn params -> Common.publisher_callback(params) end,
    columns_to_log: [:state, :ppl_id]

  def initial_query(), do: AfterPplTasks

  #######################

  def scheduling_handler(after_ppl_task) do
    with {:ok, ppl_request}   <- fetch_pipeline_request(after_ppl_task.ppl_id),
         {:ok, ppl_trace}     <- PplTracesQueries.get_by_id(ppl_request.id),
         {:ok, ppl}           <- PplsQueries.get_by_id(ppl_request.id),
         {:ok, after_task_id} <- Ppl.TaskClient.AfterPipeline.start(ppl_request, after_ppl_task, ppl_trace, ppl),
         {:ok, _ppl}          <- update_pipeline(ppl_request.id, after_task_id)
    do
      {:ok, fn _, _ -> {:ok, %{state: "running", after_task_id: after_task_id}} end}
    else
      error -> handle_error(error)
    end
  end

  def terminate_request_handler(_after_ppl_task, _), do: {:ok, :continue}

  defp update_pipeline(ppl_request_id, after_task_id) do
    {:ok, ppl} = PplsQueries.get_by_id(ppl_request_id)

    ppl
    |> Ppls.changeset(%{after_task_id: after_task_id})
    |> Repo.update()
  end

  defp fetch_pipeline_request(ppl_id) do
    PplRequestsQueries.get_by_id(ppl_id)
  end

  defp handle_error(e = {:error, _error}), do: {:ok, fn _, _ -> e end}
  defp handle_error(error), do: {:ok, fn _, _ -> {:error, error} end}
end
