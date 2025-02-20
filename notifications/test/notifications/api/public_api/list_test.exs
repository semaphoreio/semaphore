defmodule Notifications.Api.PublicApi.ListTest do
  use Notifications.DataCase

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()

  @options [
    metadata: %{
      "x-semaphore-user-id" => @user_id,
      "x-semaphore-org-id" => @org_id
    }
  ]

  setup do
    GrpcMock.stub(
      RBACMock,
      :list_user_permissions,
      fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: ["organization.notifications.manage", "organization.notifications.view"]
        )
      end
    )

    :ok
  end

  describe ".run" do
    test "when the request is not authorized => return error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.ListNotificationsRequest

      GrpcMock.stub(
        RBACMock,
        :list_user_permissions,
        fn _, _ ->
          InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
        end
      )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = ListNotificationsRequest.new()
      {:error, e} = Stub.list_notifications(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Can't list notifications in organization",
               status: 7
             }
    end

    test "it gets the resources" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.ListNotificationsRequest

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      Enum.each(1..5, fn index ->
        req = Support.Factories.Notification.api_model("first-#{index}")
        {:ok, _} = Stub.create_notification(channel, req, @options)
      end)

      req = ListNotificationsRequest.new(page_size: 3)
      {:ok, res} = Stub.list_notifications(channel, req, @options)

      assert length(res.notifications) == 3
      assert res.next_page_token != ""

      assert Enum.map(res.notifications, fn n -> n.metadata.name end) == [
               "first-1",
               "first-2",
               "first-3"
             ]

      req =
        ListNotificationsRequest.new(
          page_size: 3,
          page_token: res.next_page_token
        )

      {:ok, res} = Stub.list_notifications(channel, req, @options)

      assert length(res.notifications) == 2
      assert res.next_page_token == ""

      assert Enum.map(res.notifications, fn n -> n.metadata.name end) == [
               "first-4",
               "first-5"
             ]
    end
  end
end
