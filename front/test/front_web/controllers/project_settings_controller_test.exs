# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.ProjectSettingsControllerTest do
  use FrontWeb.ConnCase
  import Mock
  alias Support.Stubs.{DB, Feature, PermissionPatrol}

  @raw_project_form_params %{
    project: %{name: "renamed-project"}
  }

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    org_id =
      DB.first(:organizations)
      |> Map.get(:id)

    user = DB.first(:users)
    user_id = Map.get(user, :id)

    project = DB.first(:projects)
    project_name = Map.get(project, :name)

    Feature.enable_feature(org_id, :permission_patrol)
    PermissionPatrol.allow_everything(org_id, user_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("x-semaphore-user-id", user_id)
      |> Plug.Conn.put_req_header("x-semaphore-org-id", org_id)

    [
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    ]
  end

  describe "PUT update" do
    test "when the user is not authorized to edit the project, it shows 404", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.general_settings.manage")

      conn =
        conn
        |> put(
          project_settings_path(conn, :update, project_name),
          @raw_project_form_params
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "Can't modify project withouth needed permissions", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.general_settings.manage")

      change_owner =
        conn
        |> post(project_settings_path(conn, :change_owner, project_name))

      make_private =
        conn
        |> post(project_settings_path(conn, :make_private, project_name))

      make_public =
        conn
        |> post(project_settings_path(conn, :make_private, project_name))

      assert html_response(change_owner, 404) =~ "404"
      assert html_response(make_private, 404) =~ "404"
      assert html_response(make_public, 404) =~ "404"
    end

    test "Can't modify repo withouth needed permissions", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.repository_info.manage")

      github_switch =
        conn
        |> post(project_settings_path(conn, :github_switch, project_name))

      regenerate_webhook =
        conn
        |> post(project_settings_path(conn, :regenerate_webhook, project_name))

      regenerate_deploy_key =
        conn
        |> post(project_settings_path(conn, :regenerate_deploy_key, project_name))

      assert html_response(github_switch, 404) =~ "404"
      assert html_response(regenerate_webhook, 404) =~ "404"
      assert html_response(regenerate_deploy_key, 404) =~ "404"
    end

    test "when successfull, it redirects with a notice", %{conn: conn, project_name: project_name} do
      conn =
        conn
        |> put(
          project_settings_path(conn, :update, project_name),
          @raw_project_form_params
        )

      assert get_flash(conn, :notice) == "Project has been updated."
      assert redirected_to(conn) == "/projects/renamed-project/settings/general"
    end

    test "when pipeline file unchanged, it leaves repo status",
         %{conn: conn, project_name: project_name} do
      alias InternalApi.Projecthub.Project.Spec.Repository.Status
      alias InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile
      alias InternalApi.Projecthub.ResponseMeta

      project = DB.find_by(:projects, :name, project_name)

      status =
        Status.new(
          pipeline_files: [
            PipelineFile.new(level: 1, path: ".semaphore/semaphore.yml"),
            PipelineFile.new(level: 1, path: ".semaphore/semaphore2.yml")
          ]
        )

      repository = %{project.api_model.spec.repository | status: status}
      spec = %{project.api_model.spec | repository: repository}
      api_model = %{project.api_model | spec: spec}
      project = %{project | api_model: api_model}

      DB.update(:projects, project)

      GrpcMock.expect(ProjecthubMock, :update, fn req, _ ->
        new_project = %{
          id: req.project.metadata.id,
          name: req.project.metadata.name,
          org_id: req.project.metadata.org_id,
          api_model: req.project
        }

        DB.update(:projects, new_project)

        InternalApi.Projecthub.UpdateResponse.new(
          metadata:
            ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))),
          project: req.project
        )
      end)

      conn =
        conn
        |> put(
          project_settings_path(conn, :update, project_name),
          %{project: %{initial_pipeline_file: ".semaphore/semaphore.yml"}}
        )

      assert get_flash(conn, :notice) == "Project has been updated."
      assert redirected_to(conn) == project_settings_path(conn, :general, project.name)

      updated_project = DB.find_by(:projects, :name, project.name)
      assert ^status = updated_project.api_model.spec.repository.status
    end

    test "when pipeline file changed, it modifies repo status",
         %{conn: conn, project_name: project_name} do
      alias InternalApi.Projecthub.Project.Spec.Repository.Status
      alias InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile
      alias InternalApi.Projecthub.ResponseMeta

      project = DB.find_by(:projects, :name, project_name)

      status =
        Status.new(
          pipeline_files: [
            PipelineFile.new(level: 1, path: ".semaphore/semaphore.yml"),
            PipelineFile.new(level: 1, path: ".semaphore/semaphore2.yml")
          ]
        )

      repository = %{project.api_model.spec.repository | status: status}
      spec = %{project.api_model.spec | repository: repository}
      api_model = %{project.api_model | spec: spec}
      project = %{project | api_model: api_model}

      DB.update(:projects, project)

      GrpcMock.expect(ProjecthubMock, :update, fn req, _ ->
        new_project = %{
          id: req.project.metadata.id,
          name: req.project.metadata.name,
          org_id: req.project.metadata.org_id,
          api_model: req.project
        }

        DB.update(:projects, new_project)

        InternalApi.Projecthub.UpdateResponse.new(
          metadata:
            ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))),
          project: req.project
        )
      end)

      conn =
        conn
        |> put(
          project_settings_path(conn, :update, project_name),
          %{project: %{initial_pipeline_file: ".semaphore/ci.yml"}}
        )

      assert get_flash(conn, :notice) == "Project has been updated."
      assert redirected_to(conn) == project_settings_path(conn, :general, project.name)

      updated_project = DB.find_by(:projects, :name, project.name)
      assert is_nil(updated_project.api_model.spec.repository.status)
    end

    test "when project name is invalid, changeset assign is set", %{
      conn: conn,
      project_name: project_name
    } do
      params = %{project: %{name: "with space"}}

      conn =
        conn
        |> put(
          project_settings_path(conn, :update, project_name),
          params
        )

      with %{assigns: assigns} <- conn do
        assert assigns.changeset.errors == [
                 name: {
                   "Project name can have only alphanumeric characters, underscore and dash",
                   [validation: :format]
                 }
               ]
      end
    end

    test "when the request fails, it returns 302, displays the project settings page and alerts",
         %{conn: conn, project_name: project_name} do
      conn =
        conn
        |> put(
          project_settings_path(conn, :update, project_name),
          %{
            project: %{name: "RaiseError"}
          }
        )

      assert redirected_to(conn) ==
               project_settings_path(conn, :general, project_name)

      assert get_flash(conn, :alert) == "Failed to update."
    end
  end

  describe "POST submit_delete" do
    test "when all requirments are met, it notifies and redirects to home", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(
          project_settings_path(conn, :submit_delete, project_name),
          delete_confirmation: project_name,
          reason: "Something is selected",
          feedback: "Feedback"
        )

      assert get_flash(conn, :notice) == "Project has been deleted."
      assert redirected_to(conn) == dashboard_path(conn, :index)
    end

    test "when the user is not authorized to delete the project, it redirects and shows alert", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.delete")

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(
          project_settings_path(conn, :submit_delete, project_name),
          delete_confirmation: project_name,
          reason: "Something is selected",
          feedback: "Feedback"
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is auth to delete and wrong name is typed, redirects, sets needed assigns and doesn't alert",
         %{conn: conn, project_name: project_name} do
      ## when form submission fails on form validation,
      ## - app shows form errors
      ## - app doesn't show the alert

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(
          project_settings_path(conn, :submit_delete, project_name),
          delete_confirmation: "test1",
          feedback: "Feedback"
        )

      expected_changeset = %{
        changes: %{delete_confirmation: "test1", feedback: "Feedback"},
        errors: [
          reason: "Please select reason.",
          delete_confirmation: "Name does not match."
        ],
        valid?: false
      }

      assert conn.status == 302
      assert conn.assigns.alert == nil
      assert conn.assigns.changeset == expected_changeset

      assert conn.assigns.title == "Delete Project・#{project_name}"
    end

    test "when user is auth, correct name is typed and reason is not stated it redirects and doesn't alert",
         %{conn: conn, project_name: project_name} do
      ## when form submission fails on form validation,
      ## - app shows form errors
      ## - app doesn't show the alert

      conn =
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(
          project_settings_path(conn, :submit_delete, project_name),
          delete_confirmation: project_name
        )

      expected_changeset = %{
        valid?: false,
        changes: %{delete_confirmation: project_name, feedback: "N/A"},
        errors: [
          {:feedback, "Would you mind sharing how can we improve Semaphore?"},
          reason: "Please select reason."
        ]
      }

      assert conn.assigns.alert == nil
      assert conn.assigns.changeset == expected_changeset
      assert conn.status == 302

      assert conn.assigns.title == "Delete Project・#{project_name}"
    end
  end

  describe "GET" do
    # General Settings

    test "GET general - when the user is not authorized => show correct message", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.general_settings.view")

      conn =
        conn
        |> get(project_settings_path(conn, :general, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t access Project Settings."
    end

    test "GET general - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> get(project_settings_path(conn, :general, project_name))

      assert html_response(conn, 200) =~ "Set up the project basics"
    end

    # Confirm deletion page

    test "when the user is not authorized to delete the project, it redirects and shows alert", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.delete")

      conn =
        conn
        |> get(project_settings_path(conn, :confirm_delete, project_name))

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is auth to delete and the project is found, it returns 200 and opens the delete page, header is assigned",
         %{conn: conn, project_name: project_name} do
      conn =
        conn
        |> get(project_settings_path(conn, :confirm_delete, project_name))

      assert html_response(conn, 200) =~ "Delete Project"
    end

    # Github Settings

    test "GET github - when the user is not authorized => show correct message", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.repository_info.view")

      conn =
        conn
        |> get(project_settings_path(conn, :repository, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t access Repository Settings."
    end

    test "GET github - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> get(project_settings_path(conn, :repository, project_name))

      assert html_response(conn, 200) =~ "Control how this project communicates with repository"
    end

    # Notifications Settings

    test "GET notifications - when the user is not authorized => renders 404", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.general_settings.view")

      conn =
        conn
        |> get(project_settings_path(conn, :notifications, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t access Project Settings"
    end

    test "GET notifications - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> get(project_settings_path(conn, :notifications, project_name))

      assert html_response(conn, 200) =~ "Receive notification"
    end

    # Workflow Settings

    test "GET workflow - when the user is not authorized => renders 404", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.workflow.manage")

      conn =
        conn
        |> get(project_settings_path(conn, :workflow, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t modify workflows."
    end

    test "GET workflow - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> get(project_settings_path(conn, :workflow, project_name))

      assert html_response(conn, 200) =~ "Edit pipelines and set up deployment"
    end

    # Badge Settings

    test "GET badge - when the user is not authorized => renders 404", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.general_settings.view")

      conn =
        conn
        |> get(project_settings_path(conn, :badge, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t access Project Settings."
    end

    test "GET badge - when the user is authorized => renders the page", %{
      conn: conn,
      project_name: project_name
    } do
      conn =
        conn
        |> get(project_settings_path(conn, :badge, project_name))

      assert html_response(conn, 200) =~ "Use badges in your project's README"
    end

    # Permissions Settings

    test "When org does not have feature enabled, return 404", %{
      conn: conn,
      project_name: project_name
    } do
      with_mocks([{Front.Auth, [:passthrough], [is_billing_admin?: fn _, _ -> false end]}]) do
        conn =
          conn
          |> get(project_settings_path(conn, :permissions, project_name))

        assert html_response(conn, 404) =~ "404"
      end
    end

    test "When org nas feature enabled", %{
      conn: conn,
      project_name: project_name,
      org_id: org_id
    } do
      with_mocks([{Front.Auth, [:passthrough], [is_billing_admin?: fn _, _ -> false end]}]) do
        Support.Stubs.Feature.enable_feature(org_id, :restrict_job_ssh_access)

        conn =
          conn
          |> get(project_settings_path(conn, :permissions, project_name))

        assert html_response(conn, 200) =~ "Control settings for starting"
      end
    end
  end
end
