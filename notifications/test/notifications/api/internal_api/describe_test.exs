defmodule Notifications.Api.InternalApi.DescribeTest do
  use Notifications.DataCase

  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()

  alias InternalApi.Notifications.NotificationsApi.Stub
  alias InternalApi.Notifications.DescribeRequest
  alias InternalApi.Notifications.CreateRequest
  alias InternalApi.Notifications.RequestMeta

  describe ".run" do
    test "when not found => returns error" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = %DescribeRequest{
        metadata: %RequestMeta{org_id: @org_id},
        name: "non-existing"
      }

      {:error, e} = Stub.describe(channel, req)

      assert e == %GRPC.RPCError{
               message: "Notification not found",
               status: 5
             }
    end

    test "it gets the resource" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req1 = %CreateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        notification: Support.Factories.Notification.internal_api_model("first")
      }

      {:ok, _} = Stub.create(channel, req1)

      req2 = %DescribeRequest{metadata: %RequestMeta{org_id: @org_id}, name: "first"}
      {:ok, %{notification: notification}} = Stub.describe(channel, req2)

      assert notification.name == "first"
      refute is_nil(notification.id)
      assert notification.rules == req1.notification.rules
    end

    test "it gets a resource whose rule has no webhook target" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.internal_api_model("no-webhook")
      [rule] = notification.rules
      rule = %{rule | notify: %{rule.notify | webhook: nil}}

      req1 = %CreateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        notification: %{notification | rules: [rule]}
      }

      {:ok, _} = Stub.create(channel, req1)

      req2 = %DescribeRequest{metadata: %RequestMeta{org_id: @org_id}, name: "no-webhook"}
      {:ok, %{notification: described}} = Stub.describe(channel, req2)

      [described_rule] = described.rules
      assert described_rule.notify.webhook.endpoint == ""
      assert described_rule.notify.slack == rule.notify.slack
    end
  end
end
