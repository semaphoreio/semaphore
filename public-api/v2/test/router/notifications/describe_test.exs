defmodule Router.Notifications.DescribeTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.notifications.view")

      notification =
        Support.Stubs.Notifications.create(
          org,
          name: "notification_example"
        )

      {:ok, %{org_id: org_id, user_id: user_id, org: org, notification: notification}}
    end

    test "describe a notification by id", ctx do
      {:ok, response} = get(ctx, ctx.notification.id)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a notification by name", ctx do
      {:ok, response} = get(ctx, ctx.notification.name)
      assert 200 == response.status_code
      check_response(response)
    end

    test "describe a not existant notification", ctx do
      {:ok, response} = get(ctx, "not_existant")
      assert 404 == response.status_code
    end

    test "describe a notification not owned by org id", ctx do
      Support.Stubs.Notifications.Grpc.mock_wrong_org(UUID.uuid4())
      {:ok, response} = get(ctx, ctx.notification.name)
      assert 404 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      notification =
        Support.Stubs.Notifications.create(
          org,
          name: "notification_example"
        )

      {:ok, %{org_id: org_id, user_id: user_id, org: org, notification: notification}}
    end

    test "describe a notification by id", ctx do
      {:ok, response} = get(ctx, ctx.notification.id)
      assert 404 == response.status_code
    end

    test "describe a notification by name", ctx do
      {:ok, response} = get(ctx, ctx.notification.name)
      assert 404 == response.status_code
    end

    test "describe a not existant notification", ctx do
      {:ok, response} = get(ctx, "not_existant")
      assert 404 == response.status_code
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    resp = Jason.decode!(response.body)
    assert_schema(resp, "Notifications.Notification", spec)
  end

  defp get(ctx, id_or_name) do
    url = url() <> "/notifications/#{id_or_name}"

    HTTPoison.get(url, headers(ctx))
  end
end
