defmodule Front.WorkflowPage.Diagram.TaskLoader do
  def load(pipeline) do
    pipeline
    |> task_ids()
    |> Front.Models.Task.describe_many()
  end

  defp task_ids(pipeline) do
    ids =
      [pipeline.compile_task.task_id] ++
        [pipeline.after_task.task_id] ++
        block_task_ids(pipeline)

    reject_empty(ids)
  end

  defp reject_empty(ids) do
    Enum.filter(ids, fn i -> i != "" end)
  end

  defp block_task_ids(pipeline) do
    Enum.map(pipeline.blocks, fn b -> b.build_request_id end)
  end
end
