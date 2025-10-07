defmodule FrontWeb.TestResultsController do
  require Logger
  use FrontWeb, :controller

  alias Front.Async

  alias FrontWeb.Plugs.{
    FetchPermissions,
    Header,
    PublicPageAccess,
    PutProjectAssigns
  }

  alias Front.Models.{
    Artifacthub,
    Branch,
    Job,
    Organization,
    Pipeline,
    RepoProxy,
    Workflow
  }

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")

  @public_endpoints [:job_summary, :pipeline_summary, :details]
  plug(PublicPageAccess when action in @public_endpoints)
  plug(Header when action in [:job_summary, :pipeline_summary, :details])

  def job_summary(conn, _params) do
    Watchman.benchmark("job.test_results.summary", fn ->
      org_id = conn.assigns.organization_id
      job = conn.assigns.job
      project = conn.assigns.project

      fetch_organization =
        Async.run(
          fn -> Organization.find(org_id) end,
          metric: "artifacts.organization.find"
        )

      fetch_junit_json_url =
        Async.run(
          fn ->
            Artifacthub.signed_url(project.id, "jobs", job.id, "test-results/junit.json")
          end,
          metric: "artifacts.artifact.signed_url"
        )

      {:ok, org} = Async.await(fetch_organization)
      {:ok, {:ok, junit_json_url}} = Async.await(fetch_junit_json_url)

      badge_pollman = %{
        state: job.state,
        href: "/jobs/#{job.id}/status_badge"
      }

      assigns = %{
        js: "testResults",
        job_id: job.id,
        json_artifacts_url: junit_json_url,
        badge_pollman: badge_pollman
      }

      case conn.assigns.authorization do
        :member ->
          assigns =
            assigns
            |> Map.put(:layout, {FrontWeb.LayoutView, "job.html"})
            |> Map.put(:user, conn.assigns.layout_model.user)
            |> put_layout_assigns(org, project, job)
            |> Front.Breadcrumbs.Job.construct(conn, :test_results)

          render(
            conn,
            "member/job.html",
            assigns
          )

        :guest ->
          assigns =
            assigns
            |> put_layout_assigns(org, project, job)
            |> Front.Breadcrumbs.Job.construct(conn, :test_results)

          render(
            conn,
            "public/job.html",
            assigns
          )
      end
    end)
  end

  def pipeline_summary(conn, _params) do
    Watchman.benchmark("pipeline.test_results.summary", fn ->
      org_id = conn.assigns.organization_id
      workflow = conn.assigns.workflow
      project = conn.assigns.project

      pipeline_id = conn.params["pipeline_id"] || workflow.root_pipeline_id
      pipeline = Pipeline.find(pipeline_id)

      fetch_organization =
        Async.run(
          fn -> Organization.find(org_id) end,
          metric: "pipeline.test_results.organization.find"
        )

      fetch_branch =
        Async.run(
          fn -> Branch.find(workflow.project_id, workflow.branch_name) end,
          metric: "pipeline.test_results.branch.find"
        )

      fetch_junit_json_url =
        Async.run(
          fn ->
            Artifacthub.signed_url(
              pipeline.project_id,
              "workflows",
              pipeline.workflow_id,
              "test-results/#{pipeline.id}.json"
            )
          end,
          metric: "pipeline.test_results.artifact.signed_url"
        )

      {:ok, org} = Async.await(fetch_organization)
      {:ok, {:ok, junit_json_url}} = Async.await(fetch_junit_json_url)
      {:ok, branch} = Async.await(fetch_branch)

      assigns = %{
        js: "testResults",
        workflow: workflow,
        branch: branch,
        json_artifacts_url: junit_json_url,
        summary_url: test_results_path(conn, :pipeline_summary, workflow.id),
        selected_pipeline_id: pipeline_id
      }

      resource_ownership_matches? =
        organization_matches?(org_id, pipeline.organization_id) &&
          workflow_matches?(workflow.id, pipeline.workflow_id)

      case {resource_ownership_matches?, conn.assigns.authorization} do
        {false, _} ->
          conn
          |> respond_with_error(:not_found)

        {true, :member} ->
          assigns =
            assigns
            |> Map.put(:layout, {FrontWeb.LayoutView, "workflow.html"})
            |> Map.put(:user, conn.assigns.layout_model.user)
            |> put_layout_assigns(org, project, pipeline)
            |> Front.Breadcrumbs.Job.construct(conn, :test_results)

          render(
            conn,
            "member/pipeline.html",
            assigns
          )

        {true, :guest} ->
          assigns =
            assigns
            |> put_layout_assigns(org, project, pipeline)
            |> Front.Breadcrumbs.Job.construct(conn, :test_results)

          render(
            conn,
            "public/pipeline.html",
            assigns
          )
      end
    end)
  end

  def details(conn, _params) do
    Watchman.benchmark("pipeline.test_results.details", fn ->
      org_id = conn.assigns.organization_id
      workflow = conn.assigns.workflow

      pipeline_id = conn.params["pipeline_id"] || workflow.root_pipeline_id
      pipeline = Pipeline.find(pipeline_id)

      resource_ownership_matches? =
        organization_matches?(org_id, pipeline.organization_id) &&
          workflow_matches?(workflow.id, pipeline.workflow_id)

      if resource_ownership_matches? do
        fetch_junit_json_url =
          Async.run(
            fn ->
              Artifacthub.signed_url(
                pipeline.project_id,
                "workflows",
                pipeline.workflow_id,
                "test-results/#{pipeline.id}.json"
              )
            end,
            metric: "pipeline.test_results.signed_url"
          )

        {:ok, {:ok, junit_json_url}} = Async.await(fetch_junit_json_url)

        json(conn, %{
          name: pipeline.name,
          artifact_url: junit_json_url,
          icon: FrontWeb.PipelineView.pipeline_status_large(pipeline)
        })
      else
        conn
        |> respond_with_error(:not_found)
      end
    end)
  end

  defp put_layout_assigns(assigns, org, project, job = %Job{}) do
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
    |> Map.put(:title, "Tests ・#{project.name}・#{org.name}")
  end

  defp put_layout_assigns(assigns, org, project, ppl = %Pipeline{}) do
    hook = RepoProxy.find(assigns.workflow.hook_id)

    assigns
    |> Map.put(:hook, hook)
    |> Map.put(:organization, org)
    |> Map.put(:workflow, assigns.workflow)
    |> Map.put(:workflow_name, hook.commit_message |> String.split("\n") |> hd)
    |> Map.put(:pipeline, ppl)
    |> Map.put(:project, project)
    |> Map.put(:showForkExplanation?, false)
    |> Map.put(:title, "Tests ・#{project.name}・#{org.name}")
  end

  defp organization_matches?(organization_id, pipeline_organization_id) do
    organization_id == pipeline_organization_id
  end

  defp workflow_matches?(workflow_id, pipeline_workflow_id) do
    workflow_id == pipeline_workflow_id
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
end
