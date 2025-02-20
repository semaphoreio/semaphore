defmodule Notifications.Api.PublicApi.GetTest do
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
      alias Semaphore.Notifications.V1alpha.GetNotificationRequest

      GrpcMock.stub(
        RBACMock,
        :list_user_permissions,
        fn _, _ ->
          InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
        end
      )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = GetNotificationRequest.new(notification_id_or_name: "non-existing")
      {:error, e} = Stub.get_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Notification non-existing not found",
               status: 5
             }
    end

    test "when not found => returns error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.GetNotificationRequest

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = GetNotificationRequest.new(notification_id_or_name: "non-existing")
      {:error, e} = Stub.get_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Notification non-existing not found",
               status: 5
             }
    end

    test "it gets the resource" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.GetNotificationRequest

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req1 = Support.Factories.Notification.api_model("first")
      {:ok, _} = Stub.create_notification(channel, req1, @options)

      req2 = GetNotificationRequest.new(notification_id_or_name: "first")
      {:ok, notification} = Stub.get_notification(channel, req2, @options)

      assert notification.metadata.name == "first"
      refute is_nil(notification.metadata.id)
      assert notification.spec == req1.spec
    end
  end
end
