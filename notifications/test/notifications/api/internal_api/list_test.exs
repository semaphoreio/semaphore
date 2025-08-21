defmodule Notifications.Api.InternalApi.ListTest do
  use Notifications.DataCase

  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()

  describe ".run" do
    test "it gets the resources" do
      alias InternalApi.Notifications.NotificationsApi.Stub
      alias InternalApi.Notifications.ListRequest
      alias InternalApi.Notifications.CreateRequest
      alias InternalApi.Notifications.RequestMeta

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      Enum.each(1..5, fn index ->
        req = %CreateRequest{
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          notification: Support.Factories.Notification.internal_api_model("first-#{index}")
        }

        {:ok, _} = Stub.create(channel, req)
      end)

      req = %ListRequest{metadata: %RequestMeta{org_id: @org_id}, page_size: 3}
      {:ok, res} = Stub.list(channel, req)

      assert length(res.notifications) == 3
      assert res.next_page_token != ""

      assert Enum.map(res.notifications, fn n -> n.name end) == [
               "first-1",
               "first-2",
               "first-3"
             ]

      req =
        ListRequest.new(
          metadata: %RequestMeta{org_id: @org_id},
          page_size: 3,
          page_token: res.next_page_token
        )

      {:ok, res} = Stub.list(channel, req)

      assert length(res.notifications) == 2
      assert res.next_page_token == ""

      assert Enum.map(res.notifications, fn n -> n.name end) == [
               "first-4",
               "first-5"
             ]
    end
  end
end
