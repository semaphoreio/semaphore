# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.InsightsController do
  use FrontWeb, :controller

  alias Front.{
    Breadcrumbs,
    Models,
    ProjectPage
  }

  alias Models.ProjectMetrics

  alias FrontWeb.Plugs

  plug(
    Plugs.ProjectAuthorization
    when action in [:index]
  )

  plug(
    Plugs.Header
    when action in [:index]
  )

  def index(conn, params) do
    model = fetch_project_page_model(conn, params)

    Watchman.increment("velocity.insights.index.hit")

    branch_name = fetch_default_branch_name(conn)

    assigns =
      %{
        js: :insights,
        project: model.project,
        organization: model.organization,
        title: "#{model.project.name}・#{model.organization.name}",
        notice: get_flash(conn, :notice),
        layout: {FrontWeb.LayoutView, "project.html"},
        starred?: is_starred?(conn, params),
        default_branch_name: branch_name
      }
      |> Breadcrumbs.Project.construct(conn, :insights)

    conn
    |> render("index.html", assigns)
  end

  defp fetch_default_branch_name(conn) do
    project = conn.assigns.project

    case ProjectMetrics.insights_project_settings(project.id) do
      {:ok, settings} ->
        if String.length(settings.ci_branch_name) > 0 do
          settings.ci_branch_name
        else
          project.repo_default_branch
        end

      _ ->
        project.repo_default_branch
    end
  end

  defp fetch_project_page_model(conn, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    params =
      struct!(
        ProjectPage.Model.LoadParams,
        project_id: project.id,
        organization_id: org_id,
        user_id: user_id,
        page_token: params["page_token"] || "",
        direction: params["direction"] || "",
        user_page?: false,
        ref_types: []
      )

    {:ok, model, _page_source} =
      Front.Tracing.track(
        conn.assigns.trace_id,
        "fetch_project_page_model",
        fn ->
          params
          |> ProjectPage.Model.get(force_cold_boot: conn.params["force_cold_boot"])
        end
      )

    model
  end

  defp is_starred?(conn, _params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    Front.Tracing.track(
      conn.assigns.trace_id,
      "check_if_project_is_starred",
      fn ->
        Watchman.benchmark(
          "project_page_check_star",
          fn ->
            Models.User.has_favorite(user_id, org_id, project.id)
          end
        )
      end
    )
  end
end
