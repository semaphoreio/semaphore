defmodule Front.Decorators.Branch do
  alias Front.Models
  alias Front.Utils

  defstruct [:id, :name, :html_url, :workflow, :pipelines, :type]

  def decorate_one(workflow, _tracing_headers) do
    pipelines = Models.Pipeline.list(wf_id: workflow.id)
    workflow = Models.Workflow.preload_commit_data(workflow)

    construct(workflow, pipelines)
  end

  def decorate_many(lastest_workflows, tracing_headers \\ nil) do
    Utils.parallel_map(lastest_workflows, fn wf ->
      decorate_one(wf, tracing_headers)
    end)
  end

  defp construct(workflow, pipelines) do
    %__MODULE__{
      id: workflow.branch_id,
      name: workflow.branch_name,
      type: workflow.git_ref_type,
      html_url: "/branches/#{workflow.branch_id}",
      workflow: workflow,
      pipelines: sort_by_done_at(pipelines)
    }
  end

  defp sort_by_done_at(pipelines) do
    Enum.sort_by(pipelines, fn p -> p.timeline.done_at end)
  end
end
