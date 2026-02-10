defmodule FrontWeb.NotificationsControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    user_id = Map.get(user, :id)

    organization = DB.first(:organizations)
    organization_id = Map.get(organization, :id)

    Support.Stubs.PermissionPatrol.remove_all_permissions()
    Support.Stubs.PermissionPatrol.add_permissions(organization_id, user_id, "organization.view")

    project = DB.first(:projects)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    notification = DB.first(:notifications)
    notification_id = Map.get(notification, :id)

    raw_update_params = %{
      "id" => notification_id,
      "name" => "zebra",
      "rule_681550" => %{
        "projects" => "test-switch, all-about-switches",
        "branches" => "master",
        "pipelines" => "",
        "results" => "passed",
        "name" => "First Rule",
        "slack_channels" => "@bmarkons",
        "slack_endpoint" => "https://hooks.slack.com/services/xxxx",
        "webhook_endpoint" => "https://hooks.slack.com/services/xxxx",
        "webhook_secret" => "",
        "webhook_timeout" => "500",
        "webhook_retries" => "2"
      },
      "rule_682323" => %{
        "projects" => "test",
        "branches" => "dev",
        "pipelines" => "",
        "results" => "stopped",
        "name" => "Second Rule",
        "slack_channels" => "#stopped",
        "slack_endpoint" => "https://hooks.slack.com/services/xxxx",
        "webhook_endpoint" => "https://hooks.slack.com/services/xxxx",
        "webhook_secret" => "foo",
        "webhook_timeout" => "0",
        "webhook_retries" => "0"
      }
    }

    GrpcMock.stub(
      RBACMock,
      :list_accessible_projects,
      InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [project.id])
    )

    [
      conn: conn,
      organization_id: organization_id,
      user_id: user_id,
      notification_id: notification_id,
      raw_update_params: raw_update_params,
      project: project
    ]
  end

  describe "GET index" do
    test "returns a message if user cant view notifications", %{conn: conn, project: project} do
      conn =
        conn
        |> get(notifications_path(conn, :index))

      assert html_response(conn, 200) =~ project.name
      assert html_response(conn, 200) =~ "Sorry, you can’t access Organization Notifications."
    end

    test "return 200", %{
      conn: conn,
      project: project,
      organization_id: organization_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.notifications.view"
      )

      conn =
        conn
        |> get(notifications_path(conn, :index))

      assert html_response(conn, 200) =~ project.name
      refute html_response(conn, 200) =~ "Sorry, you can’t access Organization Notifications."
    end

    test "lists an existing notification", %{
      conn: conn,
      organization_id: organization_id,
      user_id: user_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.notifications.view"
      )

      conn =
        conn
        |> get(notifications_path(conn, :index))

      assert html_response(conn, 200) =~ "Notification #1"
    end
  end

  describe "GET new" do
    setup %{organization_id: organization_id, user_id: user_id} = state do
      Support.Stubs.PermissionPatrol.add_permissions(organization_id, user_id, [
        "organization.notifications.view",
        "organization.notifications.manage"
      ])

      state
    end

    test "it shows the notification form", %{conn: conn} do
      conn =
        conn
        |> get("/notifications/new")

      assert html_response(conn, 200) =~ "Create Notification"
      assert html_response(conn, 200) =~ "Rules"
      assert html_response(conn, 200) =~ "Add another Rule"
      assert html_response(conn, 200) =~ "Save Notification"
      assert html_response(conn, 200) =~ "max=\"30000\""
      assert html_response(conn, 200) =~ "max=\"10\""
    end

    test "it redirects with a note", %{conn: conn, raw_update_params: raw_update_params} do
      conn =
        conn
        |> post("/notifications/new", raw_update_params)

      assert redirected_to(conn) == "/notifications"
      assert get_flash(conn, :notice) == "Notification created."
    end

    test "when it fails, it redirects back to page with alert", %{
      conn: conn,
      raw_update_params: raw_update_params
    } do
      GrpcMock.stub(NotificationMock, :create_notification, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> post("/notifications/new", raw_update_params)

      assert redirected_to(conn) == "/notifications/new"
      assert get_flash(conn, :alert) == "Failed to create notification."
    end

    test "when it fails with taken name error, it redirects to page with alert", %{
      conn: conn,
      raw_update_params: raw_update_params
    } do
      GrpcMock.stub(NotificationMock, :create_notification, fn _, _ ->
        raise GRPC.RPCError, status: 9, message: "name 'zebra' has already been taken"
      end)

      conn =
        conn
        |> post("/notifications/new", raw_update_params)

      assert html_response(conn, 422) =~ "has already been taken"
      assert get_flash(conn, :alert) == "Failed to create notification."
    end

    test "when it fails with invalid params, it redirects to page with alert", %{
      conn: conn,
      raw_update_params: raw_update_params
    } do
      GrpcMock.stub(NotificationMock, :create_notification, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Pattern is not a valid regex statement"
      end)

      conn =
        conn
        |> post("/notifications/new", raw_update_params)

      assert redirected_to(conn) == "/notifications/new"
      assert get_flash(conn, :alert) == "Pattern is not a valid regex statement"
    end
  end

  describe "GET edit" do
    setup %{organization_id: organization_id, user_id: user_id} = state do
      Support.Stubs.PermissionPatrol.add_permissions(organization_id, user_id, [
        "organization.notifications.view",
        "organization.notifications.manage"
      ])

      state
    end

    test "it shows the edit notification page", %{conn: conn, notification_id: notification_id} do
      conn =
        conn
        |> get("/notifications/#{notification_id}/edit")

      assert html_response(conn, 200) =~ "Edit Notification"
      assert html_response(conn, 200) =~ "Rules"
      assert html_response(conn, 200) =~ "Add another Rule"
      assert html_response(conn, 200) =~ "Save Notification"
      assert html_response(conn, 200) =~ "max=\"30000\""
      assert html_response(conn, 200) =~ "max=\"10\""
    end

    test "when notification is not found, it shows 404", %{conn: conn} do
      conn =
        conn
        |> get("/notifications/58eb31dd-2e67-4393-a63c-3b9d35e34b45/edit")

      assert html_response(conn, 404)
    end
  end

  describe "successfull PUT update" do
    setup %{organization_id: organization_id, user_id: user_id} = state do
      Support.Stubs.PermissionPatrol.add_permissions(organization_id, user_id, [
        "organization.notifications.view",
        "organization.notifications.manage"
      ])

      state
    end

    test "it redirects with a note", %{
      conn: conn,
      notification_id: notification_id,
      raw_update_params: raw_update_params
    } do
      conn =
        conn
        |> put("/notifications/#{notification_id}", raw_update_params)

      assert redirected_to(conn) == "/notifications"
      assert get_flash(conn, :notice) == "Notification updated."
    end
  end

  describe "unsuccessfull PUT update" do
    setup %{organization_id: organization_id, user_id: user_id} = state do
      Support.Stubs.PermissionPatrol.add_permissions(organization_id, user_id, [
        "organization.notifications.view",
        "organization.notifications.manage"
      ])

      state
    end

    test "when notification is not found, it renders 404", %{
      conn: conn,
      raw_update_params: raw_update_params
    } do
      conn =
        conn
        |> put("/notifications/58eb31dd-2e67-4393-a63c-3b9d35e34b45", raw_update_params)

      assert html_response(conn, 404) =~ "404"
    end

    test "when it fails with taken name error, it redirects to page with alert", %{
      conn: conn,
      notification_id: notification_id,
      raw_update_params: raw_update_params
    } do
      GrpcMock.stub(NotificationMock, :update_notification, fn _, _ ->
        raise GRPC.RPCError, status: 9, message: "name 'zebra' has already been taken"
      end)

      conn =
        conn
        |> put("/notifications/#{notification_id}", raw_update_params)

      assert html_response(conn, 422) =~ "has already been taken"
      assert get_flash(conn, :alert) == "Failed to update notification."
    end

    test "when notification was updated with invalid params, it redirects to page with alert", %{
      conn: conn,
      notification_id: notification_id,
      raw_update_params: raw_update_params
    } do
      GrpcMock.stub(NotificationMock, :update_notification, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Pattern is not a valid regex statement"
      end)

      conn =
        conn
        |> put("/notifications/#{notification_id}", raw_update_params)

      assert redirected_to(conn) == "/notifications/#{notification_id}/edit"
      assert get_flash(conn, :alert) == "Pattern is not a valid regex statement"
    end

    test "update fails with an unknown error, it redirects back to page with alert", %{
      conn: conn,
      notification_id: notification_id,
      raw_update_params: raw_update_params
    } do
      GrpcMock.stub(NotificationMock, :update_notification, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> put("/notifications/#{notification_id}", raw_update_params)

      assert redirected_to(conn) == "/notifications/#{notification_id}/edit"
      assert get_flash(conn, :alert) == "Failed to update notification."
    end
  end

  describe "DELETE destroy" do
    setup %{organization_id: organization_id, user_id: user_id} = state do
      Support.Stubs.PermissionPatrol.add_permissions(organization_id, user_id, [
        "organization.notifications.view",
        "organization.notifications.manage"
      ])

      state
    end

    test "when the deletion succeeds, it redirects with a note", %{
      conn: conn,
      notification_id: notification_id
    } do
      conn =
        conn
        |> delete("/notifications/#{notification_id}")

      assert redirected_to(conn) == "/notifications"
      assert get_flash(conn, :notice) == "Notification deleted."
    end

    test "when notification is not found, it shows 404", %{conn: conn} do
      conn =
        conn
        |> delete("/notifications/58eb31dd-2e67-4393-a63c-3b9d35e34b45")

      assert html_response(conn, 404)
    end

    test "when the deletion fails, it redirects to show page with alert", %{
      conn: conn,
      notification_id: notification_id
    } do
      GrpcMock.stub(NotificationMock, :delete_notification, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> delete("/notifications/#{notification_id}")

      assert redirected_to(conn) == "/notifications"
      assert get_flash(conn, :alert) == "Failed to delete notification."
    end
  end

  describe "cant modify notifications withouth permission" do
    setup %{organization_id: organization_id, user_id: user_id} = state do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.notifications.view"
      )

      state
    end

    test "cant access new page", %{conn: conn} do
      conn =
        conn
        |> get("/notifications/new")

      assert html_response(conn, 200) =~ "Sorry, you can’t manage Organization Notifications."
    end

    test "cant access edit page", %{conn: conn, notification_id: notification_id} do
      conn =
        conn
        |> get("/notifications/#{notification_id}/edit")

      assert html_response(conn, 200) =~ "Sorry, you can’t manage Organization Notifications."
    end

    test "cant delete notification", %{
      conn: conn,
      notification_id: notification_id
    } do
      conn =
        conn
        |> delete("/notifications/#{notification_id}")

      assert redirected_to(conn) == "/notifications"
      assert get_flash(conn, :alert) == "Insufficient permissions."
    end
  end

  describe "parse_integer/2" do
    test "clamps values to min and max boundaries" do
      assert FrontWeb.NotificationsController.parse_integer("-5", 10) == 0
      assert FrontWeb.NotificationsController.parse_integer("11", 10) == 10
      assert FrontWeb.NotificationsController.parse_integer("50000", 30_000) == 30_000
    end
  end
end
