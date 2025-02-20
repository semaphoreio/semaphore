defmodule Router.Notifications.CreateTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "organization.notifications.manage")

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "create a notification", ctx do
      notification = construct("a-notification-name-one")

      {:ok, response} = create(ctx, notification)

      created_notification = Jason.decode!(response.body)

      assert 200 == response.status_code
      check_response(created_notification)
      assert notification.spec.name == created_notification["metadata"]["name"]
    end

    test "without specified name in spec => fail", ctx do
      default = construct()

      notification =
        default
        |> Map.put(:spec, Map.delete(default.spec, :name))

      {:ok, response} = create(ctx, notification)
      assert 422 == response.status_code
    end

    test "random version => fail", ctx do
      notification = construct() |> Map.put(:apiVersion, "v3")
      {:ok, response} = create(ctx, notification)

      assert 422 == response.status_code
    end

    test "wrong kind => fail", ctx do
      notification = construct() |> Map.put(:kind, "Secrets")
      {:ok, response} = create(ctx, notification)

      assert 422 == response.status_code
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "organization.secrets.manage")

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "create a notification -> fails", ctx do
      notification = construct("some-name-1")
      {:ok, response} = create(ctx, notification)
      resp = Jason.decode!(response.body)

      assert 404 == response.status_code
      api = PublicAPI.ApiSpec.spec()
      assert_schema(resp, "Error", api)
    end
  end

  defp check_response(response) do
    spec = PublicAPI.ApiSpec.spec()
    assert_schema(response, "Notifications.Notification", spec)
  end

  defp construct(name \\ "my-notification-1") do
    default = OpenApiSpex.Schema.example(PublicAPI.Schemas.Notifications.Notification.schema())

    Map.put(default, :spec, Map.put(default.spec, :name, name))
  end

  defp create(ctx, notification) do
    url = url() <> "/notifications"

    body = Jason.encode!(notification)

    HTTPoison.post(url, body, headers(ctx))
  end
end
