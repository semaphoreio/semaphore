defmodule Block.Tasks.TaskEventsConsumer do
  @moduledoc """
  Receives Task finished events from the RabbitMQ and initiates STM handlers for
  those tasks.
  """

  import Ecto.Query

  use Tackle.Consumer,
    url: System.get_env("RABBITMQ_URL"),
    exchange: "task_state_exchange",
    routing_key: "finished",
    service: "block"


  alias Block.Tasks.STMHandler.RunningState, as: TaskRunningState
  alias Block.Tasks.STMHandler.StoppingState, as: TaskStoppingState
  alias InternalApi.Task.TaskFinished
  alias Util.Metrics
  alias LogTee, as: LT

  def handle_message(message)do
    Metrics.benchmark("TasksEventsConsumer.task_finished_event", fn ->
      message
      |> decode_message()
      |> trigger_loopers()
    end)
  end

  defp decode_message(message) do
    Wormhole.capture(TaskFinished, :decode, [message], stacktrace: true)
  end

  defp trigger_loopers({:ok, %{task_id: id}})
    when is_binary(id) and id != "" do
      predicate = fn query -> query |> where(task_id: ^id) |> where([p], p.state != "done") end
      predicate |> TaskRunningState.execute_now_with_predicate()
      predicate |> TaskStoppingState.execute_now_with_predicate()

      # Compilation task callback
      fn query -> query |> where(compile_task_id: ^id) |> where([p], p.state != "done") end
      |> compile_task_done_notification_callback()

      # After pipeline task callback
      fn query -> query |> where(after_task_id: ^id) |> where([p], p.state != "done") end
      |> after_ppl_task_done_notification_callback
  end
  defp trigger_loopers(error),
    do: error |> LT.warn("Error while processing RabbitMQ message:")


  defp compile_task_done_notification_callback(predicate) do
    {m, f} = Application.get_env(:block, :compile_task_done_notification_callback,
      {":compile_task_done_notification_callback not defined", ""})

    apply(m, f, [predicate])
  end

  defp after_ppl_task_done_notification_callback(predicate) do
    {m, f} = Application.get_env(:block, :after_ppl_task_done_notification_callback,
      {":after_ppl_task_done_notification_callback not defined", ""})

    apply(m, f, [predicate])
  end
end
