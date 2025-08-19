defmodule Notifications.Api.PublicApi.CreateTest do
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
    test "it creates DB resources" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Notifications.Models.Notification

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Support.Factories.Notification.api_model("first-notification")
      {:ok, _} = Stub.create_notification(channel, req, @options)

      {:ok, n} = Notification.find_by_id_or_name(@org_id, "first-notification")

      n = Repo.preload(n, :rules)

      assert n.name == "first-notification"
      assert n.creator_id == @user_id
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

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req = Support.Factories.Notification.api_model("first-notification")
      {:ok, notification} = Stub.create_notification(channel, req, @options)

      assert notification.metadata.name == "first-notification"
      refute is_nil(notification.metadata.id)
      assert notification.spec == req.spec
    end

    test "when validation fails => returns error with message" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
      alias Semaphore.Notifications.V1alpha.Notification
      alias Notification.{Metadata, Spec}
      alias Spec.Rule

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      req =
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

      assert {:error,
              %GRPC.RPCError{
                message: "Pattern /*/ is not a valid regex statement",
                status: 3
              }} = Stub.create_notification(channel, req, @options)
    end

    test "when the request is not authorized => return error" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub

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

      req = Support.Factories.Notification.api_model("first-notification")
      {:error, e} = Stub.create_notification(channel, req, @options)

      assert e == %GRPC.RPCError{
               message: "You are not authorized to create notifications",
               status: 7
             }
    end

    test "raises error if the name is not unique" do
      alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      req = Support.Factories.Notification.api_model("first-notification")
      {:ok, _} = Stub.create_notification(channel, req, @options)

      assert Stub.create_notification(channel, req, @options) ==
               {:error,
                %GRPC.RPCError{
                  message: "name 'first-notification' has already been taken",
                  status: 9
                }}
    end
  end
end
