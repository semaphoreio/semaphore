defmodule FrontWeb.WorkflowView do
  use FrontWeb, :view

  def page_title(_conn, assigns) do
    "Push: #{assigns.hook.commit_message} - Semaphore"
  end

  def filter_done(pipelines) do
    pipelines |> Enum.filter(fn pipeline -> pipeline.state == :DONE end)
  end

  def filter_pending(pipelines) do
    pipelines |> Enum.filter(fn pipeline -> pipeline.state != :DONE end)
  end

  def pipeline_status_class(pipeline), do: pipeline_status_class(pipeline.state, pipeline.result)
  def pipeline_status_class(:DONE, :PASSED), do: "c-pipeline-activity-item-passed"
  def pipeline_status_class(:DONE, :FAILED), do: "c-pipeline-activity-item-failed"
  def pipeline_status_class(:DONE, _), do: ""

  def pipeline_status_badge(pipeline), do: pipeline_status_badge(pipeline.state, pipeline.result)

  def pipeline_status_badge(:INITIALIZING, _),
    do: "<span class='badge badge-queue mr1'>Initializing</span>"

  def pipeline_status_badge(:QUEUING, _),
    do: "<span class='badge badge-queue mr1'>Enqueued</span>"

  def pipeline_status_badge(:PENDING, _), do: "<span class='badge badge-queue mr1'>Pending</span>"

  def pipeline_status_badge(:RUNNING, _),
    do: "<span class='badge badge-running mr1'>Running…</span>"

  def pipeline_status_badge(:STOPPING, _),
    do: "<span class='badge badge-queue mr1'>Stopping</span>"

  # this should never happen
  def pipeline_status_badge(_, _), do: ""

  def pipeline_stoppable?(pipeline), do: pipeline_stoppable?(pipeline.state, pipeline.result)
  def pipeline_stoppable?(:INITIALIZING, _), do: true
  def pipeline_stoppable?(:QUEUING, _), do: true
  def pipeline_stoppable?(:PENDING, _), do: true
  def pipeline_stoppable?(:RUNNING, _), do: true
  def pipeline_stoppable?(:STOPPING, _), do: false
  def pipeline_stoppable?(_, _), do: false

  def termination_author_span(nil), do: ""

  def termination_author_span(user),
    do:
      "<span class='mh1'>·</span><span class='gray'>Stopped by #{escape_unsafe_string(user.name)}</span>"

  def code_editor_border_classes(org_id) do
    if FeatureProvider.feature_enabled?(:ui_new_workflow_code_editor, param: org_id) do
      ""
    else
      "b--lighter-gray ba"
    end
  end
end
