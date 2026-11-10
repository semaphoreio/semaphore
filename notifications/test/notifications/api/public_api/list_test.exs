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

    for missing <- [:slack, :webhook] do
      test "lists and gets a notification whose rule has no #{missing} target" do
        alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub
        alias Semaphore.Notifications.V1alpha.ListNotificationsRequest
        alias Semaphore.Notifications.V1alpha.GetNotificationRequest

        {:ok, channel} = GRPC.Stub.connect("localhost:50051")

        req = Support.Factories.Notification.api_model("no-#{unquote(missing)}")
        [rule] = req.spec.rules
        rule = %{rule | notify: Map.put(rule.notify, unquote(missing), nil)}
        req = %{req | spec: %{req.spec | rules: [rule]}}

        {:ok, created} = Stub.create_notification(channel, req, @options)

        stored = Notifications.Repo.get!(Notifications.Models.Notification, created.metadata.id)
        stored_notify = hd(stored.spec["rules"])["notify"]
        assert stored_notify[unquote(to_string(missing))] != nil

        [stored_rule] =
          Notifications.Repo.all(
            from(r in Notifications.Models.Rule, where: r.notification_id == ^created.metadata.id)
          )

        assert Map.get(stored_rule, unquote(missing)) == nil

        {:ok, res} = Stub.list_notifications(channel, ListNotificationsRequest.new(), @options)
        assert [listed] = res.notifications
        [listed_rule] = listed.spec.rules
        assert Map.get(listed_rule.notify, unquote(missing)).endpoint == ""
        assert listed_rule.notify.email == rule.notify.email

        req = GetNotificationRequest.new(notification_id_or_name: "no-#{unquote(missing)}")
        {:ok, got} = Stub.get_notification(channel, req, @options)
        assert got.spec.rules == listed.spec.rules
      end
    end
  end
end
