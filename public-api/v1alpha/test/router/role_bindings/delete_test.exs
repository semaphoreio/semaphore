defmodule Router.RoleBindings.Delete.Test do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()

    {:ok,
     extra_args: %{
       "organization_id" => org.id,
       "requester_id" => user.id
     }}
  end

  describe "DELETE /rbac/ - endpoint to delete role binding" do
    test "returns 400 when user_id header is missing", ctx do
      {:ok, resp} =
        create_delete_request(%{}, ctx, [
          {"Content-type", "application/json"},
          {"x-semaphore-org-id", ctx.extra_args["organization_id"]}
        ])

      assert resp.status_code == 400
      assert resp.body =~ "Missing user id in request header"
    end

    test "returns 400 when org_id header is missing", ctx do
      {:ok, resp} =
        create_delete_request(%{}, ctx, [
          {"Content-type", "application/json"},
          {"x-semaphore-user-id", ctx.extra_args["requester_id"]}
        ])

      assert resp.status_code == 400
      assert resp.body =~ "Missing organization id in request header"
    end

    test "returns 400 when user_id is not a valid UUID", ctx do
      {:ok, resp} =
        create_delete_request(%{}, ctx, [
          {"Content-type", "application/json"},
          {"x-semaphore-user-id", "not-a-uuid"},
          {"x-semaphore-org-id", ctx.extra_args["organization_id"]}
        ])

      assert resp.status_code == 400
      assert resp.body =~ "Invalid user id format"
    end

    test "returns 400 when org_id is not a valid UUID", ctx do
      {:ok, resp} =
        create_delete_request(%{}, ctx, [
          {"Content-type", "application/json"},
          {"x-semaphore-user-id", ctx.extra_args["requester_id"]},
          {"x-semaphore-org-id", "not-a-uuid"}
        ])

      assert resp.status_code == 400
      assert resp.body =~ "Invalid organization id format"
    end

    test "when user_id is not authorized then returns 401", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("organization.people.manage")
        )
      end)

      {:ok, resp} = create_delete_request(%{user_id: UUID.uuid4()}, ctx)
      assert resp.status_code == 400
      assert resp.body =~ "Permission denied"
    end

    test "When a non-existent user_id is provided returns 400", ctx do
      random_uuid = UUID.uuid4()

      {:ok, resp} = create_delete_request(%{user_id: random_uuid}, ctx)
      assert resp.status_code == 400
      assert resp.body =~ "User with id #{random_uuid} not found"
    end

    test "When a non-existent email is provided returns 400", ctx do
      random_email = "test@gmail.com"

      {:ok, resp} = create_delete_request(%{email: random_email}, ctx)
      assert resp.status_code == 400
      assert resp.body =~ "User with email #{random_email} not found"
    end

    test "When neither user_id nor email is provided returns 400", ctx do
      {:ok, resp} = create_delete_request(%{}, ctx)
      assert resp.status_code == 400
      assert resp.body =~ "Missing user_id or email in query parameters"
    end

    test "When user exists and is passed via user_id, successfully deletes role bindings", ctx do
      user_to_delete =
        Support.Stubs.User.create(user_id: UUID.uuid4(), email: "delete-me@example.com")

      {:ok, resp} = create_delete_request(%{user_id: user_to_delete.id, email: "test"}, ctx)

      assert resp.status_code == 200
      assert resp.body =~ "true"
    end

    test "When user exists and is passed via email, successfully deletes role bindings", ctx do
      user_to_delete =
        Support.Stubs.User.create(user_id: UUID.uuid4(), email: "delete-me@example.com")

      {:ok, resp} = create_delete_request(%{email: "delete-me@example.com"}, ctx)

      assert resp.status_code == 200
      assert resp.body =~ "true"
    end
  end

  defp url, do: "localhost:4004"

  defp headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp create_delete_request(params, ctx) do
    create_delete_request(
      params,
      ctx,
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end

  defp create_delete_request(params, _ctx, headers) do
    url = url() <> "/rbac/" <> "?" <> Plug.Conn.Query.encode(params)
    HTTPoison.delete(url, headers)
  end
end
