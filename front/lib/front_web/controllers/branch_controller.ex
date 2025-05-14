defmodule FrontWeb.BranchController do
  use FrontWeb, :controller

  alias Front.BranchPage
  alias Front.Models
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PublicPageAccess, PutProjectAssigns}

  @public_pages ~w(show workflows)a
  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")

  plug(PublicPageAccess when action in @public_pages)
  plug(PageAccess, [permissions: "project.view"] when action not in @public_pages)

  plug(Header when action in [:show])

  def edit_workflow(conn, _params) do
    Watchman.benchmark("edit_branch_workflow.duration", fn ->
      workflow =
        Models.Workflow.find_latest(
          project_id: conn.assigns.project.id,
          branch_name: conn.assigns.branch.name
        )

      conn |> redirect(to: workflow_path(conn, :edit, workflow.id))
    end)
  end

  def show(conn, params) do
    Watchman.benchmark("show.duration", fn ->
      case conn.assigns.authorization do
        :member -> common(conn, params, "member.html")
        :guest -> common(conn, params, "guest.html")
      end
    end)
  end

  defp common(conn, params, template) do
    org_id = conn.assigns.organization_id
    page_token = params["page_token"] || ""
    direction = params["direction"] || ""
    date_from = params["date_from"]
    date_to = params["date_to"]

    branch = conn.assigns.branch
    project = conn.assigns.project

    params =
      struct!(BranchPage.Model.LoadParams,
        branch_name: branch.name,
        branch_id: branch.id,
        project_id: project.id,
        organization_id: org_id,
        page_token: page_token,
        direction: direction,
        date_from: date_from,
        date_to: date_to
      )

    {:ok, model, source} = params |> BranchPage.Model.get()

    pollman = %{
      state: "poll",
      href: "/branches/#{branch.id}/workflows",
      params: [
        page_token: page_token,
        direction: direction,
        date_from: date_from,
        date_to: date_to
      ]
    }

    assigns =
      %{
        js: :branch_page,
        branch: branch,
        project: project,
        organization: model.organization,
        workflows: model.workflows,
        pagination: model.pagination,
        pollman: pollman,
        title: compose_title(branch, project, model.organization),
        conflict_info: determine_conflict(model.workflows)
      }
      |> Front.Breadcrumbs.Branch.construct()

    conn
    |> put_page_source_header(source)
    |> render(
      template,
      assigns
    )
  end

  def workflows(conn, params) do
    page_token = params["page_token"] || ""
    direction = params["direction"] || ""
    date_from = params["date_from"]
    date_to = params["date_to"]

    branch = conn.assigns.branch
    project = conn.assigns.project

    params =
      struct!(BranchPage.Model.LoadParams,
        branch_name: branch.name,
        branch_id: branch.id,
        project_id: project.id,
        organization_id: conn.assigns.organization_id,
        page_token: page_token,
        direction: direction,
        date_from: date_from,
        date_to: date_to
      )

    {:ok, model, source} = params |> BranchPage.Model.get()

    pollman = %{
      state: "poll",
      href: "/branches/#{branch.id}/workflows",
      params: [
        page_token: page_token,
        direction: direction,
        date_from: date_from,
        date_to: date_to
      ]
    }

    conn
    |> put_layout(false)
    |> put_page_source_header(source)
    |> render(
      "_workflows.html",
      workflows: model.workflows,
      pagination: model.pagination,
      pollman: pollman,
      page: :branch,
      conflict_info: determine_conflict(model.workflows)
    )
  end

  defp put_page_source_header(conn, source) do
    case source do
      :from_cache -> conn |> put_resp_header("semaphore_page_source", "cache")
      :from_api -> conn |> put_resp_header("semaphore_page_source", "API")
    end
  end

  defp determine_conflict(workflows) do
    if Enum.empty?(workflows) do
      false
    else
      latest_workflow = List.first(workflows)
      conflict_info(latest_workflow.type, latest_workflow.pr_mergeable)
    end
  end

  defp conflict_info("pr", false), do: true
  defp conflict_info(_, _), do: false

  defp compose_title(branch, project, organization) do
    "#{branch.name}・#{project.name}・#{organization.name}"
  end
end
