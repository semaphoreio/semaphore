defmodule Block.Tasks.Beholder do
  @moduledoc """
  Periodically scans 'block_builds' table searching for
  tasks stuck in scheduling.

  All scheduling activities have to be finished within Wormhole timeout
  (by default 5 seconds).
  After that task is stuck.
  """

  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Block.Tasks.STMHandler.Common
  alias LogTee, as: LT

  @period_sec Application.compile_env!(:block, :beholder_task_sleep_period_sec)
  @threshold_sec Application.compile_env!(:block, :beholder_task_threshold_sec)
  @threshold_count Application.compile_env!(:block, :beholder_task_threshold_count)
  @handler_timeout 4321

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Block.Tasks.Model.Tasks,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Block.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count,
    external_metric: "Tasks.state",
    callback: fn task -> apply(__MODULE__, :terminate_stuck_task, [task]) end

  def terminate_stuck_task(task) do
    case task.state do
      "running" -> terminate_stuck_task_(task)
      _state    -> task
    end
  end

  defp terminate_stuck_task_(task) do
    {:ok, response} = Wormhole.capture(TaskApiClient, :terminate,
                                       [task.task_id, Common.task_api_url()],
                                       timeout_ms: @handler_timeout, stacktrace: true)
    response
    |> LT.info("Stuck task with task_id: #{task.task_id} termination response: ")
  end
end
