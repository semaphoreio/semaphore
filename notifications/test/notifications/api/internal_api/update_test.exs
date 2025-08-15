defmodule Notifications.Api.InternalApi.UpdateTest do
  use Notifications.DataCase

  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()

  alias InternalApi.Notifications.NotificationsApi.Stub
  alias InternalApi.Notifications.UpdateRequest
  alias InternalApi.Notifications.CreateRequest
  alias InternalApi.Notifications.RequestMeta

  describe ".run" do
    test "when not found => returns error" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = %UpdateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        name: "non-exist",
        notification: Support.Factories.Notification.internal_api_model("first")
      }

      {:error, e} = Stub.update(channel, req)

      assert e == %GRPC.RPCError{
               message: "Notification not found",
               status: 5
             }
    end

    test "it updates DB resources" do
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.internal_api_model("first")

      {:ok, _} =
        Stub.create(channel, %CreateRequest{
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          notification: notification
        })

      req = %UpdateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        name: "first",
        notification: Support.Factories.Notification.internal_api_model("first")
      }

      {:ok, _} = Stub.update(channel, req)

      {:ok, n} = Notification.find_by_id_or_name(@org_id, "first")

      n = Repo.preload(n, :rules)

      assert n.name == "first"
      assert length(n.rules) == 1

      rule = hd(n.rules)
      rule = Repo.preload(rule, :patterns)

      assert rule.name == "Example Rule"

      assert rule.slack == %{
               "channels" => [
                 "#general",
                 "#product-hq"
               ],
               "endpoint" => "https://slack.com/api/dsasdf3243/34123412h1j2h34kj2",
               "message" => "Slack notification!",
               "status" => "ACTIVE"
             }

      assert rule.email == %{
               "bcc" => [
                 "devs@example.com"
               ],
               "cc" => [
                 "devops@example.com"
               ],
               "content" => "Email notification 101",
               "subject" => "Hi there",
               "status" => "ACTIVE"
             }

      assert rule.webhook == %{
               "action" => "POST",
               "endpoint" => "https://githu.com/api/comments",
               "retries" => 0,
               "timeout" => 500,
               "status" => "ACTIVE",
               "secret" => "B7L2XRJ12"
             }

      assert length(rule.patterns) == 8

      assert Enum.find(rule.patterns, fn p ->
               p.type == "project" && p.regex && p.term == "^s2-*"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "project" && !p.regex && p.term == "cli"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "branch" && p.regex && p.term == "^release-.*$"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "branch" && !p.regex && p.term == "master"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "branch" && p.regex && p.term == "^release-.*$"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "pipeline" && !p.regex && p.term == ".semaphore/semaphore.yml"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "pipeline" && p.regex && p.term == "^\.semaphore\/stg-*.yml"
             end)

      assert Enum.find(rule.patterns, fn p ->
               p.type == "block" && p.regex && p.term == ".*"
             end)
    end

    test "returs error when user_id not present in metadata" do
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.internal_api_model("first")

      {:ok, _} =
        Stub.create(channel, %CreateRequest{
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          notification: notification
        })

      req = %UpdateRequest{
        metadata: %RequestMeta{org_id: @org_id},
        name: "first",
        notification: Support.Factories.Notification.internal_api_model("first")
      }

      {:error, result} = Stub.update(channel, req)

      assert match?(%GRPC.RPCError{message: "Invalid user_id: expected a valid UUID"}, result)
    end

    test "it returns serialized notification" do
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.internal_api_model("first")

      {:ok, _} =
        Stub.create(channel, %CreateRequest{
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          notification: notification
        })

      req = %UpdateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        name: "first",
        notification: Support.Factories.Notification.internal_api_model("first")
      }

      {:ok, %{notification: notification}} = Stub.update(channel, req)

      assert notification.name == "first"
      refute is_nil(notification.id)
      assert notification.rules == req.notification.rules
    end

    test "when new notification is invalid => returns error with message" do
      alias InternalApi.Notifications.Notification
      alias Notification.Rule

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.internal_api_model("first")

      {:ok, _} =
        Stub.create(channel, %CreateRequest{
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          notification: notification
        })

      notif =
        Notification.new(
          name: "A",
          rules: [
            Rule.new(
              name: "Example Rule",
              filter:
                Rule.Filter.new(
                  projects: [
                    "/*/"
                  ]
                ),
              notify:
                Rule.Notify.new(
                  slack:
                    Rule.Notify.Slack.new(
                      endpoint: "https://slack.com/api/dsasdf3243/34123412h1j2h34kj2",
                      channels: [
                        "#general",
                        "#product-hq"
                      ],
                      message: "Slack notification!"
                    )
                )
            )
          ]
        )

      req =
        UpdateRequest.new(
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          name: "first",
          notification: notif
        )

      assert {:error,
              %GRPC.RPCError{
                message: "Pattern /*/ is not a valid regex statement",
                status: 3
              }} = Stub.update(channel, req)
    end

    test "raises error if the name is not unique" do
      alias InternalApi.Notifications.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, _} =
        Stub.create(
          channel,
          %CreateRequest{
            metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
            notification: Support.Factories.Notification.internal_api_model("first-notification")
          }
        )

      {:ok, %{notification: notification_2}} =
        Stub.create(
          channel,
          %CreateRequest{
            metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
            notification: Support.Factories.Notification.internal_api_model("second-notification")
          }
        )

      notif =
        Notification.new(
          name: "first-notification",
          rules: notification_2.rules
        )

      req =
        UpdateRequest.new(
          metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
          name: "second-notification",
          notification: notif
        )

      assert Stub.update(channel, req) ==
               {:error,
                %GRPC.RPCError{
                  message: "name 'first-notification' has already been taken",
                  status: 9
                }}
    end
  end
end
