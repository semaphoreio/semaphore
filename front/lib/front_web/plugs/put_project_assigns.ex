defmodule FrontWeb.Plugs.PutProjectAssigns do
  @moduledoc """
    This plug fetches all the project related data, and puts it into assigns

    If 'name_or_id' query param is present, that means the user is accessing a project page, and only project related
    data will be put in the assigns.

    If 'workflow_id' or 'id' query params are present, that means the user is accessing job or workflow page. In that
    case job/workflow data will be put in the assigns togeather with the project data.
  """
  import Plug.Conn
  require Logger

  defguard not_empty(id) when is_binary(id) and id != ""

  def init(default), do: default

  def call(conn, _opts) do
    params = conn.params
    org_id = conn.assigns.organization_id

    fetch_project!(
      conn,
      org_id,
      params["name_or_id"],
      params["workflow_id"],
      params["id"],
      params["branch_id"]
    )
  rescue
    e ->
      Logger.error("Error #{inspect(e)} while fetching project #{inspect(conn)}")
      conn |> render_404()
  end

  defp fetch_project!(conn, org_id, proj_id, _wf_id, _job_id, _branch_id)
       when not_empty(proj_id) do
    case Front.Models.Project.find(proj_id, org_id) do
      nil -> conn |> render_404()
      project -> assign(conn, :project, project)
    end
  end

  defp fetch_project!(conn, org_id, _proj_id, wf_id, _job_id, _branch_id) when not_empty(wf_id) do
    case Front.Models.Workflow.find(wf_id) do
      nil ->
        Logger.info("Workflow with id #{inspect(wf_id)} does not exist")
        conn |> render_404()

      wf ->
        conn |> assign(:workflow, wf) |> fetch_project!(org_id, wf.project_id, "", "", "")
    end
  end

  defp fetch_project!(conn, org_id, _proj_id, _wf_id, job_id, _branch_id)
       when not_empty(job_id) do
    case Front.Models.Job.find(job_id) do
      nil ->
        Logger.info("Job with id #{inspect(job_id)} does not exist")
        conn |> render_404()

      job ->
        conn |> assign(:job, job) |> fetch_project!(org_id, job.project_id, "", "", "")
    end
  end

  defp fetch_project!(conn, org_id, _proj_id, _wf_id, _job_id, branch_id)
       when not_empty(branch_id) do
    case Front.Models.Branch.find_by_id(branch_id) do
      nil ->
        Logger.info("Branch with id #{inspect(branch_id)} does not exist")
        conn |> render_404()

      branch ->
        conn |> assign(:branch, branch) |> fetch_project!(org_id, branch.project_id, "", "", "")
    end
  end

  ### Helper functions

  defp render_404(conn),
    do: conn |> assign(:project, nil) |> FrontWeb.PageController.status404(%{}) |> halt()
end
