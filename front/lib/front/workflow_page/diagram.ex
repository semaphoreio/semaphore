defmodule Front.WorkflowPage.Diagram do
  alias Front.WorkflowPage.Diagram

  def load(pipeline) do
    topology = Front.Models.Pipeline.topology(pipeline.id)

    tasks = Diagram.TaskLoader.load(pipeline)

    pipeline
    |> Diagram.Topology.assign(topology, tasks)
    |> Diagram.AfterTask.assign(topology, tasks)
    |> Diagram.WaitingForQuota.assign(tasks)
    |> Diagram.CompileTask.assign(tasks)
  end
end
