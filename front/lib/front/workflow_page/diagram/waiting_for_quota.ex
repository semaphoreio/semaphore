defmodule Front.WorkflowPage.Diagram.WaitingForQuota do
  def assign(pipeline, tasks) do
    waiting? = Front.Models.Task.waiting_to_start?(tasks, treshold: 20)

    pipeline |> Map.put(:jobs_are_waiting?, waiting?)
  end
end
