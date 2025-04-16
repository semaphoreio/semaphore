defmodule FrontWeb.WorkflowControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.{DB, PermissionPatrol}

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    workflow = DB.first(:workflows)
    pipeline = DB.first(:pipelines)
    project = DB.first(:projects)

    PermissionPatrol.allow_everything(organization.id, user.id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization.id)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      workflow: workflow,
      pipeline: pipeline,
      project: project
    ]
  end

  describe "edit" do
    test "returns 200 when USER_SCOPE is PUBLIC and GITHUB_REPO is PUBLIC", %{
      conn: conn,
      user: user,
      project: project,
      workflow: workflow
    } do
      Support.Stubs.Project.switch_repo_visibility(project, "public")
      Support.Stubs.User.switch_params(user, github_repositry_scope: "public")

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 200)
    end

    test "redirects to GitHub when USER_SCOPE is PUBLIC and GITHUB_REPO is PRIVATE", %{
      conn: conn,
      user: _user,
      workflow: workflow
    } do
      PermissionPatrol.remove_all_permissions()

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 404) =~ "404"
    end

    test "returns 200 when USER_SCOPE is PRIVATE and GITHUB_REPO is PUBLIC", %{
      conn: conn,
      project: project,
      workflow: workflow
    } do
      Support.Stubs.Project.switch_repo_visibility(project, "public")

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 200)
    end

    test "returns 200 when USER_SCOPE is PRIVATE and GITHUB_REPO is PRIVATE", %{
      conn: conn,
      project: project,
      workflow: workflow
    } do
      Support.Stubs.Project.switch_repo_visibility(project, "private")

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 200)
    end

    test "if fetching job feature is on, the fetching job is created", %{
      conn: conn,
      organization: organization,
      project: project,
      workflow: workflow
    } do
      Support.Stubs.Project.switch_repo_visibility(project, "private")
      Support.Stubs.Feature.enable_feature(organization.id, :wf_editor_via_jobs)

      Support.Stubs.Organization.put_settings(organization, %{
        "plan_machine_type" => "e2-standard-2",
        "plan_os_image" => "ubuntu2004"
      })

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 200)

      job = DB.first(:job_specs)

      assert job.job_spec == expected_spec(project, workflow)
    end
  end

  defp expected_spec(project, workflow) do
    %InternalApi.ServerFarm.Job.JobSpec{
      job_name:
        "Workflow editor fetching files * #{project.name} * #{workflow.api_model.branch_name}",
      agent: %InternalApi.ServerFarm.Job.JobSpec.Agent{
        machine: %InternalApi.ServerFarm.Job.JobSpec.Agent.Machine{
          type: "e2-standard-2",
          os_image: "ubuntu2004"
        },
        containers: [],
        image_pull_secrets: []
      },
      secrets: [],
      env_vars: [],
      files: [],
      commands: [
        "export SEMAPHORE_GIT_DEPTH=5",
        "export SEMAPHORE_GIT_REF_TYPE=branch",
        "export SEMAPHORE_GIT_BRANCH=#{workflow.api_model.branch_name}",
        "export SEMAPHORE_GIT_SHA=#{workflow.api_model.commit_sha}",
        "checkout",
        "artifact push job .semaphore -d .workflow_editor/.semaphore"
      ],
      epilogue_always_commands: [],
      epilogue_on_pass_commands: [],
      epilogue_on_fail_commands: [],
      priority: 95,
      execution_time_limit: 10
    }
  end

  describe "rebuild" do
    test "redirects to the new workflow", %{conn: conn, workflow: workflow} do
      conn = conn |> post("/workflows/#{workflow.id}/rebuild")

      refute get_flash(conn, :alert)
      assert redirected_to(conn, 302) =~ ~r/^(?=.*workflows)(?:(?!#{workflow.id}).)+$/
    end

    test "when resources exhausted error is received from WF API, shows error message in UI", %{
      conn: conn,
      workflow: workflow
    } do
      GrpcMock.stub(WorkflowMock, :reschedule, fn _, _ ->
        InternalApi.PlumberWF.ScheduleResponse.new(
          ppl_id: "",
          status:
            InternalApi.Status.new(
              code: 8,
              message: "Limit of queuing pipelines reached"
            ),
          wf_id: ""
        )
      end)

      conn = conn |> post("/workflows/#{workflow.id}/rebuild")

      assert redirected_to(conn, 302) =~ "/workflows/#{workflow.id}"
      assert get_flash(conn, :alert)
    end

    test "when user can't create an workflow, shows 404 page", %{
      conn: conn,
      user: user,
      organization: organization,
      workflow: workflow
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(organization.id, user.id, "project.job.rerun")

      conn = conn |> post("/workflows/#{workflow.id}/rebuild")

      assert html_response(conn, 404) =~ "404"
    end

    test "when an unpredicted error is received from WF API, raises 500", %{
      conn: conn,
      workflow: workflow
    } do
      GrpcMock.stub(WorkflowMock, :reschedule, fn _, _ ->
        InternalApi.PlumberWF.ScheduleResponse.new(
          ppl_id: "",
          status:
            InternalApi.Status.new(
              code: 3,
              message: "Test error msg"
            ),
          wf_id: ""
        )
      end)

      assert_raise(
        CaseClauseError,
        "no case clause matching: :INVALID_ARGUMENT",
        fn ->
          conn |> post("/workflows/#{workflow.id}/rebuild")
        end
      )
    end
  end

  describe "show" do
    test "when the user is authorized to view the workflow, it returns 200", %{
      conn: conn,
      workflow: workflow,
      pipeline: pipeline
    } do
      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")

      assert html_response(conn, 200) =~ workflow.api_model.commit_sha
      assert conn.status == 200
    end

    test "when the user is authorized to view the workflow, and and fork param is passed it returns 200 and renders the for and run notice",
         %{conn: conn, workflow: workflow, pipeline: pipeline} do
      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}&fork=true")

      assert conn.status == 200
      assert html_response(conn, 200) =~ workflow.api_model.commit_sha
      assert html_response(conn, 200) =~ "You’ve successfully forked the example"
    end

    test "when the branch is not present => returns 200", %{
      conn: conn,
      workflow: workflow,
      pipeline: pipeline
    } do
      DB.clear(:branches)

      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")

      assert html_response(conn, 200) =~ workflow.api_model.commit_sha
      assert conn.status == 200
    end

    test "returns 404 => when the project isn't found", %{
      conn: conn,
      workflow: workflow,
      pipeline: pipeline
    } do
      DB.clear(:projects)

      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")

      assert conn.status == 404
      assert html_response(conn, 404) =~ "Not Found"
    end

    test "returns 404 => when the workflow isn't found", %{
      conn: conn,
      workflow: workflow,
      pipeline: pipeline
    } do
      DB.clear(:workflows)

      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")

      assert conn.status == 404
      assert html_response(conn, 404) =~ "Not Found"
    end

    test "returns 404 => when the user isn't authorized", %{
      conn: conn,
      user: user,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline,
      project: _project
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(organization.id, user.id, "project.view")

      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")

      assert conn.status == 404
      assert html_response(conn, 404) =~ "Not Found"
    end

    @disabled_edit_button ~s(<button id="editWorkflow" class="btn btn-secondary" disabled>)
    test "when the user can't authorize public project => returns 200", %{
      conn: conn,
      project: project,
      user: _user,
      organization: _organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Project.switch_project_visibility(project, "public")
      PermissionPatrol.remove_all_permissions()

      conn = conn |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")

      assert conn.assigns.authorization == :guest
      assert conn.assigns.anonymous == false
      assert conn.status == 200

      assert html_response(conn, 200) =~ @disabled_edit_button
      refute html_response(conn, 200) =~ "Rerun"
      refute html_response(conn, 200) =~ "CLI"
      refute html_response(conn, 200) =~ "artifacts"
    end
  end
end
