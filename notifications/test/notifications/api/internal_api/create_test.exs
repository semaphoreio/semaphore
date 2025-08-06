defmodule Notifications.Api.InternalApi.CreateTest do
  use Notifications.DataCase
  alias InternalApi.Notifications.CreateRequest
  alias InternalApi.Notifications.RequestMeta

  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()

  describe ".run" do
    test "it creates DB resources" do
      alias InternalApi.Notifications.NotificationsApi.Stub
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = %CreateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        notification: Support.Factories.Notification.internal_api_model("first-notification")
      }

      {:ok, _} = Stub.create(channel, req)

      {:ok, n} = Notification.find_by_id_or_name(@org_id, "first-notification")

      n = Repo.preload(n, :rules)

      assert n.name == "first-notification"
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

    test "it returns serialized notification" do
      alias InternalApi.Notifications.NotificationsApi.Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = %CreateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        notification: Support.Factories.Notification.internal_api_model("first-notification")
      }

      {:ok, %{notification: notification}} = Stub.create(channel, req)

      assert notification.name == "first-notification"
      refute is_nil(notification.id)
      assert notification.rules == req.notification.rules
    end

    test "when validation fails => returns error with message" do
      alias InternalApi.Notifications.NotificationsApi.Stub
      alias InternalApi.Notifications.Notification
      alias Notification.Rule

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification =
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

      req = %CreateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        notification: notification
      }

      assert {:error,
              %GRPC.RPCError{
                message: "Pattern /*/ is not a valid regex statement",
                status: 3
              }} = Stub.create(channel, req)
    end

    test "raises error if the name is not unique" do
      alias InternalApi.Notifications.NotificationsApi.Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = %CreateRequest{
        metadata: %RequestMeta{org_id: @org_id, user_id: @creator_id},
        notification: Support.Factories.Notification.internal_api_model("first-notification")
      }

      {:ok, _} = Stub.create(channel, req)

      assert Stub.create(channel, req) ==
               {:error,
                %GRPC.RPCError{
                  message: "name 'first-notification' has already been taken",
                  status: 9
                }}
    end
  end
end
