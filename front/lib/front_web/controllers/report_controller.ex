defmodule FrontWeb.ReportController do
  require Logger
  use FrontWeb, :controller

  alias Front.Async

  alias FrontWeb.Plugs.{
    FetchPermissions,
    Header,
    PageAccess,
    PutProjectAssigns,
    FeatureEnabled
  }

  alias Front.Models.{
    Artifacthub,
    Branch,
    Organization,
    Pipeline,
    RepoProxy,
    Workflow
  }

  plug(FeatureEnabled, [:ui_reports])
  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")
  plug(PageAccess, permissions: "project.view")
  plug(Header when action in [:job, :workflow])

  def job(conn, _params) do
    Watchman.benchmark("markdown_report.job", fn ->
      job = conn.assigns.job
      project = conn.assigns.project

      {assigns, org} =
        assign_report_layout(conn, "job", job, %{
          job_id: job.id,
          badge_pollman: %{
            state: job.state,
            href: "/jobs/#{job.id}/status_badge"
          },
          base_url: report_url(conn, :job, job.id)
        })

      assigns =
        assigns
        |> job_assigns(org, project, job)
        |> Front.Breadcrumbs.Job.construct(conn, :reports)

      render(conn, "markdown.html", assigns)
    end)
  end

  def workflow(conn, _params) do
    Watchman.benchmark("markdown_report.workflow", fn ->
      workflow = conn.assigns.workflow
      project = conn.assigns.project

      fetch_branch =
        Async.run(
          fn -> Branch.find(workflow.project_id, workflow.branch_name) end,
          metric: "pipeline.test_results.branch.find"
        )

      {:ok, branch} = Async.await(fetch_branch)

      {assigns, org} =
        assign_report_layout(conn, "workflow", workflow, %{
          workflow: workflow,
          branch: branch,
          base_url: report_url(conn, :workflow, workflow.id)
        })

      assigns =
        assigns
        |> workflow_assigns(org, project)
        |> Front.Breadcrumbs.Workflow.construct(conn, :reports)

      render(conn, "markdown.html", assigns)
    end)
  end

  defp assign_report_layout(conn, context, resource, extra_assigns) do
    org_id = conn.assigns.organization_id
    project = conn.assigns.project

    fetch_organization =
      Async.run(
        fn -> Organization.find(org_id) end,
        metric: "artifacts.organization.find"
      )

    fetch_report_url =
      Async.run(
        fn ->
          fetch_report_from_context(project, context, resource)
        end,
        metric: "artifacts.artifact.signed_url"
      )

    {:ok, {:ok, report_url}} = Async.await(fetch_report_url)

    {:ok, org} = Async.await(fetch_organization)

    assigns =
      %{
        js: :report,
        report_context: context,
        report_url: report_url
      }
      |> Map.merge(extra_assigns)
      |> Map.put(:layout, {FrontWeb.LayoutView, "#{context}.html"})
      |> Map.put(:user, conn.assigns.layout_model.user)

    {assigns, org}
  end

  defp job_assigns(assigns, org, project, job) do
    ppl = Pipeline.find(job.ppl_id, detailed: true)

    workflow = Workflow.find(ppl.workflow_id)

    hook = RepoProxy.find(workflow.hook_id)

    block =
      Enum.find(ppl.blocks, fn block ->
        Enum.any?(block.jobs, fn j -> j.id == job.id end)
      end)

    assigns
    |> Map.put(:hook, hook)
    |> Map.put(:organization, org)
    |> Map.put(:workflow, workflow)
    |> Map.put(:workflow_name, hook.commit_message |> String.split("\n") |> hd)
    |> Map.put(:pipeline, ppl)
    |> Map.put(:block, block)
    |> Map.put(:job, job)
    |> Map.put(:project, project)
    |> Map.put(:title, "Report ・#{project.name}・#{org.name}")
  end

  defp workflow_assigns(assigns, org, project) do
    hook = RepoProxy.find(assigns.workflow.hook_id)

    assigns
    |> Map.put(:hook, hook)
    |> Map.put(:organization, org)
    |> Map.put(:workflow, assigns.workflow)
    |> Map.put(:workflow_name, hook.commit_message |> String.split("\n") |> hd)
    |> Map.put(:project, project)
    |> Map.put(:showForkExplanation?, false)
    |> Map.put(:title, "Report ・#{project.name}・#{org.name}")
  end

  defp fetch_report_from_context(project, "job", job) do
    Artifacthub.signed_url(project.id, "jobs", job.id, ".semaphore/REPORT.md")
  end

  defp fetch_report_from_context(project, "workflow", workflow) do
    Artifacthub.signed_url(project.id, "workflows", workflow.id, ".semaphore/REPORT.md")
  end
end
