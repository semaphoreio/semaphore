defmodule FrontWeb.SettingsControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  import Mock

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

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [
      conn: conn,
      organization: organization,
      organization_id: organization_id,
      user_id: user_id
    ]
  end

  describe "GET show" do
    test "when the user can't view the organization settings => show dead end page", %{conn: conn} do
      conn =
        conn
        |> get("/settings")

      assert html_response(conn, 200) =~ "Sorry, you can’t access Organization Settings."
    end

    test "when the user can't update the organization => do not show save button", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.general_settings.view"
      )

      conn =
        conn
        |> get("/settings")

      assert html_response(conn, 200) =~ "Set up organization basics"
      refute html_response(conn, 200) =~ "Save changes"
    end

    test "when the user isn't authorized to delete the organization => doesn't show the deletion option",
         %{conn: conn, user_id: user_id, organization_id: organization_id} do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.general_settings.manage", "organization.general_settings.view"]
      )

      conn =
        conn
        |> get("/settings")

      refute html_response(conn, 200) =~ "Delete Organization"
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "GET change_url" do
    test "when the user can't update the organization => returns correct message", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.general_settings.view"
      )

      conn =
        conn
        |> get("/settings/change_url")

      assert html_response(conn, 200) =~ "Ask organization owner"
    end
  end

  describe "GET confirm_delete" do
    test "when the user can delete the organization => renders the page", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.delete"
      )

      DB.clear(:projects)

      conn =
        conn
        |> get("/settings/confirm_delete")

      assert html_response(conn, 200) =~ "Delete Organization"
      refute html_response(conn, 200) =~ "It seems you still have projects in this organization"
    end

    test "when the user can't delete the organization => returns message that states it", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.general_settings.manage"
      )

      conn =
        conn
        |> get("/settings/confirm_delete")

      assert html_response(conn, 200) =~ "Ask organization owner"
      refute html_response(conn, 200) =~ "Delete"
    end

    test "when there are projects => renders notice about projects", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.delete"
      )

      conn =
        conn
        |> get("/settings/confirm_delete")

      assert html_response(conn, 200) =~ "You have to delete all projects first"
    end
  end

  describe "POST update" do
    test "when the user can't update the organization => redirect to settings with message", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.general_settings.view", "organization.ip_allow_list.manage"]
      )

      conn =
        conn
        |> post("/settings", name: "Uber")

      assert html_response(conn, 302) =~ "settings\""
      assert get_flash(conn, :alert) == "Insufficient permissions."
    end

    test "when there is an error updating the organization => redirects to settings", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.general_settings.manage", "organization.general_settings.manage"]
      )

      {:ok, message} = Poison.encode(%{"name" => ["Cannot be empty"]})

      GrpcMock.stub(OrganizationMock, :update, fn _, _ ->
        raise(GRPC.RPCError, message: message, status: GRPC.Status.invalid_argument())
      end)

      conn =
        conn
        |> post("/settings", name: "Uber", redirect_path: "/settings")

      assert redirected_to(conn) =~ "/settings"
      assert get_flash(conn, :errors)
    end
  end

  describe "POST confirm_enforce_workflow" do
    test "when the user lacks manage permissions => denies the request", %{
      conn: conn,
      organization_id: organization_id
    } do
      with_mock Front.Models.OrganizationSettings,
        modify: fn ^organization_id, _ ->
          send(self(), :modify_called)
          {:ok, %{}}
        end do
        conn =
          conn
          |> post("/settings/confirm_enforce")

        assert redirected_to(conn) =~ "/settings"
        assert get_flash(conn, :alert) == "Insufficient permissions."
        refute_received :modify_called
      end
    end

    test "when the user can manage general settings => applies the enforcement", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.view", "organization.general_settings.manage"]
      )

      with_mock Front.Models.OrganizationSettings,
        modify: fn ^organization_id, %{"enforce_whitelist" => "true"} ->
          send(self(), :modify_called)
          {:ok, %{}}
        end do
        conn =
          conn
          |> post("/settings/confirm_enforce")

        assert redirected_to(conn) == "/settings"
        assert get_flash(conn, :notice) == "Whitelist enforcement applied successfully."
        assert_received :modify_called
      end
    end

    test "when enforcing fails => shows the error", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.view", "organization.general_settings.manage"]
      )

      changeset = %Ecto.Changeset{
        valid?: false,
        changes: %{},
        errors: [enforce_whitelist: {"boom", []}],
        data: %{},
        types: %{}
      }

      with_mock Front.Models.OrganizationSettings,
        modify: fn ^organization_id, %{"enforce_whitelist" => "true"} ->
          {:error, changeset}
        end do
        conn =
          conn
          |> post("/settings/confirm_enforce")

        assert redirected_to(conn) == "/settings"
        assert get_flash(conn, :alert) == "Failed to apply whitelist enforcement."
        assert get_flash(conn, :errors) == ["enforce_whitelist: boom"]
      end
    end
  end

  describe "DELETE destroy" do
    test "when everything works => redirects to me page", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        "organization.delete"
      )

      DB.clear(:projects)

      conn =
        conn
        |> delete("/settings", delete_account: "delete")

      assert redirected_to(conn) =~ "me."
    end

    test "when the user can't delete the org => rendirect to settings with message", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.general_settings.manage", "organization.general_settings.manage"]
      )

      DB.clear(:projects)

      conn =
        conn
        |> delete("/settings", delete_account: "Rendered Text")

      assert html_response(conn, 302) =~ "settings\""
      assert get_flash(conn, :alert) == "Insufficient permissions."
    end

    test "when the organizaiton still has projects => dont delete and redirect to settings page",
         %{
           conn: conn,
           user_id: user_id,
           organization_id: organization_id
         } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.delete", "organization.general_settings.view"]
      )

      conn =
        conn
        |> delete("/settings", delete_account: "Rendered Text")

      assert html_response(conn, 302) =~ "settings"
    end

    test "when the delete confirmation is not correct => redirects back", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.delete", "organization.general_settings.view"]
      )

      DB.clear(:projects)

      conn =
        conn
        |> delete("/settings", delete_account: "something")

      assert redirected_to(conn) =~ "/confirm_delete"
      assert get_flash(conn, :errors) == %{delete_account: "Incorrect confirmation"}
    end

    test "when there is an error with org deletion => redirects to delete confirmation", %{
      conn: conn,
      user_id: user_id,
      organization_id: organization_id
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization_id,
        user_id,
        ["organization.delete", "organization.general_settings.view"]
      )

      DB.clear(:projects)

      GrpcMock.stub(OrganizationMock, :destroy, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> delete("/settings", delete_account: "delete")

      assert redirected_to(conn) =~ "/settings/confirm_delete"
      assert get_flash(conn, :alert) =~ "Failed to delete the organization."
    end
  end
end
