defmodule FrontWeb.WorkflowControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.{DB, PermissionPatrol}
  import Mock

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
    test "populates sanitized agent types for workflow editor", %{
      conn: conn,
      workflow: workflow
    } do
      with_mock Front.Models.AgentType,
        list: fn _org_id -> {:ok, hosted_agent_types_fixture()} end do
        conn = conn |> get("/workflows/#{workflow.id}/edit")

        assert html_response(conn, 200)
        assert_sanitized_agent_types(conn.assigns.agent_types)
      end
    end

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

    test "redirects to project page when workflow files reference a missing branch", %{
      conn: conn,
      project: project,
      workflow: workflow
    } do
      message =
        "err: fatal: couldn't find remote ref refs/heads/#{workflow.api_model.branch_name}: exit status 128"

      GrpcMock.stub(RepositoryMock, :get_files, fn _req, _stream ->
        raise GRPC.RPCError, status: 2, message: message
      end)

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert redirected_to(conn, 302) =~ "/projects/#{project.name}"

      assert get_flash(conn, :alert) ==
               "We couldn't load workflow files because the branch \"#{workflow.api_model.branch_name}\" no longer exists."
    end

    test "redirects to project page when fetching job creation fails", %{
      conn: conn,
      organization: organization,
      project: project,
      workflow: workflow
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :wf_editor_via_jobs)

      Support.Stubs.Organization.put_settings(organization, %{
        "plan_machine_type" => "e2-standard-2",
        "plan_os_image" => "ubuntu2004"
      })

      error_user = Support.Stubs.User.create(id: "error_response")
      PermissionPatrol.allow_everything(organization.id, error_user.id)

      conn =
        conn
        |> put_req_header("x-semaphore-user-id", error_user.id)
        |> get("/workflows/#{workflow.id}/edit")

      assert redirected_to(conn, 302) =~ "/projects/#{project.name}"
      assert get_flash(conn, :alert) == "We couldn't load workflow files. Please try again."
    end

    test "returns 200 with default template and alert when no semaphore files are found", %{
      conn: conn,
      workflow: workflow
    } do
      GrpcMock.stub(RepositoryMock, :get_files, fn _req, _stream ->
        InternalApi.Repository.GetFilesResponse.new(files: [])
      end)

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 200)

      assert get_flash(conn, :alert) ==
               "We couldn't find any semaphore files for this workflow. So we are starting with an empty template."
    end

    test "redirects to project page when fetching files returns generic GRPC error", %{
      conn: conn,
      project: project,
      workflow: workflow
    } do
      GrpcMock.stub(RepositoryMock, :get_files, fn _req, _stream ->
        raise GRPC.RPCError, status: 2, message: "Internal server error"
      end)

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert redirected_to(conn, 302) =~ "/projects/#{project.name}"
      assert get_flash(conn, :alert) == "We couldn't load workflow files. Please try again."
    end

    test "redirects to project page when fetching job returns GRPC error", %{
      conn: conn,
      organization: organization,
      project: project,
      workflow: workflow
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :wf_editor_via_jobs)

      Support.Stubs.Organization.put_settings(organization, %{
        "plan_machine_type" => "e2-standard-2",
        "plan_os_image" => "ubuntu2004"
      })

      raise_user = Support.Stubs.User.create(id: "raise_response")
      PermissionPatrol.allow_everything(organization.id, raise_user.id)

      conn =
        conn
        |> put_req_header("x-semaphore-user-id", raise_user.id)
        |> get("/workflows/#{workflow.id}/edit")

      assert redirected_to(conn, 302) =~ "/projects/#{project.name}"
      assert get_flash(conn, :alert) == "We couldn't load workflow files. Please try again."
    end

    test "returns 200 without alert when workflow files are successfully fetched", %{
      conn: conn,
      workflow: workflow
    } do
      GrpcMock.stub(RepositoryMock, :get_files, fn _req, _stream ->
        InternalApi.Repository.GetFilesResponse.new(
          files: [
            InternalApi.Repository.File.new(
              path: ".semaphore/semaphore.yml",
              content: "version: v1.0\nname: Test"
            )
          ]
        )
      end)

      conn = conn |> get("/workflows/#{workflow.id}/edit")

      assert html_response(conn, 200)
      refute get_flash(conn, :alert)
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

  defp assert_sanitized_agent_types(agent_types) do
    assert %{agent_types: listed_agent_types, default_linux_os_image: default_linux_os_image} =
             agent_types

    linux_os_images =
      listed_agent_types
      |> Enum.filter(&(&1.platform == "LINUX"))
      |> Enum.map(& &1.os_image)
      |> Enum.uniq()

    refute "ubuntu1804" in linux_os_images
    refute "ubuntu2004" in linux_os_images
    assert default_linux_os_image in ["ubuntu2404", "ubuntu2204"]
    assert default_linux_os_image in linux_os_images
  end

  defp hosted_agent_types_fixture do
    %{
      agent_types: [
        %{
          type: "e1-standard-2",
          platform: "LINUX",
          specs: "2 vCPU, 4 GB RAM",
          os_image: "ubuntu2004",
          state: "ENABLED"
        },
        %{
          type: "e1-standard-2",
          platform: "LINUX",
          specs: "2 vCPU, 4 GB RAM",
          os_image: "ubuntu2204",
          state: "ENABLED"
        },
        %{
          type: "e1-standard-2",
          platform: "LINUX",
          specs: "2 vCPU, 4 GB RAM",
          os_image: "ubuntu2404",
          state: "ENABLED"
        },
        %{
          type: "a1-standard-4",
          platform: "MAC",
          specs: "4 vCPU, 8 GB RAM",
          os_image: "macos-xcode13",
          state: "ENABLED"
        }
      ],
      default_linux_os_image: "ubuntu2004",
      default_mac_os_image: "macos-xcode13"
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

  describe "map" do
    test "returns 404 when the ui_workflow_map feature is disabled", %{
      conn: conn,
      workflow: workflow
    } do
      conn = get(conn, "/workflows/#{workflow.id}/map")

      assert conn.status == 404
    end

    test "returns the workflow's pipelines", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      json =
        conn
        |> get("/workflows/#{workflow.id}/map")
        |> json_response(200)

      assert json["root_pipeline_id"] == pipeline.id

      assert [
               %{
                 "id" => id,
                 "name" => "Build & Test",
                 "parent_id" => nil,
                 "trigger" => "INITIAL_WORKFLOW",
                 "switch_id" => switch_id
               }
             ] = json["pipelines"]

      assert id == pipeline.id
      assert is_binary(switch_id)
      assert hd(json["pipelines"])["stop_url"] == "/workflows/#{workflow.id}/pipelines/#{id}/stop"
      assert hd(json["pipelines"])["rebuild_url"] == nil
    end

    test "returns 404 when the user isn't authorized", %{
      conn: conn,
      organization: organization,
      user: user,
      workflow: workflow
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(organization.id, user.id, "project.view")

      conn = get(conn, "/workflows/#{workflow.id}/map")

      assert conn.status == 404
    end

    test "serves guests of a public project", %{
      conn: conn,
      organization: organization,
      project: project,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)
      Support.Stubs.Project.switch_project_visibility(project, "public")
      PermissionPatrol.remove_all_permissions()

      json = conn |> get("/workflows/#{workflow.id}/map") |> json_response(200)
      assert hd(json["pipelines"])["stop_url"] == nil

      assert %{"pipelines" => [%{"id" => id}]} =
               conn
               |> get("/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}")
               |> json_response(200)

      assert id == pipeline.id
    end
  end

  describe "map_pipelines" do
    test "returns 404 when the ui_workflow_map feature is disabled", %{
      conn: conn,
      workflow: workflow,
      pipeline: pipeline
    } do
      conn = get(conn, "/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}")

      assert conn.status == 404
    end

    test "returns blocks with dependencies, job statuses and the requested promotions", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      assert %{"pipelines" => [json]} =
               conn
               |> get(
                 "/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}&promotions=#{pipeline.id}"
               )
               |> json_response(200)

      assert json["id"] == pipeline.id
      assert [%{"name" => "Block 1", "dependencies" => [], "jobs" => jobs}] = json["blocks"]
      assert Enum.map(jobs, & &1["name"]) == ["job 1", "job 2", "job 3"]
      assert Enum.all?(jobs, &(&1["status"] == "queued" and is_binary(&1["id"])))
      assert json["after_jobs"] == []

      assert [production, staging] = json["promotions"]
      assert {production["name"], staging["name"]} == {"production", "staging"}
      assert production["trigger_url"] =~ "/pipelines/#{pipeline.id}/swithes/"
      assert production["can_promote"]
      assert production["events"] == []
    end

    test "leaves promotions out unless they're requested", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      assert %{"pipelines" => [json]} =
               conn
               |> get("/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}")
               |> json_response(200)

      assert json["promotions"] == nil
      assert [%{"name" => "Block 1"}] = json["blocks"]
    end

    test "loads each requested pipeline once", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      assert %{"pipelines" => [%{"id" => id}]} =
               conn
               |> get(
                 "/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id},#{pipeline.id},#{pipeline.id}"
               )
               |> json_response(200)

      assert id == pipeline.id
    end

    test "leaves promotions unchanged when they can't be loaded", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)
      Application.put_env(:front, :hide_promotions, true)
      on_exit(fn -> Application.delete_env(:front, :hide_promotions) end)

      assert %{"pipelines" => [json]} =
               conn
               |> get(
                 "/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}&promotions=#{pipeline.id}"
               )
               |> json_response(200)

      assert json["promotions"] == nil
    end

    test "ignores pipelines from other workflows", %{
      conn: conn,
      organization: organization,
      workflow: workflow
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      json =
        conn
        |> get("/workflows/#{workflow.id}/map/pipelines?ids=#{Ecto.UUID.generate()}")
        |> json_response(200)

      assert json == %{"pipelines" => []}
    end

    test "returns 404 when the organization doesn't match", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      conn =
        conn
        |> put_req_header("x-semaphore-org-id", Ecto.UUID.generate())
        |> get("/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}")

      assert conn.status == 404
    end

    test "returns 404 when the user isn't authorized", %{
      conn: conn,
      organization: organization,
      user: user,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(organization.id, user.id, "project.view")

      conn = get(conn, "/workflows/#{workflow.id}/map/pipelines?ids=#{pipeline.id}")

      assert conn.status == 404
    end
  end

  describe "show with ui_workflow_map" do
    test "renders the map instead of the diagram when the feature is enabled", %{
      conn: conn,
      organization: organization,
      workflow: workflow,
      pipeline: pipeline
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      html =
        conn
        |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")
        |> html_response(200)

      assert html =~ ~s(id="workflow-map")
      assert html =~ "window.InjectedDataByBackend.WorkflowMap"
      assert html =~ "/workflows/#{workflow.id}/map"
      refute html =~ ~s(id="diagram")
      refute html =~ ~s(data-poll-href="/workflows/#{workflow.id}/status")
    end

    test "renders the diagram when the feature is disabled", %{
      conn: conn,
      workflow: workflow,
      pipeline: pipeline
    } do
      html =
        conn
        |> get("/workflows/#{workflow.id}?pipeline_id=#{pipeline.id}")
        |> html_response(200)

      assert html =~ ~s(id="diagram")
      refute html =~ ~s(id="workflow-map")
    end

    test "escapes the selected pipeline id in the injected config", %{
      conn: conn,
      organization: organization,
      workflow: workflow
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :ui_workflow_map)

      html =
        conn
        |> get("/workflows/#{workflow.id}", pipeline_id: "</script><script>alert(1)</script>")
        |> html_response(200)

      refute html =~ "</script><script>alert(1)"
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
