defmodule FrontWeb.BranchControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.{DB, PermissionPatrol}

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()

    branch = DB.first(:branches)
    branch_name = Map.get(branch, :name)
    branch_id = Map.get(branch, :id)

    project = DB.first(:projects)
    PermissionPatrol.allow_everything()
    Support.Stubs.Feature.enable_feature(organization.id, :workflow_filtering)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization.id)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      branch_id: branch_id,
      branch_name: branch_name,
      project: project
    ]
  end

  describe "GET edit_workflow" do
    test "redirects to workflow editor", %{conn: conn, branch_id: branch_id} do
      conn =
        conn
        |> get(branch_path(conn, :edit_workflow, branch_id))

      assert redirected_to(conn, 302) =~ ~r/^(?=.*?(workflows))(?=.*?(edit))/
    end
  end

  describe "GET show" do
    test "renders data fetched from APIs", %{conn: conn, branch_id: branch_id} do
      conn =
        conn
        |> get(branch_path(conn, :show, branch_id))

      assert html_response(conn, 200) =~ "icn-branch.svg"
      assert html_response(conn, 200) =~ "master"
    end

    test "when branch is pull request, opens the page", %{conn: conn, project: project} do
      branch =
        Support.Stubs.Branch.create(project,
          pr_name: "PR name",
          pr_number: "12",
          display_name: "PR name",
          type: InternalApi.Branch.Branch.Type.value(:PR)
        )

      conn =
        conn
        |> get(branch_path(conn, :show, branch.id))

      assert html_response(conn, 200) =~ "PR name"
      assert html_response(conn, 200) =~ "icn-pullrequest.svg"
    end

    test "when branch is tag, opens the page", %{conn: conn, project: project} do
      branch =
        Support.Stubs.Branch.create(project,
          tag_name: "refs/tags/v1.4",
          pr_name: "",
          pr_number: "",
          display_name: "refs/tags/v1.4",
          type: InternalApi.Branch.Branch.Type.value(:TAG)
        )

      conn =
        conn
        |> get(branch_path(conn, :show, branch.id))

      assert html_response(conn, 200) =~ "refs/tags/v1.4"
      assert html_response(conn, 200) =~ "icn-tag.svg"
    end

    test "when the user can't authorize and project is private => returns 404", %{
      conn: conn,
      branch_id: branch_id
    } do
      PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get(branch_path(conn, :show, branch_id))

      assert conn.status == 404
      assert html_response(conn, 404) =~ "Not Found"
    end

    test "when the user can't authorize and project is public => returns 200", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()
      project = Support.Stubs.Project.create(organization, user, visibility: "public")
      branch = Support.Stubs.Branch.create(project)

      conn =
        conn
        |> get(branch_path(conn, :show, branch.id))

      assert conn.assigns.authorization == :guest
      assert conn.assigns.anonymous == false
      refute conn.assigns[:layout_model]

      assert html_response(conn, 200) =~ "Blazing-fast build and deploy!"
    end

    test "when the branch doesn't exist => returns 404", %{conn: conn} do
      conn =
        conn
        |> get(branch_path(conn, :show, "58eb31dd-2e67-4393-a63c-3b9d35e34b45"))

      assert conn.status == 404
      assert html_response(conn, 404) =~ "Not Found"
    end

    test "when there are no workflows => returns 200", %{conn: conn, branch_id: branch_id} do
      DB.clear(:workflows)

      conn =
        conn
        |> get(branch_path(conn, :show, branch_id))

      assert html_response(conn, 200) =~ "That’s uncommon"
    end

    test "with an unknown trigger => shows all workflows", %{
      conn: conn,
      branch_id: branch_id,
      user: user
    } do
      create_scheduled_workflow(user)

      html =
        conn |> get(branch_path(conn, :show, branch_id, trigger: "foo")) |> html_response(200)

      assert html =~ "by scheduler"
      assert html =~ "by jane"
    end

    test "with trigger=git => hides scheduled workflows", %{
      conn: conn,
      branch_id: branch_id,
      user: user
    } do
      create_scheduled_workflow(user)

      html =
        conn |> get(branch_path(conn, :show, branch_id, trigger: "git")) |> html_response(200)

      refute html =~ "by scheduler"
      assert html =~ "by jane"
      assert html =~ ~s(data-poll-param-trigger="git")
    end

    test "with trigger=tasks => shows only scheduled workflows", %{
      conn: conn,
      branch_id: branch_id,
      user: user
    } do
      create_scheduled_workflow(user)

      html =
        conn |> get(branch_path(conn, :show, branch_id, trigger: "tasks")) |> html_response(200)

      assert html =~ "by scheduler"
      refute html =~ "by jane"
      assert html =~ ~r/<option[^>]*selected[^>]*value="tasks"/
    end
  end

  describe "GET poll" do
    test "with trigger=git => hides scheduled workflows and keeps the filter for polling", %{
      conn: conn,
      branch_id: branch_id,
      user: user
    } do
      create_scheduled_workflow(user)

      conn = get(conn, branch_path(conn, :workflows, branch_id, trigger: "git"))

      html = html_response(conn, 200)
      refute html =~ "by scheduler"
      assert html =~ ~s(data-poll-param-trigger="git")
    end

    test "when the user requests next page => renders paginated workflows", %{
      conn: conn,
      branch_id: branch_id
    } do
      conn =
        conn
        |> get(branch_path(conn, :workflows, branch_id, page: 1))

      assert html_response(conn, 200) =~ "Queuing"
    end

    test "when the user isn't authorized => returns 404", %{conn: conn, branch_id: branch_id} do
      PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get(branch_path(conn, :workflows, branch_id, page: 1))

      assert conn.status == 404
      assert html_response(conn, 404) =~ "Not Found"
    end

    test "when the user isn't authorized, and project is public => returns 200", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()
      project = Support.Stubs.Project.create(organization, user, visibility: "public")
      branch = Support.Stubs.Branch.create(project)

      conn =
        conn
        |> get(branch_path(conn, :workflows, branch.id, page: 1))

      assert conn.status == 200
      assert html_response(conn, 200) =~ "Pull new workflows on the branch page"
    end
  end

  defp create_scheduled_workflow(user) do
    hook = DB.first(:hooks)

    workflow =
      Support.Stubs.Workflow.create(hook, user,
        triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:SCHEDULE)
      )

    Support.Stubs.Pipeline.create_initial(workflow)
  end
end
