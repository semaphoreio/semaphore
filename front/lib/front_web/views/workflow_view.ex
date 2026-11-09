defmodule FrontWeb.WorkflowView do
  use FrontWeb, :view

  def page_title(_conn, assigns) do
    "Push: #{assigns.hook.commit_message} - Semaphore"
  end

  def render("map.json", %{workflow: workflow, conn: conn}) do
    permissions = conn.assigns.permissions
    anonymous? = FrontWeb.PipelineView.anonymous?(conn)

    rebuild? =
      FeatureProvider.feature_enabled?(:ui_partial_ppl_rebuild,
        param: conn.assigns.organization_id
      )

    %{
      root_pipeline_id: workflow.root_pipeline_id,
      pipelines:
        Enum.map(workflow.pipelines, fn pipeline ->
          pipeline
          |> map_pipeline()
          |> Map.merge(%{
            stop_url:
              if(
                !anonymous? && permissions["project.job.stop"] &&
                  FrontWeb.PipelineView.pipeline_stoppable?(pipeline),
                do: pipeline_stop_path(conn, :stop, workflow.id, pipeline.id)
              ),
            rebuild_url:
              if(
                !anonymous? && rebuild? && permissions["project.job.rerun"] &&
                  FrontWeb.PipelineView.pipeline_rebuildable?(pipeline),
                do: pipeline_rebuild_path(conn, :rebuild, workflow.id, pipeline.id)
              )
          })
        end)
    }
  end

  def render("map_pipelines.json", %{pipelines: pipelines, conn: conn, can_promote?: can_promote?}) do
    %{
      pipelines:
        Enum.map(pipelines, fn %{pipeline: pipeline, switch: switch} ->
          FrontWeb.PipelineView.render("map.json", %{
            conn: conn,
            pipeline: pipeline,
            switch: switch,
            can_promote?: can_promote?
          })
        end)
    }
  end

  defp map_pipeline(pipeline) do
    %{
      id: pipeline.id,
      name: pipeline.name,
      yaml_file: pipeline.yaml_file_name,
      state: pipeline.state,
      result: pipeline.result,
      parent_id: map_parent_id(pipeline),
      trigger: pipeline.triggerer.trigger_type,
      switch_id: blank_to_nil(pipeline.switch_id),
      created_at: zero_to_nil(pipeline.timeline.created_at),
      running_at: zero_to_nil(pipeline.timeline.running_at),
      done_at: zero_to_nil(pipeline.timeline.done_at)
    }
  end

  defp map_parent_id(%{partial_rerun_of: parent_id}) when parent_id not in [nil, ""],
    do: parent_id

  defp map_parent_id(%{promotion_of: parent_id}) when parent_id not in [nil, ""], do: parent_id

  defp map_parent_id(_), do: nil

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp zero_to_nil(0), do: nil
  defp zero_to_nil(value), do: value

  def workflow_map_config(conn, workflow_id, selected_pipeline_id) do
    %{
      workflowUrl: workflow_path(conn, :map, workflow_id),
      pipelinesUrl: workflow_path(conn, :map_pipelines, workflow_id),
      elkWorkerUrl: static_path(conn, "/projects/assets/workers/elk-worker.min.js"),
      selectedPipelineId: selected_pipeline_id,
      pollInterval: 4000
    }
    |> Poison.encode!(escape: :html_safe)
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
    if FeatureProvider.feature_enabled?(:ui_monaco_workflow_code_editor, param: org_id) do
      ""
    else
      "b--lighter-gray ba"
    end
  end
end
