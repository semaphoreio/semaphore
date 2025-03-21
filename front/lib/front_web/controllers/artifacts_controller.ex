defmodule FrontWeb.ArtifactsController do
  require Logger
  use FrontWeb, :controller

  alias Front.Artifacts.Folder

  alias Front.Models.{
    Artifacthub,
    Pipeline,
    RepoProxy,
    User,
    Workflow
  }

  alias Front.Async
  alias Front.Audit
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PutProjectAssigns}

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")

  @ui_endpoints ~w(projects workflows jobs)a
  @download_endpoints ~w(projects_download workflows_download jobs_download)a
  @delete_endpoints ~w(projects_destroy workflows_destroy jobs_destroy)a

  plug(PageAccess, [permissions: "project.view"] when action in @ui_endpoints)
  plug(PageAccess, [permissions: "project.artifacts.view"] when action in @download_endpoints)
  plug(PageAccess, [permissions: "project.artifacts.delete"] when action in @delete_endpoints)
  plug(Header when action in @ui_endpoints)
  plug(:set_artifact_source_params)

  def projects(conn, _params) do
    Watchman.benchmark("artifacts.projects.duration", fn ->
      project = conn.assigns.project
      organization = conn.assigns.layout_model.current_organization
      user = conn.assigns.layout_model.user

      source_kind = "projects"
      source_id = project.id

      case Artifacthub.list(project.id, source_kind, source_id, conn.assigns.page_path) do
        {:ok, artifacts} ->
          assigns =
            common_assigns(conn, artifacts, source_kind, source_id)
            |> Map.put(:js, "project_artifacts")
            |> Map.put(:starred?, User.has_favorite(user.id, organization.id, project.id))
            |> Map.put(:layout, {FrontWeb.LayoutView, "project.html"})
            |> Map.put(:title, "Project Artifacts・#{project.name}・#{organization.name}")
            |> Front.Breadcrumbs.Artifacts.construct(conn, source_kind)

          render(conn, "index.html", assigns)

        {:error, :non_existent_path} ->
          render_404(conn)
      end
    end)
  end

  def workflows(conn, params) do
    Watchman.benchmark("artifacts.projects.duration", fn ->
      project = conn.assigns.project
      workflow = conn.assigns.workflow
      user = conn.assigns.layout_model.user
      organization = conn.assigns.layout_model.current_organization

      fork = params["fork"] == "true"
      close_fork_explanation = conn.req_cookies["close_fork_explanation"] == "true"

      source_kind = "workflows"
      source_id = workflow.id

      hook = RepoProxy.find(workflow.hook_id)

      case Artifacthub.list(project.id, source_kind, source_id, conn.assigns.page_path) do
        {:ok, artifacts} ->
          assigns =
            common_assigns(conn, artifacts, source_kind, source_id)
            |> Map.put(:selected_pipeline_id, workflow.root_pipeline_id)
            |> Map.put(:hook, hook)
            |> Map.put(:showForkExplanation?, fork && !close_fork_explanation)
            |> Map.put(:organization, organization)
            |> Map.put(:user, user)
            |> Map.put(:layout, {FrontWeb.LayoutView, "workflow.html"})
            |> Map.put(:title, "Workflow Artifacts・#{project.name}・#{organization.name}")
            |> Front.Breadcrumbs.Artifacts.construct(conn, source_kind)

          render(conn, "index.html", assigns)

        {:error, :non_existent_path} ->
          render_404(conn)
      end
    end)
  end

  def jobs(conn, _params) do
    Watchman.benchmark("artifacts.projects.duration", fn ->
      project = conn.assigns.project
      job = conn.assigns.job
      organization = conn.assigns.layout_model.current_organization

      fetch_pipeline = Async.run(fn -> Pipeline.find(job.ppl_id, detailed: true) end)

      {:ok, pipeline} = Async.await(fetch_pipeline)

      fetch_workflow = Async.run(fn -> Workflow.find(pipeline.workflow_id) end)
      fetch_hook = Async.run(fn -> RepoProxy.find(pipeline.hook_id) end)

      {:ok, hook} = Async.await(fetch_hook)
      {:ok, workflow} = Async.await(fetch_workflow)

      source_kind = "jobs"
      source_id = job.id

      badge_pollman = %{
        state: job.state,
        href: "/jobs/#{job.id}/status_badge"
      }

      block =
        Enum.find(pipeline.blocks, fn block ->
          Enum.any?(block.jobs, fn job -> job.id == source_id end)
        end)

      case Artifacthub.list(project.id, source_kind, source_id, conn.assigns.page_path) do
        {:ok, artifacts} ->
          assigns =
            common_assigns(conn, artifacts, source_kind, source_id)
            |> Map.put(:layout, {FrontWeb.LayoutView, "job.html"})
            |> Map.put(:hook, hook)
            |> Map.put(:workflow, workflow)
            |> Map.put(:workflow_name, hook.commit_message |> String.split("\n") |> hd)
            |> Map.put(:pipeline, pipeline)
            |> Map.put(:block, block)
            |> Map.put(:badge_pollman, badge_pollman)
            |> Map.put(:title, "Job Artifacts・#{project.name}・#{organization.name}")
            |> Front.Breadcrumbs.Artifacts.construct(conn, source_kind)

          render(conn, "index.html", assigns)

        {:error, :non_existent_path} ->
          render_404(conn)
      end
    end)
  end

  def projects_download(conn, _params) do
    download(conn, "projects", conn.assigns.project.id)
  end

  def workflows_download(conn, _params) do
    download(conn, "workflows", conn.assigns.workflow.id)
  end

  def jobs_download(conn, _params) do
    download(conn, "jobs", conn.assigns.job.id)
  end

  defp download(conn, source_kind, source_id) do
    Watchman.benchmark("artifacts.download.duration", fn ->
      project_id = conn.assigns.project.id
      artifact_path = conn.assigns.resource_path

      conn
      |> Audit.new(:Artifact, :Download)
      |> Audit.add(resource_name: artifact_path)
      |> Audit.metadata(source_kind: source_kind, source_id: source_id, project_id: project_id)
      |> Audit.log()

      with {:ok, url} <- Artifacthub.signed_url(project_id, source_kind, source_id, artifact_path) do
        conn
        |> redirect(external: url)
      else
        _ ->
          conn
          |> put_flash(:alert, "Failed to fetch requested artifact.")
      end
    end)
  end

  def projects_destroy(conn, _params) do
    destroy(conn, :projects, "projects", conn.assigns.project)
  end

  def workflows_destroy(conn, _params) do
    destroy(conn, :workflows, "workflows", conn.assigns.workflow)
  end

  def jobs_destroy(conn, _params) do
    destroy(conn, :jobs, "jobs", conn.assigns.job)
  end

  defp destroy(conn, action, source_kind, source) do
    Watchman.benchmark("artifacts.destroy.duration", fn ->
      project_id = conn.assigns.project.id
      artifact_path = conn.assigns.resource_path

      conn
      |> Audit.new(:Artifact, :Removed)
      |> Audit.add(resource_name: artifact_path)
      |> Audit.metadata(source_kind: source_kind, source_id: source.id, project_id: project_id)
      |> Audit.log()

      with {:ok, _response} <-
             Artifacthub.destroy(project_id, source_kind, source.id, artifact_path) do
        conn
        |> put_flash(:notice, "Artifact resource deleted.")
        |> redirect(to: redirect_path(conn, action, source))
      else
        _ ->
          conn
          |> put_flash(:alert, "Failed to delete the artifact.")
          |> redirect(to: redirect_path(conn, action, source))
      end
    end)
  end

  defp redirect_path(conn, action = :projects, source),
    do: artifacts_path(conn, action, source.name)

  defp redirect_path(conn, action, source), do: artifacts_path(conn, action, source.id)

  defp set_artifact_source_params(conn, _opts) do
    page_path = conn.params["path"] || ""
    resource_path = conn.params["resource_path"] || ""

    conn
    |> assign(:page_path, page_path)
    |> assign(:resource_path, resource_path)
  end

  defp common_assigns(conn, artifacts, source_kind, source_id) do
    %{
      artifact_navbar_components: Folder.get_navigation(conn.assigns.page_path),
      artifacts: artifacts,
      source_kind: source_kind,
      permissions: conn.assigns.permissions,
      source_id: source_id
    }
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
  end
end
