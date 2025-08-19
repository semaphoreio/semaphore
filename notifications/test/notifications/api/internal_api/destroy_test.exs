defmodule Notifications.Api.InternalApi.DestroyTest do
  use Notifications.DataCase

  alias InternalApi.Notifications.NotificationsApi.Stub
  alias InternalApi.Notifications.DestroyRequest
  alias InternalApi.Notifications.CreateRequest
  alias InternalApi.Notifications.RequestMeta

  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()

  alias Notifications.Models

  describe ".run" do
    test "when not found => returns error" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = DestroyRequest.new(metadata: %RequestMeta{org_id: @org_id}, name: "non-existing")
      {:error, e} = Stub.destroy(channel, req)

      assert e == %GRPC.RPCError{
               message: "Notification not found",
               status: 5
             }
    end

    test "it deletes the resource by name, and everything connected" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Support.Factories.Notification.internal_api_model("first")

      {:ok, _} =
        Stub.create(channel, %CreateRequest{
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          notification: req
        })

      req = DestroyRequest.new(metadata: %RequestMeta{org_id: @org_id}, name: "first")
      {:ok, _} = Stub.destroy(channel, req)

      assert Repo.aggregate(Models.Notification, :count, :id) == 0
      assert Repo.aggregate(Models.Rule, :count, :id) == 0
      assert Repo.aggregate(Models.Pattern, :count, :id) == 0
    end
  end
end
