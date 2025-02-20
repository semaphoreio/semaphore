defmodule FrontWeb.SchedulersControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.{DB, PermissionPatrol}

  import Mock

  @raw_scheduler_form_params %{
    at: "1 12,00 * * *",
    branch: "master",
    id: "888ea187-ssss-4f41-879d-a30a96faa01e",
    name: "first-scheduler",
    project_name_or_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
    pipeline_file: ".semaphore/semaphore.yml",
    recurring: true,
    parameters: %{
      "0" => %{
        "name" => "param1",
        "description" => "param1 description",
        "default_value" => "param1 default value",
        "options" => "foo
        bar",
        "required" => true
      },
      "1" => %{
        "name" => "param2",
        "description" => "param2 description",
        "default_value" => "",
        "options" => "",
        "required" => false
      }
    }
  }

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    org = Support.Stubs.Organization.default()
    user = Support.Stubs.User.default()

    PermissionPatrol.allow_everything(org.id, user.id)

    project = DB.first(:projects)
    project_name = Map.get(project, :name)

    other_project = Support.Stubs.Project.create(org, user, name: "test", run_on: ["branches"])
    other_project_name = Map.get(other_project, :name)

    scheduler = Support.Stubs.Scheduler.create(project, user)
    scheduler_id = Map.get(scheduler, :id)

    conn =
      conn
      |> Plug.Conn.put_req_header("x-semaphore-user-id", user.id)
      |> Plug.Conn.put_req_header("x-semaphore-org-id", org.id)
      |> Plug.Conn.assign(:project, project)

    [
      org_id: org.id,
      user_id: user.id,
      scheduler_id: scheduler_id,
      project_name: project_name,
      other_project_name: other_project_name,
      conn: conn
    ]
  end

  describe "GET index" do
    test "when the user is not authorized to update project, it renders 404", %{
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.view")

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :index, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t access Project Tasks"
    end

    test "it shows the schedulers", %{project_name: project_name} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :index, project_name))

      assert html_response(conn, 200) =~ "Scheduler"
      refute html_response(conn, 200) =~ "No active Tasks"
      refute html_response(conn, 200) =~ "Blazing-fast build and deploy!"
    end

    test "whent there are no schedulers for a project, it shows empty page", %{
      project_name: project_name,
      scheduler_id: scheduler_id
    } do
      DB.delete(:schedulers, scheduler_id)
      DB.delete(:triggers, scheduler_id)

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :index, project_name))

      assert html_response(conn, 200) =~ "No active Tasks"
      refute html_response(conn, 200) =~ "Blazing-fast build and deploy!"
    end

    test "when there is more than ten schedulers for a project, it paginates", _ctx do
      user = DB.first(:users)
      project = DB.first(:projects)

      for i <- 1..15 do
        Support.Stubs.Scheduler.create(project, user, name: "Scheduler #{i}")
      end

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :index, project.name))

      refute html_response(conn, 200) =~ "No active Tasks"
      assert html_response(conn, 200) =~ "schedulers?page=1"
      assert html_response(conn, 200) =~ "schedulers?page=2"

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :index, project.name, page: 2))

      refute html_response(conn, 200) =~ "No active Tasks"
      assert html_response(conn, 200) =~ "schedulers?page=1"
      assert html_response(conn, 200) =~ "schedulers?page=2"
    end

    test "when there is search string in the query params, it filters", _ctx do
      user = DB.first(:users)
      project = DB.first(:projects)

      for i <- 1..15 do
        Support.Stubs.Scheduler.create(project, user, name: "Scheduler #{i}")
      end

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :index, project.name, search: "1"))

      refute html_response(conn, 200) =~ "No active Tasks"

      refute html_response(conn, 200) =~ "Scheduler 2"
      refute html_response(conn, 200) =~ "Scheduler 3"
      refute html_response(conn, 200) =~ "Scheduler 4"

      assert html_response(conn, 200) =~ "Scheduler 12"
      assert html_response(conn, 200) =~ "Scheduler 13"
      assert html_response(conn, 200) =~ "Scheduler 14"
    end
  end

  describe "POST activate" do
    test "when project is not found, it renders 404", %{scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :activate, "foo", scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :activate, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is found, user is not authorized to edit scheduler, it redirects to index and flashes error message",
         %{
           project_name: project_name,
           scheduler_id: scheduler_id,
           org_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")

      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :activate, project_name, scheduler_id))

      assert redirected_to(conn) == schedulers_path(conn, :index, project_name)

      expected_msg =
        "You are not allowed to activate the scheduler. " <>
          "Please reach out to support if you think this is a mistake."

      assert get_flash(conn, :alert) == expected_msg
      refute html_response(conn, 302) =~ "Blazing-fast build and deploy!"
    end

    test "when scheduler is not found then renders 404",
         %{project_name: project_name} do
      conn =
        build_conn()
        |> post(
          schedulers_path(
            build_conn(),
            :activate,
            project_name,
            "78114608-be8a-465a-b9cd-81970fb802c"
          )
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is found, user is authorized to edit scheduler, activation passes, it redirects to index and flashes success message",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :activate, project_name, scheduler_id))

      assert redirected_to(conn) == schedulers_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Scheduler activated."
      refute html_response(conn, 302) =~ "Blazing-fast build and deploy!"
    end
  end

  describe "POST deactivate" do
    test "when project is not found, it renders 404", %{scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :deactivate, "foo", scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :deactivate, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is found, user is not authorized to edit scheduler, it redirects to index and flashes error message",
         %{
           project_name: project_name,
           scheduler_id: scheduler_id,
           org_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")

      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :deactivate, project_name, scheduler_id))

      assert redirected_to(conn) == schedulers_path(conn, :index, project_name)

      expected_msg =
        "You are not allowed to deactivate the scheduler. " <>
          "Please reach out to support if you think this is a mistake."

      assert get_flash(conn, :alert) == expected_msg
      refute html_response(conn, 302) =~ "Blazing-fast build and deploy!"
    end

    test "when scheduler is not found then renders 404",
         %{project_name: project_name} do
      conn =
        build_conn()
        |> post(
          schedulers_path(
            build_conn(),
            :deactivate,
            project_name,
            "78114608-be8a-465a-b9cd-81970fb802c"
          )
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is found, user is authorized to edit scheduler, deactivation passes, it redirects to index and flashes success message",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(schedulers_path(build_conn(), :deactivate, project_name, scheduler_id))

      assert redirected_to(conn) == schedulers_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Scheduler deactivated."
      refute html_response(conn, 302) =~ "Blazing-fast build and deploy!"
    end
  end

  describe "GET new" do
    test "when the user is not authorized to update project, it show a message", %{
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :new, project_name))

      assert html_response(conn, 200) =~ "Sorry, you can’t modify Tasks."
    end

    test "it shows the scheduler form", %{project_name: project_name} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :new, project_name))

      assert html_response(conn, 200) =~ "Create"
      refute html_response(conn, 200) =~ "Blazing-fast build and deploy!"
    end
  end

  describe "GET show" do
    test "when the user is not authorized to see history, it shows a message",
         %{
           conn: conn,
           project_name: project_name,
           scheduler_id: scheduler_id,
           org_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.view")

      path = schedulers_path(conn, :show, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "Sorry, you can’t access Tasks"
    end

    test "it shows the scheduler history",
         %{conn: conn, project_name: project_name, scheduler_id: scheduler_id} do
      path = schedulers_path(conn, :show, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "Task History"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :show, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "is shows scheduler history entries",
         %{conn: conn, project_name: project_name, scheduler_id: scheduler_id} do
      scheduler = DB.find(:schedulers, scheduler_id)
      workflow = DB.first(:workflows)
      user = DB.first(:users)

      Support.Stubs.Scheduler.create_trigger(
        scheduler.api_model,
        workflow.api_model,
        user
      )

      path = schedulers_path(conn, :show, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "Task History"
      assert html_response(conn, 200) =~ workflow.api_model.branch_name
      assert html_response(conn, 200) =~ String.slice(workflow.api_model.commit_sha, 0..6)
    end
  end

  describe "GET latest_trigger" do
    test "when the user is not authorized to see latest trigger, it renders 404",
         %{
           conn: conn,
           project_name: project_name,
           scheduler_id: scheduler_id,
           org_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.view")

      path = schedulers_path(conn, :latest, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 404) =~ "404"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :latest, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "it shows the miscarried trigger view when latest trigger is missing",
         %{conn: conn, project_name: project_name, scheduler_id: scheduler_id} do
      path = schedulers_path(conn, :latest, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "Waiting for your first task execution."
    end

    test "is shows scheduler latest trigger",
         %{conn: conn, project_name: project_name, scheduler_id: scheduler_id} do
      scheduler = DB.find(:schedulers, scheduler_id)
      workflow = DB.first(:workflows)
      user = DB.first(:users)

      Support.Stubs.Scheduler.create_trigger(
        scheduler.api_model,
        workflow.api_model,
        user
      )

      path = schedulers_path(conn, :latest, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "data-poll-state=\"poll\""
      assert html_response(conn, 200) =~ workflow.api_model.branch_name
      assert html_response(conn, 200) =~ String.slice(workflow.api_model.commit_sha, 0..6)
    end
  end

  describe "GET expression" do
    test "it checks the scheduler history",
         %{conn: conn, project_name: project_name} do
      path = schedulers_path(conn, :expression, project_name, expression: "1 12,00 * * *")
      conn = get(conn, path)

      assert json_response(conn, 200) == %{"expression" => "1 12,0 * * *"}
    end
  end

  describe "GET history" do
    test "when the user is not authorized to see history, it renders 404",
         %{
           conn: conn,
           project_name: project_name,
           scheduler_id: scheduler_id,
           org_id: org_id,
           user_id: user_id
         } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.view")

      path = schedulers_path(conn, :history, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 404) =~ "404"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :history, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "it shows the scheduler history",
         %{conn: conn, project_name: project_name, scheduler_id: scheduler_id} do
      path = schedulers_path(conn, :history, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "We didn't find any workflows matching your criteria."
    end

    test "is shows scheduler history entries",
         %{conn: conn, project_name: project_name, scheduler_id: scheduler_id} do
      scheduler = DB.find(:schedulers, scheduler_id)
      workflow = DB.first(:workflows)
      user = DB.first(:users)

      Support.Stubs.Scheduler.create_trigger(
        scheduler.api_model,
        workflow.api_model,
        user
      )

      path = schedulers_path(conn, :history, project_name, scheduler_id)
      conn = get(conn, path)

      assert html_response(conn, 200) =~ "data-poll-state=\"poll\""
      assert html_response(conn, 200) =~ workflow.api_model.branch_name
      assert html_response(conn, 200) =~ String.slice(workflow.api_model.commit_sha, 0..6)
    end
  end

  describe "POST create" do
    test "when project is found, user is not authorized to create scheduler, it returns 422", %{
      project_name: project_name,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")

      conn =
        build_conn()
        |> post(
          schedulers_path(build_conn(), :create, project_name),
          @raw_scheduler_form_params
        )

      assert html_response(conn, 422) =~
               "You are not allowed to create the scheduler. Please reach out to support if you think this is a mistake."
    end

    test "when project is found, user is authorized to edit it and apply request passes, it returns 302 and redirects to schedulers",
         %{project_name: project_name} do
      conn =
        build_conn()
        |> post(
          schedulers_path(build_conn(), :create, project_name),
          @raw_scheduler_form_params
        )

      assert redirected_to(conn) == schedulers_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Schedule created."
      refute html_response(conn, 302) =~ "Blazing-fast build and deploy!"
    end

    test "when apply request fails with an error, it returns 422, displays the new scheduler page with entered params and alerts",
         %{project_name: project_name} do
      with_mocks([
        {
          Front.Models.Scheduler,
          [:passthrough],
          [persist: fn _, _ -> {:error, :grpc_req_failed} end]
        }
      ]) do
        conn =
          build_conn()
          |> post(
            schedulers_path(build_conn(), :create, project_name),
            @raw_scheduler_form_params
          )

        assert html_response(conn, 422) =~ @raw_scheduler_form_params[:name]

        assert html_response(conn, 422) =~
                 "Failed to create the scheduler. Please try again later."

        refute html_response(conn, 422) =~ "Blazing-fast build and deploy!"
      end
    end

    test "when params don't meet UI side validation criteria, it returns 422, displays the new scheduler page with user-provided params and alerts",
         %{project_name: project_name} do
      changeset = %{
        errors: [
          branch: "Required. Cannot be empty.",
          pipeline_file: "Required. Cannot be empty.",
          at: "Required. Cannot be empty."
        ],
        valid?: false
      }

      with_mocks([
        {
          Front.Models.Scheduler,
          [:passthrough],
          [persist: fn _, _ -> {:error, changeset} end]
        }
      ]) do
        conn =
          build_conn()
          |> post(
            schedulers_path(build_conn(), :create, project_name),
            @raw_scheduler_form_params
          )

        assert html_response(conn, 422) =~ @raw_scheduler_form_params[:name]
        assert html_response(conn, 422) =~ "Failed to create the scheduler."
        refute html_response(conn, 422) =~ "Blazing-fast build and deploy!"
      end
    end

    test "when params don't meet periodic service side validation criteria, it returns 422, displays the new scheduler page with user-provided params and alerts",
         %{project_name: project_name} do
      with_mocks([
        {
          Front.Models.Scheduler,
          [:passthrough],
          [persist: fn _, _ -> {:error, %{errors: %{branch: "Error about the branch"}}} end]
        }
      ]) do
        conn =
          build_conn()
          |> post(
            schedulers_path(build_conn(), :create, project_name),
            @raw_scheduler_form_params
          )

        assert html_response(conn, 422) =~ @raw_scheduler_form_params[:name]
        assert html_response(conn, 422) =~ "Failed to create the scheduler."
        refute html_response(conn, 422) =~ "Blazing-fast build and deploy!"
      end
    end
  end

  describe "GET edit" do
    test "when the user is not authorized to edit project, it renders 404", %{
      project_name: project_name,
      scheduler_id: scheduler_id,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")

      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :edit, project_name, scheduler_id))

      assert html_response(conn, 200) =~ "Sorry, you can’t modify Tasks"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :edit, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is found and user is authorized to edit it, it returns 200 and displays the page data",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :edit, project_name, scheduler_id))

      assert html_response(conn, 200) =~ "Name of the target"
      refute html_response(conn, 200) =~ "Blazing-fast build and deploy!"
    end

    test "when the scheduler is not found, it renders 404", %{project_name: project_name} do
      conn =
        build_conn()
        |> get(
          schedulers_path(
            build_conn(),
            :edit,
            project_name,
            "78114608-be8a-465a-b9cd-81970fb802c"
          )
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is not found, it renders 404", %{scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :edit, "foo", scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "PUT update" do
    def build_update_scheduler_conn(scheduler_id, project_name) do
      build_conn()
      |> put(
        schedulers_path(build_conn(), :update, project_name, scheduler_id),
        @raw_scheduler_form_params
      )
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> put(
          schedulers_path(build_conn(), :update, project_name, scheduler_id),
          @raw_scheduler_form_params
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when project is found, user is not authorized to update scheduler, it returns 422", %{
      project_name: project_name,
      scheduler_id: scheduler_id,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")

      conn =
        build_conn()
        |> put(
          schedulers_path(build_conn(), :update, project_name, scheduler_id),
          @raw_scheduler_form_params
        )

      assert html_response(conn, 422) =~
               "You are not allowed to update the scheduler. Please reach out to support if you think this is a mistake."
    end

    test "when project is found and user is authorized to edit it, it redirects to project settings page",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> put(
          schedulers_path(build_conn(), :update, project_name, scheduler_id),
          @raw_scheduler_form_params
        )

      assert redirected_to(conn) == schedulers_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Schedule updated."
      refute html_response(conn, 302) =~ "Blazing-fast build and deploy!"
    end

    test "when the periodic service side validation fails for apply request, it returns 422, displays the edit scheduler page and alerts",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      with_mocks([
        {
          Front.Models.Scheduler,
          [:passthrough],
          [
            persist: fn _, _ ->
              {:error, %{errors: %{name: "Form error about the name field"}}}
            end
          ]
        }
      ]) do
        conn =
          build_conn()
          |> put(
            schedulers_path(build_conn(), :update, project_name, scheduler_id),
            @raw_scheduler_form_params
          )

        assert html_response(conn, 422) =~ @raw_scheduler_form_params[:name]
        assert html_response(conn, 422) =~ "Failed to update the scheduler."
        refute html_response(conn, 422) =~ "Blazing-fast build and deploy!"
      end
    end

    test "when apply request fails, it returns 422, displays the scheduler form with entered params and alerts",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      with_mocks([
        {
          Front.Models.Scheduler,
          [:passthrough],
          [persist: fn _, _ -> {:error, :grpc_req_failed} end]
        }
      ]) do
        conn =
          build_conn()
          |> put(
            schedulers_path(build_conn(), :update, project_name, scheduler_id),
            @raw_scheduler_form_params
          )

        assert html_response(conn, 422) =~ @raw_scheduler_form_params[:name]

        assert html_response(conn, 422) =~
                 "Failed to update the scheduler. Please try again later."

        refute html_response(conn, 422) =~ "Blazing-fast build and deploy!"
      end
    end

    test "when params don't meet UI side validation criteria, it returns 422, displays the new scheduler page with user-provided params and alerts",
         %{project_name: project_name, scheduler_id: scheduler_id} do
      changeset = %{
        errors: [
          branch: "Required. Cannot be empty.",
          pipeline_file: "Required. Cannot be empty.",
          at: "Required. Cannot be empty."
        ],
        valid?: false
      }

      with_mocks([
        {
          Front.Models.Scheduler,
          [:passthrough],
          [persist: fn _, _ -> {:error, changeset} end]
        }
      ]) do
        conn =
          build_conn()
          |> put(
            schedulers_path(build_conn(), :update, project_name, scheduler_id),
            @raw_scheduler_form_params
          )

        assert html_response(conn, 422) =~ @raw_scheduler_form_params[:name]
        assert html_response(conn, 422) =~ "Failed to update the scheduler."
        refute html_response(conn, 422) =~ "Blazing-fast build and deploy!"
      end
    end
  end

  describe "GET /just_run" do
    test "when user is not authorized it renders 404", %{
      conn: conn,
      org_id: org_id,
      user_id: user_id
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")
      scheduler = prepare_scheduler_for_just_run()

      conn = form_just_run(conn, scheduler)
      assert html_response(conn, 200) =~ "Sorry, you can’t manually run Tasks"
    end

    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> get(schedulers_path(build_conn(), :form_just_run, project_name, scheduler_id))

      assert html_response(conn, 404) =~ "404"
    end

    test "when scheduler is not found it renders 404", %{conn: conn} do
      scheduler = prepare_scheduler_for_just_run()

      conn = form_just_run(conn, %{scheduler | id: UUID.uuid4()})
      assert html_response(conn, 404) =~ "404"
    end

    test "correctly renders form with default values", %{conn: conn} do
      scheduler =
        prepare_scheduler_for_just_run(
          branch: "develop",
          pipeline_file: "pipeline.yml",
          parameters: [
            %{name: "PARAM1", default_value: "VALUE11"},
            %{name: "PARAM2", options: ["VALUE21", "VALUE22"]},
            %{name: "PARAM3", options: ["VALUE31", "VALUE32"], default_value: "VALUE31"},
            %{name: "PARAM4", options: ["VALUE41", "VALUE42"], default_value: "VALUE43"}
          ]
        )

      conn = form_just_run(conn, scheduler)

      # imports default values
      assert html_response(conn, 200) =~ "value=\"develop\""
      assert html_response(conn, 200) =~ "value=\"pipeline.yml\""

      # displays default values for parameters
      assert html_response(conn, 200) =~ "value=\"VALUE11\""
      assert html_response(conn, 200) =~ "<option selected value=\"VALUE31\">VALUE31</option>"
      assert html_response(conn, 200) =~ "<option selected value=\"VALUE43\">VALUE43</option>"

      # displays prompt and options for parameters
      assert html_response(conn, 200) =~ "<option value=\"\">Choose PARAM2 value</option>"
      refute html_response(conn, 200) =~ "<option selected value=\"VALUE21\">VALUE21</option>"
      refute html_response(conn, 200) =~ "<option selected value=\"VALUE22\">VALUE22</option>"
    end

    test "correctly renders form without default values and without parameters", %{conn: conn} do
      scheduler = prepare_scheduler_for_just_run()

      conn = form_just_run(conn, scheduler)

      # imports default values
      assert html_response(conn, 200) =~
               "placeholder=\"Enter a branch…\" type=\"text\" value=\"\""

      assert html_response(conn, 200) =~
               "placeholder=\"e.g. .semaphore/semaphore.yml\" type=\"text\" value=\"\""
    end

    test "overrides default values with query parameters", %{conn: conn} do
      scheduler =
        prepare_scheduler_for_just_run(
          branch: "master",
          parameters: [
            %{name: "PARAM1", default_value: "VALUE11"},
            %{name: "PARAM2", options: ["VALUE21", "VALUE22"]},
            %{name: "PARAM3"},
            %{name: "PARAM4", options: ["VALUE41", "VALUE42"], default_value: "VALUE41"}
          ]
        )

      conn =
        form_just_run(conn, scheduler, %{
          "branch" => "develop",
          "pipeline_file" => ".semaphore/semaphore.yml",
          "parameters" => %{
            "PARAM1" => "VALUE12",
            "PARAM2" => "VALUE22",
            "PARAM3" => "VALUE31"
          }
        })

      # imports default values
      assert html_response(conn, 200) =~
               "placeholder=\"Enter a branch…\" type=\"text\" value=\"develop\""

      assert html_response(conn, 200) =~
               "placeholder=\"e.g. .semaphore/semaphore.yml\" type=\"text\" value=\".semaphore/semaphore.yml\""

      assert html_response(conn, 200) =~ "Parameters"
      assert html_response(conn, 200) =~ "value=\"VALUE12\""
      assert html_response(conn, 200) =~ "value=\"VALUE31\""
      assert html_response(conn, 200) =~ "<option selected value=\"VALUE22\">VALUE22</option>"
      assert html_response(conn, 200) =~ "<option selected value=\"VALUE41\">VALUE41</option>"
    end
  end

  describe "POST /just_run" do
    test "when project doesn't match the scheduler, it renders 404",
         %{other_project_name: project_name, scheduler_id: scheduler_id} do
      conn =
        build_conn()
        |> post(
          schedulers_path(build_conn(), :trigger_just_run, project_name, scheduler_id),
          @raw_scheduler_form_params
        )

      assert html_response(conn, 404) =~ "404"
    end

    test "when user is not allowed it renders 404",
         %{conn: conn, project_name: project_name, org_id: org_id, user_id: user_id} do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(org_id, user_id, "project.scheduler.manage")
      scheduler = prepare_scheduler_for_just_run()

      conn = trigger_just_run(conn, scheduler)
      assert redirected_to(conn, 302) =~ schedulers_path(conn, :index, project_name)

      assert get_flash(conn, :alert) ==
               "You do not have sufficient rights to start tasks manually."
    end

    test "when scheduler is not found it renders 404", %{conn: conn} do
      scheduler = prepare_scheduler_for_just_run()

      conn = trigger_just_run(conn, %{scheduler | id: UUID.uuid4()})
      assert html_response(conn, 404) =~ "404"
    end

    test "when request fails because pipeline queue limit is reached it redirects to index with proper error message",
         %{conn: conn, project_name: project_name} do
      scheduler = prepare_scheduler_for_just_run(branch: "master", pipeline_file: "pipeline.yml")

      with_mocks([
        {
          InternalApi.PeriodicScheduler.PeriodicService.Stub,
          [:passthrough],
          [
            run_now: fn _, _, _ ->
              {:ok,
               %InternalApi.PeriodicScheduler.RunNowResponse{
                 status: %InternalApi.Status{code: 8, message: "Error"}
               }}
            end
          ]
        }
      ]) do
        conn = trigger_just_run(conn, scheduler)
        assert redirected_to(conn, 302) =~ schedulers_path(conn, :index, project_name)

        assert get_flash(conn, :alert) ==
                 "Unable to start workflow, pipeline queue limit reached."
      end
    end

    test "correctly passes parameters to the request",
         %{conn: conn, project_name: project_name} do
      scheduler =
        prepare_scheduler_for_just_run(
          branch: "master",
          pipeline_file: "pipeline.yml",
          parameters: [
            %{name: "PARAM1", default_value: "VALUE11"},
            %{name: "PARAM2", options: ["VALUE21", "VALUE22"]},
            %{name: "PARAM3", options: ["VALUE31", "VALUE32"], default_value: "VALUE31"},
            %{name: "PARAM4", options: ["VALUE41", "VALUE42"], default_value: "VALUE43"}
          ]
        )

      conn =
        trigger_just_run(conn, scheduler, %{
          "branch" => "develop",
          "pipeline_file" => "initial.yml",
          "parameters" => %{
            "0" => %{"name" => "PARAM1", "value" => "VALUE1"},
            "1" => %{"name" => "PARAM2", "value" => "VALUE21"},
            "2" => %{"name" => "PARAM3", "value" => "VALUE32"},
            "3" => %{"name" => "PARAM4", "value" => "VALUE42"}
          }
        })

      assert redirected_to(conn, 302) =~ schedulers_path(conn, :show, project_name, scheduler.id)
      assert get_flash(conn, :notice) == "Workflow started successfully."
      assert [trigger] = DB.find_all_by(:triggers, :periodic_id, scheduler.id)

      assert trigger.api_model.branch == "develop"
      assert trigger.api_model.pipeline_file == "initial.yml"

      assert parameter_values =
               Enum.into(trigger.api_model.parameter_values, %{}, &{&1.name, &1.value})

      assert %{
               "PARAM1" => "VALUE1",
               "PARAM2" => "VALUE21",
               "PARAM3" => "VALUE32",
               "PARAM4" => "VALUE42"
             } == parameter_values
    end

    test "implicitly uses default values",
         %{conn: conn, project_name: project_name} do
      scheduler =
        prepare_scheduler_for_just_run(
          branch: "master",
          pipeline_file: "pipeline.yml",
          parameters: [
            %{name: "PARAM1", default_value: "VALUE11"},
            %{name: "PARAM2", options: ["VALUE21", "VALUE22"]},
            %{name: "PARAM3", options: ["VALUE31", "VALUE32"], default_value: "VALUE31"},
            %{name: "PARAM4", options: ["VALUE41", "VALUE42"], default_value: "VALUE43"}
          ]
        )

      conn = trigger_just_run(conn, scheduler, %{})

      assert redirected_to(conn, 302) =~ schedulers_path(conn, :index, project_name)
      assert get_flash(conn, :notice) == "Workflow started successfully."
      assert [trigger] = DB.find_all_by(:triggers, :periodic_id, scheduler.id)

      assert trigger.api_model.branch == "master"
      assert trigger.api_model.pipeline_file == "pipeline.yml"

      assert parameter_values =
               Enum.into(trigger.api_model.parameter_values, %{}, &{&1.name, &1.value})

      assert %{
               "PARAM1" => "VALUE11",
               "PARAM2" => "",
               "PARAM3" => "VALUE31",
               "PARAM4" => "VALUE43"
             } == parameter_values
    end

    test "fails if branch is not given",
         %{conn: conn, project_name: _project_name} do
      scheduler =
        prepare_scheduler_for_just_run(
          pipeline_file: "pipeline.yml",
          parameters: [
            %{name: "PARAM1", default_value: "VALUE11"}
          ]
        )

      conn = trigger_just_run(conn, scheduler, %{})

      assert html_response(conn, 200) =~ "Run"
      assert get_flash(conn, :alert) == "Unable to start workflow, please provide correct data."
    end

    test "fails if pipeline file is not given",
         %{conn: conn, project_name: _project_name} do
      scheduler =
        prepare_scheduler_for_just_run(
          branch: "master",
          parameters: [
            %{name: "PARAM1", default_value: "VALUE11"}
          ]
        )

      conn = trigger_just_run(conn, scheduler, %{})

      assert html_response(conn, 200) =~ "Run"
      assert get_flash(conn, :alert) == "Unable to start workflow, please provide correct data."
    end

    test "fails if required parameter is not given",
         %{conn: conn, project_name: _project_name} do
      scheduler =
        prepare_scheduler_for_just_run(
          branch: "master",
          pipeline_file: "pipeline.yml",
          parameters: [
            %{name: "PARAM1", required: true}
          ]
        )

      conn = trigger_just_run(conn, scheduler, %{})

      assert html_response(conn, 200) =~ "Run"
      assert get_flash(conn, :alert) == "Unable to start workflow, please provide correct data."
    end
  end

  defp prepare_scheduler_for_just_run(params \\ []) do
    project = DB.first(:projects)
    user = DB.first(:users)

    default_params = [
      name: "JustRun Scheduler",
      recurring: false,
      at: "",
      branch: "",
      pipeline_file: "",
      parameters: []
    ]

    Support.Stubs.Scheduler.create(project, user, default_params |> Keyword.merge(params))
  end

  defp form_just_run(conn, scheduler, params \\ %{}) do
    path = schedulers_path(conn, :form_just_run, scheduler.project_id, scheduler.id)
    get(conn, path, params)
  end

  defp trigger_just_run(conn, scheduler, params \\ %{}) do
    path = schedulers_path(conn, :trigger_just_run, scheduler.project_id, scheduler.id)
    post(conn, path, params)
  end
end
