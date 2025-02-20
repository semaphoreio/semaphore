# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.TestResultsControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    workflow_id =
      DB.first(:workflows)
      |> Map.get(:id)

    job_id =
      DB.first(:jobs)
      |> Map.get(:id)

    pipeline_id =
      DB.first(:pipelines)
      |> Map.get(:id)

    project_id =
      job_id
      |> Front.Models.Job.find()
      |> Map.get(:project_id)

    org_id =
      DB.first(:organizations)
      |> Map.get(:id)

    user_id =
      DB.first(:users)
      |> Map.get(:id)

    Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("x-semaphore-user-id", user_id)
      |> Plug.Conn.put_req_header("x-semaphore-org-id", org_id)

    [
      org_id: org_id,
      job_id: job_id,
      workflow_id: workflow_id,
      project_id: project_id,
      pipeline_id: pipeline_id,
      conn: conn
    ]
  end

  describe "GET job_summary" do
    setup context do
      job = DB.find(:jobs, context[:job_id])

      jobs =
        Front.Models.Task.describe_many([job.task_id])
        |> case do
          [%{jobs: jobs}] ->
            jobs

          _ ->
            []
        end

      jobs
      |> Enum.map(fn job ->
        job
        |> Support.Stubs.Task.add_job_artifact(
          url: "https://some/path/to/tr.json",
          path: "test-results/junit.json"
        )
      end)

      context
    end

    test "provides proper configuration for test results", %{job_id: job_id} do
      conn =
        build_conn()
        |> get(test_results_path(build_conn(), :job_summary, job_id))

      assert conn.assigns.json_artifacts_url == "https://some/path/to/tr.json"
      assert conn.assigns.js == "testResults"
      assert conn.assigns.layout == {FrontWeb.LayoutView, "job.html"}
      assert conn.private.phoenix_template == "member/job.html"

      assert html_response(conn, 200) =~ "window.InjectedDataByBackend.scope = \"job\""
    end
  end

  describe "GET pipeline_summary" do
    setup context do
      workflow = DB.find(:workflows, context[:workflow_id])

      workflow
      |> Support.Stubs.Workflow.add_artifact(
        url: "https://some/path/to/pipeline/tr.json",
        path: "test-results/#{context[:pipeline_id]}.json"
      )

      Support.Stubs.Pipeline.create_initial(workflow, organization_id: context[:org_id])
      |> then(&Support.Stubs.Pipeline.add_after_task(&1.id))

      context
    end

    test "provides proper configuration for test results", %{
      pipeline_id: _pipeline_id,
      workflow_id: workflow_id
    } do
      conn =
        build_conn()
        |> get(test_results_path(build_conn(), :pipeline_summary, workflow_id))

      assert html_response(conn, 200) =~ "window.InjectedDataByBackend.scope = \"pipeline\""

      assert conn.assigns.json_artifacts_url == "https://some/path/to/pipeline/tr.json"
      assert conn.assigns.js == "testResults"
      assert conn.assigns.layout == {FrontWeb.LayoutView, "workflow.html"}
      assert conn.private.phoenix_template == "member/pipeline.html"
    end
  end

  describe "GET details" do
    setup context do
      workflow = DB.find(:workflows, context[:workflow_id])

      workflow
      |> Support.Stubs.Workflow.add_artifact(
        url: "https://some/path/to/pipeline/tr.json",
        path: "test-results/#{context[:pipeline_id]}.json"
      )

      Support.Stubs.Pipeline.create_initial(workflow, organization_id: context[:org_id])
      |> then(&Support.Stubs.Pipeline.add_after_task(&1.id))

      context
    end

    test "returns correct data with pipeline_id", %{
      pipeline_id: pipeline_id,
      workflow_id: workflow_id
    } do
      response =
        build_conn()
        |> get(test_results_path(build_conn(), :details, workflow_id, pipeline_id))
        |> json_response(200)

      assert %{
               "artifact_url" => artifact_url,
               "icon" => icon,
               "name" => name
             } = response

      assert artifact_url == "https://some/path/to/pipeline/tr.json"

      assert icon ==
               "<div class='flex-shrink-0 f6 br2 lh-copy w3 tc white mr2 ba bg-orange'>Queuing</div>"

      assert name == "Build & Test"
    end
  end
end
