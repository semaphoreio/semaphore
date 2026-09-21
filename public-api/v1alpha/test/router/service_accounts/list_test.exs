defmodule Router.ServiceAccounts.List.Test do
  use ExUnit.Case

  setup do
    on_exit(fn -> Support.Stubs.reset() end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()

    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: ["organization.service_accounts.view"]
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()

    {:ok,
     extra_args: %{
       "organization_id" => org.id,
       "requester_id" => user.id
     }}
  end

  describe "GET /service_accounts - page_token validation" do
    test "rejects a non-integer page_token with 400", ctx do
      {:ok, resp} = list_request(%{page_token: "abc"}, ctx)

      assert resp.status_code == 400
      assert resp.body =~ "page_token"
    end

    test "rejects a negative page_token with 400", ctx do
      {:ok, resp} = list_request(%{page_token: "-1"}, ctx)

      assert resp.status_code == 400
      assert resp.body =~ "page_token"
    end
  end

  defp url, do: "localhost:4004"

  defp headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp list_request(params, ctx) do
    url = url() <> "/service_accounts" <> "?" <> Plug.Conn.Query.encode(params)
    HTTPoison.get(url, headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"]))
  end
end
