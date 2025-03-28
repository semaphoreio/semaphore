defmodule FrontWeb.ProjectControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.DB

  import Mock

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    project = DB.first(:projects)
    branch = DB.first(:branches)

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      project: project,
      branch: branch
    ]
  end

  describe "GET index" do
    test "when the user is not authorized to view the org, it renders 404", %{conn: conn} do
      conn =
        conn
        |> get(project_path(build_conn(), :index))

      assert html_response(conn, 404) =~ "404"
    end

    test "when listing projects succeeds, it returns 200, lists projects and sets necessary assigns",
         %{conn: conn, organization: organization, user: user, project: project} do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        "organization.view"
      )

      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [project.id])
      )

      conn =
        conn
        |> get(project_path(build_conn(), :index))

      assert conn.assigns.title == organization.api_model.name
      assert Enum.any?(conn.assigns.categorized_projects)

      assert html_response(conn, 200) =~ "All projects in this organization"
    end
  end

  describe "GET edit_workflow" do
    test "when project doesn't have branches, it redirects to the onboarding template page",
         %{conn: conn, project: project, organization: organization, user: user} do
      DB.clear(:workflows)
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      conn =
        conn
        |> get("/projects/#{project.name}/edit_workflow")

      assert html_response(conn, 200) =~ "workflow-editor-tabs"
    end
  end

  describe "GET show" do
    test "when the user can't authorize private project => returns 404", %{
      conn: conn,
      user: _user,
      organization: _organization,
      project: project
    } do
      conn =
        conn
        |> get("/projects/#{project.name}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user can't authorize public project => returns 200", %{
      conn: conn,
      user: _user,
      organization: _organization,
      project: project
    } do
      Support.Stubs.Project.switch_project_visibility(project, "public")

      conn =
        conn
        |> get("/projects/#{project.name}")

      assert conn.assigns.authorization == :guest
      assert conn.assigns.anonymous == false
      refute conn.assigns[:layout_model]

      assert html_response(conn, 200) =~ "Blazing-fast build and deploy!"
      assert html_response(conn, 200) =~ project.name
    end

    test "when the project doesn't exist => returns 404", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      conn =
        conn
        |> get("/projects/foo_bar")

      assert html_response(conn, 404) =~ "404"
    end

    test "when there are no workflows => returns 200", %{
      conn: conn,
      organization: organization,
      user: user,
      project: project
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        project.id,
        "project.view"
      )

      DB.clear(:workflows)

      conn =
        conn
        |> get("/projects/#{project.name}?force_cold_boot=true")

      assert html_response(conn, 200) =~ "Anything to add"
    end
  end

  describe "GET filtered_branches" do
    test "when everything is ok => renders the template", %{
      conn: conn,
      organization: organization,
      user: user,
      project: project,
      branch: branch
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        project.id,
        "project.view"
      )

      conn =
        conn
        |> get("/projects/#{project.name}/filtered_branches?name_contains=master")

      assert json_response(conn, 200) == [
               %{
                 "id" => branch.id,
                 "type" => "branch",
                 "display_name" => branch.api_model.name,
                 "html_url" => "/branches/#{branch.id}"
               }
             ]
    end
  end

  describe "GET workflows" do
    setup %{project: project, organization: organization, user: user} = ctx do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        project.id,
        "project.view"
      )

      ctx
    end

    test "when user is not authenticated, but has 'requester' param, ignore it", %{
      conn: conn,
      project: project
    } do
      Support.Stubs.Project.switch_project_visibility(project, "public")

      conn =
        conn
        |> put_req_header("x-semaphore-user-anonymous", "true")
        |> delete_req_header("x-semaphore-user-id")
        |> get("/projects/#{project.name}/workflows?requester=true")

      assert html_response(conn, 200)
    end

    test "returns 200 when there are workflows", %{conn: conn, project: project} do
      conn =
        conn
        |> get("/projects/#{project.name}/workflows")

      assert html_response(conn, 200)
    end

    test "returns 200 when there are no workflows", %{conn: conn, project: project} do
      DB.clear(:workflows)

      conn =
        conn
        |> get("/projects/#{project.name}/workflows")

      assert html_response(conn, 200)
    end
  end

  describe "GET check_commit_job" do
    test "returns commit_sha read from artifacts if the job has passed",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job = Support.Stubs.DB.first(:jobs)
      Support.Stubs.Task.change_job_state(job, :finished, :passed)

      params = [
        path: ".workflow_editor/commit_sha.val",
        scope: "jobs",
        url: "https://localhost:9000/commit_sha.val"
      ]

      Support.Stubs.Artifacthub.create(job.id, params)

      with_mock HTTPoison, get: fn url -> mocked_get_file(url) end do
        conn =
          conn
          |> get("/projects/#{project.name}/check_commit_job?job_id=#{job.id}")

        assert response = json_response(conn, 200)
        assert response["commit_sha"] == "commit_sha_1"
      end
    end

    defp mocked_get_file(url) do
      if url == "https://localhost:9000/commit_sha.val" do
        {:ok, %{status_code: 200, body: "commit_sha_1"}}
      else
        {:ok, %{status_code: 404, body: "Invalid url"}}
      end
    end

    test "returns error if job can not be found",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job_id = UUID.uuid4()

      conn =
        conn
        |> get("/projects/#{project.name}/check_commit_job?job_id=#{job_id}")

      assert response = json_response(conn, 422)

      message = "Failed to commit changes to git repository."
      message = message <> " Please, contact support."
      assert response["error"] == message
    end

    test "returns error if commit job fails",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job = Support.Stubs.DB.first(:jobs)
      Support.Stubs.Task.change_job_state(job, :finished, :failed)

      conn =
        conn
        |> get("/projects/#{project.name}/check_commit_job?job_id=#{job.id}")

      assert response = json_response(conn, 422)

      message = "Failed to commit changes to git repository."
      message = message <> " Please, contact support."
      assert response["error"] == message
    end

    test "if job is still running, returns empty string as a commit_sha",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job = Support.Stubs.DB.first(:jobs)
      Support.Stubs.Task.change_job_state(job, :running)

      conn =
        conn
        |> get("/projects/#{project.name}/check_commit_job?job_id=#{job.id}")

      assert response = json_response(conn, 200)
      assert response["commit_sha"] == ""
    end
  end

  describe "GET fetch_yaml_artifacts" do
    test "returns signed URLs to artifacts if the job has passed",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job = Support.Stubs.DB.first(:jobs)
      Support.Stubs.Task.change_job_state(job, :finished, :passed)

      Support.Stubs.Artifacthub.create(job.id,
        path: ".workflow_editor/.semaphore/semaphore.yml",
        scope: "jobs",
        url: "https://localhost:9000/.workflow_editor/.semaphore/semaphore.yml"
      )

      Support.Stubs.Artifacthub.create(job.id,
        path: ".workflow_editor/.semaphore/release.yml",
        scope: "jobs",
        url: "https://localhost:9000/.workflow_editor/.semaphore/release.yml"
      )

      conn =
        conn
        |> get("/projects/#{project.name}/fetch_yaml_artifacts?job_id=#{job.id}")

      assert response = json_response(conn, 200)

      assert response["signed_urls"] == [
               "https://localhost:9000/.workflow_editor/.semaphore/semaphore.yml",
               "https://localhost:9000/.workflow_editor/.semaphore/release.yml"
             ]
    end

    test "returns error if job can not be found",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job_id = UUID.uuid4()

      conn =
        conn
        |> get("/projects/#{project.name}/fetch_yaml_artifacts?job_id=#{job_id}")

      assert response = json_response(conn, 422)

      message = "Failed to fetch Semaphore YAML files from the git repository."
      message = message <> " Please, contact support."
      assert response["error"] == message
    end

    test "returns error if fetch yaml job fails",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job = Support.Stubs.DB.first(:jobs)
      Support.Stubs.Task.change_job_state(job, :finished, :failed)

      conn =
        conn
        |> get("/projects/#{project.name}/fetch_yaml_artifacts?job_id=#{job.id}")

      assert response = json_response(conn, 422)

      message = "Failed to fetch Semaphore YAML files from the git repository."
      message = message <> " Please, contact support."
      assert response["error"] == message
    end

    test "if job is still running, return empty list of signed URLs",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      job = Support.Stubs.DB.first(:jobs)
      Support.Stubs.Task.change_job_state(job, :running)

      conn =
        conn
        |> get("/projects/#{project.name}/fetch_yaml_artifacts?job_id=#{job.id}")

      assert response = json_response(conn, 200)
      assert response["signed_urls"] == []
    end
  end

  describe "POST commit_config" do
    test "if commit via job feature is on the commit job is created",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)
      Support.Stubs.Feature.enable_feature(organization.id, :wf_editor_via_jobs)

      Support.Stubs.Organization.put_settings(organization, %{
        "plan_machine_type" => "e2-standard-2",
        "plan_os_image" => "ubuntu2004"
      })

      parameters = %{
        "branch" => "new-branch",
        "commit_message" => "Update Semaphore configuration",
        "initial_branch" => "master",
        "target_branch" => "new-branch",
        "modified_files" => [
          %Plug.Upload{
            filename: ".semaphore/semaphore.yml",
            path: "test/fixture/yamls/saas/semaphore.yml",
            content_type: "text/yaml"
          },
          %Plug.Upload{
            filename: ".semaphore/deploy.yml",
            path: "test/fixture/yamls/saas/deploy.yml",
            content_type: "text/yaml"
          }
        ],
        "deleted_files" => [
          %Plug.Upload{
            filename: ".semaphore/staging.yml",
            path: "test/fixture/yamls/saas/staging.yml",
            content_type: "text/yaml"
          }
        ]
      }

      conn =
        conn
        |> post("/projects/#{project.name}/commit_config", parameters)

      assert response = json_response(conn, 201)
      assert response["branch"] == "new-branch"
      assert response["message"] == "Commiting changes to git repository."
      assert response["wait"] == true
      assert response["job_id"] != ""
      assert response["commit_sha"] == ""

      job_id = response["job_id"]

      record = DB.find(:job_specs, job_id)
      assert record.job_spec == expected_spec()

      Support.Stubs.Feature.disable_feature(project.org_id, :wf_editor_via_jobs)
    end

    test "if commit via job feature is off the commit is created via repohub",
         %{conn: conn, project: project, organization: organization, user: user} do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)
      Support.Stubs.Feature.disable_feature(project.org_id, :wf_editor_via_jobs)

      parameters = %{
        "branch" => "new-branch",
        "commit_message" => "Update Semaphore configuration",
        "modified_files" => [
          %Plug.Upload{
            filename: ".semaphore/semaphore.yml",
            path: "test/fixture/yamls/saas/semaphore.yml",
            content_type: "text/yaml"
          },
          %Plug.Upload{
            filename: ".semaphore/deploy.yml",
            path: "test/fixture/yamls/saas/deploy.yml",
            content_type: "text/yaml"
          }
        ],
        "deleted_files" => [
          %Plug.Upload{
            filename: ".semaphore/staging.yml",
            path: "test/fixture/yamls/saas/staging.yml",
            content_type: "text/yaml"
          }
        ]
      }

      conn =
        conn
        |> post("/projects/#{project.name}/commit_config", parameters)

      assert response = json_response(conn, 201)
      assert response["branch"] == "new-branch"
      assert response["message"] == "Config committed. Waiting for Workflow to start."
      assert response["wait"] == true
      assert response["job_id"] == ""
      assert response["commit_sha"] != ""
    end
  end

  defp expected_spec do
    %InternalApi.ServerFarm.Job.JobSpec{
      job_name: "Commiting changes from workflow editor to branch new-branch",
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
      files: [
        %InternalApi.ServerFarm.Job.JobSpec.File{
          path: ".workflow_editor/git_username.txt",
          content: "eC1vYXV0aC10b2tlbg=="
        },
        %InternalApi.ServerFarm.Job.JobSpec.File{
          path: ".workflow_editor/git_password.txt",
          content: "dmFsaWRfdG9rZW5fdmFsdWU="
        },
        %InternalApi.ServerFarm.Job.JobSpec.File{
          path: ".changed_files/.semaphore/semaphore.yml",
          content: File.read!("test/fixture/yamls/saas/semaphore.yml") |> Base.encode64()
        },
        %InternalApi.ServerFarm.Job.JobSpec.File{
          path: ".changed_files/.semaphore/deploy.yml",
          content: File.read!("test/fixture/yamls/saas/deploy.yml") |> Base.encode64()
        }
      ],
      commands: [
        "export GIT_USERNAME=$(cat .workflow_editor/git_username.txt)",
        "export GIT_PASSWORD=$(cat .workflow_editor/git_password.txt)",
        "export GIT_REPO_URL=\"${SEMAPHORE_GIT_URL/://}\"",
        "export GIT_REPO_URL=\"${GIT_REPO_URL/git@/https:\/\/$GIT_USERNAME:$GIT_PASSWORD@}\"",
        "export SEMAPHORE_GIT_BRANCH=master",
        "checkout",
        "git checkout -b new-branch",
        "mv ../.changed_files/.semaphore/semaphore.yml ./.semaphore/semaphore.yml",
        "mv ../.changed_files/.semaphore/deploy.yml ./.semaphore/deploy.yml",
        "rm .semaphore/staging.yml || true",
        "git config --global user.name Test Test the 3rd",
        "git config --global user.email jane.doe@example.com",
        "git add .",
        "git commit -m \"Update Semaphore configuration\"",
        "git push $GIT_REPO_URL HEAD",
        "git rev-parse HEAD > commit_sha.val",
        "artifact push job commit_sha.val -d .workflow_editor/commit_sha.val"
      ],
      epilogue_always_commands: [],
      epilogue_on_pass_commands: [],
      epilogue_on_fail_commands: [],
      priority: 95,
      execution_time_limit: 10
    }
  end
end
