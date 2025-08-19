defmodule Front.Models.Notification do
  require Logger

  # public api handles authorization
  alias Semaphore.Notifications.V1alpha, as: PublicApi
  alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub

  @notifications_page_size 300

  def api_endpoint do
    Application.fetch_env!(:front, :notification_api_grpc_endpoint)
  end

  def find(notification_id, user_id, org_id) do
    Watchman.benchmark("notifications.get_notification_request.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(api_endpoint())

      request = %PublicApi.GetNotificationRequest{
        notification_id_or_name: notification_id
      }

      metadata = %{
        "x-semaphore-org-id" => org_id,
        "x-semaphore-user-id" => user_id
      }

      channel
      |> Stub.get_notification(request, metadata: metadata, timeout: 30_000)
    end)
  end

  def list(user_id, org_id) do
    Watchman.benchmark("notifications.list_notifications_request.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(api_endpoint())

      request = %PublicApi.ListNotificationsRequest{
        page_size: @notifications_page_size,
        page_token: "",
        order: PublicApi.ListNotificationsRequest.Order.value(:BY_NAME_ASC)
      }

      metadata = %{
        "x-semaphore-org-id" => org_id,
        "x-semaphore-user-id" => user_id
      }

      {:ok, response} =
        Stub.list_notifications(
          channel,
          request,
          metadata: metadata,
          timeout: 30_000
        )

      response.notifications
    end)
  end

  def create(user_id, org_id, notification_data, _metadata \\ nil) do
    Watchman.benchmark("notifications.create_notification_request.duration", fn ->
      notification = construct_notification(notification_data, user_id)

      {:ok, channel} = GRPC.Stub.connect(api_endpoint())

      metadata = %{
        "x-semaphore-org-id" => org_id,
        "x-semaphore-user-id" => user_id
      }

      channel
      |> Stub.create_notification(notification, metadata: metadata, timeout: 30_000)
    end)
  end

  def delete(id, user_id, org_id, _metadata \\ nil) do
    Watchman.benchmark("notifications.delete_notification_request.duration", fn ->
      {:ok, channel} = GRPC.Stub.connect(api_endpoint())

      req = PublicApi.DeleteNotificationRequest.new(notification_id_or_name: id)

      metadata = %{
        "x-semaphore-org-id" => org_id,
        "x-semaphore-user-id" => user_id
      }

      channel
      |> Stub.delete_notification(req, metadata: metadata, timeout: 30_000)
    end)
  end

  def update(user_id, org_id, notification_data) do
    Watchman.benchmark("notifications.update_notification_request.duration", fn ->
      notification = construct_notification(notification_data, user_id)

      {:ok, channel} = GRPC.Stub.connect(api_endpoint())

      metadata = %{
        "x-semaphore-org-id" => org_id,
        "x-semaphore-user-id" => user_id
      }

      req =
        PublicApi.UpdateNotificationRequest.new(
          notification_id_or_name: notification_data.id,
          notification: notification
        )

      channel
      |> Stub.update_notification(req, metadata: metadata, timeout: 30_000)
    end)
  end

  def construct_notification(data, creator_id) do
    rules =
      data.rules
      |> Enum.map(&construct_rule(&1))

    PublicApi.Notification.new(
      metadata: PublicApi.Notification.Metadata.new(name: data.name, creator_id: creator_id),
      spec: PublicApi.Notification.Spec.new(rules: rules)
    )
  end

  def construct_rule(data) do
    PublicApi.Notification.Spec.Rule.new(
      filter:
        PublicApi.Notification.Spec.Rule.Filter.new(
          pipelines: data.pipelines,
          projects: data.projects,
          branches: data.branches,
          results: data.results
        ),
      name: data.rule_name,
      notify:
        PublicApi.Notification.Spec.Rule.Notify.new(
          slack:
            PublicApi.Notification.Spec.Rule.Notify.Slack.new(
              endpoint: data.slack_endpoint,
              channels: data.slack_channels
            ),
          webhook:
            PublicApi.Notification.Spec.Rule.Notify.Webhook.new(
              endpoint: data.webhook_endpoint,
              secret: data.webhook_secret
            )
        )
    )
  end
end
