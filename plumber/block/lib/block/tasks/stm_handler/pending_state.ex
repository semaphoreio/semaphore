defmodule Block.Tasks.STMHandler.PendingState do
  @moduledoc """
  Handles running tasks
  """

  @entry_metric_name "Ppl.zebra_task_init_overhead"

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:block, :task_pending_sp),
    repo: Block.EctoRepo,
    schema: Block.Tasks.Model.Tasks,
    observed_state: "pending",
    allowed_states: ~w(running done),
    cooling_time_sec: Util.Config.get_cooling_time(:block, :task_pending_ct),
    columns_to_log: [:state, :recovery_count, :block_id, :build_request_id]

  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Tasks.STMHandler.Common
  alias Block.Tasks.Model.Tasks
  alias LogTee, as: LT
  alias Util.{ToTuple, Metrics}

  @handler_timeout 4321
  @partition_rejected_metric "Block.job_copy_partition.rejected_by_task_api"

  def initial_query(), do: Tasks

  def terminate_request_handler(blke, result) when result in ["cancel", "stop"] do
    reason = determin_reason(blke)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_pple, _), do: {:ok, :continue}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

  def scheduling_handler(task) do
    with block_id           <- task.block_id,
         {:ok, blk_req}     <- BlockRequestsQueries.get_by_id(block_id),
         {:ok, task_params} <- form_task_params(blk_req, task.build_request_id),
         {:ok, message}     <- schedule_task_with_fallback(task_params)
    do handle_schedule_result({:ok, message}, task)
    else
      e -> handle_schedule_result(e, task)
    end
  end

  defp schedule_task(task_params) do
    with {:ok, result} <- Wormhole.capture(TaskApiClient, :schedule, task_params,
                                          timeout_ms: @handler_timeout, stacktrace: true),
    do: result
  end

  # A Task API invalid_argument rejection is deterministic - retrying the same
  # request can not succeed. When the request carried a job copy partition,
  # degrade by stripping it and rescheduling the whole block once; a rejection
  # of a partition-free request falls through to the regular error path.
  defp schedule_task_with_fallback(task_params) do
    case schedule_task(task_params) do
      error = {:error, %GRPC.RPCError{status: 3}} ->
        retry_without_job_copy_partition(task_params, error)

      result ->
        result
    end
  end

  defp retry_without_job_copy_partition([definition, params, url], error) do
    ppl_args = Map.get(params, "ppl_args", %{})

    if is_map(ppl_args) and Map.has_key?(ppl_args, "job_copy_partition") do
      Watchman.increment(@partition_rejected_metric)
      error |> LT.warn("Task API rejected job copy partition, rescheduling whole block")

      params = Map.put(params, "ppl_args", Map.delete(ppl_args, "job_copy_partition"))
      schedule_task([definition, params, url])
    else
      error
    end
  end
  defp retry_without_job_copy_partition(_task_params, error), do: error

  defp form_task_params(blk_req, bld_req_id) do
    [
     blk_req.build,
     %{"wf_id" => blk_req.request_args |> Map.get("wf_id", ""),
       "ppl_id" => blk_req.ppl_id,
       "request_token" => bld_req_id,
       "project_id" => blk_req.request_args |> Map.get("project_id", ""),
       "org_id" => blk_req.request_args |> Map.get("organization_id", ""),
       "hook_id" => blk_req.request_args |> Map.get("hook_id", ""),
       "deployment_target_id" => blk_req.request_args |> Map.get("deployment_target_id", ""),
       "repository_id" => blk_req.request_args |> Map.get("repository_id", ""),
       # this is needed for evaluating When expressions in job priority settings
       "ppl_args" => blk_req.request_args |> Map.merge(blk_req.source_args || %{}),
       },
     Common.task_api_url()
    ]
    |> ToTuple.ok()
  end

  defp handle_schedule_result({:ok, task}, ppl_task) do
    {:ok, inserted_at} = DateTime.from_naive(ppl_task.inserted_at, "Etc/UTC")
    diff = DateTime.diff(task.created_at, inserted_at, :millisecond)

    {@entry_metric_name, [Metrics.dot2dash(__MODULE__)]}
    |> Watchman.submit(diff, :timing)

    desc = %{message: "#{inspect task}"}
    {:ok, fn _, _ -> {:ok, %{state: "running", description: desc, task_id: task.id}} end}
  end

  defp handle_schedule_result({:error, {:malformed, msg}}, _task) do
    {:ok, fn _, _ ->
      {:ok, %{state: "done", description: %{error: msg}, result: "failed",
              result_reason: "malformed"}}
    end}
  end

  defp handle_schedule_result({:error, msg}, _task) do
    desc = %{error: msg}
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_block_when_done(data)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
