defmodule FrontWeb.GroupsController.Test do
  use FrontWeb.ConnCase, async: false

  import Mock
  alias Support.Stubs.{DB, PermissionPatrol}

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)

    PermissionPatrol.allow_everything(organization.id, user.id)

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    [
      conn: conn,
      organization: organization,
      user: user
    ]
  end

  describe "modify group" do
    test "when user does not have permissions", ctx do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        ctx.organization.id,
        ctx.user.id,
        "organization.people.manage"
      )

      conn =
        ctx.conn
        |> put("/groups/#{Ecto.UUID.generate()}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when something goes wrong, return error message", ctx do
      conn =
        ctx.conn
        |> put("/groups/#{Ecto.UUID.generate()}?name=test&description=test")

      assert response(conn, 302) =~ "/people"
      assert get_flash(conn, :alert) =~ "Group not found"
    end

    test "successfully modify group", ctx do
      members_to_add = [Ecto.UUID.generate(), Ecto.UUID.generate()]
      members_to_remove = [Ecto.UUID.generate()]
      group_id = Ecto.UUID.generate()

      mocked_function = fn _, req ->
        assert req.requester_id == ctx.user.id
        assert req.org_id == ctx.organization.id
        assert req.group.id == group_id
        assert List.first(members_to_add) in req.members_to_add
        assert List.last(members_to_add) in req.members_to_add
        assert members_to_remove == req.members_to_remove
        {:ok, nil}
      end

      with_mocks [
        {InternalApi.Groups.Groups.Stub, [], [modify_group: mocked_function]}
      ] do
        conn =
          ctx.conn
          |> put("/groups/#{group_id}",
            members_to_add: members_to_add,
            members_to_remove: members_to_remove
          )

        assert response(conn, 302) =~ "/people"
        assert get_flash(conn, :notice) =~ "Group successfully modified"
      end
    end
  end

  describe "create group" do
    test "when user does not have permissions", ctx do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        ctx.organization.id,
        ctx.user.id,
        "organization.people.manage"
      )

      conn =
        ctx.conn
        |> post("/groups")

      assert html_response(conn, 404) =~ "404"
    end

    test "error while creating the group", ctx do
      with_mocks [
        {InternalApi.Groups.Groups.Stub, [], [create_group: fn _, _ -> {:error, ""} end]}
      ] do
        conn =
          ctx.conn
          |> post("/groups")

        assert html_response(conn, 302) =~ "/people"
        assert get_flash(conn, :alert) =~ "An error occurred"
      end
    end

    test "success", ctx do
      description = "test_desc"
      name = "test_name"
      member_ids = [Ecto.UUID.generate()]

      with_mocks [
        {InternalApi.Groups.Groups.Stub, [],
         [
           create_group: fn _, req ->
             assert req.requester_id == ctx.user.id
             assert req.org_id == ctx.organization.id
             assert req.group.name == name
             assert req.group.description == description
             assert req.group.member_ids == member_ids
             {:ok, nil}
           end
         ]}
      ] do
        conn =
          ctx.conn
          |> post("/groups", name: name, description: description, member_ids: member_ids)

        assert html_response(conn, 302) =~ "/people"
        assert get_flash(conn, :notice) =~ "Group successfully created"
      end
    end
  end

  describe "destroy group" do
    test "when user does not have permissions", ctx do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        ctx.organization.id,
        ctx.user.id,
        "organization.people.manage"
      )

      group = create_group(ctx)
      conn = ctx.conn |> delete("/groups/#{group.id}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when something goes wrong, return error message", ctx do
      conn = ctx.conn |> delete("/groups/#{Ecto.UUID.generate()}")

      assert response(conn, 302) =~ "/people"
      assert get_flash(conn, :alert) =~ "An error occurred: Group not found"
    end

    test "successfully destroy group", ctx do
      group = create_group(ctx)
      conn = ctx.conn |> delete("/groups/#{group.id}")

      assert response(conn, 302) =~ "/people"
      assert get_flash(conn, :notice) =~ "Request for deleting the group has been sent"
    end
  end

  ###
  ### Helper functions
  ###

  alias Support.Stubs.DB

  defp create_group(ctx) do
    DB.insert(:groups, %{
      id: Ecto.UUID.generate(),
      name: "test_group",
      description: "test_description",
      org_id: ctx.organization.id,
      member_ids: [Ecto.UUID.generate()]
    })
  end
end
