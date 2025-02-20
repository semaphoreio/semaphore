defmodule Router.Notifications.UpdateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.notifications.manage")

      notification =
        Support.Stubs.Notifications.create(
          org,
          name: "notification_example"
        )

      {:ok, %{org_id: org_id, user_id: user_id, org: org, notification: notification}}
    end

    test "update a notification", ctx do
      notification = construct("a-fast-notification")
      {:ok, response} = update(ctx, ctx.notification.id, notification)
      updated_notification = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(updated_notification)
      assert notification.spec.name == updated_notification["metadata"]["name"]
    end

    test "update with notification name in path", ctx do
      notification = construct("a-slow-notification")
      {:ok, response} = update(ctx, ctx.notification.name, notification)

      updated_notification = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(updated_notification)
      assert notification.spec.name == updated_notification["metadata"]["name"]
    end

    test "without specified name in spec => fail", ctx do
      default = construct()

      notification =
        default
        |> Map.put(:spec, Map.delete(default.spec, :name))

      {:ok, response} = update(ctx, ctx.notification.id, notification)
      assert 422 == response.status_code
    end

    test "update a notification not owned by org id", ctx do
      Support.Stubs.Notifications.Grpc.mock_wrong_org(UUID.uuid4())
      notification = construct("a-fast-notification")
      {:ok, response} = update(ctx, ctx.notification.name, notification)
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

    test "fail", ctx do
      notification = construct()
      {:ok, response} = update(ctx, ctx.notification.id, notification)
      error = Jason.decode!(response.body)

      assert 404 == response.status_code
      api = PublicAPI.ApiSpec.spec()
      assert_schema(error, "Error", api)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Notifications.Notification", spec)
  end

  defp construct(name \\ "my-instant-notification") do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Notifications.Notification.schema())

    Map.put(default, :spec, Map.put(default.spec, :name, name))
  end

  defp update(ctx, id_or_name, notification) do
    url = url() <> "/notifications/#{id_or_name}"
    body = Jason.encode!(notification)

    HTTPoison.put(url, body, headers(ctx))
  end
end
