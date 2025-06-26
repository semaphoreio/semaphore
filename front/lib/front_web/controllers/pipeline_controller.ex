defmodule FrontWeb.PipelineController do
  use FrontWeb, :controller

  alias Front.Audit
  alias Front.Models.Pipeline
  alias Front.Models.Switch
  alias Front.WorkflowPage.PipelineStatus
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess, PublicPageAccess, PutProjectAssigns}

  require Logger

  plug(:put_layout, false)

  @public_endpoints ~w(path status show poll switch)a
  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")

  plug(PublicPageAccess when action in @public_endpoints)
  plug(PageAccess, [permissions: "project.view"] when action not in @public_endpoints)
  plug(PageAccess, [permissions: "project.job.stop"] when action == :stop)
  plug(PageAccess, [permissions: "project.job.rerun"] when action == :rebuild)

  plug(:assign_pipeline_with_blocks when action in [:show, :poll])
  plug(:assign_pipeline_without_blocks when action in [:status, :switch, :stop, :rebuild])
  plug(:preload_switch when action in [:show, :poll, :switch])

  def path(conn, params) do
    organization_id = conn.assigns.organization_id
    workflow_id = conn.assigns.workflow.id

    toggle_skipped_blocks_enabled? =
      FeatureProvider.feature_enabled?(
        :toggle_skipped_blocks,
        param: organization_id
      )

    dt_enabled? =
      FeatureProvider.feature_enabled?(
        :deployment_targets,
        param: organization_id
      )

    opts = [
      fold_skipped_blocks?: toggle_skipped_blocks_enabled?,
      requester_id: if(dt_enabled?, do: conn.assigns[:user_id], else: "")
    ]

    root_pipeline = Pipeline.path(params["pipeline_id"], opts)

    resource_ownership_matches? =
      organization_matches?(organization_id, root_pipeline.organization_id) &&
        workflow_matches?(workflow_id, root_pipeline.workflow_id)

    resource_ownership_matches?
    |> case do
      true ->
        data =
          [
            workflow: conn.assigns.workflow,
            pipeline: root_pipeline,
            selected_trigger_event_id: nil,
            can_promote?: conn.assigns.permissions["project.job.rerun"] || false,
            selected_pipeline_id: params["pipeline_id"]
          ]
          |> inject_nonce(params)

        render(conn, "path.html", data)

      false ->
        conn
        |> respond_with_error(:not_found)
    end
  end

  def show(conn, params) do
    pipeline_data =
      pipeline_data(conn, params)
      |> inject_nonce(params)

    render(conn, "show.html", pipeline_data)
  end

  def poll(conn, params) do
    pipeline_data =
      pipeline_data(conn, params)
      |> inject_nonce(params)

    render(conn, "_pipeline.html", pipeline_data)
  end

  def status(conn, _params) do
    Watchman.benchmark("pipeline_controller.status", fn ->
      pipeline = conn.assigns.pipeline

      {:ok, pipeline_status} = PipelineStatus.Model.load(pipeline.id)
      text(conn, pipeline_status)
    end)
  end

  def switch(conn, params) do
    render(conn, "_switch.html",
      workflow: conn.assigns.workflow,
      pipeline: conn.assigns.pipeline,
      switch:
        conn.assigns.pipeline.switch |> Switch.preload_users() |> Switch.preload_pipelines(),
      selected_trigger_event_id: params["selected_trigger_event_id"],
      can_promote?: conn.assigns.permissions["project.job.rerun"] || false
    )
  end

  def stop(conn, _params) do
    Watchman.benchmark("stop.duration", fn ->
      project = conn.assigns.project
      workflow = conn.assigns.workflow
      pipeline = conn.assigns.pipeline

      log_stop(conn, project, workflow, pipeline)
      stop_pipeline(conn, pipeline.id, conn.assigns.user_id, conn.assigns.tracing_headers)
    end)
  end

  defp stop_pipeline(conn, ppl_id, user_id, tracing_headers) do
    case Pipeline.stop(ppl_id, user_id, tracing_headers) do
      :ok ->
        conn
        |> json(%{message: "Pipeline will be stopped shortly."})

      {:error, message} ->
        conn
        |> json(%{error: message})
    end
  end

  def rebuild(conn, _params) do
    Watchman.benchmark("rebuild.duration", fn ->
      project = conn.assigns.project
      workflow = conn.assigns.workflow
      pipeline = conn.assigns.pipeline

      log_rebuild(conn, project, workflow, pipeline)
      rebuild_pipeline(conn, pipeline.id, conn.assigns.user_id, conn.assigns.tracing_headers)
    end)
  end

  defp rebuild_pipeline(conn, ppl_id, user_id, tracing_headers) do
    case Pipeline.rebuild(ppl_id, user_id, tracing_headers) do
      {:ok, new_pipeline_id} ->
        conn
        |> json(%{
          message: "Pipeline rebuild initiated successfully.",
          pipeline_id: new_pipeline_id
        })

      {:error, message} ->
        conn
        |> json(%{error: message})
    end
  end

  defp organization_matches?(organization_id, pipeline_organization_id) do
    organization_id == pipeline_organization_id
  end

  defp workflow_matches?(workflow_id, pipeline_workflow_id) do
    workflow_id == pipeline_workflow_id
  end

  defp log_stop(conn, project, workflow, pipeline) do
    conn
    |> Audit.new(:Pipeline, :Stopped)
    |> Audit.add(:resource_name, pipeline.name)
    |> Audit.add(:description, "Stopped the pipeline")
    |> Audit.metadata(project_id: project.id)
    |> Audit.metadata(project_name: project.name)
    |> Audit.metadata(branch_name: workflow.branch_name)
    |> Audit.metadata(workflow_id: workflow.id)
    |> Audit.metadata(commit_sha: workflow.commit_sha)
    |> Audit.metadata(pipeline_id: pipeline.id)
    |> Audit.log()
  end

  defp log_rebuild(conn, project, workflow, pipeline) do
    conn
    |> Audit.new(:Pipeline, :Rebuild)
    |> Audit.add(:resource_name, pipeline.name)
    |> Audit.add(:description, "Rebuilt the pipeline")
    |> Audit.metadata(project_id: project.id)
    |> Audit.metadata(project_name: project.name)
    |> Audit.metadata(branch_name: workflow.branch_name)
    |> Audit.metadata(workflow_id: workflow.id)
    |> Audit.metadata(commit_sha: workflow.commit_sha)
    |> Audit.metadata(pipeline_id: pipeline.id)
    |> Audit.log()
  end

  defp pipeline_data(conn, params) do
    diagram =
      if FeatureProvider.feature_enabled?(:toggle_skipped_blocks,
           param: conn.assigns.organization_id
         ) do
        conn.assigns.pipeline
        |> Front.WorkflowPage.Diagram.load()
        |> Front.WorkflowPage.Diagram.SkippedBlocks.fold_dependencies()
      else
        Front.WorkflowPage.Diagram.load(conn.assigns.pipeline)
      end

    [
      workflow: conn.assigns.workflow,
      pipeline: diagram,
      selected_trigger_event_id: params["selected_trigger_event_id"],
      can_promote?: conn.assigns.permissions["project.job.rerun"] || false,
      selected_pipeline_id: params["pipeline_id"]
    ]
  end

  defp inject_nonce(data, %{"nonce" => nonce}),
    do: Keyword.merge([script_src_nonce: nonce], data)

  defp inject_nonce(data, _), do: data

  defp assign_pipeline_with_blocks(conn, _), do: assign_pipeline(conn, detailed: true)
  defp assign_pipeline_without_blocks(conn, _), do: assign_pipeline(conn, detailed: false)

  defp assign_pipeline(conn, detailed: detailed) do
    pipeline = Pipeline.find(conn.params["pipeline_id"], detailed: detailed)
    organization_id = conn.assigns.organization_id
    workflow_id = conn.assigns.workflow.id

    resource_ownership_matches? =
      organization_matches?(organization_id, pipeline.organization_id) &&
        workflow_matches?(workflow_id, pipeline.workflow_id)

    if pipeline && resource_ownership_matches? do
      conn
      |> assign(:pipeline, pipeline)
    else
      conn
      |> respond_with_error(:not_found)
    end
  end

  defp respond_with_error(conn, error = :not_found) do
    error
    |> case do
      :not_found ->
        conn
        |> put_status(:not_found)
        |> put_view(FrontWeb.ErrorView)
        |> render("404.html")
        |> halt
    end
  end

  defp preload_switch(conn, _) do
    pipeline_without_switch = conn.assigns[:pipeline]
    requester_id = conn.assigns[:user_id]

    if pipeline_without_switch do
      pipeline_with_switch = pipeline_without_switch |> Pipeline.preload_switch(requester_id)

      conn
      |> assign(:pipeline, pipeline_with_switch)
    else
      conn
    end
  end
end
