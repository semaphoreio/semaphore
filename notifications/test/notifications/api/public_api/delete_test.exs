defmodule Notifications.Api.PublicApi.DeleteTest do
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
          permissions: ["organization.notifications.manage"]
        )
      end
    )

    :ok
  end

  alias Notifications.Models

  describe ".run" do
    test "when the request is not authorized => return error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.DeleteNotificationRequest

      GrpcMock.stub(
        RBACMock,
        :list_user_permissions,
        fn _, _ ->
          InternalApi.RBAC.ListUserPermissionsResponse.new(
            permissions: ["organization.notifications.view"]
          )
        end
      )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = DeleteNotificationRequest.new(notification_id_or_name: "non-existing")
      {:error, e} = Stub.delete_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Notification non-existing not found",
               status: 5
             }
    end

    test "when not found => returns error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.DeleteNotificationRequest

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = DeleteNotificationRequest.new(notification_id_or_name: "non-existing")
      {:error, e} = Stub.delete_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Notification non-existing not found",
               status: 5
             }
    end

    test "it deletes the resource, and everything connected" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.DeleteNotificationRequest

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Support.Factories.Notification.api_model("first")
      {:ok, _} = Stub.create_notification(channel, req, @options)

      req = DeleteNotificationRequest.new(notification_id_or_name: "first")
      {:ok, _} = Stub.delete_notification(channel, req, @options)

      assert Repo.aggregate(Models.Notification, :count, :id) == 0
      assert Repo.aggregate(Models.Rule, :count, :id) == 0
      assert Repo.aggregate(Models.Pattern, :count, :id) == 0
    end
  end
end
