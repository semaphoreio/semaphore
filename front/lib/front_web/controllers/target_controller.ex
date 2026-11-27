defmodule FrontWeb.TargetController do
  use FrontWeb, :controller

  alias Front.Audit
  alias Front.Models.{Pipeline, Switch}
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess, PutProjectAssigns}

  plug(:put_layout, false)
  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")
  plug(PageAccess, permissions: "project.job.rerun")
  plug(:assign_pipeline)

  def trigger(conn, params) do
    Watchman.benchmark("trigger.duration", fn ->
      switch_id = params["switch_id"]
      name = params["name"]
      user_id = conn.assigns.user_id
      tracing_headers = conn.assigns.tracing_headers

      switch = Switch.find(switch_id, user_id)

      if switch && switch.pipeline_id == conn.assigns.pipeline.id do
        target = Switch.find_target_by_name(switch, name)
        parameters = parse_target_parameters(conn)

        log_promotion(conn, name, switch, parameters)

        case Switch.Target.trigger(target, user_id, parameters, tracing_headers) do
          {:ok, _} ->
            text(conn, "Target '#{name}' triggered.")

          {:error, msg} ->
            conn |> put_status(500) |> text(msg)
        end
      else
        conn |> put_status(404) |> text("Not found")
      end
    end)
  end

  # Resolves the pipeline named in the URL the same way PipelineController
  # does, so this controller doesn't end up reasoning about a pipeline that
  # belongs to a different workflow/organization than the request's.
  defp assign_pipeline(conn, _opts) do
    pipeline = Pipeline.find(conn.params["pipeline_id"])
    organization_id = conn.assigns.organization_id
    workflow_id = conn.assigns.workflow.id

    if Pipeline.belongs_to_workflow?(pipeline, organization_id, workflow_id) do
      assign(conn, :pipeline, pipeline)
    else
      conn |> put_status(404) |> text("Not found") |> halt()
    end
  end

  defp log_promotion(conn, name, switch, parameters) do
    conn
    |> Audit.new(:Pipeline, :Promoted)
    |> Audit.add(:resource_name, name)
    |> Audit.add(:description, log_description(name, parameters))
    |> Audit.metadata(project_id: conn.assigns.project.id)
    |> Audit.metadata(project_name: conn.assigns.project.name)
    |> Audit.metadata(branch_name: conn.assigns.workflow.branch_name)
    |> Audit.metadata(workflow_id: conn.assigns.workflow.id)
    |> Audit.metadata(commit_sha: conn.assigns.workflow.commit_sha)
    |> Audit.metadata(pipeline_id: switch.pipeline_id)
    |> Audit.log()
  end

  defp log_description(name, []) do
    "Triggered a promotion to #{name}"
  end

  defp log_description(name, parameters) do
    parameter_description =
      parameters
      |> Enum.map_join(" ", fn p -> "#{p.name}=#{p.value}" end)

    log_description(name, []) <> " with parameters " <> parameter_description
  end

  defp parse_target_parameters(conn) do
    (conn.body_params["parameters"] || [])
    |> Enum.map(fn {key, value} ->
      InternalApi.Gofer.EnvVariable.new(name: key, value: value)
    end)
  end
end
