defmodule Router.Roles.Create.Test do
  use ExUnit.Case

  setup do
    on_exit(fn -> Support.Stubs.reset() end)

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

  describe "POST /roles - permission escalation guard" do
    test "rejects an org role with a permission the requester does not hold", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: ["organization.custom_roles.manage", "organization.people.manage"]
        )
      end)

      body = %{name: "danger", scope: "org", permissions: ["organization.delete"]}
      {:ok, resp} = create_role_request(body, ctx)

      assert resp.status_code == 400
      assert resp.body =~ "cannot grant permissions you do not hold"
    end
  end

  defp url, do: "localhost:4004"

  defp headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp create_role_request(body, ctx) do
    HTTPoison.post(
      url() <> "/roles",
      Poison.encode!(body),
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end
end
