defmodule Notifications.Api.PublicApi.UpdateTest do
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

  describe ".run" do
    test "when the request is not authorized => return error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.UpdateNotificationRequest
      alias Notifications.Models.Notification

      GrpcMock.stub(
        RBACMock,
        :list_user_permissions,
        fn _, _ ->
          InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
        end
      )

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = UpdateNotificationRequest.new(notification_id_or_name: "non-exist")
      {:error, e} = Stub.update_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Notification non-exist not found",
               status: 5
             }
    end

    test "when not found => returns error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.UpdateNotificationRequest
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
        UpdateNotificationRequest.new(
          notification_id_or_name: "non-exist",
          notification: Support.Factories.Notification.api_model("first")
        )

      {:error, e} = Stub.update_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "Notification non-exist not found",
               status: 5
             }
    end

    test "it updates DB resources" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.UpdateNotificationRequest
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.api_model("first")
      {:ok, _} = Stub.create_notification(channel, notification, @options)

      req =
        UpdateNotificationRequest.new(
          notification_id_or_name: "first",
          notification: Support.Factories.Notification.api_model("first")
        )

      {:ok, _} = Stub.update_notification(channel, req, @options)

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

    test "it returns serialized notification" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.UpdateNotificationRequest
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.api_model("first")
      {:ok, _} = Stub.create_notification(channel, notification, @options)

      req =
        UpdateNotificationRequest.new(
          notification_id_or_name: "first",
          notification: Support.Factories.Notification.api_model("first")
        )

      {:ok, notification} = Stub.update_notification(channel, req, @options)

      assert notification.metadata.name == "first"
      refute is_nil(notification.metadata.id)
      assert notification.spec == req.notification.spec
    end

    test "when new notification is invalid => returns error with message" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.UpdateNotificationRequest
      alias Semaphore.Notifications.V1alpha.Notification
      alias Notification.{Metadata, Spec}
      alias Spec.Rule

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      notification = Support.Factories.Notification.api_model("first")
      {:ok, _} = Stub.create_notification(channel, notification, @options)

      notif =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
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
        )

      req =
        UpdateNotificationRequest.new(
          notification_id_or_name: "first",
          notification: notif
        )

      assert {:error,
              %GRPC.RPCError{
                message: "Pattern /*/ is not a valid regex statement",
                status: 3
              }} = Stub.update_notification(channel, req, @options)
    end

    test "raises error if the name is not unique" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.UpdateNotificationRequest
      alias Semaphore.Notifications.V1alpha.Notification
      alias Notification.Metadata

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      {:ok, _} =
        Stub.create_notification(
          channel,
          Support.Factories.Notification.api_model("first-notification"),
          @options
        )

      {:ok, notification_2} =
        Stub.create_notification(
          channel,
          Support.Factories.Notification.api_model("second-notification"),
          @options
        )

      notif =
        Notification.new(
          metadata: Metadata.new(name: "first-notification"),
          spec: notification_2.spec
        )

      req =
        UpdateNotificationRequest.new(
          notification_id_or_name: "second-notification",
          notification: notif
        )

      assert Stub.update_notification(channel, req, @options) ==
               {:error,
                %GRPC.RPCError{
                  message: "name 'first-notification' has already been taken",
                  status: 9
                }}
    end
  end
end
